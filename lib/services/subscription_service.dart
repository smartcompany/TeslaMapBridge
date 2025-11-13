import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

enum SubscriptionPurchaseState {
  idle,
  loading,
  purchasing,
  purchased,
  restored,
  error,
}

class SubscriptionService extends ChangeNotifier {
  SubscriptionService()
    : _iap = InAppPurchase.instance,
      _storage = const FlutterSecureStorage();

  static const _premiumProductId = 'com.teslamap.monthly';
  static const _premiumStorageKey = 'subscription_com_teslamap_monthly_active';

  final InAppPurchase _iap;
  final FlutterSecureStorage _storage;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  bool _isAvailable = false;
  bool _isSubscribed = false;
  bool _isLoading = false;
  bool _restoreInProgress = false;
  List<ProductDetails> _products = const [];
  PurchaseDetails? _lastPurchase;
  SubscriptionPurchaseState _purchaseState = SubscriptionPurchaseState.idle;
  String? _lastError;

  bool get isAvailable => _isAvailable;
  bool get isSubscribed => _isSubscribed;
  bool get isLoading => _isLoading;
  bool get restoreInProgress => _restoreInProgress;
  List<ProductDetails> get products => _products;
  PurchaseDetails? get lastPurchase => _lastPurchase;
  SubscriptionPurchaseState get purchaseState => _purchaseState;
  String? get lastError => _lastError;

  Future<void> initialize() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('[Subscription] Initializing');

      final storedFlag = await _storage.read(key: _premiumStorageKey);
      _isSubscribed = storedFlag == 'true';
      debugPrint('[Subscription] Stored subscription flag = $_isSubscribed');

      _isAvailable = await _iap.isAvailable();
      debugPrint('[Subscription] Store available = $_isAvailable');

      if (_isAvailable) {
        await _queryProducts();
        _purchaseSub ??= _iap.purchaseStream.listen(
          _onPurchaseUpdated,
          onError: (error) {
            _lastError = error.toString();
            _purchaseState = SubscriptionPurchaseState.error;
            debugPrint('[Subscription] Purchase stream error: $_lastError');
            notifyListeners();
          },
        );
      } else {
        _lastError = 'Store not available on this device';
        debugPrint('[Subscription] $_lastError');
      }
    } catch (error, stack) {
      _lastError = error.toString();
      debugPrint('[Subscription] Initialization failed: $error');
      debugPrint('$stack');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> disposeService() async {
    await _purchaseSub?.cancel();
    _purchaseSub = null;
  }

  Future<void> _queryProducts() async {
    debugPrint('[Subscription] Querying product $_premiumProductId');
    final response = await _iap.queryProductDetails(
      {_premiumProductId}.toSet(),
    );

    debugPrint(
      '[Subscription] Query result: '
      'error=${response.error?.message} '
      'notFound=${response.notFoundIDs} '
      'count=${response.productDetails.length}',
    );

    if (response.error != null) {
      _lastError = response.error!.message;
      _products = const [];
      _purchaseState = SubscriptionPurchaseState.error;
      debugPrint('[Subscription] Store error: $_lastError');
    } else {
      _products = response.productDetails;
      if (_products.isEmpty) {
        _lastError =
            'Product $_premiumProductId not found in App Store configuration.';
        debugPrint('[Subscription] $_lastError');
      } else {
        debugPrint(
          '[Subscription] Loaded products: '
          '${_products.map((p) => '${p.id}:${p.price}').join(', ')}',
        );
      }
    }
    notifyListeners();
  }

  Future<void> refreshProducts() async {
    await _queryProducts();
  }

  Future<void> buyMonthlyPremium() async {
    if (!_isAvailable) {
      _lastError = 'App Store unavailable';
      notifyListeners();
      return;
    }

    final product = _products.firstWhere(
      (item) => item.id == _premiumProductId,
      orElse: () => throw StateError(
        'Product $_premiumProductId not loaded. Ensure App Store product is configured.',
      ),
    );

    _purchaseState = SubscriptionPurchaseState.purchasing;
    _lastError = null;
    notifyListeners();

    PurchaseParam param;
    if (Platform.isAndroid) {
      if (product is! GooglePlayProductDetails) {
        throw StateError(
          'Expected GooglePlayProductDetails for $_premiumProductId on Android.',
        );
      }
      final offerToken = product.offerToken;
      if (offerToken == null || offerToken.isEmpty) {
        throw StateError(
          'No subscription offer token found for $_premiumProductId on Android.',
        );
      }
      param = GooglePlayPurchaseParam(
        productDetails: product,
        offerToken: offerToken,
      );
    } else {
      param = PurchaseParam(productDetails: product);
    }

    await _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restorePurchases() async {
    if (!_isAvailable || _restoreInProgress) {
      return;
    }

    _restoreInProgress = true;
    _purchaseState = SubscriptionPurchaseState.loading;
    notifyListeners();

    await _iap.restorePurchases();
  }

  Future<void> _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      _lastPurchase = purchase;
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _purchaseState = SubscriptionPurchaseState.loading;
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _handleSuccessfulPurchase(purchase);
          break;
        case PurchaseStatus.error:
          _lastError = purchase.error?.message ?? 'Purchase failed';
          _purchaseState = SubscriptionPurchaseState.error;
          break;
        case PurchaseStatus.canceled:
          _purchaseState = SubscriptionPurchaseState.idle;
          break;
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }

    _restoreInProgress = false;
    notifyListeners();
  }

  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchase) async {
    _isSubscribed = true;
    await _storage.write(key: _premiumStorageKey, value: 'true');
    _purchaseState = purchase.status == PurchaseStatus.restored
        ? SubscriptionPurchaseState.restored
        : SubscriptionPurchaseState.purchased;
    _lastError = null;

    // In production you should verify receipts server-side.
    if (kDebugMode) {
      debugPrint(
        '[Subscription] Purchase confirmed for product ${purchase.productID}',
      );
    }
  }

  Future<void> clearLocalSubscriptionFlag() async {
    _isSubscribed = false;
    await _storage.delete(key: _premiumStorageKey);
    notifyListeners();
  }

  void resetTransientState() {
    var didChange = false;

    if (_purchaseState == SubscriptionPurchaseState.loading ||
        _purchaseState == SubscriptionPurchaseState.purchasing) {
      _purchaseState = SubscriptionPurchaseState.idle;
      didChange = true;
    }

    if (_restoreInProgress) {
      _restoreInProgress = false;
      didChange = true;
    }

    if (didChange) {
      notifyListeners();
    }
  }
}

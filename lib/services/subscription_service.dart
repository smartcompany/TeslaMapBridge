import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import '../models/credit_pack_meta.dart';
import 'usage_limit_service.dart';

import '../models/purchase_mode.dart';

enum SubscriptionPurchaseState {
  idle,
  loading,
  purchasing,
  purchased,
  restored,
  error,
}

class SubscriptionService extends ChangeNotifier {
  SubscriptionService() : _iap = InAppPurchase.instance;

  // Product IDs
  static const String _subscriptionProductId = 'com.teslamap.monthly';
  static const String _oneTimeProductId = 'com.teslamap.onetime';
  Map<String, CreditPackMeta> creditPacks = {};

  final InAppPurchase _iap;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  bool _isAvailable = false;
  bool _isLoading = false;
  bool _restoreInProgress = false;
  List<ProductDetails> _products = const [];
  SubscriptionPurchaseState _purchaseState = SubscriptionPurchaseState.idle;
  String? _lastError;
  String? _processingProductId;

  bool get isAvailable => _isAvailable;
  bool get isSubscribed => () {
    switch (_purchaseState) {
      case SubscriptionPurchaseState.purchased:
      case SubscriptionPurchaseState.restored:
        return true;
      default:
        return false;
    }
  }();
  bool get isLoading => _isLoading;
  bool get restoreInProgress => _restoreInProgress;
  List<ProductDetails> get products => _products;
  SubscriptionPurchaseState get purchaseState => _purchaseState;
  String? get lastError => _lastError;
  String? get processingProductId => _processingProductId;
  PurchaseMode? _purchaseMode;
  PurchaseMode? get purchaseMode => _purchaseMode;
  bool get purchasingAvailable => _purchaseMode != null;

  /// Update purchase mode from server settings
  void updatePurchaseMode(PurchaseMode? mode) {
    if (_purchaseMode != mode) {
      _purchaseMode = mode;
      notifyListeners();
    }
  }

  /// Get product details for non-credit modes.
  /// - subscription -> returns subscription product
  /// - oneTime -> returns one-time product
  /// - creditPack -> not applicable (returns null; use creditPackProducts)
  ProductDetails? get currentNonCreditProduct {
    final mode = _purchaseMode;
    if (mode == null) return null;

    String? targetId;
    switch (mode) {
      case PurchaseMode.subscription:
        targetId = _subscriptionProductId;
        break;
      case PurchaseMode.oneTime:
        targetId = _oneTimeProductId;
        break;
      case PurchaseMode.creditPack:
        return null;
    }
    try {
      return _products.firstWhere((product) => product.id == targetId);
    } catch (_) {
      return null;
    }
  }

  Future<void> initialize() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('[Subscription] Initializing');

      _isAvailable = await _iap.isAvailable();
      debugPrint('[Subscription] Store available = $_isAvailable');

      if (_isAvailable) {
        debugPrint(
          '[Subscription] Platform: ${Platform.isIOS
              ? 'iOS'
              : Platform.isAndroid
              ? 'Android'
              : 'Other'}',
        );
        await _queryProducts();

        switch (_purchaseMode) {
          case PurchaseMode.creditPack:
            _purchaseSub ??= _iap.purchaseStream.listen(
              _onConsumablePurchaseUpdated,
              onError: (error) {
                _lastError = error.toString();
                _purchaseState = SubscriptionPurchaseState.error;
                debugPrint('[Subscription] Purchase stream error: $_lastError');
                notifyListeners();
              },
            );
            break;
          case PurchaseMode.subscription:
            _purchaseSub ??= _iap.purchaseStream.listen(
              _onPurchaseUpdated,
              onError: (error) {
                _lastError = error.toString();
                _purchaseState = SubscriptionPurchaseState.error;
                debugPrint('[Subscription] Purchase stream error: $_lastError');
                notifyListeners();
              },
            );
            await _iap.restorePurchases();
            break;
          default:
            break;
        }
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
    // Query subscription, one-time, and credit pack (consumable) products
    final productIds = {
      _subscriptionProductId,
      _oneTimeProductId,
      ...creditPacks.keys,
    };

    final response = await _iap.queryProductDetails(productIds);

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
        _lastError = 'No products found in App Store configuration.';
        debugPrint('[Subscription] $_lastError');
      } else {
        debugPrint(
          '[Subscription] Loaded products: '
          '${_products.map((p) => '${p.id}:${p.price}').join(', ')}',
        );

        // 여기서 _creditPacks 의 가격 정보를 업데이트 해야 함
        creditPacks.forEach((id, meta) {
          final product = _products.firstWhere((p) => p.id == id);
          meta.rawPrice = (product.rawPrice as num?)?.toDouble();
          meta.displayPrice = product.price;
        });
        debugPrint('[Subscription] Credit packs updated: $creditPacks');
      }
    }
    notifyListeners();
  }

  Future<void> refreshProducts() async {
    await _queryProducts();
  }

  /// Update credit pack products with meta (credits + price)
  void setCreditPackProducts(Map<String, CreditPackMeta> idToMeta) {
    creditPacks = Map<String, CreditPackMeta>.from(idToMeta);
    debugPrint('[Subscription] Credit packs map updated: $creditPacks');
  }

  /// Purchase premium based on current purchase mode
  Future<void> buyPremium() async {
    if (!_isAvailable) {
      _lastError = 'App Store unavailable';
      notifyListeners();
      return;
    }

    final productId = _subscriptionProductId;
    final product = currentNonCreditProduct;

    if (product == null) {
      throw StateError(
        'Product $_subscriptionProductId not loaded. Ensure App Store product is configured.',
      );
    }

    _purchaseState = SubscriptionPurchaseState.purchasing;
    _lastError = null;
    notifyListeners();

    PurchaseParam param;
    if (Platform.isAndroid) {
      if (product is! GooglePlayProductDetails) {
        throw StateError(
          'Expected GooglePlayProductDetails for $_subscriptionProductId on Android.',
        );
      }

      // For subscriptions, we need offerToken
      // For one-time purchases, we can use applicationUsername
      final offerToken = product.offerToken;

      if (_purchaseMode == PurchaseMode.subscription) {
        if (offerToken == null || offerToken.isEmpty) {
          throw StateError(
            'No subscription offer token found for $productId on Android.',
          );
        }
        param = GooglePlayPurchaseParam(
          productDetails: product,
          offerToken: offerToken,
        );
      } else {
        // One-time purchase on Android - no offerToken needed
        param = GooglePlayPurchaseParam(productDetails: product);
      }
    } else {
      // iOS - both subscription and one-time use PurchaseParam
      param = PurchaseParam(productDetails: product);
    }

    // Route to correct purchase API
    switch (_purchaseMode ?? PurchaseMode.oneTime) {
      case PurchaseMode.oneTime:
      case PurchaseMode.subscription:
        // Both are non-consumables from client perspective (subscription is managed by store)
        await _iap.buyNonConsumable(purchaseParam: param);
        break;
      case PurchaseMode.creditPack:
        // Consumable credits; let store consume automatically
        await _iap.buyConsumable(purchaseParam: param, autoConsume: true);
        break;
    }
  }

  /// Purchase a specific credit pack by productId
  Future<void> buyCredits(String productId) async {
    debugPrint('[Subscription] buyCredits called for: $productId');
    if (!_isAvailable) {
      debugPrint('[Subscription] App Store unavailable');
      _lastError = 'App Store unavailable';
      notifyListeners();
      return;
    }

    if (!creditPacks.keys.contains(productId)) {
      debugPrint('[Subscription] Unknown credit pack: $productId');
      throw StateError('Unknown credit pack: $productId');
    }

    final meta = creditPacks[productId];
    if (meta == null) {
      debugPrint('[Subscription] Credit pack meta not found: $productId');
      throw StateError('Credit pack $productId not found');
    }

    debugPrint(
      '[Subscription] Available products: ${products.map((p) => p.id).join(", ")}',
    );
    if (products.isEmpty) {
      debugPrint('[Subscription] No products available. Refreshing...');
      await refreshProducts();
    }

    // Wait a bit to ensure any pending purchases from restorePurchases() are processed first
    // This prevents new purchases from being treated as restored
    await Future.delayed(const Duration(milliseconds: 500));

    _processingProductId = productId;
    _purchaseState = SubscriptionPurchaseState.purchasing;
    _lastError = null;
    notifyListeners();

    final product = products.firstWhere(
      (p) => p.id == productId,
      orElse: () {
        debugPrint('[Subscription] Product not found: $productId');
        throw StateError('Product $productId not found');
      },
    );

    debugPrint(
      '[Subscription] Purchasing product: ${product.id}, price: ${product.price}',
    );

    PurchaseParam param;
    if (Platform.isAndroid) {
      if (product is! GooglePlayProductDetails) {
        throw StateError(
          'Expected GooglePlayProductDetails for $productId on Android.',
        );
      }
      param = GooglePlayPurchaseParam(productDetails: product);
    } else {
      param = PurchaseParam(productDetails: product);
    }

    debugPrint('[Subscription] Calling buyConsumable...');
    try {
      final result = await _iap.buyConsumable(
        purchaseParam: param,
        autoConsume: true,
      );
      debugPrint('[Subscription] buyConsumable completed $result');

      // 사용자가 결제 UI를 닫아 구매를 진행하지 않은 경우,
      // 추가 업데이트 콜백이 오지 않으므로 여기서 상태를 초기화한다.
      final bool noFollowUpPurchaseEvent =
          _purchaseState == SubscriptionPurchaseState.purchasing &&
          _processingProductId == productId;

      if (noFollowUpPurchaseEvent) {
        _processingProductId = null;
        _purchaseState = SubscriptionPurchaseState.idle;
        notifyListeners();
      }
    } catch (e, stackTrace) {
      debugPrint('[Subscription] buyConsumable error: $e');
      debugPrint('[Subscription] Stack trace: $stackTrace');
      _lastError = 'Purchase failed: $e';
      _purchaseState = SubscriptionPurchaseState.error;
      _processingProductId = null;
      notifyListeners();
      rethrow;
    }
  }

  /// Legacy method - kept for backward compatibility
  @Deprecated('Use buyPremium() instead')
  Future<void> buyMonthlyPremium() async {
    await buyPremium();
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
    debugPrint(
      '[Subscription] _onPurchaseUpdated called with ${purchases.length} purchases',
    );
    for (final purchase in purchases) {
      debugPrint(
        '[Subscription] Processing purchase: ${purchase.productID}, status: ${purchase.status}',
      );

      switch (purchase.status) {
        case PurchaseStatus.pending:
          _purchaseState = SubscriptionPurchaseState.loading;
          break;
        case PurchaseStatus.purchased:
          _purchaseState = SubscriptionPurchaseState.purchased;
          _lastError = null;
          if (_processingProductId == purchase.productID) {
            _processingProductId = null;
          }
          break;
        case PurchaseStatus.restored:
          _purchaseState = SubscriptionPurchaseState.restored;
          _lastError = null;
          if (_processingProductId == purchase.productID) {
            _processingProductId = null;
          }
          break;
        case PurchaseStatus.error:
          _lastError = purchase.error?.message ?? 'Purchase failed';
          _purchaseState = SubscriptionPurchaseState.error;
          if (_processingProductId == purchase.productID) {
            _processingProductId = null;
          }
          break;
        case PurchaseStatus.canceled:
          _purchaseState = SubscriptionPurchaseState.idle;
          if (_processingProductId == purchase.productID) {
            _processingProductId = null;
          }
          break;
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }

    _restoreInProgress = false;
    notifyListeners();
  }

  Future<bool> _topUpAndCompletePurchase({
    required PurchaseDetails purchase,
  }) async {
    if (purchase.status != PurchaseStatus.pending &&
        purchase.status != PurchaseStatus.restored) {
      return false;
    }

    final meta = creditPacks[purchase.productID];

    if (meta == null) {
      debugPrint(
        '[Subscription] Skipped top-up (missing credit pack metadata)',
      );
      _lastError = 'Missing credit pack metadata';
      _purchaseState = SubscriptionPurchaseState.error;
      notifyListeners();
      return false;
    }

    try {
      final usage = await UsageLimitService.shared.addCredits(meta.credits);

      debugPrint(
        '[Subscription] Top-up success: +${meta.credits} → quota=${usage.quota}',
      );

      await _iap.completePurchase(purchase);
      if (_processingProductId == purchase.productID) {
        _processingProductId = null;
      }
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('[Subscription] Top-up error: $e');
      _lastError = 'Top-up failed: $e';
      _purchaseState = SubscriptionPurchaseState.error;
      if (_processingProductId == purchase.productID) {
        _processingProductId = null;
      }
      notifyListeners();
      return false;
    }
  }

  /// Handle consumable (credit pack) purchases
  Future<void> _onConsumablePurchaseUpdated(
    List<PurchaseDetails> purchases,
  ) async {
    debugPrint(
      '[Subscription] _onConsumablePurchaseUpdated called with ${purchases.length} purchases',
    );
    for (final purchase in purchases) {
      debugPrint(
        '[Subscription] Processing consumable purchase: ${purchase.productID}, status: ${purchase.status}',
      );

      switch (purchase.status) {
        case PurchaseStatus.pending:
          _purchaseState = SubscriptionPurchaseState.loading;
          notifyListeners();
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _topUpAndCompletePurchase(purchase: purchase);
          break;

        case PurchaseStatus.error:
          _lastError = purchase.error?.message ?? 'Purchase failed';
          _purchaseState = SubscriptionPurchaseState.error;
          if (_processingProductId == purchase.productID) {
            _processingProductId = null;
          }
          notifyListeners();
          break;

        case PurchaseStatus.canceled:
          _purchaseState = SubscriptionPurchaseState.idle;
          if (_processingProductId == purchase.productID) {
            _processingProductId = null;
          }
          notifyListeners();
          break;
      }
    }
  }

  Future<void> clearLocalSubscriptionFlag() async {
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

    if (_processingProductId != null) {
      _processingProductId = null;
      didChange = true;
    }

    if (didChange) {
      notifyListeners();
    }
  }
}

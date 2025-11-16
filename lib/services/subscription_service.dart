import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import '../models/credit_pack_meta.dart';
import 'tesla_auth_service.dart';
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
  // Credit pack product IDs - provided dynamically from server settings
  Set<String> _creditPackIds = {};
  Map<String, CreditPackMeta> _creditPacks = {};

  final InAppPurchase _iap;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  bool _isAvailable = false;
  bool _isLoading = false;
  bool _restoreInProgress = false;
  List<ProductDetails> _products = const [];
  PurchaseDetails? _lastPurchase;
  SubscriptionPurchaseState _purchaseState = SubscriptionPurchaseState.idle;
  String? _lastError;

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
  PurchaseDetails? get lastPurchase => _lastPurchase;
  SubscriptionPurchaseState get purchaseState => _purchaseState;
  String? get lastError => _lastError;
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

  /// Get available credit pack product details
  List<ProductDetails> get creditPackProducts {
    if (_products.isEmpty) return const [];
    return _products
        .where((p) => _creditPackIds.contains(p.id))
        // sort by credits ascending using mapping
        .toList()
      ..sort((a, b) => _creditsForProduct(a).compareTo(_creditsForProduct(b)));
  }

  int _creditsForProduct(ProductDetails product) {
    final meta = _creditPacks[product.id];
    return meta?.credits ?? 0;
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
        _purchaseSub ??= _iap.purchaseStream.listen(
          _onPurchaseUpdated,
          onError: (error) {
            _lastError = error.toString();
            _purchaseState = SubscriptionPurchaseState.error;
            debugPrint('[Subscription] Purchase stream error: $_lastError');
            notifyListeners();
          },
        );

        debugPrint('[Subscription] Restoring purchases');
        await _iap.restorePurchases();
        debugPrint('[Subscription] end Restored purchases');
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
      ..._creditPackIds,
    };
    debugPrint('[Subscription] Querying products: $productIds');

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
        // Update stored credit pack prices from IAP results
        for (final p in _products) {
          final meta = _creditPacks[p.id];
          if (meta != null) {
            meta.rawPrice = (p.rawPrice as num?)?.toDouble();
            meta.displayPrice = p.price;
          }
        }
        for (final p in _products) {
          debugPrint(
            '[Subscription] Product detail\n'
            '  id=${p.id}\n'
            '  title=${p.title}\n'
            '  description=${p.description}\n'
            '  price=${p.price} raw=${p.rawPrice}\n',
          );
        }
      }
    }
    notifyListeners();
  }

  Future<void> refreshProducts() async {
    await _queryProducts();
  }

  /// Update credit pack product IDs (from server settings)
  void setCreditPackProductIds(Iterable<String> ids) {
    final newSet = ids.toSet();
    // avoid overlap with non-credit products
    newSet.remove(_subscriptionProductId);
    newSet.remove(_oneTimeProductId);
    final changed =
        !(newSet.length == _creditPackIds.length &&
            newSet.every(_creditPackIds.contains));
    if (changed) {
      _creditPackIds = newSet;
      debugPrint('[Subscription] Credit pack IDs updated: $_creditPackIds');
    }
  }

  /// Update credit pack products with meta (credits + price)
  void setCreditPackProducts(Map<String, CreditPackMeta> idToMeta) {
    setCreditPackProductIds(idToMeta.keys);
    _creditPacks = Map<String, CreditPackMeta>.from(idToMeta);
    debugPrint('[Subscription] Credit packs map updated: $_creditPacks');
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
    if (!_isAvailable) {
      _lastError = 'App Store unavailable';
      notifyListeners();
      return;
    }
    if (!_creditPackIds.contains(productId)) {
      throw StateError('Unknown credit pack: $productId');
    }

    final product = _products.firstWhere(
      (p) => p.id == productId,
      orElse: () => throw StateError('Credit pack $productId not loaded'),
    );

    _purchaseState = SubscriptionPurchaseState.purchasing;
    _lastError = null;
    notifyListeners();

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

    await _iap.buyConsumable(purchaseParam: param, autoConsume: true);
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
    for (final purchase in purchases) {
      _lastPurchase = purchase;
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _purchaseState = SubscriptionPurchaseState.loading;
          break;
        case PurchaseStatus.purchased:
          // If this was a credit pack, top-up quota before completing purchase
          if (_purchaseMode == PurchaseMode.creditPack) {
            try {
              final userId = await TeslaAuthService().getEmail();
              final token = await TeslaAuthService().getAccessToken();
              final meta = _creditPacks[purchase.productID];
              if (userId != null &&
                  token != null &&
                  meta != null &&
                  meta.credits > 0) {
                // Business rule: 2 credits per 1 quota unit
                final increment = (meta.credits ~/ 2);
                final usage = await UsageLimitService().addCredits(
                  userId: userId,
                  accessToken: token,
                  credits: increment,
                );
                debugPrint(
                  '[Subscription] Top-up success: +$increment → quota=${usage.quota}',
                );
              } else {
                debugPrint('[Subscription] Skipped top-up (missing user/meta)');
              }
            } catch (e) {
              _lastError = 'Top-up failed: $e';
              _purchaseState = SubscriptionPurchaseState.error;
              notifyListeners();
              // do not complete purchase on failure to top-up
              continue;
            }
          }
          _purchaseState = SubscriptionPurchaseState.purchased;
          _lastError = null;
          break;
        case PurchaseStatus.restored:
          _purchaseState = SubscriptionPurchaseState.restored;
          _lastError = null;
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

    if (didChange) {
      notifyListeners();
    }
  }
}

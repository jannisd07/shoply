import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/services/supabase_service.dart';

/// Subscription product IDs - must match App Store Connect / Google Play Console
class SubscriptionProducts {
  // Monthly subscription
  static const String monthlyId = 'shoply_premium_monthly';
  // Yearly subscription
  static const String yearlyId = 'shoply_premium_yearly';

  static const Set<String> allIds = {monthlyId, yearlyId};
}

/// Subscription status enum
enum SubscriptionStatus { unknown, notSubscribed, subscribed, expired, pending }

/// Service for handling in-app subscriptions (iOS & Android)
class SubscriptionService {
  static final SubscriptionService instance = SubscriptionService._();
  SubscriptionService._();

  final InAppPurchase _iap = InAppPurchase.instance;

  // Stream subscription for purchase updates
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // Available products from store
  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  // Products stream for reactive UI updates
  final _productsController =
      StreamController<List<ProductDetails>>.broadcast();
  Stream<List<ProductDetails>> get productsStream => _productsController.stream;

  // Current subscription status
  SubscriptionStatus _status = SubscriptionStatus.unknown;
  SubscriptionStatus get status => _status;

  // Callbacks for UI updates
  final _statusController = StreamController<SubscriptionStatus>.broadcast();
  Stream<SubscriptionStatus> get statusStream => _statusController.stream;

  // Error callback
  final _errorController = StreamController<String>.broadcast();
  Stream<String> get errorStream => _errorController.stream;

  // Loading state
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // SharedPreferences key
  static const String _subscriptionKey = 'subscription_status';
  static const String _subscriptionExpiryKey = 'subscription_expiry';

  /// Initialize the subscription service
  Future<void> initialize() async {
    debugPrint('💳 [SUBSCRIPTION] Initializing subscription service...');

    // Check if IAP is available
    final available = await _iap.isAvailable();
    if (!available) {
      debugPrint('⚠️ [SUBSCRIPTION] In-app purchases not available');
      _status = SubscriptionStatus.notSubscribed;
      _statusController.add(_status);
      await refreshStatusForCurrentUser();
      return;
    }

    // Load cached subscription status
    await _loadCachedStatus();

    // Listen to purchase updates
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: _onPurchaseStreamDone,
      onError: _onPurchaseStreamError,
    );

    // Load products from store
    await _loadProducts();

    // The account entitlement (users.subscription_*) is the source of truth.
    // No silent restorePurchases() here: StoreKit restore also returns lapsed
    // subscriptions, which would re-grant premium on every launch. Renewals
    // still arrive on purchaseStream as `purchased`; restoring is the user's
    // explicit "Restore purchases" action.
    await refreshStatusForCurrentUser();

    debugPrint('✅ [SUBSCRIPTION] Subscription service initialized');
  }

  /// Load products from the store
  Future<void> _loadProducts() async {
    debugPrint('💳 [SUBSCRIPTION] Loading products...');
    debugPrint(
      '💳 [SUBSCRIPTION] Requesting IDs: ${SubscriptionProducts.allIds}',
    );

    try {
      final stopwatch = Stopwatch()..start();
      final response = await _iap.queryProductDetails(
        SubscriptionProducts.allIds,
      );
      stopwatch.stop();

      debugPrint(
        '💳 [SUBSCRIPTION] Query took ${stopwatch.elapsedMilliseconds}ms',
      );
      debugPrint(
        '💳 [SUBSCRIPTION] Found: ${response.productDetails.length}, Not found: ${response.notFoundIDs}',
      );

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint(
          '⚠️ [SUBSCRIPTION] Products not found: ${response.notFoundIDs}',
        );
        debugPrint(
          '⚠️ [SUBSCRIPTION] Hint: Ensure IDs match App Store Connect AND StoreKit config',
        );
      }

      if (response.error != null) {
        debugPrint(
          '❌ [SUBSCRIPTION] Error loading products: ${response.error}',
        );
        debugPrint(
          '❌ [SUBSCRIPTION] Error code: ${response.error?.code}, source: ${response.error?.source}',
        );
        debugPrint(
          '❌ [SUBSCRIPTION] Error message: ${response.error?.message}',
        );
        debugPrint(
          '❌ [SUBSCRIPTION] Error details: ${response.error?.details}',
        );
        _errorController.add('Failed to load subscription options');
        return;
      }

      _products = response.productDetails;
      _productsController.add(_products);
      debugPrint('✅ [SUBSCRIPTION] Loaded ${_products.length} products');

      for (final product in _products) {
        debugPrint(
          '   - ${product.id}: ${product.title} - ${product.price} (${product.rawPrice} ${product.currencyCode})',
        );
      }

      if (_products.isEmpty &&
          response.notFoundIDs.isEmpty &&
          response.error == null) {
        debugPrint(
          '⚠️ [SUBSCRIPTION] No products AND no errors — StoreKit config may not be linked to scheme',
        );
      }
    } catch (e, st) {
      debugPrint('❌ [SUBSCRIPTION] Exception in _loadProducts: $e');
      debugPrint('❌ [SUBSCRIPTION] Stack trace: $st');
      _errorController.add('Failed to load products: $e');
    }
  }

  /// Handle purchase updates
  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    debugPrint(
      '💳 [SUBSCRIPTION] Purchase update received: ${purchaseDetailsList.length} items',
    );

    for (final purchase in purchaseDetailsList) {
      debugPrint('   - ${purchase.productID}: ${purchase.status}');

      switch (purchase.status) {
        case PurchaseStatus.pending:
          _status = SubscriptionStatus.pending;
          _statusController.add(_status);
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _handleSuccessfulPurchase(purchase);
          break;

        case PurchaseStatus.error:
          _handlePurchaseError(purchase);
          break;

        case PurchaseStatus.canceled:
          debugPrint('💳 [SUBSCRIPTION] Purchase canceled');
          _isLoading = false;
          break;
      }

      // Complete the purchase
      if (purchase.pendingCompletePurchase) {
        _iap.completePurchase(purchase);
      }
    }
  }

  /// Handle successful purchase
  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchase) async {
    debugPrint('✅ [SUBSCRIPTION] Purchase successful: ${purchase.productID}');

    _status = SubscriptionStatus.subscribed;
    _isLoading = false;

    await _activateSubscriptionForCurrentUser(purchase);

    // Cache the subscription status
    await _cacheSubscriptionStatus(
      true,
      expiry: _expiryForProduct(purchase.productID),
    );

    _statusController.add(_status);
  }

  /// Handle purchase error
  void _handlePurchaseError(PurchaseDetails purchase) {
    debugPrint('❌ [SUBSCRIPTION] Purchase error: ${purchase.error}');

    _status = SubscriptionStatus.notSubscribed;
    _isLoading = false;

    final errorMessage = purchase.error?.message ?? 'Purchase failed';
    _errorController.add(errorMessage);
    _statusController.add(_status);
  }

  void _onPurchaseStreamDone() {
    debugPrint('💳 [SUBSCRIPTION] Purchase stream closed');
    _subscription?.cancel();
  }

  void _onPurchaseStreamError(dynamic error) {
    debugPrint('❌ [SUBSCRIPTION] Purchase stream error: $error');
    _errorController.add('Purchase stream error');
  }

  /// Purchase a subscription
  Future<bool> purchaseSubscription(ProductDetails product) async {
    debugPrint('💳 [SUBSCRIPTION] Purchasing: ${product.id}');

    _isLoading = true;

    try {
      final purchaseParam = PurchaseParam(productDetails: product);

      // For subscriptions, use buyNonConsumable
      final success = await _iap.buyNonConsumable(purchaseParam: purchaseParam);

      if (!success) {
        debugPrint('❌ [SUBSCRIPTION] Purchase initiation failed');
        _isLoading = false;
        _errorController.add('Could not initiate purchase');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('❌ [SUBSCRIPTION] Purchase error: $e');
      _isLoading = false;
      _errorController.add('Purchase failed: $e');
      return false;
    }
  }

  /// Restore previous purchases (user-initiated "Restore purchases").
  ///
  /// Note: until receipts are validated server-side, a restored transaction
  /// is trusted as an active subscription for one period from now.
  Future<void> restorePurchases() async {
    debugPrint('💳 [SUBSCRIPTION] Restoring purchases...');

    _isLoading = true;
    final statusBeforeRestore = _status;

    try {
      await _iap.restorePurchases();

      // restorePurchases() returns before StoreKit has replayed the
      // transactions; give them time to arrive on purchaseStream.
      await Future.delayed(const Duration(seconds: 2));

      // If no subscription was restored, mark as not subscribed
      if (_status == SubscriptionStatus.unknown) {
        _status = SubscriptionStatus.notSubscribed;
        _statusController.add(_status);
      }

      _isLoading = false;
      debugPrint('✅ [SUBSCRIPTION] Restore complete. Status: $_status');
    } catch (e) {
      debugPrint('❌ [SUBSCRIPTION] Restore error: $e');
      _isLoading = false;
      if (statusBeforeRestore != SubscriptionStatus.subscribed) {
        _status = SubscriptionStatus.notSubscribed;
      }
      _statusController.add(_status);
    }
  }

  /// Check if user is subscribed
  bool get isSubscribed => _status == SubscriptionStatus.subscribed;

  /// Refresh entitlement state from the signed-in Supabase account.
  Future<void> refreshStatusForCurrentUser() async {
    final user = SupabaseService.instance.currentUser;
    if (user == null) {
      _status = SubscriptionStatus.notSubscribed;
      await _cacheSubscriptionStatus(false);
      _statusController.add(_status);
      return;
    }

    try {
      final response = await SupabaseService.instance.client
          .from('users')
          .select('subscription_status, subscription_expires_at')
          .eq('id', user.id)
          .maybeSingle();

      final subscriptionStatus = response?['subscription_status'] as String?;
      final expiry = _parseExpiry(response?['subscription_expires_at']);
      final hasAccountPremium = _isRemoteSubscriptionActive(
        subscriptionStatus,
        expiry,
      );

      if (hasAccountPremium) {
        _status = SubscriptionStatus.subscribed;
        await _cacheSubscriptionStatus(true, expiry: expiry);
        debugPrint('✅ [SUBSCRIPTION] Account entitlement active');
      } else {
        _status = _status == SubscriptionStatus.pending
            ? SubscriptionStatus.pending
            : SubscriptionStatus.notSubscribed;
        await _cacheSubscriptionStatus(false);
        debugPrint('💳 [SUBSCRIPTION] No active account entitlement');
      }

      _statusController.add(_status);
    } catch (e) {
      debugPrint('⚠️ [SUBSCRIPTION] Could not refresh account entitlement: $e');
      _statusController.add(_status);
    }
  }

  /// Cache subscription status locally
  Future<void> _cacheSubscriptionStatus(
    bool isSubscribed, {
    DateTime? expiry,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_subscriptionKey, isSubscribed);

    if (isSubscribed) {
      // Cache expiry date (30 days for monthly, 365 for yearly)
      final expiryDate = expiry ?? DateTime.now().add(const Duration(days: 30));
      await prefs.setString(
        _subscriptionExpiryKey,
        expiryDate.toIso8601String(),
      );
    } else {
      await prefs.remove(_subscriptionExpiryKey);
    }
  }

  Future<void> _activateSubscriptionForCurrentUser(
    PurchaseDetails purchase,
  ) async {
    final user = SupabaseService.instance.currentUser;
    if (user == null) {
      debugPrint('⚠️ [SUBSCRIPTION] Purchase restored without signed-in user');
      return;
    }

    final expiry = _expiryForProduct(purchase.productID);
    final tier = _tierForProduct(purchase.productID);
    final transactionId =
        purchase.purchaseID ??
        '${purchase.productID}-${purchase.verificationData.serverVerificationData.hashCode}';

    try {
      await SupabaseService.instance.client.rpc(
        'activate_subscription',
        params: {
          'user_uuid': user.id,
          'tier': tier,
          'transaction_id_param': transactionId,
          'platform_param': _platformForCurrentDevice(),
          'expiry_date_param': expiry.toIso8601String(),
        },
      );
      await refreshStatusForCurrentUser();
      debugPrint('✅ [SUBSCRIPTION] Account entitlement saved');
    } catch (e) {
      // No client-side fallback write to users.subscription_*: entitlements
      // must only be granted by the server-side RPC.
      debugPrint('⚠️ [SUBSCRIPTION] Could not save account entitlement: $e');
    }
  }

  bool _isRemoteSubscriptionActive(String? status, DateTime? expiry) {
    if (status != 'active' && status != 'trial') return false;
    return expiry == null || expiry.isAfter(DateTime.now());
  }

  DateTime? _parseExpiry(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  DateTime _expiryForProduct(String productId) {
    final days = productId == SubscriptionProducts.yearlyId ? 365 : 30;
    return DateTime.now().add(Duration(days: days));
  }

  String _tierForProduct(String productId) {
    return productId == SubscriptionProducts.yearlyId
        ? 'premium_yearly'
        : 'premium_monthly';
  }

  String _platformForCurrentDevice() {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => 'web',
    };
  }

  /// Load cached subscription status
  Future<void> _loadCachedStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getBool(_subscriptionKey) ?? false;

    if (cached) {
      // Check if subscription has expired
      final expiryString = prefs.getString(_subscriptionExpiryKey);
      if (expiryString != null) {
        final expiry = DateTime.tryParse(expiryString);
        if (expiry != null && expiry.isAfter(DateTime.now())) {
          _status = SubscriptionStatus.subscribed;
          debugPrint(
            '💳 [SUBSCRIPTION] Loaded cached subscription (valid until $expiry)',
          );
        } else {
          _status = SubscriptionStatus.expired;
          debugPrint('💳 [SUBSCRIPTION] Cached subscription expired');
        }
      }
    } else {
      _status = SubscriptionStatus.notSubscribed;
    }

    _statusController.add(_status);
  }

  /// Get product by ID
  ProductDetails? getProduct(String productId) {
    try {
      return _products.firstWhere((p) => p.id == productId);
    } catch (_) {
      return null;
    }
  }

  /// Get monthly product
  ProductDetails? get monthlyProduct =>
      getProduct(SubscriptionProducts.monthlyId);

  /// Get yearly product
  ProductDetails? get yearlyProduct =>
      getProduct(SubscriptionProducts.yearlyId);

  /// Retry loading products (for UI retry button)
  Future<void> retryLoadProducts() async {
    debugPrint('💳 [SUBSCRIPTION] Retrying product load...');
    await _loadProducts();
  }

  /// Dispose resources
  void dispose() {
    _subscription?.cancel();
    _statusController.close();
    _errorController.close();
    _productsController.close();
  }
}

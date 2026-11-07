import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shoply/data/services/subscription_service.dart';

/// Subscription service provider
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService.instance;
});

/// Subscription status provider - reactive to status changes
final subscriptionStatusProvider = StreamProvider<SubscriptionStatus>((ref) {
  final service = ref.watch(subscriptionServiceProvider);

  // Return a stream that starts with current status and updates
  return Stream<SubscriptionStatus>.multi((controller) {
    controller.add(service.status);
    final subscription = service.statusStream.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.onCancel = subscription.cancel;
  });
});

/// Is user subscribed provider - simple boolean check
final isSubscribedProvider = Provider<bool>((ref) {
  final statusAsync = ref.watch(subscriptionStatusProvider);
  return statusAsync.when(
    data: (status) => status == SubscriptionStatus.subscribed,
    loading: () => SubscriptionService.instance.isSubscribed,
    error: (_, __) => false,
  );
});

/// Available products provider - reactive to product loading
final subscriptionProductsProvider = StreamProvider<List<ProductDetails>>((
  ref,
) async* {
  final service = ref.watch(subscriptionServiceProvider);

  // Emit current products immediately
  yield service.products;

  // Then listen for updates from the store
  await for (final products in service.productsStream) {
    yield products;
  }
});

/// Subscription error provider
final subscriptionErrorProvider = StreamProvider<String>((ref) {
  final service = ref.watch(subscriptionServiceProvider);
  return service.errorStream;
});

/// Subscription state notifier for managing purchases
class SubscriptionNotifier
    extends StateNotifier<AsyncValue<SubscriptionStatus>> {
  final SubscriptionService _service;
  StreamSubscription<SubscriptionStatus>? _statusSubscription;

  SubscriptionNotifier(this._service) : super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    // Set initial state
    state = AsyncValue.data(_service.status);

    // Listen to status changes
    _statusSubscription = _service.statusStream.listen((status) {
      state = AsyncValue.data(status);
    });
  }

  /// Starts a purchase; returns whether the store sheet opened. The state
  /// keeps the current status meanwhile — the outcome arrives through
  /// [SubscriptionService.statusStream], and a cancelled sheet emits nothing,
  /// so switching to loading here would never be undone.
  Future<bool> purchase(ProductDetails product) async {
    try {
      return await _service.purchaseSubscription(product);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Restore purchases, then publish the resulting status (the service only
  /// emits one when the status actually changed).
  Future<void> restore() async {
    state = const AsyncValue.loading();
    await _service.restorePurchases();
    if (mounted) state = AsyncValue.data(_service.status);
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }
}

/// Subscription notifier provider
final subscriptionNotifierProvider =
    StateNotifierProvider<SubscriptionNotifier, AsyncValue<SubscriptionStatus>>(
      (ref) {
        final service = ref.watch(subscriptionServiceProvider);
        return SubscriptionNotifier(service);
      },
    );

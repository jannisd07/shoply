import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/data/models/store_flyer_model.dart';
import 'package:shoply/data/services/store_flyer_service.dart';

/// Provider für aktive Prospekte mit Auto-Refresh
final activeFlyersProvider = FutureProvider.autoDispose<List<StoreFlyerModel>>((ref) async {
  // Auto-Refresh alle 60 Minuten
  final timer = ref.watch(flyerRefreshTimerProvider);
  
  return await StoreFlyerService.getActiveFlyers();
});

/// Provider für spezifische Kette
final flyersForChainProvider = FutureProvider.autoDispose.family<List<StoreFlyerModel>, String>(
  (ref, chain) async {
    return await StoreFlyerService.getFlyersForChain(chain);
  },
);

/// Timer Provider für automatisches Refresh (alle 60 Minuten)
final flyerRefreshTimerProvider = StreamProvider<int>((ref) {
  return Stream.periodic(
    const Duration(minutes: 60),
    (count) => count,
  );
});

/// Provider für manuelles Refresh
final flyerRefreshProvider = Provider<void>((ref) {
  StoreFlyerService.clearCache();
  ref.invalidate(activeFlyersProvider);
});

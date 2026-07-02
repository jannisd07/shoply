import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/data/models/expense_split.dart';
import 'package:shoply/data/services/expense_split_service.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/lists_provider.dart';

final expenseSplitServiceProvider = Provider<ExpenseSplitService>((ref) {
  return ExpenseSplitService.instance;
});

/// Splits for one completed trip (empty list if the trip hasn't been split).
final tripSplitsProvider =
    FutureProvider.autoDispose.family<List<ExpenseSplit>, String>(
  (ref, historyId) async {
    final service = ref.watch(expenseSplitServiceProvider);
    return service.getSplitsForHistory(historyId);
  },
);

/// Members of a list, for the split-participant picker. Returns raw maps
/// with a joined `user` object, matching `ListRepository.getListMembers`.
final splitCandidateMembersProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, listId) async {
    final repo = ref.watch(listRepositoryProvider);
    return repo.getListMembers(listId);
  },
);

/// Trips the current user paid for that still have unpaid participants.
final tripsAwaitingPaymentToMeProvider =
    FutureProvider.autoDispose<List<TripSplitSummary>>((ref) async {
  final authUser = await ref.watch(authUserProvider.future);
  if (authUser == null) return const [];
  final service = ref.watch(expenseSplitServiceProvider);
  return service.getTripsAwaitingPaymentToMe();
});

/// Trips where the current user still owes their share to someone else.
final tripsIOweProvider =
    FutureProvider.autoDispose<List<TripSplitSummary>>((ref) async {
  final authUser = await ref.watch(authUserProvider.future);
  if (authUser == null) return const [];
  final service = ref.watch(expenseSplitServiceProvider);
  return service.getTripsIOwe();
});

/// Combined count of unpaid-split trips relevant to the current user, for
/// the home-screen status banner badge.
final pendingSplitsCountProvider = Provider.autoDispose<int>((ref) {
  final owedToMe =
      ref.watch(tripsAwaitingPaymentToMeProvider).valueOrNull ?? const [];
  final iOwe = ref.watch(tripsIOweProvider).valueOrNull ?? const [];
  return owedToMe.length + iOwe.length;
});

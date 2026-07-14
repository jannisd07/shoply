import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/data/models/diet_challenge.dart';
import 'package:shoply/data/services/diet_challenge_service.dart';
import 'package:shoply/presentation/state/auth_provider.dart';

final dietChallengeServiceProvider = Provider<DietChallengeService>((ref) {
  return DietChallengeService.instance;
});

/// Currently active challenges (auto-closes any that just passed their
/// fixed target end date — see [DietChallengeService.getActiveChallenges]).
final activeChallengesProvider = FutureProvider.autoDispose<List<DietChallenge>>((ref) async {
  final authUser = await ref.watch(authUserProvider.future);
  if (authUser == null) return [];
  final service = ref.watch(dietChallengeServiceProvider);
  return service.getActiveChallenges();
});

/// Completed/abandoned challenges, most recent first.
final challengeHistoryProvider = FutureProvider.autoDispose<List<DietChallenge>>((ref) async {
  final authUser = await ref.watch(authUserProvider.future);
  if (authUser == null) return [];
  final service = ref.watch(dietChallengeServiceProvider);
  return service.getHistory();
});

void invalidateChallenges(WidgetRef ref) {
  ref.invalidate(activeChallengesProvider);
  ref.invalidate(challengeHistoryProvider);
}

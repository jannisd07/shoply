import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/data/models/diet_challenge.dart';
import 'package:shoply/data/services/diet_challenge_service.dart';
import 'package:shoply/presentation/state/auth_provider.dart';

final dietChallengeServiceProvider = Provider<DietChallengeService>((ref) {
  return DietChallengeService.instance;
});

/// Currently running challenges; fixed ones past their end are shown in the
/// history instead (the server closes them on its schedule, see
/// [DietChallengeService.getActiveChallenges]).
final activeChallengesProvider = FutureProvider.autoDispose<List<DietChallenge>>((ref) async {
  if (ref.watch(authUserIdProvider) == null) return [];
  final service = ref.watch(dietChallengeServiceProvider);
  return service.getActiveChallenges();
});

/// Completed/abandoned challenges, most recent first.
final challengeHistoryProvider = FutureProvider.autoDispose<List<DietChallenge>>((ref) async {
  if (ref.watch(authUserIdProvider) == null) return [];
  final service = ref.watch(dietChallengeServiceProvider);
  return service.getHistory();
});

void invalidateChallenges(WidgetRef ref) {
  ref.invalidate(activeChallengesProvider);
  ref.invalidate(challengeHistoryProvider);
}

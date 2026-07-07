import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/data/services/avo_nudge_service.dart';
import 'package:shoply/presentation/state/auth_provider.dart';

/// Avo's restock suggestions for the home screen card.
/// autoDispose so a fresh visit to home recomputes against current lists.
final restockSuggestionsProvider =
    FutureProvider.autoDispose<List<RestockSuggestion>>((ref) async {
  final authUser = await ref.watch(authUserProvider.future);
  if (authUser == null) return const [];
  return AvoNudgeService.instance.getRestockSuggestions(limit: 3);
});

/// Rhythm items currently on offer nearby ("Milch: −23 % bei Lidl"), for the
/// same home card. Backed by a 6h persistent cache in [AvoNudgeService], so
/// watching this does not hit the offers API on every home visit.
final offerNudgesProvider =
    FutureProvider.autoDispose<List<OfferNudge>>((ref) async {
  final authUser = await ref.watch(authUserProvider.future);
  if (authUser == null) return const [];
  return AvoNudgeService.instance.getOfferNudges(limit: 2);
});

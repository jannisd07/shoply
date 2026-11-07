import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/services/split_nudge_cache_service.dart';
import 'package:shoply/presentation/screens/history/widgets/split_cost_sheet.dart';
import 'package:shoply/presentation/screens/home/widgets/nudge_card.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/expense_split_provider.dart';

/// Home-screen card connecting shopping history + cost splitting (Feature 2)
/// to the highest-traffic screen in the app: "Split [list]'s trip with your
/// group?" — the brief's own cross-feature example. Renders nothing when
/// there's no recent, still-unsplit, genuinely shared trip. Dismissible for
/// this exact trip; a new completed trip always surfaces normally.
class SplitTripNudgeCard extends ConsumerWidget {
  const SplitTripNudgeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidate = ref.watch(unsplitTripNudgeProvider).valueOrNull;
    if (candidate == null) return const SizedBox.shrink();

    return NudgeCard(
      icon: Icons.people_outline,
      title: context.tr(
        'split_trip_nudge_title',
        params: {'list': candidate.listName},
      ),
      subtitle: candidate.totalCost != null
          ? context.tr(
              'split_trip_nudge_subtitle_amount',
              params: {'amount': candidate.totalCost!.toStringAsFixed(2)},
            )
          : context.tr('split_trip_nudge_subtitle_no_amount'),
      onTap: () {
        final userId = ref.read(authUserProvider).valueOrNull?.id ?? '';
        showSplitCostSheet(
          context,
          ref,
          entry: ShoppingHistory(
            id: candidate.historyId,
            userId: userId,
            listId: candidate.listId,
            listName: candidate.listName,
            totalItems: candidate.totalItems,
            completedAt: candidate.completedAt,
            totalCost: candidate.totalCost,
          ),
        );
      },
      onDismiss: () async {
        await SplitNudgeCacheService.instance.dismiss(candidate.historyId);
        ref.invalidate(unsplitTripNudgeProvider);
      },
    );
  }
}

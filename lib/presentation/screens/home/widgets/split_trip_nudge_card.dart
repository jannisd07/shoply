import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/app_dimensions.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/services/split_nudge_cache_service.dart';
import 'package:shoply/presentation/screens/history/widgets/split_cost_sheet.dart';
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

    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final accent = AppColors.accentColor(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.screenHorizontalPadding,
        8,
        AppDimensions.screenHorizontalPadding,
        0,
      ),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
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
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border(context)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.people_outline, size: 15, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(
                        'split_trip_nudge_title',
                        params: {'list': candidate.listName},
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: textPrimary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      candidate.totalCost != null
                          ? context.tr(
                              'split_trip_nudge_subtitle_amount',
                              params: {
                                'amount': candidate.totalCost!.toStringAsFixed(2),
                              },
                            )
                          : context.tr('split_trip_nudge_subtitle_no_amount'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: textSecondary),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () async {
                  HapticFeedback.selectionClick();
                  await SplitNudgeCacheService.instance
                      .dismiss(candidate.historyId);
                  ref.invalidate(unsplitTripNudgeProvider);
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded, size: 16, color: textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

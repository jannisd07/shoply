import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/app_dimensions.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/services/home_price_comparison_cache_service.dart';
import 'package:shoply/presentation/providers/price_comparison_provider.dart';

/// Home-screen card connecting price comparison (Feature 1) to the
/// highest-traffic screen in the app: "This list is €X cheaper at [store]
/// than [store]." Renders nothing when there's no meaningful comparison for
/// any recently-updated list. Dismissible for this exact comparison — it
/// comes back on its own once the list or prices genuinely change.
class PriceComparisonNudgeCard extends ConsumerWidget {
  const PriceComparisonNudgeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highlight = ref.watch(homePriceHighlightProvider).valueOrNull;
    if (highlight == null) return const SizedBox.shrink();

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
          context.push(
            '/lists/${highlight.listId}?name=${Uri.encodeComponent(highlight.listName)}',
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
                child: Icon(Icons.savings_outlined, size: 15, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('home_price_highlight_title', params: {
                        'listName': highlight.listName,
                        'amount': highlight.savings.toStringAsFixed(2),
                        'cheaperStore': highlight.cheaperRetailerName,
                        'pricierStore': highlight.pricierRetailerName,
                      }),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: textPrimary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      context.tr('home_price_highlight_subtitle', params: {
                        'matched': '${highlight.matchedItemCount}',
                        'total': '${highlight.totalItemCount}',
                      }),
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
                  await HomePriceComparisonCacheService.instance
                      .dismiss(highlight.signature);
                  ref.invalidate(homePriceHighlightProvider);
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

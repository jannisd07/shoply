import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/services/home_price_comparison_cache_service.dart';
import 'package:shoply/presentation/providers/price_comparison_provider.dart';
import 'package:shoply/presentation/screens/home/widgets/nudge_card.dart';

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

    return NudgeCard(
      icon: Icons.savings_outlined,
      title: context.tr('home_price_highlight_title', params: {
        'listName': highlight.listName,
        'amount': highlight.savings.toStringAsFixed(2),
        'cheaperStore': highlight.cheaperRetailerName,
        'pricierStore': highlight.pricierRetailerName,
      }),
      subtitle: context.tr('home_price_highlight_subtitle', params: {
        'matched': '${highlight.matchedItemCount}',
        'total': '${highlight.totalItemCount}',
      }),
      onTap: () => context.push(
        '/lists/${highlight.listId}?name=${Uri.encodeComponent(highlight.listName)}',
      ),
      onDismiss: () async {
        await HomePriceComparisonCacheService.instance
            .dismiss(highlight.signature);
        ref.invalidate(homePriceHighlightProvider);
      },
    );
  }
}

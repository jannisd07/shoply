import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/data/models/recommendation_item.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/presentation/state/recommendations_provider.dart';
import 'package:shoply/presentation/widgets/recommendations/recommendation_card.dart';

class RecommendationsSection extends ConsumerWidget {
  final List<ShoppingItemModel> currentItems;
  final Function(String itemName, String? category, double? quantity) onAddItem;

  const RecommendationsSection({
    super.key,
    required this.currentItems,
    required this.onAddItem,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final isExpanded = ref.watch(recommendationsVisibilityProvider);
    final recommendationsAsync = ref.watch(recommendationsProvider(currentItems));

    return recommendationsAsync.when(
      data: (recommendations) {
        if (recommendations.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: isDarkMode 
                ? Colors.blue.shade900.withValues(alpha: 0.2) 
                : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkMode 
                  ? Colors.blue.shade700.withValues(alpha: 0.3) 
                  : Colors.blue.shade200,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              InkWell(
                onTap: () => ref.read(recommendationsVisibilityProvider.notifier).toggle(),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              isDarkMode ? Colors.blue.shade400 : Colors.blue.shade600,
                              isDarkMode ? Colors.purple.shade400 : Colors.purple.shade600,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Suggested Items',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${recommendations.length} items you might need',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Recommendations list with animation
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Column(
                  children: [
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: recommendations.map((rec) {
                          return RecommendationCard(
                            recommendation: rec,
                            onAdd: () => _handleAddItem(context, ref, rec),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
                crossFadeState: isExpanded 
                    ? CrossFadeState.showSecond 
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 300),
                sizeCurve: Curves.easeInOut,
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(), // Don't show loading state
      error: (_, __) => const SizedBox.shrink(), // Don't show error state
    );
  }

  void _handleAddItem(BuildContext context, WidgetRef ref, RecommendationItem rec) {
    // Add item to list
    onAddItem(
      rec.itemName,
      rec.category,
      rec.quantity,
    );

    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Added ${_capitalizeItemName(rec.itemName)} to list',
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Refresh recommendations (they will auto-update via provider)
    ref.invalidate(recommendationsProvider);
  }

  String _capitalizeItemName(String name) {
    if (name.isEmpty) return name;
    return name.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }
}

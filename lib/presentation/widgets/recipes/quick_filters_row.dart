import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/data/models/recipe_filter.dart';
import 'package:shoply/presentation/state/recipe_filter_provider.dart';
import 'package:shoply/presentation/widgets/recipes/quick_filter_card.dart';

class QuickFiltersRow extends ConsumerStatefulWidget {
  const QuickFiltersRow({super.key});

  @override
  ConsumerState<QuickFiltersRow> createState() => _QuickFiltersRowState();
}

class _QuickFiltersRowState extends ConsumerState<QuickFiltersRow> {

  @override
  Widget build(BuildContext context) {
    final filterState = ref.watch(recipeFilterProvider);
    final allFilters = QuickFilters.all;
    
    // Separate selected and unselected filters
    final selectedFilters = allFilters
        .where((f) => filterState.activeQuickFilters.contains(f.id))
        .toList();
    final unselectedFilters = allFilters
        .where((f) => !filterState.activeQuickFilters.contains(f.id))
        .toList();

    return SizedBox(
      height: 60,
      child: Row(
        children: [
          // Left pinned zone for selected filters
          if (selectedFilters.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.only(left: 16, right: 8, top: 10, bottom: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: selectedFilters.map((filter) {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.2, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: QuickFilterCard(
                      key: ValueKey('selected_${filter.id}'),
                      filter: filter,
                      isActive: true,
                      onTap: () => _handleFilterTap(context, ref, filter.id),
                    ),
                  );
                }).toList(),
              ),
            ),
            // Visual separator
            Container(
              width: 1,
              height: 28,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.recipeDarkBorder
                    : AppColors.recipeLightBorder,
                borderRadius: BorderRadius.circular(0.5),
              ),
            ),
          ],
          // Right scrollable zone for unselected filters
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: unselectedFilters.length,
              itemBuilder: (context, index) {
                final filter = unselectedFilters[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: animation,
                          child: child,
                        ),
                      );
                    },
                    child: QuickFilterCard(
                      key: ValueKey('unselected_${filter.id}'),
                      filter: filter,
                      isActive: false,
                      onTap: () => _handleFilterTap(context, ref, filter.id),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _handleFilterTap(BuildContext context, WidgetRef ref, String filterId) {
    // All filters available to all users
    ref.read(recipeFilterProvider.notifier).toggleQuickFilter(filterId);
  }
}

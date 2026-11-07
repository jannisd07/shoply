import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/app_dimensions.dart';
import 'package:shoply/core/constants/categories.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/utils/category_detector.dart';
import 'package:shoply/data/models/custom_category.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/presentation/providers/price_comparison_provider.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_drag_controller.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_item_tile.dart';
import 'package:shoply/presentation/state/items_provider.dart';

/// One category of the list detail screen with its items, sorted.
class ListCategoryGroup {
  final String id;
  final String name;
  final Color color;
  final bool isCustom;
  final List<ShoppingItemModel> items;

  const ListCategoryGroup({
    required this.id,
    required this.name,
    required this.color,
    required this.isCustom,
    required this.items,
  });
}

/// Groups [items] by category in the user's saved [categoryOrder].
///
/// Custom categories are always shown, even when empty. Items that point at
/// a custom category this device doesn't know (created on another device,
/// or deleted) fall back to 'other'.
List<ListCategoryGroup> groupItemsByCategory(
  List<ShoppingItemModel> items, {
  required List<CustomCategory> customCategories,
  required List<String> categoryOrder,
  required String languageCode,
}) {
  final customById = {for (final c in customCategories) c.id: c};
  final categoryMap = <String, List<ShoppingItemModel>>{
    for (final c in customCategories) c.id: [],
  };

  for (final item in items) {
    // Prefer the language-agnostic category_id, fall back to legacy name.
    var categoryId = item.categoryId ?? item.category ?? 'other';
    if (CustomCategory.isCustomId(categoryId)) {
      if (!customById.containsKey(categoryId)) categoryId = 'other';
    } else if (!Categories.allIds.contains(categoryId)) {
      categoryId = Categories.getIdByName(categoryId, languageCode) ?? 'other';
    }
    (categoryMap[categoryId] ??= []).add(item);
  }

  bool hasItems(String id) => categoryMap[id]?.isNotEmpty ?? false;

  final sortedIds = <String>[];
  if (categoryOrder.isNotEmpty) {
    // Saved order first (only categories with items, or known custom ones).
    for (final id in categoryOrder) {
      if (hasItems(id) || customById.containsKey(id)) sortedIds.add(id);
    }
    // Then any category with items that isn't in the saved order yet.
    for (final id in categoryMap.keys) {
      if (!sortedIds.contains(id) && hasItems(id)) sortedIds.add(id);
    }
  } else {
    // Custom categories first, then built-in categories that have items.
    sortedIds.addAll(customCategories.map((c) => c.id));
    for (final category in Categories.all) {
      if (hasItems(category.id)) sortedIds.add(category.id);
    }
  }

  return [
    for (final id in sortedIds)
      _buildGroup(id, categoryMap[id] ?? const [], customById, languageCode),
  ];
}

ListCategoryGroup _buildGroup(
  String id,
  List<ShoppingItemModel> items,
  Map<String, CustomCategory> customById,
  String languageCode,
) {
  // Sort items by order_index within the category.
  final sorted = [...items]
    ..sort((a, b) {
      final aIndex = a.orderIndex ?? a.sortOrder ?? 999;
      final bIndex = b.orderIndex ?? b.sortOrder ?? 999;
      return aIndex.compareTo(bIndex);
    });

  final custom = customById[id];
  if (custom != null) {
    return ListCategoryGroup(
      id: id,
      name: custom.name,
      color: custom.color,
      isCustom: true,
      items: sorted,
    );
  }
  final category = Categories.getById(id);
  return ListCategoryGroup(
    id: id,
    name: category.getName(languageCode),
    color: category.color,
    isCustom: false,
    items: sorted,
  );
}

/// A category header plus its items. The whole section accepts drops of
/// items from other categories; a drop zone after the last item lets users
/// move items to the very end.
class ListCategorySection extends ConsumerWidget {
  final ListCategoryGroup group;
  final String listId;
  final ListDragController dragController;
  final ValueChanged<ShoppingItemModel> onEditItem;

  const ListCategorySection({
    super.key,
    required this.group,
    required this.listId,
    required this.dragController,
    required this.onEditItem,
  });

  Future<void> _moveToCategory(
    WidgetRef ref,
    ShoppingItemModel item,
  ) async {
    HapticFeedback.mediumImpact();
    await ref
        .read(itemsNotifierProvider(listId).notifier)
        .updateItem(item.id, {'category_id': group.id});
    // Record preference so AI learns the user's category choice
    CategoryDetector.recordUserCategoryChange(item.name, group.name);
  }

  Future<void> _moveToEnd(WidgetRef ref, ShoppingItemModel dragged) async {
    final notifier = ref.read(itemsNotifierProvider(listId).notifier);
    HapticFeedback.lightImpact();
    if (dragController.draggedFromCategory != group.id) {
      await notifier.updateItem(dragged.id, {'category_id': group.id});
    }
    if (group.items.isNotEmpty) {
      await notifier.reorderItemAfter(dragged.id, group.items.last.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // One comparison lookup per section instead of one per row.
    final hasOpenItems = group.items.any((i) => !i.isChecked);
    final comparison = hasOpenItems
        ? ref.watch(basketComparisonProvider(listId)).valueOrNull
        : null;

    return DragTarget<ShoppingItemModel>(
      onWillAcceptWithDetails: (_) =>
          dragController.draggedFromCategory != group.id,
      onAcceptWithDetails: (details) => _moveToCategory(ref, details.data),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: isHovering
              ? BoxDecoration(
                  color: group.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: group.color.withValues(alpha: 0.5),
                    width: 2,
                  ),
                )
              : null,
          padding: isHovering ? const EdgeInsets.all(8) : EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Header - paper kicker style
              if (group.name.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(
                    top: AppDimensions.spacingLarge,
                    bottom: AppDimensions.spacingSmall,
                  ),
                  child: Text(
                    group.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ),
              if (group.items.isEmpty && group.isCustom)
                _EmptyCustomCategoryHint(isDark: isDark)
              else ...[
                for (final item in group.items)
                  DraggableListItemTile(
                    key: ValueKey(item.id),
                    item: item,
                    categoryId: group.id,
                    listId: listId,
                    dragController: dragController,
                    offer: item.isChecked
                        ? null
                        : comparison?.cheapestOfferFor(item.name.trim()),
                    onEdit: onEditItem,
                  ),
                DragTarget<ShoppingItemModel>(
                  onWillAcceptWithDetails: (details) =>
                      group.items.isEmpty ||
                      details.data.id != group.items.last.id,
                  onAcceptWithDetails: (details) =>
                      _moveToEnd(ref, details.data),
                  builder: (context, candidateData, rejectedData) =>
                      _EndDropZone(isHovering: candidateData.isNotEmpty),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _EmptyCustomCategoryHint extends StatelessWidget {
  final bool isDark;

  const _EmptyCustomCategoryHint({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : PaperColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : PaperColors.hairline,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.drag_indicator_rounded,
            size: 18,
            color: isDark ? Colors.grey.shade600 : PaperColors.faint,
          ),
          const SizedBox(width: 8),
          Text(
            context.tr('drag_items_here'),
            style: TextStyle(
              color: isDark ? Colors.grey.shade500 : PaperColors.muted,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _EndDropZone extends StatelessWidget {
  final bool isHovering;

  const _EndDropZone({required this.isHovering});

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentColor(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: isHovering ? 40 : 20,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: isHovering
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: accent.withValues(alpha: 0.4),
                width: 1.5,
              ),
            )
          : null,
      child: isHovering
          ? Center(
              child: Container(
                width: 40,
                height: 3,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            )
          : null,
    );
  }
}

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/constants/categories.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/utils/category_detector.dart';
import 'package:shoply/data/models/custom_category.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_detail_data.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_drag_controller.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/item_row.dart';

/// One aisle of the list screen with its items, sorted.
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

/// Border of an aisle while a lifted row hovers over it.
const double _hoverBorder = 2;

/// One aisle of the list (D2-Liste, Konzept 11 §1.1 item 7): the category
/// name as [SectionCaps] with the number of rows on the right, then the
/// rows in an [InsetSection].
///
/// The whole aisle accepts a row lifted in another aisle: dropping it on
/// the heading or between rows moves it to the end of this aisle and sets
/// (and learns) its category. Rows themselves take drops for a position.
class ListAisleSection extends ConsumerWidget {
  const ListAisleSection({
    super.key,
    required this.group,
    required this.listId,
    required this.rowBuilder,
    this.dragController,
  });

  final ListCategoryGroup group;
  final String listId;

  /// Builds the row of one item (a `ListItemTile`).
  final Widget Function(ShoppingItemModel item) rowBuilder;
  final ListDragController? dragController;

  Future<void> _moveHere(WidgetRef ref, ShoppingItemModel dragged) async {
    final notifier = ref.read(itemsNotifierProvider(listId).notifier);
    unawaited(AvoHaptics.selection());
    try {
      await notifier.updateItem(dragged.id, {'category_id': group.id});
      unawaited(
        CategoryDetector.recordUserCategoryChange(dragged.name, group.name),
      );
      final others = group.items.where((i) => i.id != dragged.id);
      if (others.isNotEmpty) {
        await notifier.reorderItemAfter(dragged.id, others.last.id);
      }
    } catch (e) {
      debugPrint('❌ [LIST_DETAIL] Move to aisle failed: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = group.items.length;
    final heading = SectionCaps(
      group.name,
      trailing: Semantics(
        label: context.tr(
          'list_detail_rows_count',
          params: {'count': '$count'},
        ),
        child: ExcludeSemantics(child: Text('$count')),
      ),
    );
    final rows = InsetSection(
      separatorIndent: ItemRow.separatorIndentOf(
        context,
        withThumb: listImagesShown(context, ref),
      ),
      children: [for (final item in group.items) rowBuilder(item)],
    );

    final drag = dragController;
    if (drag == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [heading, rows],
      );
    }

    return DragTarget<ShoppingItemModel>(
      // Only rows from other aisles. Asked before `onDragStarted` runs, so
      // it checks the rows instead of the controller.
      onWillAcceptWithDetails: (details) =>
          !group.items.any((item) => item.id == details.data.id),
      onAcceptWithDetails: (details) => _moveHere(ref, details.data),
      builder: (context, candidates, rejected) {
        final hovering = candidates.isNotEmpty;
        final colors = context.colors;
        final plain = context.isAccessibilityText;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            heading,
            // One structure while hovering or not, so the rows keep their
            // state (and their drop targets) when the border appears.
            Stack(
              children: [
                rows,
                if (hovering)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: plain ? 0 : AvoSpacing.screen,
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: colors.tint,
                              width: _hoverBorder,
                            ),
                            borderRadius: BorderRadius.circular(
                              plain ? 0 : AvoRadii.group,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

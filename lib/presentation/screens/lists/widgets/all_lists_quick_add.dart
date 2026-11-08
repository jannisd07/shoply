import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/presentation/screens/lists/widgets/all_lists_data.dart';
import 'package:shoply/presentation/widgets/design/home_card.dart';
import 'package:shoply/presentation/widgets/design/quick_add_tile.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';

/// Gap between tiles (D2-Home `gap: 10px`).
const double _kTileGap = 10; // D2

/// Space between the heading and the tiles (D2-Home `margin-top: 8px`).
const double _kHeadingGap = AvoSpacing.s; // D2

/// Tiles per row: four (D2), three from AX1, two from AX3 so the names keep
/// room to wrap.
int quickAddColumns(BuildContext context) {
  final category = context.typography.category;
  if (category.index >= ContentSizeCategory.ax3.index) return 2;
  if (category.isAccessibility) return 3;
  return 4;
}

/// "Schnell wieder hinzufügen" (D2-Home, D2-Komponenten): one row of
/// [QuickAddTile]s for the list of the big card, at most one row of
/// [quickAddColumns]. Renders nothing without suggestions.
class AllListsQuickAdd extends StatelessWidget {
  const AllListsQuickAdd({
    super.key,
    required this.listId,
    required this.suggestions,
    required this.onAdd,
  });

  /// The list the tiles add to (the big card's).
  final String listId;

  final List<QuickAddSuggestion> suggestions;

  /// Puts the suggestion on [listId].
  final ValueChanged<QuickAddSuggestion> onAdd;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    final columns = quickAddColumns(context);
    final shown = suggestions.take(columns).toList();
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);

    Widget tile(QuickAddSuggestion s) => QuickAddTile(
      name: s.name,
      thumb: ArticleImage(
        item: ShoppingItemModel(
          id: 'quick-add-${s.name}',
          listId: listId,
          name: s.name,
          categoryId: s.categoryId,
          createdAt: epoch,
          updatedAt: epoch,
        ),
        size: AvoSizes.thumbSmall,
        radius: AvoRadii.imageSmall,
      ),
      onTap: () => onAdd(s),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AvoSectionHeader(context.tr('list_ov_quick_add')),
        const SizedBox(height: _kHeadingGap),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < columns; i++) ...[
                  if (i > 0) const SizedBox(width: _kTileGap),
                  Expanded(
                    child: i < shown.length
                        ? tile(shown[i])
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

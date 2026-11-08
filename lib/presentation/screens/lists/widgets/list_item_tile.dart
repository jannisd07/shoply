import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/app_translations.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/utils/category_detector.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_drag_controller.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/item_row.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';

/// A full swipe deletes once the row moved this share of its width
/// (Konzept 11 §1.1: "Volles Wischen über 60 % der Breite löscht").
const double _deleteThreshold = 0.6;

/// A long press that moved less than this and was not dropped anywhere
/// opens the context menu instead of reordering (Konzept 11 §1.1).
const double _menuSlop = 10;

/// Opacity of the row left behind while it is dragged.
const double _draggedOpacity = 0.3;

/// The lifted row grows a little (Konzept 11 §1.1: "Skalierung 1,03").
const double _liftScale = 1.03;

/// Insertion line while another row hovers over this one.
const double _insertLine = 2;

/// Unit ids the item parser and the editor store (`Categories.units` plus
/// `bunch`); anything else is shown as typed.
const Set<String> _knownUnits = {
  'kg',
  'g',
  'l',
  'ml',
  'dozen',
  'pack',
  'bottle',
  'can',
  'box',
  'bunch',
};

/// Spellings of "pieces" in older rows.
const Set<String> _pieceUnits = {
  'pcs',
  'pc',
  'stk',
  'stk.',
  'st',
  'st.',
  'stück',
  'x',
  'piece',
  'pieces',
};

/// "2 St.", "1,5 l", "500 g": quantity without a trailing ",0" in the app
/// language, plus the unit (pieces when none is stored).
String formatItemQuantity(
  ShoppingItemModel item, {
  String languageCode = 'de',
}) {
  final number = NumberFormat('0.##', languageCode).format(item.quantity);
  final unit = item.unit?.trim() ?? '';
  final lower = unit.toLowerCase();
  final key = lower.isEmpty || _pieceUnits.contains(lower)
      ? 'list_detail_unit_pcs'
      : (_knownUnits.contains(lower) ? 'list_detail_unit_$lower' : null);
  if (key == null) return '$number $unit';
  return '$number ${_unitLabel(key, languageCode)}';
}

String _unitLabel(String key, String languageCode) =>
    AppTranslations.get(key, languageCode);

/// Second line of a row: quantity, note, diet warning ("500 g · für
/// Lasagne").
String itemSubtitle(BuildContext context, ShoppingItemModel item) {
  final lang = Localizations.localeOf(context).languageCode;
  final note = item.notes?.trim();
  return [
    formatItemQuantity(item, languageCode: lang),
    if (note != null && note.isNotEmpty) note,
    if (item.isDietWarning) context.tr('list_detail_diet_warning'),
  ].join(' · ');
}

/// One item of the list (Konzept 11 §1.1, §1.4): the D2 [ItemRow] with
/// Teil B's picture and offer pill.
///
/// - The leading 54 pt check it off, the rest opens the item full screen.
/// - A full swipe to the left deletes ([onDelete], the screen offers undo).
/// - A long press lifts the row: moving it reorders within the aisle or
///   moves it to another one (the category is set and learned); letting go
///   without moving opens the context menu (Bearbeiten, Löschen).
/// - VoiceOver: one element, double tap checks off, custom actions
///   "Bearbeiten" and "Löschen".
class ListItemTile extends ConsumerStatefulWidget {
  const ListItemTile({
    super.key,
    required this.item,
    required this.listId,
    required this.categoryId,
    required this.categoryName,
    required this.onToggle,
    required this.onOpen,
    required this.onDelete,
    this.dragController,
  });

  final ShoppingItemModel item;
  final String listId;

  /// The aisle the row sits in (drop target for reordering).
  final String categoryId;
  final String categoryName;
  final ValueChanged<bool> onToggle;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  /// Null: the row cannot be lifted (done rows).
  final ListDragController? dragController;

  @override
  ConsumerState<ListItemTile> createState() => _ListItemTileState();
}

class _ListItemTileState extends ConsumerState<ListItemTile> {
  double _moved = 0;

  ShoppingItemModel get _item => widget.item;

  Future<void> _onDrop(ShoppingItemModel dragged) async {
    final drag = widget.dragController;
    final notifier = ref.read(itemsNotifierProvider(widget.listId).notifier);
    unawaited(AvoHaptics.selection());
    try {
      if (drag?.draggedFromCategory != widget.categoryId) {
        await notifier.updateItem(dragged.id, {
          'category_id': widget.categoryId,
        });
        unawaited(
          CategoryDetector.recordUserCategoryChange(
            dragged.name,
            widget.categoryName,
          ),
        );
      }
      await notifier.reorderItemToPosition(dragged.id, _item.id);
    } catch (e) {
      debugPrint('❌ [LIST_DETAIL] Reorder failed: $e');
    }
  }

  void _openMenu() {
    showAvoMenu(
      context,
      items: [
        AvoMenuItem(
          label: context.tr('common_edit_item'),
          onSelected: widget.onOpen,
        ),
        const AvoMenuDivider(),
        AvoMenuItem(
          label: context.tr('list_detail_delete_item'),
          icon: AvoIcons.trash,
          destructive: true,
          onSelected: widget.onDelete,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final colors = context.colors;
    final deleteLabel = context.tr('list_detail_delete_item');
    // Without pictures (setting off, AX sizes) the row leaves no gap.
    final images = articleImagesShown(context, ref);

    final row = ItemRow(
      title: item.name,
      subtitle: itemSubtitle(context, item),
      thumb: images
          ? ArticleImage(
              item: item,
              size: AvoSizes.thumbSmall,
              radius: AvoRadii.imageSmall,
            )
          : null,
      trailing: item.isChecked
          ? null
          : ItemOfferBadge(listId: widget.listId, item: item),
      checked: item.isChecked,
      onToggle: widget.onToggle,
      onTap: widget.onOpen,
      openLabel: context.tr('common_edit_item'),
      semanticActions: {deleteLabel: widget.onDelete},
    );

    final dismissible = Dismissible(
      key: ValueKey<String>('dismiss-${item.id}'),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: _deleteThreshold},
      onUpdate: (details) {
        if (details.reached && !details.previousReached) {
          unawaited(AvoHaptics.light());
        }
      },
      onDismissed: (_) => widget.onDelete(),
      background: ColoredBox(
        color: colors.destructive,
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: AvoSpacing.xl),
            child: AvoIcon(AvoIcons.trash, color: colors.onTint),
          ),
        ),
      ),
      child: ColoredBox(color: colors.surface, child: row),
    );

    final drag = widget.dragController;
    if (drag == null) return dismissible;

    final lifted = LongPressDraggable<ShoppingItemModel>(
      data: item,
      hapticFeedbackOnStart: false,
      onDragStarted: () {
        _moved = 0;
        drag.startDrag(widget.categoryId);
      },
      onDragUpdate: (details) {
        _moved += details.delta.distance;
        drag.handleDragUpdate(context, details.globalPosition.dy);
      },
      onDragEnd: (details) {
        drag.endDrag();
        if (!details.wasAccepted && _moved < _menuSlop && mounted) _openMenu();
      },
      feedback: _DragFeedback(
        width: MediaQuery.sizeOf(context).width - 2 * AvoSpacing.screen,
        title: item.name,
        subtitle: itemSubtitle(context, item),
      ),
      childWhenDragging: Opacity(opacity: _draggedOpacity, child: row),
      child: dismissible,
    );

    return DragTarget<ShoppingItemModel>(
      onWillAcceptWithDetails: (details) => details.data.id != item.id,
      onAcceptWithDetails: (details) => _onDrop(details.data),
      builder: (context, candidates, rejected) {
        if (candidates.isEmpty) return lifted;
        return Stack(
          children: [
            lifted,
            PositionedDirectional(
              start: ItemRow.separatorIndentOf(context, withThumb: images),
              end: 0,
              top: 0,
              height: _insertLine,
              child: ColoredBox(color: colors.tint),
            ),
          ],
        );
      },
    );
  }
}

/// The lifted row under the finger: name and quantity on a raised card.
class _DragFeedback extends StatelessWidget {
  const _DragFeedback({
    required this.width,
    required this.title,
    required this.subtitle,
  });

  final double width;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Transform.scale(
      scale: _liftScale,
      child: SizedBox(
        width: width,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            borderRadius: BorderRadius.circular(AvoRadii.card),
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                blurRadius: AvoSpacing.xl,
                offset: const Offset(0, AvoSpacing.s),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AvoSpacing.l,
              vertical: AvoSpacing.m,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text(AvoTextStyle.body)),
                Text(
                  subtitle,
                  style: context.text(
                    AvoTextStyle.subhead,
                    color: colors.secondaryLabel,
                    tabular: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

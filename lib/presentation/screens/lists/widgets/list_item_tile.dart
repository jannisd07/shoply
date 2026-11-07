import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/presentation/screens/lists/widgets/item_offer_sheet.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_drag_controller.dart';
import 'package:shoply/presentation/state/items_provider.dart';

/// "2 kg" / "1.5" — quantity without a trailing ".0", plus the unit.
String formatItemQuantity(ShoppingItemModel item) {
  final quantity =
      item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity;
  final unit = item.unit;
  return unit != null && unit.isNotEmpty ? '$quantity $unit' : '$quantity';
}

/// A list row that can be dragged to another category or position,
/// swiped to delete, tapped to check (left part) or tapped to edit (right).
///
/// Each row is also a [DragTarget], so dropping another item onto it
/// reorders within the category or moves the item into this category at
/// this position.
class DraggableListItemTile extends ConsumerWidget {
  final ShoppingItemModel item;
  final String categoryId;
  final String listId;
  final ListDragController dragController;
  final StoreOffer? offer;
  final ValueChanged<ShoppingItemModel> onEdit;

  const DraggableListItemTile({
    super.key,
    required this.item,
    required this.categoryId,
    required this.listId,
    required this.dragController,
    required this.offer,
    required this.onEdit,
  });

  Future<void> _onDrop(WidgetRef ref, ShoppingItemModel dragged) async {
    final notifier = ref.read(itemsNotifierProvider(listId).notifier);
    if (dragController.draggedFromCategory == categoryId) {
      HapticFeedback.lightImpact();
      await notifier.reorderItemToPosition(dragged.id, item.id);
    } else {
      // Move into this category, then land at this item's position.
      HapticFeedback.mediumImpact();
      await notifier.updateItem(dragged.id, {'category_id': categoryId});
      await notifier.reorderItemToPosition(dragged.id, item.id);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    // The row is gone once the item leaves the list, so grab the messenger
    // before awaiting.
    final messenger = ScaffoldMessenger.of(context);
    final deletedLabel = '${item.name} ${context.tr('deleted')}';
    final failedLabel = context.tr('action_failed');
    try {
      await ref.read(itemsNotifierProvider(listId).notifier).deleteItem(item.id);
      HapticFeedback.lightImpact();
      messenger.showSnackBar(
        SnackBar(
          content: Text(deletedLabel),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ [LIST_DETAIL] Failed to delete item: $e');
      messenger.showSnackBar(SnackBar(content: Text(failedLabel)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ListItemTileContent(
      item: item,
      offer: offer,
      onToggle: () {
        HapticFeedback.selectionClick();
        ref
            .read(itemsNotifierProvider(listId).notifier)
            .toggleItemChecked(item.id, !item.isChecked);
      },
      onEdit: () {
        HapticFeedback.selectionClick();
        onEdit(item);
      },
      onOfferTap: (offer) => showItemOfferSheet(
        context,
        ref: ref,
        listId: listId,
        item: item,
        offer: offer,
      ),
    );

    return DragTarget<ShoppingItemModel>(
      onWillAcceptWithDetails: (details) => details.data.id != item.id,
      onAcceptWithDetails: (details) => _onDrop(ref, details.data),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Insertion indicator line when another item hovers here
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: isHovering ? 3 : 0,
              margin: isHovering
                  ? const EdgeInsets.symmetric(horizontal: 12, vertical: 2)
                  : EdgeInsets.zero,
              decoration: BoxDecoration(
                color: isHovering
                    ? AppColors.accentColor(context).withValues(alpha: 0.7)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            LongPressDraggable<ShoppingItemModel>(
              data: item,
              delay: const Duration(milliseconds: 300),
              onDragStarted: () {
                HapticFeedback.mediumImpact();
                dragController.startDrag(categoryId);
              },
              onDragUpdate: (details) => dragController.handleDragUpdate(
                context,
                details.globalPosition.dy,
              ),
              onDragEnd: (_) => dragController.endDrag(),
              onDraggableCanceled: (_, __) => dragController.endDrag(),
              feedback: _DragFeedback(item: item),
              childWhenDragging: Opacity(opacity: 0.3, child: content),
              child: Dismissible(
                key: Key(item.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.delete,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                confirmDismiss: (direction) async {
                  HapticFeedback.heavyImpact();
                  return true;
                },
                onDismissed: (_) => _delete(context, ref),
                child: content,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DragFeedback extends StatelessWidget {
  final ShoppingItemModel item;

  const _DragFeedback({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: MediaQuery.of(context).size.width - 64,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.accentColor(context).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.drag_indicator_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            Text(
              '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity} ${item.unit ?? ''}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Row content: left part toggles the check, right part opens the editor.
class ListItemTileContent extends StatelessWidget {
  final ShoppingItemModel item;
  final StoreOffer? offer;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final ValueChanged<StoreOffer> onOfferTap;

  const ListItemTileContent({
    super.key,
    required this.item,
    required this.offer,
    required this.onToggle,
    required this.onEdit,
    required this.onOfferTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppColors.accentColor(context);
    final textTertiary = AppColors.textTertiary(context);
    final offer = this.offer;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider(context), width: 1),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: Row(
          children: [
            // LEFT 2/3 ZONE: Tap to check/uncheck
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: onToggle,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(2, 13, 8, 13),
                  child: Row(
                    children: [
                      // Checkbox - paper circle
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: item.isChecked ? accent : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: item.isChecked ? accent : textTertiary,
                            width: 1.5,
                          ),
                        ),
                        child: item.isChecked
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 14,
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      // Item name and notes
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                decoration: item.isChecked
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationColor: textTertiary,
                                color: item.isChecked
                                    ? textTertiary
                                    : AppColors.textPrimary(context),
                              ),
                            ),
                            if (item.notes != null &&
                                item.notes!.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                item.notes!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.grey.shade500
                                      : PaperColors.muted,
                                ),
                              ),
                            ],
                            if (item.hasPrice) ...[
                              const SizedBox(height: 3),
                              Text(
                                [
                                  '${item.price!.toStringAsFixed(2)} €',
                                  if (item.priceUnit != null) item.priceUnit!,
                                  if (item.priceRetailer != null)
                                    item.priceRetailer!,
                                ].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: accent,
                                ),
                              ),
                            ],
                            if (!item.isChecked &&
                                offer != null &&
                                ItemOfferChip.isWorthShowing(item, offer))
                              ItemOfferChip(
                                item: item,
                                offer: offer,
                                onTap: () => onOfferTap(offer),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // RIGHT ZONE: Tap to edit item
            GestureDetector(
              onTap: onEdit,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 10, 16, 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatItemQuantity(item),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: item.isChecked
                            ? textTertiary
                            : AppColors.textSecondary(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.drag_indicator,
                      size: 16,
                      color: textTertiary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

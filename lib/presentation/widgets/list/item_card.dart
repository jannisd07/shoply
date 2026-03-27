import 'package:flutter/material.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/app_dimensions.dart';
import 'package:shoply/core/constants/app_text_styles.dart';
import 'package:shoply/data/models/shopping_item_model.dart';

class ItemCard extends StatelessWidget {
  final ShoppingItemModel item;
  final VoidCallback? onTap;
  final ValueChanged<bool?>? onCheckedChanged;
  final VoidCallback? onDelete;
  final bool showAddedBy;

  const ItemCard({
    super.key,
    required this.item,
    this.onTap,
    this.onCheckedChanged,
    this.onDelete,
    this.showAddedBy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppDimensions.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(26),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Item'),
            content: Text('Remove "${item.name}" from the list?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) => onDelete?.call(),
      child: Card(
        margin: const EdgeInsets.only(bottom: AppDimensions.spacingSmall),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26), // iOS 18 Style - extrem rund
          side: item.isDietWarning
              ? const BorderSide(color: AppColors.warning, width: 2)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(26),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.cardPadding,
              vertical: 12,
            ),
            child: Row(
              children: [
                // Checkbox - circular
                Checkbox(
                  value: item.isChecked,
                  onChanged: onCheckedChanged,
                  shape: const CircleBorder(),
                ),

                const SizedBox(width: 12),

                // Item Details - horizontal layout
                Expanded(
                  child: Row(
                    children: [
                      // Name
                      Expanded(
                        child: Text(
                          item.name,
                          style: AppTextStyles.bodyLarge.copyWith(
                            decoration: item.isChecked
                                ? TextDecoration.lineThrough
                                : null,
                            color: item.isChecked ? Colors.grey : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      
                      const SizedBox(width: 12),
                      
                      // Quantity
                      Text(
                        '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity}${item.unit != null ? ' ${item.unit}' : ''}',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Favorite Icon - rechts
                Icon(
                  item.notes != null && item.notes!.isNotEmpty
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: item.notes != null && item.notes!.isNotEmpty
                      ? AppColors.error
                      : Colors.grey.shade400,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shoply/core/utils/category_detector.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/extracted_deal_model.dart';
import 'package:shoply/data/services/product_matching_service.dart';
import 'package:shoply/presentation/widgets/deals/deal_badge.dart';

class ShoppingItemGridCard extends StatefulWidget {
  final ShoppingItemModel item;
  final VoidCallback? onTap;
  final ValueChanged<bool?>? onCheckedChanged;
  final VoidCallback? onDelete;

  const ShoppingItemGridCard({
    super.key,
    required this.item,
    this.onTap,
    this.onCheckedChanged,
    this.onDelete,
  });

  @override
  State<ShoppingItemGridCard> createState() => _ShoppingItemGridCardState();
}

class _ShoppingItemGridCardState extends State<ShoppingItemGridCard> {
  ExtractedDeal? _bestDeal;
  bool _isLoadingDeal = true;

  @override
  void initState() {
    super.initState();
    _loadBestDeal();
  }

  Future<void> _loadBestDeal() async {
    try {
      final deal = await ProductMatchingService.findBestDealForProduct(
        widget.item.name,
      );
      if (mounted) {
        setState(() {
          _bestDeal = deal;
          _isLoadingDeal = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingDeal = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: widget.onTap, // Jetzt für Bearbeiten
      onLongPress: widget.onDelete,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: widget.item.isChecked
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.green.withValues(alpha: 0.3),
                    Colors.green.withValues(alpha: 0.2),
                  ],
                )
              : null,
          color: widget.item.isChecked
              ? null
              : (isDarkMode
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white),
          border: Border.all(
            color: widget.item.isChecked
                ? Colors.green.withValues(alpha: 0.5)
                : (isDarkMode
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.2)),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top row: Icon and Name
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  CategoryDetector.getCategoryIcon(widget.item.category ?? ''),
                  size: 20,
                  color: widget.item.isChecked
                      ? Colors.green.shade700
                      : CategoryDetector.getCategoryColor(widget.item.category ?? ''),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.item.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      decoration: widget.item.isChecked
                          ? TextDecoration.lineThrough
                          : null,
                      color: widget.item.isChecked
                          ? Colors.grey.shade600
                          : (isDarkMode ? Colors.white : Colors.black),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Deal Badge
                if (_bestDeal != null && !_isLoadingDeal)
                  DealBadge(
                    deal: _bestDeal!,
                    compact: true,
                  ),
              ],
            ),
            
            // Deal Info (wenn vorhanden)
            if (_bestDeal != null && !_isLoadingDeal) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_offer,
                      size: 14,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${_bestDeal!.formattedDiscountedPrice} statt ${_bestDeal!.formattedOriginalPrice} bei ${_bestDeal!.supermarket}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Bottom row: Quantity and Checkbox
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (widget.item.quantity > 0)
                  Text(
                    '${widget.item.quantity % 1 == 0 ? widget.item.quantity.toInt() : widget.item.quantity} ${widget.item.unit ?? ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  )
                else
                  const SizedBox.shrink(),
                // Checkbox mit eigenem GestureDetector um Klick zu isolieren
                GestureDetector(
                  onTap: () {
                    widget.onCheckedChanged?.call(!widget.item.isChecked);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      widget.item.isChecked ? Icons.check_circle : Icons.circle_outlined,
                      color: widget.item.isChecked ? Colors.green.shade600 : Colors.grey.shade400,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

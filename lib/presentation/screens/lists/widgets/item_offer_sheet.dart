import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/presentation/state/items_provider.dart';

/// Inline chip under a list item's name surfacing the cheapest current offer
/// for that item: "save €X at [store]" when the item already has a (higher)
/// price, or "€X · [store]" when it has none yet. Tapping opens
/// [showItemOfferSheet] to review and apply the offer.
class ItemOfferChip extends StatelessWidget {
  final ShoppingItemModel item;
  final StoreOffer offer;
  final VoidCallback onTap;

  const ItemOfferChip({
    super.key,
    required this.item,
    required this.offer,
    required this.onTap,
  });

  /// A cheaper offer is only worth surfacing when it beats the item's own
  /// price by a meaningful margin (avoids "save €0.02" noise).
  static bool isWorthShowing(ShoppingItemModel item, StoreOffer? offer) {
    if (offer == null) return false;
    final ownPrice = item.price;
    if (ownPrice == null) return true;
    return ownPrice - offer.price >= 0.10;
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentColor(context);
    final savings = item.price != null ? item.price! - offer.price : null;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_offer_outlined, size: 11, color: accent),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                savings != null
                    ? context.tr('save_at_store', params: {
                        'amount': savings.toStringAsFixed(2),
                        'store': offer.retailerName,
                      })
                    : '${offer.price.toStringAsFixed(2)} € · ${offer.retailerName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet showing a live offer matched to a list item, with an action
/// to attach the offer's price/retailer/unit to the item.
Future<void> showItemOfferSheet(
  BuildContext context, {
  required WidgetRef ref,
  required String listId,
  required ShoppingItemModel item,
  required StoreOffer offer,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ItemOfferSheet(
      parentRef: ref,
      listId: listId,
      item: item,
      offer: offer,
    ),
  );
}

class _ItemOfferSheet extends StatefulWidget {
  final WidgetRef parentRef;
  final String listId;
  final ShoppingItemModel item;
  final StoreOffer offer;

  const _ItemOfferSheet({
    required this.parentRef,
    required this.listId,
    required this.item,
    required this.offer,
  });

  @override
  State<_ItemOfferSheet> createState() => _ItemOfferSheetState();
}

class _ItemOfferSheetState extends State<_ItemOfferSheet> {
  bool _applying = false;

  String? _validityLabel(BuildContext context) {
    final validTo = widget.offer.validTo;
    if (validTo == null) return null;
    final daysLeft =
        validTo.toUtc().difference(DateTime.now().toUtc()).inHours / 24;
    if (daysLeft < 0) return null;
    if (daysLeft < 1) return context.tr('offer_ends_today');
    final local = validTo.toLocal();
    final date = '${local.day}.${local.month}.';
    return context.tr('valid_until_date', params: {'date': date});
  }

  Future<void> _apply() async {
    if (_applying) return;
    setState(() => _applying = true);
    HapticFeedback.mediumImpact();
    try {
      await widget.parentRef
          .read(itemsNotifierProvider(widget.listId).notifier)
          .updateItem(widget.item.id, {
        'price': widget.offer.price,
        'price_currency': 'EUR',
        'price_retailer': widget.offer.retailerName,
        'price_unit': widget.offer.unitShortName,
        'price_updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _applying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('error_adding', params: {'error': e.toString()}),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    final item = widget.item;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final accent = AppColors.accentColor(context);
    final savings = item.price != null ? item.price! - offer.price : null;
    final validity = _validityLabel(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.divider(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            context.tr('current_offer').toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  offer.imageUrl,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 56,
                    height: 56,
                    color:
                        isDark ? const Color(0xFF2C2C2E) : PaperColors.cream,
                    child: Icon(
                      Icons.shopping_basket_outlined,
                      size: 24,
                      color: isDark
                          ? AppColors.textSecondary(context)
                          : PaperColors.creamInk,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.productName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: PaperTextStyles.serif(17, color: textPrimary),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (offer.brandName != null &&
                            offer.brandName!.isNotEmpty)
                          offer.brandName!,
                        offer.retailerName,
                        if (offer.unitShortName != null) offer.unitShortName!,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${offer.price.toStringAsFixed(2)} €',
                style: PaperTextStyles.serif(26, color: textPrimary),
              ),
              const SizedBox(width: 8),
              if (offer.regularPrice != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    context.tr(
                      'instead_of_price',
                      params: {
                        'price': offer.regularPrice!.toStringAsFixed(2),
                      },
                    ),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textTertiary(context),
                    ),
                  ),
                ),
              const Spacer(),
              if (offer.discountPercent != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '-${offer.discountPercent}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ),
            ],
          ),
          if (savings != null && savings >= 0.10) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                context.tr('swap_saves', params: {
                  'amount': savings.toStringAsFixed(2),
                  'price': item.price!.toStringAsFixed(2),
                }),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: accent,
                ),
              ),
            ),
          ],
          if (validity != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.schedule_outlined, size: 13, color: textSecondary),
                const SizedBox(width: 5),
                Text(
                  validity,
                  style: TextStyle(fontSize: 11.5, color: textSecondary),
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _applying ? null : _apply,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: PaperColors.paper,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _applying
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      context.tr('apply_offer_price'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

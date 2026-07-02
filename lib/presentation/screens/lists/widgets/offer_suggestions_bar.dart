import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/presentation/providers/price_comparison_provider.dart';

/// Top-3 live offers for the text currently typed in the add bar.
/// Paper card floating above the add bar; tap adds the product to the list.
class OfferSuggestionsBar extends ConsumerWidget {
  final String query;
  final void Function(StoreOffer offer) onSelect;

  const OfferSuggestionsBar({
    super.key,
    required this.query,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(offerSuggestionsProvider(query));
    final offers = offersAsync.valueOrNull ?? const <StoreOffer>[];
    if (offers.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
            child: Row(
              children: [
                Icon(
                  Icons.local_offer_outlined,
                  size: 12,
                  color: AppColors.accentColor(context),
                ),
                const SizedBox(width: 6),
                Text(
                  context.tr('offers_nearby').toUpperCase(),
                  style: TextStyle(
                    fontSize: 9.5,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < offers.length; i++) ...[
            if (i > 0)
              Container(
                height: 0.5,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                color: AppColors.divider(context),
              ),
            _OfferRow(
              offer: offers[i],
              onTap: () {
                HapticFeedback.lightImpact();
                onSelect(offers[i]);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _OfferRow extends StatelessWidget {
  final StoreOffer offer;
  final VoidCallback onTap;

  const _OfferRow({required this.offer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.network(
                offer.imageUrl,
                width: 38,
                height: 38,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 38,
                  height: 38,
                  color: isDark ? const Color(0xFF2C2C2E) : PaperColors.cream,
                  child: Icon(
                    Icons.shopping_basket_outlined,
                    size: 17,
                    color: isDark
                        ? AppColors.textSecondary(context)
                        : PaperColors.creamInk,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    offer.unitShortName != null
                        ? '${offer.retailerName} · ${offer.unitShortName}'
                        : offer.retailerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${offer.price.toStringAsFixed(2)} €',
                  style: PaperTextStyles.serif(
                    15,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                if (offer.oldPrice != null && offer.oldPrice! > offer.price)
                  Text(
                    '${offer.oldPrice!.toStringAsFixed(2)} €',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textTertiary(context),
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: AppColors.accentColor(context),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 16,
                color: PaperColors.paper,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

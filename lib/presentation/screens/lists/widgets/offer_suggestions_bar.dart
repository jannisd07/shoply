import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/presentation/providers/price_comparison_provider.dart';
import 'package:shoply/presentation/screens/lists/widgets/zip_code_sheet.dart';

/// Top-3 live offers for the text currently typed in the add bar.
/// Paper card floating above the add bar; tap adds the product to the list.
/// Also nudges the user to set a zip code when location isn't available yet,
/// since offer lookups have no way to pick a region without one.
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
    final zipAsync = ref.watch(userZipCodeProvider);
    if (!zipAsync.hasValue) return const SizedBox.shrink();
    // No real zip: suggestions still work through the nationwide fallback
    // zip, but nudge for a real one so prices become local.
    final needsZip = zipAsync.value == null;

    final offersAsync = ref.watch(offerSuggestionsProvider(query));
    final offers = offersAsync.valueOrNull ?? const <StoreOffer>[];
    if (offers.isEmpty) {
      if (needsZip) {
        return _ZipCodeNudge(
          onTap: () async {
            HapticFeedback.selectionClick();
            await showZipCodeSheet(context);
          },
        );
      }
      return const SizedBox.shrink();
    }

    final allOffers =
        ref.watch(offerSearchAllProvider(query)).valueOrNull ?? offers;
    final maxPrice = allOffers.isEmpty
        ? null
        : allOffers.map((o) => o.price).reduce((a, b) => a > b ? a : b);
    final savings =
        maxPrice != null ? maxPrice - offers.first.price : 0.0;
    final showSavings = allOffers.length > 1 && savings >= 0.20;

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
                Expanded(
                  child: Text(
                    context.tr('offers_nearby').toUpperCase(),
                    style: TextStyle(
                      fontSize: 9.5,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ),
                if (showSavings)
                  Text(
                    context.tr(
                      'cheapest_saves_up_to',
                      params: {'amount': savings.toStringAsFixed(2)},
                    ),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentColor(context),
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
          if (needsZip)
            GestureDetector(
              onTap: () async {
                HapticFeedback.selectionClick();
                await showZipCodeSheet(context);
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: AppColors.divider(context),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 12,
                      color: AppColors.textSecondary(context),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        context.tr('offers_nationwide_set_zip'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ZipCodeNudge extends StatelessWidget {
  final VoidCallback onTap;
  const _ZipCodeNudge({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 16,
              color: AppColors.accentColor(context),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.tr('set_zip_code_prompt'),
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textPrimary(context),
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textSecondary(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferRow extends StatelessWidget {
  final StoreOffer offer;
  final VoidCallback onTap;

  const _OfferRow({required this.offer, required this.onTap});

  /// "Ends today" / "ends in Xd" when the offer's validity window closes
  /// soon — a lightweight freshness/confidence signal for the user.
  String? _expiryLabel(BuildContext context) {
    final validTo = offer.validTo;
    if (validTo == null) return null;
    final daysLeft = validTo.toUtc().difference(DateTime.now().toUtc()).inHours / 24;
    if (daysLeft < 0 || daysLeft > 3) return null;
    if (daysLeft < 1) return context.tr('offer_ends_today');
    return context.tr('offer_ends_in_days', params: {'days': '${daysLeft.ceil()}'});
  }

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
                    offer.unitSizeLabel != null
                        ? '${offer.retailerName} · ${offer.unitSizeLabel}'
                        : offer.retailerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                  if (_expiryLabel(context) != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      _expiryLabel(context)!,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (offer.discountPercent != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentColor(context)
                              .withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '-${offer.discountPercent}%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accentColor(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      '${offer.price.toStringAsFixed(2)} €',
                      style: PaperTextStyles.serif(
                        15,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                  ],
                ),
                if (offer.regularPrice != null)
                  Text(
                    context.tr(
                      'instead_of_price',
                      params: {
                        'price': offer.regularPrice!.toStringAsFixed(2),
                      },
                    ),
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textTertiary(context),
                    ),
                  ),
                if (offer.unitPriceLabel != null)
                  Text(
                    offer.unitPriceLabel!,
                    style: TextStyle(
                      fontSize: 9.5,
                      color: AppColors.textTertiary(context),
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

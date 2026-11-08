import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/utils/diet_checker.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/providers/list_offer_prefs_provider.dart';
import 'package:shoply/presentation/providers/price_comparison_provider.dart';
import 'package:shoply/presentation/providers/region_provider.dart';
import 'package:shoply/presentation/providers/store_for_list_provider.dart';
import 'package:shoply/presentation/screens/lists/widgets/zip_code_sheet.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/items_provider.dart';

/// Height of one suggestion row. Fixed so the card shows exactly
/// [_visibleRows] rows and scrolls the remainder internally, and so the
/// list can stay lazy (a fixed extent avoids measuring every row, which
/// would eagerly build — and download the image of — every offer).
///
/// Sized for the tallest row: a 38px thumbnail, or four text lines
/// (name 13.5, price 11, Grundpreis 9.5, expiry 10 ≈ 55px) plus 16px of
/// vertical padding.
const double _rowHeight = 72;
const int _visibleRows = 3;

/// Live offers for the text currently typed in the add bar (contract 3.3).
/// Paper card floating above the add bar; tap adds the product to the list.
/// Also nudges the user to set a zip code when location isn't available yet,
/// since offer lookups have no way to pick a region without one.
///
/// Renders nothing, and asks the offers source nothing, while offers are
/// unavailable (module or kill switch) or hidden on [listId].
class OfferSuggestionsBar extends ConsumerWidget {
  /// The list the tapped offer goes to when [onSelect] is null, and whose
  /// "hide offers" choice applies. Nullable only while Teil A's
  /// `list_detail_screen.dart` still calls `OfferSuggestionsBar(query:,
  /// onSelect:)`; becomes required once A switched.
  final String? listId;
  final String query;

  /// Called after the tapped offer was added to [listId], so the host can
  /// clear its input field.
  final VoidCallback? onAdded;

  /// Old entry point of Teil A: called with the tapped offer instead of
  /// adding it to [listId]. Goes away once A switched to [onAdded].
  final void Function(StoreOffer offer)? onSelect;

  const OfferSuggestionsBar({
    super.key,
    this.listId,
    required this.query,
    this.onAdded,
    this.onSelect,
  }) : assert(listId != null || onSelect != null,
            'Without onSelect the bar needs a listId to add the offer to');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listId = this.listId;
    final visible = listId == null
        ? ref.watch(offersAvailableProvider)
        : ref.watch(offersVisibleForListProvider(listId));
    if (!visible) return const SizedBox.shrink();

    // No region: never ask the offers source, only nudge once for a zip code.
    if (!ref.watch(regionLoadedProvider)) return const SizedBox.shrink();
    if (ref.watch(regionProvider) == null) {
      return _ZipCodeNudge(
        onTap: () async {
          HapticFeedback.selectionClick();
          await showZipCodeSheet(context);
        },
      );
    }

    final offers = ref
            .watch(offerSuggestionsProvider((listId: listId, query: query)))
            .valueOrNull ??
        const <StoreOffer>[];
    if (offers.isEmpty) return const SizedBox.shrink();
    final storeName =
        listId == null ? '' : ref.watch(storeForListProvider(listId))?.name ?? '';

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
                    context.tr(
                      'offer_suggestions_header',
                      params: {'store': storeName},
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Every match is in the list, but the card keeps the height of
          // three rows — the rest is reached by scrolling inside it, so the
          // composer below never gets pushed off screen no matter how many
          // stores carry the product.
          SizedBox(
            height: offers.length <= _visibleRows
                ? offers.length * _rowHeight
                : _visibleRows * _rowHeight,
            child: Scrollbar(
              thumbVisibility: offers.length > _visibleRows,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemExtent: _rowHeight,
                itemCount: offers.length,
                physics: offers.length <= _visibleRows
                    ? const NeverScrollableScrollPhysics()
                    : const ClampingScrollPhysics(),
                itemBuilder: (context, i) => _OfferRow(
                  offer: offers[i],
                  showTopDivider: i > 0,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    final select = onSelect;
                    if (select != null) {
                      select(offers[i]);
                    } else if (listId != null) {
                      _addToList(context, ref, listId, offers[i]);
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Adds [offer] with its price to [listId], like the list screen does:
  /// the offer already carries the real product name, so no parse pass.
  Future<void> _addToList(
    BuildContext context,
    WidgetRef ref,
    String listId,
    StoreOffer offer,
  ) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    try {
      await ref.read(itemsNotifierProvider(listId).notifier).addItem(
            name: offer.productName,
            isDietWarning: user != null &&
                DietChecker.checkDietWarning(
                  offer.productName,
                  user.dietPreferences,
                ),
            price: offer.price,
            priceCurrency: 'EUR',
            priceRetailer: offer.retailerName,
            priceUnit: offer.unitSizeLabel ?? offer.unitShortName,
            priceOldValue: offer.regularPrice,
            autoParse: false,
          );
      onAdded?.call();
    } catch (e) {
      debugPrint('❌ [OFFERS] Adding the offer to the list failed: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('action_failed'))),
      );
    }
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

  /// Drawn inside the row instead of between rows, so every row occupies
  /// exactly [_rowHeight] and the 3-row viewport stays exact.
  final bool showTopDivider;

  const _OfferRow({
    required this.offer,
    required this.onTap,
    this.showTopDivider = false,
  });

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
      child: Container(
        height: _rowHeight,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: showTopDivider
            ? BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppColors.divider(context),
                    width: 0.5,
                  ),
                ),
              )
            : null,
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
                  if (offer.isBroadMatch) ...[
                    const SizedBox(height: 1),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 9.5, color: AppColors.textTertiary(context)),
                        const SizedBox(width: 3),
                        Text(
                          context.tr('similar_product_match'),
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textTertiary(context),
                          ),
                        ),
                      ],
                    ),
                  ],
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

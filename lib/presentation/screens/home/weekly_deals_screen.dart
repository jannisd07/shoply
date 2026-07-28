import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/recipe_offer_highlight.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/data/repositories/item_repository.dart';
import 'package:shoply/presentation/providers/price_comparison_provider.dart';
import 'package:shoply/presentation/screens/lists/widgets/zip_code_sheet.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/state/lists_provider.dart';

/// A common display shape both [StoreOffer] (raw search results) and
/// [RecipeIngredientOffer] (personalized matches) can render through the
/// same row/sheet widgets without either model depending on the other.
class _DealDisplay {
  final String productName;
  final String retailerName;
  final double price;
  final double? regularPrice;
  final String? unitSizeLabel;
  final String? unitPriceLabel;
  final int? discountPercent;
  final bool isBroadMatch;
  final String imageUrl;
  final DateTime? validTo;

  const _DealDisplay({
    required this.productName,
    required this.retailerName,
    required this.price,
    required this.regularPrice,
    required this.unitSizeLabel,
    required this.unitPriceLabel,
    required this.discountPercent,
    required this.isBroadMatch,
    required this.imageUrl,
    required this.validTo,
  });

  factory _DealDisplay.fromStoreOffer(StoreOffer o) => _DealDisplay(
        productName: o.productName,
        retailerName: o.retailerName,
        price: o.price,
        regularPrice: o.regularPrice,
        unitSizeLabel: o.unitSizeLabel,
        unitPriceLabel: o.unitPriceLabel,
        discountPercent: o.discountPercent,
        isBroadMatch: o.isBroadMatch,
        imageUrl: o.imageUrl,
        validTo: o.validTo,
      );

  factory _DealDisplay.fromIngredientOffer(RecipeIngredientOffer o) =>
      _DealDisplay(
        productName: o.productName,
        retailerName: o.retailerName,
        price: o.price,
        regularPrice: o.regularPrice,
        unitSizeLabel: o.unitSizeLabel,
        unitPriceLabel: o.unitPriceLabel,
        discountPercent: o.discountPercent,
        isBroadMatch: o.isBroadMatch,
        imageUrl: o.imageUrl,
        validTo: o.validTo,
      );
}

/// Browse-and-search screen for live supermarket offers (Feature 1's
/// marktguru pipeline) — the destination behind the home screen's "Angebote"
/// strip, which previously led nowhere. Defaults to real deals matching the
/// user's shopping lists; a search bar covers anything else.
class WeeklyDealsScreen extends ConsumerStatefulWidget {
  const WeeklyDealsScreen({super.key});

  @override
  ConsumerState<WeeklyDealsScreen> createState() => _WeeklyDealsScreenState();
}

class _WeeklyDealsScreenState extends ConsumerState<WeeklyDealsScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final zipAsync = ref.watch(userZipCodeProvider);
    final needsZip = zipAsync.hasValue && zipAsync.value == null;
    final searching = _query.trim().length >= 2;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, size: 22, color: textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          context.tr('weekly_deals_title'),
          style: PaperTextStyles.serif(18, color: textPrimary),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
                children: [
                  _SearchField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  if (needsZip) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () async {
                        HapticFeedback.selectionClick();
                        await showZipCodeSheet(context);
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 13, color: textSecondary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              context.tr('offers_nationwide_set_zip'),
                              style:
                                  TextStyle(fontSize: 12, color: textSecondary),
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded,
                              size: 16, color: textSecondary),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: searching
                  ? _SearchResults(query: _query.trim())
                  : const _PersonalizedDeals(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: TextStyle(fontSize: 14, color: AppColors.textPrimary(context)),
        decoration: InputDecoration(
          hintText: context.tr('search_deals_hint'),
          hintStyle: TextStyle(
              fontSize: 14, color: AppColors.textTertiary(context)),
          prefixIcon: Icon(Icons.search,
              size: 19, color: AppColors.textSecondary(context)),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close, size: 17,
                      color: AppColors.textSecondary(context)),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

class _SearchResults extends ConsumerWidget {
  final String query;
  const _SearchResults({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(offerSearchAllProvider(query));
    return offersAsync.when(
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (_, __) => _EmptyState(
        icon: Icons.wifi_off_rounded,
        text: context.tr('deals_load_error'),
      ),
      data: (offers) {
        if (offers.isEmpty) {
          return _EmptyState(
            icon: Icons.search_off_rounded,
            text: context.tr('no_deals_found'),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          itemCount: offers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _DealCard(
            display: _DealDisplay.fromStoreOffer(offers[i]),
          ),
        );
      },
    );
  }
}

class _PersonalizedDeals extends ConsumerWidget {
  const _PersonalizedDeals();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dealsAsync = ref.watch(personalizedDealsProvider);
    final textSecondary = AppColors.textSecondary(context);

    return dealsAsync.when(
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (_, __) => _EmptyState(
        icon: Icons.wifi_off_rounded,
        text: context.tr('deals_load_error'),
      ),
      data: (deals) {
        if (deals.isEmpty) {
          return _EmptyState(
            icon: Icons.local_offer_outlined,
            text: context.tr('no_personalized_deals_hint'),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          itemCount: deals.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  context.tr('deals_matching_your_lists').toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
              );
            }
            final deal = deals[i - 1];
            return _DealCard(
              display: _DealDisplay.fromIngredientOffer(deal),
              subtitleOverride: deal.ingredientName,
            );
          },
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyState({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: AppColors.textTertiary(context)),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 13.5, color: AppColors.textSecondary(context)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DealCard extends StatelessWidget {
  final _DealDisplay display;
  /// For personalized matches: which of the user's list items this offer
  /// was matched against (shown when it differs from the product name).
  final String? subtitleOverride;

  const _DealCard({required this.display, this.subtitleOverride});

  String? _expiryLabel(BuildContext context) {
    final validTo = display.validTo;
    if (validTo == null) return null;
    final daysLeft =
        validTo.toUtc().difference(DateTime.now().toUtc()).inHours / 24;
    if (daysLeft < 0 || daysLeft > 3) return null;
    if (daysLeft < 1) return context.tr('offer_ends_today');
    return context.tr('offer_ends_in_days', params: {'days': '${daysLeft.ceil()}'});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final accent = AppColors.accentColor(context);
    final expiry = _expiryLabel(context);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (_) => _AddDealSheet(display: display),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                display.imageUrl,
                width: 46,
                height: 46,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 46,
                  height: 46,
                  color: isDark ? const Color(0xFF2C2C2E) : PaperColors.cream,
                  child: Icon(Icons.shopping_basket_outlined,
                      size: 19,
                      color: isDark
                          ? AppColors.textSecondary(context)
                          : PaperColors.creamInk),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    display.productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    display.unitSizeLabel != null
                        ? '${display.retailerName} · ${display.unitSizeLabel}'
                        : display.retailerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: textSecondary),
                  ),
                  if (subtitleOverride != null &&
                      subtitleOverride!.toLowerCase() !=
                          display.productName.toLowerCase()) ...[
                    const SizedBox(height: 2),
                    Text(
                      context.tr('matched_for_item',
                          params: {'item': subtitleOverride!}),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, color: textSecondary),
                    ),
                  ],
                  if (display.isBroadMatch) ...[
                    const SizedBox(height: 2),
                    Text(
                      context.tr('similar_product_match'),
                      style: TextStyle(fontSize: 10, color: AppColors.textTertiary(context)),
                    ),
                  ],
                  if (expiry != null) ...[
                    const SizedBox(height: 2),
                    Text(expiry,
                        style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.warning)),
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
                    if (display.discountPercent != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('-${display.discountPercent}%',
                            style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w600, color: accent)),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text('${display.price.toStringAsFixed(2)} €',
                        style: PaperTextStyles.serif(14, color: textPrimary)),
                  ],
                ),
                if (display.regularPrice != null)
                  Text(
                    context.tr('instead_of_price',
                        params: {'price': display.regularPrice!.toStringAsFixed(2)}),
                    style: TextStyle(fontSize: 9.5, color: AppColors.textTertiary(context)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet to pick which list a browsed deal should be added to,
/// creating a brand-new item (unlike `showItemOfferSheet`, which updates an
/// item that already exists on a list).
class _AddDealSheet extends ConsumerStatefulWidget {
  final _DealDisplay display;
  const _AddDealSheet({required this.display});

  @override
  ConsumerState<_AddDealSheet> createState() => _AddDealSheetState();
}

class _AddDealSheetState extends ConsumerState<_AddDealSheet> {
  bool _adding = false;

  Future<void> _addTo(String listId) async {
    if (_adding) return;
    setState(() => _adding = true);
    HapticFeedback.mediumImpact();
    try {
      await ItemRepository.instance.addItem(
        listId: listId,
        name: widget.display.productName,
        price: widget.display.price,
        priceCurrency: 'EUR',
        priceRetailer: widget.display.retailerName,
        priceUnit: widget.display.unitSizeLabel,
        priceOldValue: widget.display.regularPrice,
        autoParse: false,
      );
      ref.invalidate(itemsNotifierProvider(listId));
      ref.invalidate(listsNotifierProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _adding = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('error_adding', params: {'error': e.toString()})),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final listsAsync = ref.watch(userListsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2C2C2E) : PaperColors.surface;
    final separatorColor =
        isDark ? Colors.white.withValues(alpha: 0.08) : PaperColors.hairline;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(16, 16, 16, 20 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('add_to_shopping_list'),
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context)),
          ),
          const SizedBox(height: 4),
          Text(
            widget.display.productName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary(context)),
          ),
          const SizedBox(height: 14),
          if (_adding)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CupertinoActivityIndicator()),
            )
          else
            listsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CupertinoActivityIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text('Error: $e'),
              ),
              data: (lists) {
                if (lists.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        context.tr('no_lists_yet'),
                        style: TextStyle(color: AppColors.textSecondary(context)),
                      ),
                    ),
                  );
                }
                return Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < lists.length; i++) ...[
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => _addTo(lists[i].id),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Icon(CupertinoIcons.cart_fill,
                                    size: 16, color: CupertinoColors.systemBlue),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    lists[i].name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 15,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (i < lists.length - 1)
                          Padding(
                            padding: const EdgeInsets.only(left: 42),
                            child: Container(height: 0.5, color: separatorColor),
                          ),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

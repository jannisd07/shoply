import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/data/services/user_location_service.dart';
import 'package:shoply/presentation/providers/price_comparison_provider.dart';
import 'package:shoply/presentation/state/items_provider.dart';

/// Compact "known total + cheapest store" chip for the list detail screen.
/// Tapping it opens the full per-store basket comparison. Renders nothing
/// while there isn't enough data (no priced items and no basket comparison).
class ListPriceSummaryBar extends ConsumerWidget {
  final String listId;
  final List<ShoppingItemModel> items;

  const ListPriceSummaryBar({
    super.key,
    required this.listId,
    required this.items,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pricedItems = items.where((i) => !i.isChecked && i.hasPrice).toList();
    final knownTotal = pricedItems.fold<double>(
        0, (sum, i) => sum + (i.price ?? 0) * i.pricingQuantity);
    final zipInfo = ref.watch(effectiveZipProvider).valueOrNull;
    final basketAsync = ref.watch(basketComparisonProvider(listId));
    final bestStore = basketAsync.valueOrNull?.bestStore;

    // Using the nationwide fallback zip (no GPS / permission denied): invite
    // the user to set their real PLZ instead of hiding the feature.
    final usingFallbackZip = zipInfo != null && !zipInfo.isReal;
    if (pricedItems.isEmpty && bestStore == null) {
      if (usingFallbackZip && items.any((i) => !i.isChecked)) {
        return _ZipPromptChip(listId: listId);
      }
      return const SizedBox.shrink();
    }

    final accent = AppColors.accentColor(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final comparison = basketAsync.valueOrNull;

    // Primary line prefers the comparable best-basket (a real, single-store
    // number). Falls back to the running total of prices already added.
    final openCount = items.where((i) => !i.isChecked).length;
    final Widget primary;
    if (bestStore != null) {
      primary = RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          style: TextStyle(fontSize: 12.5, color: textPrimary),
          children: [
            TextSpan(
              text: '${bestStore.comparableTotal.toStringAsFixed(2)} € ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(
              text: context.tr('cheapest_basket'),
              style: TextStyle(color: textSecondary),
            ),
          ],
        ),
      );
    } else if (pricedItems.isNotEmpty) {
      primary = RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          style: TextStyle(fontSize: 12.5, color: textPrimary),
          children: [
            TextSpan(
              text: '${knownTotal.toStringAsFixed(2)} € ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(
              text: context.tr('known_of_items', params: {
                'known': '${pricedItems.length}',
                'total': '$openCount',
              }),
              style: TextStyle(color: textSecondary),
            ),
          ],
        ),
      );
    } else {
      primary = Text(
        context.tr('price_data_from_offers'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: textSecondary),
      );
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _showComparisonSheet(context, comparison);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Row(
          children: [
            Icon(Icons.receipt_long_outlined, size: 15, color: accent),
            const SizedBox(width: 8),
            Expanded(child: primary),
            if (bestStore != null) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.storefront_outlined, size: 11, color: accent),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          bestStore.retailerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 16, color: textSecondary),
          ],
        ),
      ),
    );
  }

  void _showComparisonSheet(BuildContext context, BasketComparison? comparison) {
    if (comparison == null || comparison.stores.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          _StoreComparisonSheet(comparison: comparison, listId: listId),
    );
  }
}

/// Shown instead of the summary bar when no zip code could be resolved:
/// lets the user type a PLZ manually so offers work without location access.
class _ZipPromptChip extends ConsumerWidget {
  final String listId;

  const _ZipPromptChip({required this.listId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        showManualZipDialog(context, ref, listId);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.location_off_outlined,
              size: 15,
              color: AppColors.textSecondary(context),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.tr('enter_zip_prompt'),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accentColor(context),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'PLZ',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: PaperColors.paper,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paper-styled dialog to set/change the manual zip code used for offers.
/// Returns true when a valid PLZ was saved.
Future<bool> showManualZipDialog(
  BuildContext context,
  WidgetRef ref,
  String listId,
) async {
  final controller = TextEditingController(
    text: await UserLocationService.instance.getManualZipCode() ?? '',
  );
  if (!context.mounted) return false;

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface(ctx),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        ctx.tr('enter_zip_title'),
        style: PaperTextStyles.serif(18, color: AppColors.textPrimary(ctx)),
      ),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        maxLength: 5,
        style: TextStyle(fontSize: 16, color: AppColors.textPrimary(ctx)),
        decoration: InputDecoration(
          hintText: '10115',
          counterText: '',
          hintStyle: TextStyle(color: AppColors.textTertiary(ctx)),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.border(ctx)),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.accentColor(ctx)),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(
            ctx.tr('cancel'),
            style: TextStyle(color: AppColors.textSecondary(ctx)),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            ctx.tr('save'),
            style: TextStyle(
              color: AppColors.accentColor(ctx),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  var changed = false;
  if (saved == true) {
    final zip = controller.text.trim();
    if (zip.length == 5) {
      await UserLocationService.instance.setManualZipCode(zip);
      ref.invalidate(userZipCodeProvider);
      ref.invalidate(effectiveZipProvider);
      ref.invalidate(basketComparisonProvider(listId));
      changed = true;
    }
  }
  controller.dispose();
  return changed;
}

class _StoreComparisonSheet extends ConsumerWidget {
  final BasketComparison comparison;
  final String listId;

  const _StoreComparisonSheet({required this.comparison, required this.listId});

  /// Estimate for the whole open list: an item's own price when set, else
  /// the cheapest current offer for it, else it stays uncovered. Returns
  /// (total, coveredCount, openCount); null total when nothing is covered.
  (double, int, int)? _estimateListTotal(WidgetRef ref) {
    final items =
        ref.watch(itemsNotifierProvider(listId)).valueOrNull ?? const [];
    final open = items.where((i) => !i.isChecked).toList();
    if (open.isEmpty) return null;
    var total = 0.0;
    var covered = 0;
    for (final item in open) {
      final price = item.price ??
          comparison.cheapestOfferFor(item.name.trim())?.price;
      if (price == null) continue;
      total += price * item.pricingQuantity;
      covered++;
    }
    if (covered == 0) return null;
    return (total, covered, open.length);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final accent = AppColors.accentColor(context);
    final stores = comparison.ranked;
    final estimate = _estimateListTotal(ref);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
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
            context.tr('store_comparison'),
            style: PaperTextStyles.serif(20, color: textPrimary),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr(
                    'matched_of_items',
                    params: {'count': '${comparison.comparableItemCount}'},
                  ),
                  style: TextStyle(fontSize: 12.5, color: textSecondary),
                ),
              ),
              GestureDetector(
                onTap: () async {
                  HapticFeedback.selectionClick();
                  final changed =
                      await showManualZipDialog(context, ref, listId);
                  if (changed && context.mounted) {
                    Navigator.pop(context);
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Icon(Icons.place_outlined, size: 13, color: textSecondary),
                    const SizedBox(width: 3),
                    Text(
                      context.tr(
                        'zip_code_label',
                        params: {'zip': comparison.zipCode},
                      ),
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                    const SizedBox(width: 3),
                    Icon(Icons.edit_outlined, size: 12, color: textSecondary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < stores.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == 0 ? accent : AppColors.border(context),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: i == 0 ? PaperColors.paper : textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stores[i].retailerName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          stores[i].savings > 0.01
                              ? '${context.tr(
                                  'items_on_offer_here',
                                  params: {
                                    'matched': '${stores[i].matchedCount}',
                                    'total': '${comparison.comparableItemCount}',
                                  },
                                )} · ${context.tr(
                                  'saves_amount',
                                  params: {
                                    'amount':
                                        stores[i].savings.toStringAsFixed(2),
                                  },
                                )}'
                              : context.tr(
                                  'items_on_offer_here',
                                  params: {
                                    'matched': '${stores[i].matchedCount}',
                                    'total': '${comparison.comparableItemCount}',
                                  },
                                ),
                          style: TextStyle(fontSize: 11.5, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${stores[i].comparableTotal.toStringAsFixed(2)} €',
                    style: PaperTextStyles.serif(16, color: textPrimary),
                  ),
                ],
              ),
            ),
          if (estimate != null) ...[
            Container(
              height: 0.5,
              margin: const EdgeInsets.only(bottom: 10),
              color: AppColors.divider(context),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('estimated_list_total', params: {
                      'known': '${estimate.$2}',
                      'total': '${estimate.$3}',
                    }),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: textPrimary,
                    ),
                  ),
                ),
                Text(
                  '≈ ${estimate.$1.toStringAsFixed(2)} €',
                  style: PaperTextStyles.serif(16, color: textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 2),
          Text(
            context.tr('comparable_note',
                params: {'count': '${comparison.comparableItemCount}'}),
            style: TextStyle(fontSize: 10.5, color: textSecondary, height: 1.4),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr('offers_source_note'),
            style: TextStyle(fontSize: 10.5, color: textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}

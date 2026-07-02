import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/presentation/providers/price_comparison_provider.dart';

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
    final knownTotal = pricedItems.fold<double>(0, (sum, i) => sum + (i.price ?? 0) * i.quantity);
    final basketAsync = ref.watch(basketComparisonProvider(listId));
    final bestStore = basketAsync.valueOrNull?.bestStore;

    if (pricedItems.isEmpty && bestStore == null) return const SizedBox.shrink();

    final accent = AppColors.accentColor(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _showComparisonSheet(context, basketAsync.valueOrNull);
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
            Icon(Icons.receipt_long_outlined, size: 15, color: accent),
            const SizedBox(width: 8),
            Expanded(
              child: pricedItems.isEmpty
                  ? Text(
                      context.tr('price_data_from_offers'),
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    )
                  : RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 12.5, color: textPrimary),
                        children: [
                          TextSpan(
                            text: '${knownTotal.toStringAsFixed(2)} € ',
                            style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary),
                          ),
                          TextSpan(
                            text: context.tr(
                              'known_of_items',
                              params: {
                                'known': '${pricedItems.length}',
                                'total': '${items.where((i) => !i.isChecked).length}',
                              },
                            ),
                            style: TextStyle(color: textSecondary),
                          ),
                        ],
                      ),
                    ),
            ),
            if (bestStore != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  context.tr(
                    'cheapest_at',
                    params: {'store': bestStore.retailerName},
                  ),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ),
            ],
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
      builder: (ctx) => _StoreComparisonSheet(comparison: comparison),
    );
  }
}

class _StoreComparisonSheet extends StatelessWidget {
  final BasketComparison comparison;

  const _StoreComparisonSheet({required this.comparison});

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final accent = AppColors.accentColor(context);
    final stores = comparison.stores;

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
          Text(
            context.tr(
              'matched_of_items',
              params: {'count': '${comparison.itemCount}'},
            ),
            style: TextStyle(fontSize: 12.5, color: textSecondary),
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
                          context.tr(
                            'matched_count_line',
                            params: {
                              'matched': '${stores[i].matchedCount}',
                              'total': '${comparison.itemCount}',
                            },
                          ),
                          style: TextStyle(fontSize: 11.5, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${stores[i].total.toStringAsFixed(2)} €',
                    style: PaperTextStyles.serif(16, color: textPrimary),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              context.tr('offers_source_note'),
              style: TextStyle(fontSize: 10.5, color: textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

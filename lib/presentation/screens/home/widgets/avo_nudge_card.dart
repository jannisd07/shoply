import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/app_dimensions.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/mascot/avo_mascot.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/services/avo_nudge_service.dart';
import 'package:shoply/presentation/state/avo_nudge_provider.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/state/lists_provider.dart';

/// Home-screen card with Avo's nudges, computed from the user's own data:
/// restock suggestions ("you buy milk about every 5 days — last bought 8
/// days ago", including "usually on Sundays" weekday patterns), and rhythm
/// items that are currently on offer nearby ("Milch: −23 % bei Lidl").
/// One-tap add to the most recently used list, or dismiss to snooze.
/// Renders nothing when nothing is due.
class AvoNudgeCard extends ConsumerWidget {
  const AvoNudgeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestions =
        ref.watch(restockSuggestionsProvider).valueOrNull ?? const [];
    final allOffers = ref.watch(offerNudgesProvider).valueOrNull ?? const [];
    // A restock row for the same item wins; the offer then shows inline
    // under it instead of as a second row.
    final restockNames = suggestions.map((s) => s.itemName).toSet();
    final offers = allOffers
        .where((o) => o.isStillValid && !restockNames.contains(o.itemName))
        .toList();
    final offerByItem = <String, OfferNudge>{
      for (final o in allOffers)
        if (o.isStillValid) o.itemName: o,
    };
    if (suggestions.isEmpty && offers.isEmpty) {
      return const SizedBox.shrink();
    }

    final accent = AppColors.accentColor(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.screenHorizontalPadding,
        8,
        AppDimensions.screenHorizontalPadding,
        0,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border(context)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const AvoMascot(size: 22, expression: AvoExpression.thinking),
                const SizedBox(width: 8),
                Text(
                  context
                      .tr(suggestions.isNotEmpty
                          ? 'restock_title'
                          : 'offer_nudge_title')
                      .toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            for (final suggestion in suggestions)
              _SuggestionRow(
                suggestion: suggestion,
                offer: offerByItem[suggestion.itemName],
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                accent: accent,
                onAdd: () => _addToList(
                  context,
                  ref,
                  name: suggestion.displayName,
                  quantity: suggestion.preferredQuantity,
                  category: suggestion.preferredCategory,
                  offer: offerByItem[suggestion.itemName],
                ),
                onSnooze: () => _snooze(ref, suggestion),
              ),
            for (final offer in offers)
              _OfferRow(
                offer: offer,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                accent: accent,
                onAdd: () => _addToList(
                  context,
                  ref,
                  name: offer.displayName,
                  quantity: offer.preferredQuantity,
                  category: offer.preferredCategory,
                  offer: offer,
                ),
                onSnooze: () => _snoozeOffer(ref, offer),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _addToList(
    BuildContext context,
    WidgetRef ref, {
    required String name,
    double? quantity,
    String? category,
    OfferNudge? offer,
  }) async {
    HapticFeedback.lightImpact();
    try {
      final lists = await ref.read(userListsProvider.future);
      if (lists.isEmpty) return;

      // Add to the most recently touched list.
      final sorted = List<ShoppingListModel>.from(lists)
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final target = sorted.first;

      await ref.read(itemRepositoryProvider).addItem(
            listId: target.id,
            name: name,
            quantity: quantity ?? 1.0,
            category: category,
            // Carry the live offer price along, exactly like adding from an
            // offer suggestion in the list itself.
            price: offer?.price,
            priceCurrency: offer != null ? 'EUR' : null,
            priceRetailer: offer?.retailerName,
            priceUnit: offer?.unitSizeLabel,
            priceOldValue: offer?.regularPrice,
            // The name comes from the user's own purchase stats — no need
            // for the Gemini free-text parse pass.
            autoParse: false,
          );

      ref.invalidate(listItemsProvider(target.id));
      ref.invalidate(itemsByCategoryProvider(target.id));
      ref.invalidate(restockSuggestionsProvider);
      ref.invalidate(offerNudgesProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('restock_added_to', params: {
              'item': name,
              'list': target.name,
            })),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('🥑 [AVO_NUDGE] Failed to add suggestion: $e');
    }
  }

  Future<void> _snooze(WidgetRef ref, RestockSuggestion suggestion) async {
    HapticFeedback.selectionClick();
    await AvoNudgeService.instance.snooze(suggestion);
    ref.invalidate(restockSuggestionsProvider);
  }

  Future<void> _snoozeOffer(WidgetRef ref, OfferNudge offer) async {
    HapticFeedback.selectionClick();
    await AvoNudgeService.instance.snoozeOffer(offer);
    ref.invalidate(offerNudgesProvider);
  }
}

/// "Frische Vollmilch · −23 % · 0,99 € · Lidl" when the retailer disclosed
/// a regular price, else "Frische Vollmilch · 0,99 € · Lidl". Always names
/// the actual offered product — it can be more specific than the item.
String _offerLine(BuildContext context, OfferNudge offer) {
  if (offer.hasDisclosedDiscount) {
    return context.tr('offer_nudge_line', params: {
      'product': offer.productName,
      'pct': '${offer.discountPercent}',
      'store': offer.retailerName,
      'price': offer.price.toStringAsFixed(2),
    });
  }
  return context.tr('offer_nudge_line_simple', params: {
    'product': offer.productName,
    'store': offer.retailerName,
    'price': offer.price.toStringAsFixed(2),
  });
}

class _SuggestionRow extends StatelessWidget {
  final RestockSuggestion suggestion;
  final OfferNudge? offer;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final VoidCallback onAdd;
  final VoidCallback onSnooze;

  const _SuggestionRow({
    required this.suggestion,
    this.offer,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.onAdd,
    required this.onSnooze,
  });

  @override
  Widget build(BuildContext context) {
    final usualDay = suggestion.usualWeekday;
    final rhythmLine = usualDay != null
        ? context.tr('restock_line_weekday', params: {
            'avg': '${suggestion.averageDays}',
            'weekday': context.tr('weekday_adverb_$usualDay'),
          })
        : context.tr('restock_line', params: {
            'avg': '${suggestion.averageDays}',
            'days': '${suggestion.daysSince}',
          });

    return _NudgeRow(
      title: suggestion.displayName,
      subtitle: rhythmLine,
      offerLine: offer != null ? _offerLine(context, offer!) : null,
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      accent: accent,
      onAdd: onAdd,
      onSnooze: onSnooze,
    );
  }
}

class _OfferRow extends StatelessWidget {
  final OfferNudge offer;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final VoidCallback onAdd;
  final VoidCallback onSnooze;

  const _OfferRow({
    required this.offer,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.onAdd,
    required this.onSnooze,
  });

  @override
  Widget build(BuildContext context) {
    return _NudgeRow(
      title: offer.displayName,
      subtitle: null,
      offerLine: _offerLine(context, offer),
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      accent: accent,
      onAdd: onAdd,
      onSnooze: onSnooze,
    );
  }
}

/// Shared row layout: title, optional rhythm subtitle, optional accent
/// offer line, Add action, snooze ✕.
class _NudgeRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? offerLine;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final VoidCallback onAdd;
  final VoidCallback onSnooze;

  const _NudgeRow({
    required this.title,
    required this.subtitle,
    required this.offerLine,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.onAdd,
    required this.onSnooze,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onAdd,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: textSecondary),
                    ),
                  ],
                  if (offerLine != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      offerLine!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: accent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            GestureDetector(
              onTap: onAdd,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text(
                  context.tr('restock_add_action'),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: onSnooze,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: 4, top: 6, bottom: 6),
                child: Icon(Icons.close_rounded, size: 16, color: textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

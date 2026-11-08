import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/constants/categories.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/utils/item_input_parser.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/data/services/ai_categorization_service.dart';
import 'package:shoply/presentation/providers/offer_display_prefs_provider.dart';
import 'package:shoply/presentation/providers/price_comparison_provider.dart';
import 'package:shoply/presentation/screens/offers/offer_actions.dart';
import 'package:shoply/presentation/screens/offers/offer_paths.dart';
import 'package:shoply/presentation/screens/offers/offer_text.dart';
import 'package:shoply/presentation/screens/offers/widgets/offer_row.dart';

/// At most this many offers above the add field (S6).
const int _kMaxRows = 3;

// The panel: a white card on the floating layer (D2 hint card).
const double _kShadowAlpha = 0.08; // D2 `.card` on the floating layer
const double _kShadowBlur = 14; // D2
const Offset _kShadowOffset = Offset(0, 6); // D2

/// The category of a typed item, for the symbol of its offer rows: the
/// local, synchronous answer of the categorizer (never Claude); override in
/// tests.
final offerCategoryOfProvider = Provider<String Function(String name)>(
  (ref) => (name) {
    try {
      return AiCategorizationService.instance.categorizeLocal(name);
    } catch (e) {
      debugPrint('⚠️ [OFFERS] No category for an offer row: $e');
      return 'other';
    }
  },
);

/// Offers for the text typed in a list's add field (S6, contract
/// `b_slots.dart`): up to three offers of the list's market, without a
/// header and without retailer images, in the order of the source.
///
/// A tap puts the item on [listId] under the name as typed ("2 Milch" adds
/// "Milch", 2) with the offer's price, or attaches the offer when "Milch" is
/// already open on the list; then [onAdded] lets the host clear its field.
/// A long press opens the offer. No haptics.
///
/// Renders nothing, and asks the offers source nothing, while offers are off
/// (module, kill switch), hidden on [listId], without a real region, with
/// "Vorschläge beim Tippen" off, for under two characters, while loading, on
/// errors and without a hit: the add field stays usable.
class OfferSuggestionsBar extends ConsumerWidget {
  const OfferSuggestionsBar({
    super.key,
    required this.listId,
    required this.query,
    this.onAdded,
  });

  /// The list the tapped offer goes to, and whose market and "hide offers"
  /// choice apply.
  final String listId;

  /// What is typed in the add field.
  final String query;

  /// Called after the offer was put on [listId] (the host clears its field).
  final VoidCallback? onAdded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(
      offerSurfaceVisibleProvider((
        surface: OfferSurface.typingSuggestions,
        listId: listId,
      )),
    );
    if (!visible) return const SizedBox.shrink();
    final lang = offerLanguageOf(context);
    final parsed = parseSingleItem(query, lang: lang);
    final name = (parsed?.name ?? query).trim();
    if (name.length < 2) return const SizedBox.shrink();

    final offers =
        ref
            .watch(offerSuggestionsProvider((listId: listId, query: name)))
            .valueOrNull ??
        const <StoreOffer>[];
    if (offers.isEmpty) return const SizedBox.shrink();
    final symbol = Categories.getById(
      ref.watch(offerCategoryOfProvider)(name),
    ).icon;
    final colors = context.colors;
    final shown = offers.take(_kMaxRows).toList();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AvoRadii.card),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: _kShadowAlpha),
            offset: _kShadowOffset,
            blurRadius: _kShadowBlur,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AvoRadii.card),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: context.isAccessibilityText
                        ? AvoSpacing.l
                        : offerRowTextIndent,
                  ),
                  child: SizedBox(
                    height: AvoSizes.hairline,
                    child: ColoredBox(color: colors.separator),
                  ),
                ),
              _row(context, shown[i], name, parsed, symbol, lang),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    StoreOffer offer,
    String name,
    ParsedItem? parsed,
    IconData symbol,
    String lang,
  ) {
    final store = offerStoreName(offer);
    final pack = formatPack(offer, lang);
    final to = offer.validTo;
    final product = offerProductTitle(offer);
    final price = formatEuro(offer.price, lang);
    final spokenPrice = spokenEuro(offer.price, lang);
    // The full wording when pack and end date are known, else the parts
    // that are.
    final sub = pack != null && to != null
        ? context.tr(
            'offer_suggest_row_sub',
            params: {
              'store': store,
              'pack': pack,
              'weekday': shortWeekday(to, lang),
            },
          )
        : [
            store,
            ?pack,
            if (to != null)
              context.tr(
                'offer_valid_until',
                params: {'date': shortWeekday(to, lang)},
              ),
          ].join(' · ');
    final spoken = pack != null && to != null
        ? context.tr(
            'offer_suggest_row_a11y',
            params: {
              'product': product,
              'store': store,
              'pack': pack,
              'date': spokenOfferDate(to, lang),
              'price': spokenPrice,
            },
          )
        : [
            product,
            store,
            ?pack,
            context.tr('offer_badge_a11y', params: {'price': spokenPrice}),
          ].join(', ');
    final similar = context.tr('offer_similar_product');

    return OfferRow(
      compact: true,
      title: product,
      lines: [sub, if (offer.isBroadMatch) similar],
      price: price,
      uncertain: offer.isBroadMatch,
      symbol: symbol,
      semanticLabel: offer.isBroadMatch ? '$similar, $spoken' : spoken,
      semanticHint: context.tr(
        'offer_suggest_row_hint_a11y',
        params: {'item': name},
      ),
      onTap: () => unawaited(_add(context, offer, name, parsed)),
      onLongPress: () => _open(context, offer, name),
      longPressLabel: context.tr('offer_action_view'),
    );
  }

  Future<void> _add(
    BuildContext context,
    StoreOffer offer,
    String name,
    ParsedItem? parsed,
  ) async {
    final added = await addOfferToList(
      context,
      listId: listId,
      name: name,
      offer: offer,
      quantity: parsed?.quantity ?? 1,
      unit: parsed?.unit,
    );
    if (added) onAdded?.call();
  }

  void _open(BuildContext context, StoreOffer offer, String name) {
    rememberOffer(context, offer);
    context.push(
      offerDetailLocation(
        offer.id,
        listId: listId,
        mode: OfferDetailMode.add,
        name: name,
      ),
    );
  }
}

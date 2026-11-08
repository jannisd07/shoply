import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/presentation/providers/offer_display_prefs_provider.dart';
import 'package:shoply/presentation/providers/price_comparison_provider.dart';
import 'package:shoply/presentation/screens/offers/offer_actions.dart';
import 'package:shoply/presentation/screens/offers/offer_paths.dart';
import 'package:shoply/presentation/screens/offers/offer_text.dart';

// D2-Artikel offer card (`angebote.md` 2.1).
const EdgeInsets _kPadding = EdgeInsets.fromLTRB(16, 14, 16, 4); // D2
const double _kKickerTracking = 0.4; // D2 +0.4 on the caps kicker
const double _kKickerGap = 2;

/// The green offer card in the full-screen item editor (S4, D2-Artikel,
/// contract `b_slots.dart`): kicker "ANGEBOT", "Lidl · 0,99 €", the product
/// and pack, "laut Händler statt 1,49 € · bis Sa., 14. Nov.", "Preis
/// übernommen" when the item carries the offer's price, and the link
/// "Angebot ansehen" (44 pt) to the offer detail.
///
/// Renders nothing (the note card moves up without a gap) under the same
/// conditions as [ItemOfferBadge]: offers off, hidden on [listId], no real
/// region, "Angebote an Artikeln" off, or no current offer for [item].
/// VoiceOver: the card is one element, the link one more.
class ItemOfferCard extends ConsumerWidget {
  const ItemOfferCard({super.key, required this.listId, required this.item});

  final String listId;
  final ShoppingItemModel item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (item.isChecked) return const SizedBox.shrink();
    final visible = ref.watch(
      offerSurfaceVisibleProvider((
        surface: OfferSurface.itemOffers,
        listId: listId,
      )),
    );
    if (!visible) return const SizedBox.shrink();
    final offer = ref.watch(
      itemOfferProvider((listId: listId, itemId: item.id)),
    );
    if (offer == null) return const SizedBox.shrink();
    return _OfferCard(listId: listId, item: item, offer: offer);
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.listId,
    required this.item,
    required this.offer,
  });

  final String listId;
  final ShoppingItemModel item;
  final StoreOffer offer;

  void _open(BuildContext context) {
    rememberOffer(context, offer);
    context.push(
      offerDetailLocation(
        offer.id,
        listId: listId,
        itemId: item.id,
        mode: OfferDetailMode.take,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final lang = offerLanguageOf(context);
    final store = offerStoreName(offer);
    final price = formatEuro(offer.price, lang);
    final pack = formatPack(offer, lang);
    final product = [offerProductTitle(offer), ?pack].join(', ');
    final regular = offer.regularPrice;
    final until = offerValidUntil(offer, lang);
    final details = [
      if (offer.isBroadMatch)
        context.tr('offer_similar_product')
      else if (regular != null)
        context.tr(
          'offer_was_price',
          params: {'price': formatEuro(regular, lang)},
        ),
      ?until,
    ].join(' · ');
    final taken = isOfferPriceTaken(item, offer);

    final spokenDetails = [
      if (offer.isBroadMatch)
        context.tr('offer_similar_product')
      else if (regular != null)
        context.tr(
          'offer_was_price',
          params: {'price': spokenEuro(regular, lang)},
        ),
      if (offer.validTo case final to?)
        context.tr(
          'offer_valid_until',
          params: {'date': spokenOfferDate(to, lang)},
        ),
      if (taken) context.tr('offer_card_price_taken'),
    ].join(', ');

    final kicker = context.text(
      AvoTextStyle.caption2,
      color: colors.tint,
      weight: FontWeight.w500,
    );
    final body = context.text(
      AvoTextStyle.subhead,
      color: colors.tertiaryLabel,
    );

    final link = Semantics(
      button: true,
      label: context.tr('offer_action_view'),
      excludeSemantics: true,
      onTap: () => _open(context),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _open(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 1,
            child: Text(
              context.tr('offer_action_view'),
              style: context.text(
                AvoTextStyle.subhead,
                color: colors.tint,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.tintSoft,
        borderRadius: BorderRadius.circular(AvoRadii.group),
      ),
      child: Padding(
        padding: _kPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              container: true,
              label: context.tr(
                'offer_card_a11y',
                params: {
                  'store': store,
                  'price': spokenEuro(offer.price, lang),
                  'product': product,
                  'details': spokenDetails,
                },
              ),
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    // Caps for display only ("ANGEBOT"); the word has no ß.
                    context.tr('offer_card_kicker').toUpperCase(),
                    style: kicker.copyWith(
                      letterSpacing:
                          (kicker.letterSpacing ?? 0) + _kKickerTracking,
                    ),
                  ),
                  const SizedBox(height: _kKickerGap),
                  Text(
                    context.tr(
                      'offer_card_title',
                      params: {'store': store, 'price': price},
                    ),
                    style: context.text(AvoTextStyle.headline, tabular: true),
                  ),
                  Text(product, style: body),
                  if (details.isNotEmpty) Text(details, style: body),
                  if (taken)
                    Text(context.tr('offer_card_price_taken'), style: body),
                ],
              ),
            ),
            link,
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/widgets.dart';

import 'package:shoply/core/localization/app_translations.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/presentation/screens/offers/offer_text.dart';
import 'package:shoply/presentation/screens/offers/widgets/offer_row.dart';

/// One line of an offer row, as shown and as spoken.
typedef OfferLine = ({String shown, String spoken});

/// The lines the full offer rows of S9, S10 and S15 are made of, in the
/// mandatory wording (`angebote.md` 3.3): "laut Händler statt …" only when
/// the retailer names a "statt" price, end dates only within three days,
/// "Ähnliches Produkt" for an uncertain match. Numbers and dates are
/// written out for VoiceOver (3.11).
abstract final class OfferLines {
  /// "Milbona Frische Vollmilch 3,5 % · 1 l · bis Sa., 14. Nov." (S9, S15).
  static OfferLine product(StoreOffer offer, String lang) {
    final title = offerProductTitle(offer);
    final pack = formatPack(offer, lang);
    final until = offerValidUntil(offer, lang);
    return (
      shown: [title, ?pack, ?until].join(' · '),
      spoken: [
        spokenText(title, lang),
        ?spokenPack(offer, lang),
        ?spokenValidUntil(offer, lang),
      ].join(', '),
    );
  }

  /// "1 l · 0,99 €/l · laut Händler statt 1,19 €" (S10); null when the
  /// offer has none of it.
  static OfferLine? details(StoreOffer offer, String lang) {
    final pack = formatPack(offer, lang);
    final unit = formatUnitPrice(offer, lang);
    final was = _was(offer, lang);
    if (pack == null && unit == null && was == null) return null;
    return (
      shown: [?pack, ?unit, ?was?.shown].join(' · '),
      spoken: [
        ?spokenPack(offer, lang),
        ?spokenUnitPrice(offer, lang),
        ?was?.spoken,
      ].join(', '),
    );
  }

  /// "laut Händler statt 1,19 €"; null without a "statt" price.
  static OfferLine? was(StoreOffer offer, String lang) => _was(offer, lang);

  /// "endet morgen" within three days, else "Ähnliches Produkt" for an
  /// uncertain match; null otherwise.
  static OfferLine? flag(StoreOffer offer, String lang) {
    final ends = offerEndsLabel(offer, lang);
    if (ends != null) return (shown: ends, spoken: ends);
    if (!offer.isBroadMatch) return null;
    final similar = AppTranslations.get('offer_similar_product', lang);
    return (shown: similar, spoken: similar);
  }

  static OfferLine? _was(StoreOffer offer, String lang) {
    final regular = offer.regularPrice;
    if (regular == null) return null;
    return (
      shown: AppTranslations.get(
        'offer_was_price',
        lang,
        params: {'price': formatEuro(regular, lang)},
      ),
      spoken: AppTranslations.get(
        'offer_was_price',
        lang,
        params: {'price': spokenEuro(regular, lang)},
      ),
    );
  }
}

/// A full [OfferRow] (S9, S10, S15): [title] (the product, or "Milch · 2"),
/// the [lines] below, the pill at the end and, for VoiceOver, the whole row
/// as one sentence ending with the price: "Milch, 2, …, im Angebot 0,99
/// Euro laut Händler".
OfferRow offerEntryRow(
  BuildContext context, {
  required StoreOffer offer,
  required String title,
  String? spokenTitle,
  List<OfferLine> lines = const [],
  IconData? symbol,
  String? store,
  VoidCallback? onTap,
  ValueSetter<BuildContext>? onAdd,
  String? addLabel,
  Map<String, VoidCallback> actions = const {},
}) {
  final lang = offerLanguageOf(context);
  final price = context.tr(
    offer.isBroadMatch ? 'offer_badge_similar_a11y' : 'offer_badge_a11y',
    params: {'price': spokenEuro(offer.price, lang)},
  );
  final label = [
    spokenTitle ?? spokenText(title, lang),
    for (final line in lines) line.spoken,
    price,
  ].join(', ');
  return OfferRow(
    title: title,
    lines: [for (final line in lines) line.shown],
    price: formatEuro(offer.price, lang),
    store: store,
    uncertain: offer.isBroadMatch,
    symbol: symbol,
    semanticLabel: label,
    semanticHint: onTap == null ? null : context.tr('offer_action_view'),
    onTap: onTap,
    onAdd: onAdd,
    addLabel: addLabel,
    actions: actions,
  );
}

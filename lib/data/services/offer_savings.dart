/// The one savings rule of the app (Kap. 12, rule 5), for the list, the
/// checkout, the history and Avo: what a list saves at its market against
/// the "statt" prices the retailer states, over the base price (Grundpreis)
/// and the list quantity. Pure functions, no network.
library;

import 'package:flutter/foundation.dart' show immutable;

import 'package:shoply/core/localization/app_translations.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/data/services/store_chain_directory.dart';

/// "4 von 11 Artikeln diese Woche bei Lidl im Angebot, ca. 3,20 € gespart,
/// in deiner Region" as data.
@immutable
class OfferSummary {
  const OfferSummary({
    required this.chainId,
    required this.storeName,
    required this.matched,
    required this.total,
    this.savingsCents,
  });

  /// `StoreChainDirectory` id of the list's market, e.g. `lidl`.
  final String chainId;

  /// Name of the market as the chip shows it, e.g. "Lidl".
  final String storeName;

  /// Open items with an offer of the market.
  final int matched;

  /// All open items of the list.
  final int total;

  /// Rounded savings in cents (see [roundedSavingsCents]); null when there
  /// is nothing to claim: no "statt" price, below 0,50 € or no real region.
  final int? savingsCents;

  @override
  bool operator ==(Object other) =>
      other is OfferSummary &&
      other.chainId == chainId &&
      other.storeName == storeName &&
      other.matched == matched &&
      other.total == total &&
      other.savingsCents == savingsCents;

  @override
  int get hashCode =>
      Object.hash(chainId, storeName, matched, total, savingsCents);
}

/// The summary of [openItems] at the market [chainId], given the offer of
/// that market per item id. Checked items and offers of other markets do
/// not count. A similar product (broad match) counts as on offer but saves
/// nothing. Without [realRegion] there is no savings figure. Null when no
/// item is on offer.
OfferSummary? summarizeListOffers({
  required String chainId,
  required List<ShoppingItemModel> openItems,
  required Map<String, StoreOffer> offersByItemId,
  required bool realRegion,
}) {
  final open = [
    for (final item in openItems)
      if (!item.isChecked) item,
  ];
  var matched = 0;
  var savings = 0.0;
  for (final item in open) {
    final offer = offersByItemId[item.id];
    if (offer == null || !offer.isFromChain(chainId)) continue;
    matched++;
    savings += offerSavingsCents(offer, quantity: item.quantity, unit: item.unit) ??
        0;
  }
  if (matched == 0) return null;
  return OfferSummary(
    chainId: chainId,
    storeName: StoreChainDirectory.byId(chainId)?.displayName ?? chainId,
    matched: matched,
    total: open.length,
    savingsCents: realRegion ? roundedSavingsCents(savings.round()) : null,
  );
}

/// What buying [quantity] [unit] at [offer] saves against the retailer's
/// "statt" price, in (fractional) cents. Null without such a price or for a
/// similar product.
///
/// With a measured list quantity in the dimension of the offer ("500 g"
/// against a 1-kg pack) it is the base-price difference times the quantity
/// in the base unit; otherwise the pack difference times the number of packs
/// ([packCount]).
double? offerSavingsCents(
  StoreOffer offer, {
  required double quantity,
  String? unit,
}) {
  final regular = offer.regularPrice;
  if (regular == null || regular <= offer.price || offer.isBroadMatch) {
    return null;
  }
  final listAmount = _baseAmount(quantity, unit);
  final packAmount = _packBaseAmount(offer);
  if (listAmount != null &&
      packAmount != null &&
      listAmount.unit == packAmount.unit &&
      packAmount.amount > 0) {
    final perBaseUnit = (regular - offer.price) / packAmount.amount;
    return perBaseUnit * listAmount.amount * 100;
  }
  return (regular - offer.price) * packCount(quantity, unit) * 100;
}

/// Savings as the app shows them: below 50 ct none (null), otherwise rounded
/// to 10 ct ("ca. 3,20 €").
int? roundedSavingsCents(int rawCents) {
  if (rawCents < 50) return null;
  return (rawCents + 5) ~/ 10 * 10;
}

/// How many packs a list quantity stands for: pieces ("3", "3 Stk")
/// multiply, a measured quantity ("500 g") is one purchase. Same rule as
/// `ShoppingItemModel.pricingQuantity`.
double packCount(double quantity, String? unit) {
  final u = unit?.trim().toLowerCase();
  final isPieceLike = u == null || u.isEmpty || _pieceUnits.contains(u);
  if (!isPieceLike) return 1;
  if (quantity < 1 || quantity > 50) return 1;
  return quantity;
}

const Set<String> _pieceUnits = {
  'x', 'stk', 'stk.', 'st', 'st.', 'pcs', 'pc', 'piece', 'pieces', 'stück',
};

/// The mandatory sentence of [OfferSummary] in its three shapes (Kap. 12
/// rule 3, `angebote.md` 3.3): [head] and [detail] for the two lines of the
/// D2 savings card, [sentence] for VoiceOver and every one-line place.
@immutable
class OfferSummaryText {
  const OfferSummaryText({
    required this.head,
    required this.detail,
    required this.sentence,
  });

  /// "4 von 11 Artikeln diese Woche bei Lidl im Angebot".
  final String head;

  /// "ca. 3,20 € gespart · in deiner Region · Preise laut Händler"; without
  /// savings "in deiner Region · Preise laut Händler".
  final String detail;

  /// "4 von 11 Artikeln diese Woche bei Lidl im Angebot, ca. 3,20 € gespart,
  /// in deiner Region".
  final String sentence;
}

/// The texts of [summary] in [languageCode] ('de' or 'en'). This is the
/// only place that puts the sentence together.
OfferSummaryText offerSummaryText(OfferSummary summary, String languageCode) {
  String t(String key, Map<String, String> params) =>
      AppTranslations.get(key, languageCode, params: params);
  final counts = {
    'matched': '${summary.matched}',
    'total': '${summary.total}',
    'store': summary.storeName,
  };
  final head = summary.total == 1
      ? t('offer_summary_head_one', counts)
      : t('offer_summary_head_other', counts);
  final area = t('offer_in_your_area', const {});
  final prices = t('offer_retailer_prices', const {});
  final cents = summary.savingsCents;
  if (cents == null) {
    return OfferSummaryText(
      head: head,
      detail: '$area · $prices',
      sentence: t('offer_summary_sentence_no_savings', {'head': head}),
    );
  }
  final amount = formatEuroCents(cents, languageCode);
  return OfferSummaryText(
    head: head,
    detail: '${t('offer_summary_saved', {'amount': amount})} · $area · $prices',
    sentence: t('offer_summary_sentence', {'head': head, 'amount': amount}),
  );
}

/// The sentence for [summary] in [languageCode] ('de' or 'en'), exactly in
/// the wording of Kap. 12 rule 3 ([OfferSummaryText.sentence]).
String formatOfferSummary(OfferSummary summary, String languageCode) =>
    offerSummaryText(summary, languageCode).sentence;

/// "3,20" (German) or "3.20" (English) for [cents], without the currency
/// sign.
String formatEuroAmount(int cents, String languageCode) {
  final euros = cents ~/ 100;
  final rest = (cents % 100).toString().padLeft(2, '0');
  return languageCode == 'de' ? '$euros,$rest' : '$euros.$rest';
}

/// "3,20 €" (German) or "€3.20" (English) for [cents].
String formatEuroCents(int cents, String languageCode) {
  final amount = formatEuroAmount(cents, languageCode);
  return languageCode == 'de' ? '$amount €' : '€$amount';
}

typedef _Amount = ({double amount, String unit});

/// [quantity] [unit] in kg or l; null for pieces or an unknown unit.
_Amount? _baseAmount(double quantity, String? unit) {
  final factor = _baseUnits[unit?.trim().toLowerCase()];
  if (factor == null || quantity <= 0) return null;
  return (amount: quantity * factor.factor, unit: factor.unit);
}

/// The amount the offer price buys, in kg or l: pack size times packs, or,
/// without a pack size, price / Grundpreis.
_Amount? _packBaseAmount(StoreOffer offer) {
  final factor = _baseUnits[offer.unitShortName?.trim().toLowerCase()];
  if (factor == null) return null;
  final volume = offer.volume;
  if (volume != null && volume > 0) {
    final packs = offer.packQuantity ?? 1;
    return (
      amount: volume * (packs > 0 ? packs : 1) * factor.factor,
      unit: factor.unit,
    );
  }
  final reference = offer.referencePrice;
  if (reference != null && reference > 0) {
    return (amount: offer.price / reference * factor.factor, unit: factor.unit);
  }
  return null;
}

const Map<String, ({double factor, String unit})> _baseUnits = {
  'g': (factor: 0.001, unit: 'kg'),
  'gr': (factor: 0.001, unit: 'kg'),
  'kg': (factor: 1, unit: 'kg'),
  'ml': (factor: 0.001, unit: 'l'),
  'cl': (factor: 0.01, unit: 'l'),
  'l': (factor: 1, unit: 'l'),
  'liter': (factor: 1, unit: 'l'),
};

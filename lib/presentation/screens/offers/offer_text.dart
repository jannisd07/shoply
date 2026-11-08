/// Numbers, packs, dates and spoken forms of offers (`angebote.md` 3.3,
/// 3.11): "0,99 €" / "€0.99", "1 l" / "1 L", "bis Sa., 14. Nov." / "until
/// Sat, Nov 14", and for VoiceOver "0,99 Euro" / "99 cents". Pure functions
/// of the language code ('de' or 'en'), so every offer surface writes them
/// the same way. The savings sentence itself lives in `offer_savings.dart`.
library;

import 'package:flutter/widgets.dart';

import 'package:shoply/core/localization/app_translations.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/data/services/store_chain_directory.dart';

/// 'de' for German devices, else 'en' (the two languages of the app).
String offerLanguageOf(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'de' ? 'de' : 'en';

String _t(String key, String lang, [Map<String, String>? params]) =>
    AppTranslations.get(key, lang, params: params);

// ------------------------------------------------------------------ numbers

/// "0,99" / "0.99", "1,5" / "1.5": at most two decimals, none for whole
/// numbers when [trim] is set.
String _decimal(double value, String lang, {bool trim = false}) {
  var text = value.toStringAsFixed(2);
  if (trim) {
    if (text.endsWith('00')) {
      text = text.substring(0, text.length - 3);
    } else if (text.endsWith('0')) {
      text = text.substring(0, text.length - 1);
    }
  }
  return lang == 'de' ? text.replaceAll('.', ',') : text;
}

/// "0,99 €" (German) or "€0.99" (English).
String formatEuro(double euros, String lang) {
  final amount = _decimal(euros, lang);
  return lang == 'de' ? '$amount €' : '€$amount';
}

/// The price as VoiceOver should say it: "0,99 Euro", "99 cents", "€1.49".
String spokenEuro(double euros, String lang) {
  if (lang == 'de') return '${_decimal(euros, lang)} Euro';
  final cents = (euros * 100).round();
  if (cents < 100) return cents == 1 ? '1 cent' : '$cents cents';
  return formatEuro(euros, lang);
}

// -------------------------------------------------------------------- packs

/// The unit as shown: "l" / "L", "kg", "g", "ml".
String _unitLabel(String unit, String lang) {
  final u = unit.trim();
  if (lang == 'en' && u.toLowerCase() == 'l') return 'L';
  return u;
}

/// "1 l", "250 g", "6 × 1,5 l" / "1 L", "6 × 1.5 L"; null without pack data.
String? formatPack(StoreOffer offer, String lang) {
  final volume = offer.volume;
  final unit = offer.unitShortName;
  if (volume == null || unit == null || volume <= 0) return null;
  final size =
      '${_decimal(volume, lang, trim: true)} ${_unitLabel(unit, lang)}';
  final packs = offer.packQuantity;
  if (packs != null && packs > 1) {
    return '${_decimal(packs, lang, trim: true)} × $size';
  }
  return size;
}

/// "1 Liter", "6 × 1,5 Liter" / "1 litre" for VoiceOver; null without pack
/// data.
String? spokenPack(StoreOffer offer, String lang) {
  final shown = formatPack(offer, lang);
  if (shown == null) return null;
  final unit = offer.unitShortName!;
  final spoken = _spokenUnit(unit, lang);
  if (spoken == null) return shown;
  final size = '${_decimal(offer.volume!, lang, trim: true)} $spoken';
  final packs = offer.packQuantity;
  if (packs != null && packs > 1) {
    return '${_decimal(packs, lang, trim: true)} × $size';
  }
  return size;
}

/// [text] as VoiceOver should read it: "3,5 %" becomes "3,5 Prozent".
String spokenText(String text, String lang) => text
    .replaceAll('%', lang == 'de' ? ' Prozent' : ' percent')
    .replaceAll(RegExp(r'\s{2,}'), ' ');

/// The spoken name of a base unit; null for one VoiceOver reads well.
String? _spokenUnit(String unit, String lang) => switch (unit.toLowerCase()) {
  'l' || 'liter' => _t('offer_unit_l', lang),
  'kg' => _t('offer_unit_kg', lang),
  'stk' || 'stk.' || 'stück' || 'st' => _t('offer_unit_piece', lang),
  _ => null,
};

/// "0,99 €/l" / "€0.99/L"; null without a base price or when it says no
/// more than the price (exactly one unit in one pack).
String? formatUnitPrice(StoreOffer offer, String lang) {
  final reference = offer.referencePrice;
  final unit = offer.unitShortName;
  if (reference == null || unit == null || reference <= 0) return null;
  final single =
      (offer.packQuantity == null || offer.packQuantity == 1) &&
      offer.volume == 1;
  if (single) return null;
  return '${formatEuro(reference, lang)}/${_unitLabel(unit, lang)}';
}

/// "0,99 Euro pro Liter" / "99 cents per litre" for [formatUnitPrice].
String? spokenUnitPrice(StoreOffer offer, String lang) {
  final shown = formatUnitPrice(offer, lang);
  if (shown == null) return null;
  final unit = offer.unitShortName!;
  return _t('offer_unit_price_a11y', lang, {
    'price': spokenEuro(offer.referencePrice!, lang),
    'unit': _spokenUnit(unit, lang) ?? unit,
  });
}

// -------------------------------------------------------------------- dates

const _deWeekdayShort = ['Mo.', 'Di.', 'Mi.', 'Do.', 'Fr.', 'Sa.', 'So.'];
const _deWeekday = [
  'Montag',
  'Dienstag',
  'Mittwoch',
  'Donnerstag',
  'Freitag',
  'Samstag',
  'Sonntag',
];
const _deMonthShort = [
  'Jan.',
  'Feb.',
  'März',
  'Apr.',
  'Mai',
  'Juni',
  'Juli',
  'Aug.',
  'Sept.',
  'Okt.',
  'Nov.',
  'Dez.',
];
const _deMonth = [
  'Januar',
  'Februar',
  'März',
  'April',
  'Mai',
  'Juni',
  'Juli',
  'August',
  'September',
  'Oktober',
  'November',
  'Dezember',
];
const _enWeekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _enWeekday = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _enMonthShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
const _enMonth = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// "Sa." / "Sat" for the local day of [date].
String shortWeekday(DateTime date, String lang) {
  final d = date.toLocal();
  return (lang == 'de' ? _deWeekdayShort : _enWeekdayShort)[d.weekday - 1];
}

/// "Sa., 14. Nov." / "Sat, Nov 14" for the local day of [date].
String formatOfferDate(DateTime date, String lang) {
  final d = date.toLocal();
  final weekday = shortWeekday(d, lang);
  if (lang == 'de') return '$weekday, ${d.day}. ${_deMonthShort[d.month - 1]}';
  return '$weekday, ${_enMonthShort[d.month - 1]} ${d.day}';
}

/// "Samstag, 14. November" / "Saturday, November 14" for VoiceOver.
String spokenOfferDate(DateTime date, String lang) {
  final d = date.toLocal();
  if (lang == 'de') {
    return '${_deWeekday[d.weekday - 1]}, ${d.day}. ${_deMonth[d.month - 1]}';
  }
  return '${_enWeekday[d.weekday - 1]}, ${_enMonth[d.month - 1]} ${d.day}';
}

/// "Sa., 14. Nov., 9:30" / "Sat, Nov 14, 9:30 AM": when the offers on the
/// device were fetched ("Angebote vom Stand …").
String formatOfferDateTime(DateTime date, String lang) {
  final d = date.toLocal();
  final minutes = d.minute.toString().padLeft(2, '0');
  final time = lang == 'de'
      ? '${d.hour}:$minutes'
      : '${d.hour % 12 == 0 ? 12 : d.hour % 12}:$minutes '
            '${d.hour < 12 ? 'AM' : 'PM'}';
  return _t('offer_datetime', lang, {
    'date': formatOfferDate(d, lang),
    'time': time,
  });
}

/// "bis Samstag, 14. November" / "until Saturday, November 14" for
/// VoiceOver; null without an end date.
String? spokenValidUntil(StoreOffer offer, String lang) {
  final to = offer.validTo;
  if (to == null) return null;
  return _t('offer_valid_until', lang, {'date': spokenOfferDate(to, lang)});
}

/// "bis Sa., 14. Nov." / "until Sat, Nov 14"; null without an end date.
String? offerValidUntil(StoreOffer offer, String lang) {
  final to = offer.validTo;
  if (to == null) return null;
  return _t('offer_valid_until', lang, {'date': formatOfferDate(to, lang)});
}

/// "endet heute", "endet morgen", "endet Montag" when the offer ends within
/// three calendar days in local time; otherwise and when it has ended null.
String? offerEndsLabel(StoreOffer offer, String lang, {DateTime? now}) {
  final to = offer.validTo;
  if (to == null) return null;
  final today = _day(now ?? DateTime.now());
  final last = _day(to.toLocal());
  final days = last.difference(today).inDays;
  if (days < 0 || days > 3) return null;
  if (days == 0) return _t('offer_ends_today', lang);
  if (days == 1) return _t('offer_ends_tomorrow', lang);
  final d = to.toLocal();
  final weekday = (lang == 'de' ? _deWeekday : _enWeekday)[d.weekday - 1];
  return _t('offer_ends_weekday', lang, {'weekday': weekday});
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Whether [offer] has ended at [now].
bool offerHasEnded(StoreOffer offer, {DateTime? now}) {
  final to = offer.validTo;
  if (to == null) return false;
  return (now ?? DateTime.now()).toUtc().isAfter(to.toUtc());
}

// ------------------------------------------------------------- store names

/// The market of [offer] in the directory's spelling ("REWE", "Aldi Süd"),
/// else the retailer name the source gives.
String offerStoreName(StoreOffer offer) {
  final chain =
      StoreChainDirectory.byId(offer.retailerUniqueName) ??
      StoreChainDirectory.byId(matchChain(offer.retailerName) ?? '');
  return chain?.displayName ?? offer.retailerName;
}

/// The directory id of [offer]'s market, or null for a market Avo does not
/// know.
String? offerChainId(StoreOffer offer) {
  if (StoreChainDirectory.byId(offer.retailerUniqueName) != null) {
    return offer.retailerUniqueName;
  }
  for (final chain in StoreChainDirectory.chains) {
    if (offer.isFromChain(chain.id)) return chain.id;
  }
  return matchChain(offer.retailerName);
}

/// "Milbona Frische Vollmilch 3,5 %": brand and product, without repeating
/// a brand the product name already starts with.
String offerProductTitle(StoreOffer offer) {
  final brand = offer.brandName?.trim() ?? '';
  final product = offer.productName.trim();
  if (brand.isEmpty || product.toLowerCase().startsWith(brand.toLowerCase())) {
    return product;
  }
  return '$brand $product';
}

// ----------------------------------------------------------------- distance

/// "120 m" / "1,2 km" and the spoken form "120 Meter" / "1,2 Kilometer".
({String shown, String spoken}) formatDistance(double meters, String lang) {
  if (meters < 1000) {
    final n = '${(meters / 10).round() * 10}';
    return (
      shown: _t('offer_distance_m', lang, {'n': n}),
      spoken: _t('offer_distance_m_a11y', lang, {'n': n}),
    );
  }
  final value = _decimal((meters / 100).round() / 10, lang, trim: true);
  return (
    shown: _t('offer_distance_km', lang, {'n': value}),
    spoken: _t('offer_distance_km_a11y', lang, {'n': value}),
  );
}

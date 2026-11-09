/// How the history area writes money (verlauf-kosten.md §3.3): "42,80 €"
/// with a no-break space in German, "€42.80" in English; never "42.80 €".
library;

import 'dart:ui' show PlatformDispatcher;

import 'package:intl/intl.dart';

/// [cents] as "42,80 €" / "€42.80" for [languageCode] (`de` or `en`).
String formatEuroCents(int cents, String languageCode) {
  final locale = languageCode == 'de' ? 'de_DE' : 'en_IE';
  final text = NumberFormat.currency(
    locale: locale,
    symbol: '€',
    decimalDigits: 2,
  ).format(cents / 100);
  // en_IE writes "€42.80"; de_DE "42,80 €" with a no-break space already.
  return text;
}

/// What VoiceOver reads for [cents]: "42,80 Euro" / "42 euros 80" (§3.10).
String spokenEuroCents(int cents, String languageCode) {
  final euros = cents ~/ 100;
  final rest = cents % 100;
  if (languageCode == 'de') {
    return rest == 0
        ? '$euros Euro'
        : '$euros,${rest.toString().padLeft(2, '0')} Euro';
  }
  final unit = euros == 1 ? 'euro' : 'euros';
  return rest == 0 ? '$euros $unit' : '$euros $unit $rest';
}

/// The language of pushes sent from this device (`de` or `en`): the
/// sender's, until the server localizes them per recipient.
String pushLanguageCode() =>
    PlatformDispatcher.instance.locale.languageCode == 'de' ? 'de' : 'en';

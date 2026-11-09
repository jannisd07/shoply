/// Money rules of "Einkauf abschließen" and "Kosten teilen" (verlauf-kosten.md
/// §3.3): amounts typed in any common notation, kept in whole cents, and
/// equal shares that add up to the cent. Pure functions, no network.
library;

import 'package:flutter/foundation.dart' show immutable;

/// The highest amount a trip may have (same limit as the server functions).
const int maxTripAmountCents = 10000000; // 100.000,00 €

/// What [parseAmountCents] made of a typed amount.
@immutable
class AmountInput {
  const AmountInput._(this.cents, {required this.isEmpty});

  /// Nothing typed: a trip without an amount.
  const AmountInput.empty() : this._(null, isEmpty: true);

  /// Something that is not an amount ("abc", "-3", "4,567").
  const AmountInput.invalid() : this._(null, isEmpty: false);

  /// A valid amount in whole cents.
  const AmountInput.valid(int cents) : this._(cents, isEmpty: false);

  /// The amount in cents; null when empty or invalid.
  final int? cents;

  /// Whether the field is empty (not an error).
  final bool isEmpty;

  /// Whether the text is neither empty nor an amount.
  bool get isInvalid => !isEmpty && cents == null;

  @override
  bool operator ==(Object other) =>
      other is AmountInput && other.cents == cents && other.isEmpty == isEmpty;

  @override
  int get hashCode => Object.hash(cents, isEmpty);

  @override
  String toString() => isEmpty
      ? 'AmountInput.empty'
      : cents == null
      ? 'AmountInput.invalid'
      : 'AmountInput.valid($cents)';
}

/// Reads a typed amount: "42,8", "42,80", "42.80", "1.234,56", "1234,5",
/// "1,234.56", "€ 12" all work (verlauf-kosten.md §3.3, Bug 14). A lone
/// separator followed by exactly three digits is the thousands separator of
/// [languageCode] ("1.234" is 1234 € in German, "1,234" in English), any
/// other lone separator is the decimal mark. More than two decimals,
/// negative numbers, letters and amounts above [maxTripAmountCents] are
/// invalid, never silently 0.
AmountInput parseAmountCents(String text, {String languageCode = 'de'}) {
  var s = text.replaceAll(RegExp(r'[\s  €]'), '');
  if (s.isEmpty) return const AmountInput.empty();
  if (!RegExp(r'^[0-9.,]+$').hasMatch(s)) return const AmountInput.invalid();

  final lastDot = s.lastIndexOf('.');
  final lastComma = s.lastIndexOf(',');
  String integer;
  String fraction = '';

  if (lastDot >= 0 && lastComma >= 0) {
    // Both: the later one is the decimal mark, the other groups thousands.
    final decimal = lastDot > lastComma ? '.' : ',';
    final group = decimal == '.' ? ',' : '.';
    final at = s.lastIndexOf(decimal);
    if (s.indexOf(decimal) != at) return const AmountInput.invalid();
    final head = s.substring(0, at);
    if (!_validGroups(head, group)) return const AmountInput.invalid();
    integer = head.replaceAll(group, '');
    fraction = s.substring(at + 1);
  } else if (lastDot >= 0 || lastComma >= 0) {
    final sep = lastDot >= 0 ? '.' : ',';
    final count = sep.allMatches(s).length;
    final tail = s.substring(s.lastIndexOf(sep) + 1);
    final groupSep = languageCode == 'en' ? ',' : '.';
    if (count > 1) {
      if (!_validGroups(s, sep)) return const AmountInput.invalid();
      integer = s.replaceAll(sep, '');
    } else if (tail.length == 3 && sep == groupSep && s.indexOf(sep) > 0) {
      integer = s.replaceAll(sep, '');
    } else {
      integer = s.substring(0, s.indexOf(sep));
      fraction = tail;
    }
  } else {
    integer = s;
  }

  if (integer.isEmpty) integer = '0';
  if (fraction.length > 2) return const AmountInput.invalid();
  if (!RegExp(r'^[0-9]+$').hasMatch(integer) ||
      (fraction.isNotEmpty && !RegExp(r'^[0-9]+$').hasMatch(fraction))) {
    return const AmountInput.invalid();
  }
  if (integer.length > 7) return const AmountInput.invalid();
  final cents =
      int.parse(integer) * 100 + int.parse(fraction.padRight(2, '0'));
  if (cents > maxTripAmountCents) return const AmountInput.invalid();
  return AmountInput.valid(cents);
}

/// "1.234.567" with [sep] '.': the first group 1 to 3 digits, all others
/// exactly 3.
bool _validGroups(String s, String sep) {
  final groups = s.split(sep);
  if (groups.first.isEmpty || groups.first.length > 3) return false;
  return groups.skip(1).every((g) => g.length == 3);
}

/// Equal shares of [totalCents] for [people] people in "Wer teilt?" order:
/// whole cents, the rest cents go to the first positions, so the shares
/// always add up (10,00 € / 3 = 3,34 + 3,33 + 3,33). Empty for no people.
/// The server function `trip_b_equal_share` uses the same rule.
List<int> equalShareCents(int totalCents, int people) {
  if (people <= 0) return const [];
  if (totalCents < 0) {
    throw ArgumentError.value(totalCents, 'totalCents', 'must not be negative');
  }
  final base = totalCents ~/ people;
  final rest = totalCents % people;
  return [for (var i = 0; i < people; i++) base + (i < rest ? 1 : 0)];
}

/// Euro amount of [cents] for the database (`numeric`), without float
/// noise: 334 -> 3.34.
double centsToEuros(int cents) => cents / 100;

/// Whole cents of a stored euro amount: 3.34 -> 334 (rounded, so 0.1 + 0.2
/// float noise never loses a cent).
int eurosToCents(num euros) => (euros * 100).round();

/// Whether [shareCents] add up to [totalCents] exactly.
bool sharesAddUp(int totalCents, Iterable<int> shareCents) =>
    shareCents.fold<int>(0, (a, b) => a + b) == totalCents;

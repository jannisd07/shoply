/// Dates, months and month numbers of the history area (verlauf-kosten.md
/// §3.3, V4, V9, V10). Pure functions: the screens pass the language and
/// the clock, so tests need no intl date data.
library;

import 'package:flutter/foundation.dart';

import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/services/store_chain_directory.dart';

const _deMonths = [
  'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', //
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
];
const _enMonths = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];

// In dates ("Mi., 4. Nov."), as iOS writes them.
const _deMonthsInDate = [
  'Jan.', 'Feb.', 'März', 'Apr.', 'Mai', 'Juni', //
  'Juli', 'Aug.', 'Sept.', 'Okt.', 'Nov.', 'Dez.',
];
const _enMonthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
// Axis labels of the month bars ("Jun", "Jul").
const _deMonthsAxis = [
  'Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez',
];
const _deWeekdaysShort = ['Mo.', 'Di.', 'Mi.', 'Do.', 'Fr.', 'Sa.', 'So.'];
const _enWeekdaysShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _deWeekdays = [
  'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', //
  'Sonntag',
];
const _enWeekdays = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', //
  'Sunday',
];

bool _de(String lang) => lang == 'de';

/// "November" / "November" (with the year when it is not [now]'s).
String monthName(DateTime month, String lang, {DateTime? now}) {
  final name = (_de(lang) ? _deMonths : _enMonths)[month.month - 1];
  if (now != null && now.year != month.year) return '$name ${month.year}';
  return name;
}

/// "Jun" / "Jun", the axis label of a month bar.
String monthAxis(DateTime month, String lang) =>
    (_de(lang) ? _deMonthsAxis : _enMonthsShort)[month.month - 1];

/// "18:40" / "6:40 PM".
String clockTime(DateTime t, String lang) {
  final mm = t.minute.toString().padLeft(2, '0');
  if (_de(lang)) return '${t.hour.toString().padLeft(2, '0')}:$mm';
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:$mm ${t.hour < 12 ? 'AM' : 'PM'}';
}

/// "Mi., 4. Nov." / "Wed, Nov 4"; with the year when it is not [now]'s
/// ("Mo., 2. Nov. 2025").
String shortDate(DateTime d, String lang, DateTime now) {
  final year = d.year == now.year ? '' : ' ${d.year}';
  if (_de(lang)) {
    return '${_deWeekdaysShort[d.weekday - 1]}, ${d.day}. '
        '${_deMonthsInDate[d.month - 1]}$year';
  }
  final y = d.year == now.year ? '' : ', ${d.year}';
  return '${_enWeekdaysShort[d.weekday - 1]}, ${_enMonthsShort[d.month - 1]} '
      '${d.day}$y';
}

/// "8. Nov." / "Nov 8" (paid on …).
String dayMonth(DateTime d, String lang, DateTime now) {
  final year = d.year == now.year ? '' : ' ${d.year}';
  if (_de(lang)) return '${d.day}. ${_deMonthsInDate[d.month - 1]}$year';
  final y = d.year == now.year ? '' : ', ${d.year}';
  return '${_enMonthsShort[d.month - 1]} ${d.day}$y';
}

/// "Samstag, 7. November" / "Saturday, November 7" for VoiceOver.
String spokenDate(DateTime d, String lang) => _de(lang)
    ? '${_deWeekdays[d.weekday - 1]}, ${d.day}. ${_deMonths[d.month - 1]}'
    : '${_enWeekdays[d.weekday - 1]}, ${_enMonths[d.month - 1]} ${d.day}';

/// How a trip's date reads in a row: "Heute, 18:40", "Gestern, 19:05", else
/// [shortDate]. [today] and [yesterday] are the translated patterns with
/// `{time}`.
String tripDate(
  DateTime d,
  String lang,
  DateTime now, {
  required String today,
  required String yesterday,
}) {
  final day = DateTime(d.year, d.month, d.day);
  final start = DateTime(now.year, now.month, now.day);
  final diff = start.difference(day).inDays;
  if (diff == 0) return today.replaceAll('{time}', clockTime(d, lang));
  if (diff == 1) return yesterday.replaceAll('{time}', clockTime(d, lang));
  return shortDate(d, lang, now);
}

/// "heute", "gestern", else the weekday ("Montag") for the hint "{list}
/// von {day} mit Lena teilen?".
String relativeDay(
  DateTime d,
  String lang,
  DateTime now, {
  required String today,
  required String yesterday,
}) {
  final diff = DateTime(now.year, now.month, now.day)
      .difference(DateTime(d.year, d.month, d.day))
      .inDays;
  if (diff == 0) return today;
  if (diff == 1) return yesterday;
  return (_de(lang) ? _deWeekdays : _enWeekdays)[d.weekday - 1];
}

/// The display name of a trip's market, or null without one.
String? tripStoreName(ShoppingHistory trip) {
  final id = trip.storeChainId;
  return id == null ? null : StoreChainDirectory.byId(id)?.displayName;
}

// ------------------------------------------------------------------ months

/// What one month of trips adds up to (V4 `MonthReview`, V9).
@immutable
class MonthSummary {
  const MonthSummary({
    required this.month,
    required this.trips,
    required this.items,
    required this.tripsWithAmount,
    required this.spendCents,
    required this.savingsRaw,
  });

  /// Day 1 of the month.
  final DateTime month;

  /// Trips in the month.
  final int trips;

  /// Items in those trips.
  final int items;

  /// Trips that have a typed amount.
  final int tripsWithAmount;

  /// Sum of the typed amounts.
  final int spendCents;

  /// Savings in cents, unrounded (rounded only at the end, §3.3).
  final double savingsRaw;

  bool get hasAmounts => tripsWithAmount > 0;

  /// Every trip has an amount.
  bool get fullyCovered => trips > 0 && tripsWithAmount == trips;

  /// At least 80 % of the trips have an amount (comparisons, §5 row 4).
  bool get wellCovered => trips > 0 && tripsWithAmount * 5 >= trips * 4;
}

/// Sums [trips] for [month] (day 1). Only typed amounts count (Bug 7).
MonthSummary summarizeMonth(Iterable<ShoppingHistory> trips, DateTime month) {
  var n = 0;
  var items = 0;
  var withAmount = 0;
  var spend = 0;
  final inMonth = <ShoppingHistory>[];
  for (final t in tripsInMonth(trips, year: month.year, month: month.month)) {
    n++;
    items += t.totalItems;
    inMonth.add(t);
    final cents = t.totalCostCents;
    if (cents != null && cents > 0) {
      withAmount++;
      spend += cents;
    }
  }
  return MonthSummary(
    month: DateTime(month.year, month.month),
    trips: n,
    items: items,
    tripsWithAmount: withAmount,
    spendCents: spend,
    savingsRaw: totalSavingsOf(inMonth) * 100,
  );
}

/// The current month and the five before it, oldest first.
List<DateTime> lastSixMonths(DateTime now) => [
  for (var i = 5; i >= 0; i--) DateTime(now.year, now.month - i),
];

/// The six month summaries of the bar chart, oldest first.
List<MonthSummary> sixMonths(Iterable<ShoppingHistory> trips, DateTime now) => [
  for (final m in lastSixMonths(now)) summarizeMonth(trips, m),
];

/// Whether the chart shows spending: at least 3 of the 6 months have an
/// amount (K12-05); else it counts trips.
bool chartShowsSpending(List<MonthSummary> months) =>
    months.where((m) => m.hasAmounts).length >= 3;

/// A finished month against the one before: the difference in cents
/// (positive = more), or null when either month is not well covered.
int? monthDifference(MonthSummary month, MonthSummary previous) {
  if (!month.wellCovered || !previous.wellCovered) return null;
  return month.spendCents - previous.spendCents;
}

/// The weekday (1 = Monday) most trips of the last 90 days fell on, when
/// there are at least 6 and one day is clearly ahead; else null.
int? usualWeekday(Iterable<ShoppingHistory> trips, DateTime now) {
  final from = now.subtract(const Duration(days: 90));
  final counts = List<int>.filled(8, 0);
  var n = 0;
  for (final t in trips) {
    if (t.completedAt.isBefore(from) || t.completedAt.isAfter(now)) continue;
    counts[t.completedAt.weekday]++;
    n++;
  }
  if (n < 6) return null;
  var best = 0;
  var bestCount = 0;
  var tie = false;
  for (var d = 1; d <= 7; d++) {
    if (counts[d] > bestCount) {
      best = d;
      bestCount = counts[d];
      tie = false;
    } else if (counts[d] == bestCount) {
      tie = true;
    }
  }
  return tie || best == 0 ? null : best;
}

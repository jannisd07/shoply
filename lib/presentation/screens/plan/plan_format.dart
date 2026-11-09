import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/meal_plan.dart';

/// ISO 8601 week number of [d] ("KW 46").
int planIsoWeek(DateTime d) {
  final day = planDay(d);
  final thursday = planAddDays(day, DateTime.thursday - day.weekday);
  final firstThursday = DateTime(thursday.year, 1, 4);
  final firstWeek = planWeekStart(firstThursday);
  return (planWeekStart(thursday).difference(firstWeek).inDays / 7).round() + 1;
}

/// Dates, ranges and counts of the Wochenplan in the device language
/// (`wochenplan.md` 4.1.9): "9.–15. November" / "Nov 9–15", "Do., 12. Nov."
/// / "Thu, Nov 12", "Mi., 11." / "Wed 11".
extension PlanFormat on BuildContext {
  String get _dateLocale {
    final tag = Localizations.maybeLocaleOf(this)?.toString() ?? 'en';
    return Intl.verifiedLocale(tag, DateFormat.localeExists, onFailure: (_) => 'en') ?? 'en';
  }

  bool get _german => _dateLocale.startsWith('de');

  /// "9.–15. November" ([longMonth]), "16.–22. Nov.", "30. Nov. – 6. Dez.";
  /// English "Nov 9–15", "Nov 30 – Dec 6".
  String planWeekRange(DateTime weekStart, {bool longMonth = false}) {
    final from = planWeekStart(weekStart);
    final to = planAddDays(from, 6);
    final month = longMonth ? DateFormat.MMMM(_dateLocale) : DateFormat.MMM(_dateLocale);
    final short = DateFormat.MMM(_dateLocale);
    if (_german) {
      if (from.month == to.month) return '${from.day}.–${to.day}. ${month.format(to)}';
      return '${from.day}. ${short.format(from)} – ${to.day}. ${short.format(to)}';
    }
    if (from.month == to.month) return '${short.format(from)} ${from.day}–${to.day}';
    return '${short.format(from)} ${from.day} – ${short.format(to)} ${to.day}';
  }

  /// "9. November bis 15. November" for VoiceOver.
  String planWeekRangeSpoken(DateTime weekStart) {
    final from = planWeekStart(weekStart);
    final format = DateFormat.MMMMd(_dateLocale);
    return tr('plan_a11y_range', params: {
      'from': format.format(from),
      'to': format.format(planAddDays(from, 6)),
    });
  }

  /// The week header: the current week as its range with the month
  /// written out, next and last week by name, others with their number.
  String planWeekTitle(DateTime weekStart, DateTime today) {
    final start = planWeekStart(weekStart);
    final current = planWeekStart(today);
    if (start == current) return planWeekRange(start, longMonth: true);
    final range = planWeekRange(start);
    if (start == planAddDays(current, 7)) return tr('plan_week_next_range', params: {'range': range});
    if (start == planAddDays(current, -7)) return tr('plan_week_last_range', params: {'range': range});
    return planWeekNumbered(start);
  }

  /// "KW 48 · 23.–29. Nov." / "Week 48 · Nov 23–29".
  String planWeekNumbered(DateTime weekStart) => tr('plan_week_number', params: {
        'n': '${planIsoWeek(weekStart)}',
        'range': planWeekRange(weekStart),
      });

  /// "Do., 12. Nov." / "Thu, Nov 12".
  String planDayShort(DateTime day) => DateFormat.MMMEd(_dateLocale).format(day);

  /// "Donnerstag, 12. November" / "Thursday, November 12".
  String planDayFull(DateTime day) => DateFormat.MMMMEEEEd(_dateLocale).format(day);

  /// "Donnerstag" / "Thursday".
  String planWeekday(DateTime day) => DateFormat.EEEE(_dateLocale).format(day);

  /// The date part of a day header: "Mi., 11." / "Wed 11" for today, the
  /// day number ("12." / "12") after a written-out weekday otherwise.
  String planDayNumber(DateTime day, {bool withWeekday = false}) {
    final number = _german ? '${day.day}.' : '${day.day}';
    if (!withWeekday) return number;
    final weekday = DateFormat.E(_dateLocale).format(day);
    return _german ? '$weekday, $number' : '$weekday $number';
  }

  /// "25 Min" / "25 min".
  String planMinutes(int minutes) => tr('plan_minutes', params: {'n': '$minutes'});

  /// "2 Portionen" / "1 Portion" for VoiceOver and menus.
  String planServings(int n) =>
      n == 1 ? tr('plan_a11y_servings_one') : tr('plan_a11y_servings', params: {'n': '$n'});

  /// "Koriander und Paprika", "Dill, Koriander und Paprika".
  String planJoinAnd(List<String> names) {
    if (names.isEmpty) return '';
    if (names.length == 1) return names.first;
    return tr('plan_join_and', params: {
      'a': names.sublist(0, names.length - 1).join(', '),
      'b': names.last,
    });
  }

  /// Whole numbers with the device's grouping ("1.360").
  String planNumber(num value) {
    final tag = Localizations.maybeLocaleOf(this)?.toString() ?? 'en';
    final locale = Intl.verifiedLocale(tag, NumberFormat.localeExists, onFailure: (_) => 'en') ?? 'en';
    return NumberFormat.decimalPattern(locale).format(value);
  }

  /// The app language for amounts ("de" or "en").
  String get planLanguage => _german ? 'de' : 'en';
}

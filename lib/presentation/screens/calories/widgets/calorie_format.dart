import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/data/models/food_log_entry.dart';

/// Numbers, dates and meal names of the calories area in the device
/// language (`kalorien.md` §3.3): "1.360 kcal" / "1,360 kcal", "1,25 l" /
/// "1.25 L", "Do., 5. Nov." / "Thu, Nov 5".
extension CalorieFormat on BuildContext {
  String get _localeTag {
    final tag = Localizations.maybeLocaleOf(this)?.toString() ?? 'en';
    return Intl.verifiedLocale(tag, NumberFormat.localeExists,
            onFailure: (_) => 'en') ??
        'en';
  }

  String get _dateLocale {
    final tag = Localizations.maybeLocaleOf(this)?.toString() ?? 'en';
    return Intl.verifiedLocale(tag, DateFormat.localeExists,
            onFailure: (_) => 'en') ??
        'en';
  }

  /// Whole kilocalories with grouping: "1.360".
  String kcal(num value) =>
      NumberFormat.decimalPattern(_localeTag).format(value.round());

  /// Grams: one decimal under 10 g ("0,5"), whole numbers above ("82").
  String grams(num value) => NumberFormat(
        value.abs() < 10 && value != value.roundToDouble() ? '0.#' : '0',
        _localeTag,
      ).format(value);

  /// Litres from millilitres, at most two decimals: "1,25", "2", "1,5".
  String liters(int ml) => NumberFormat('0.##', _localeTag).format(ml / 1000);

  /// A plain amount without trailing zeros ("1", "1,5").
  String amount(num value) => NumberFormat('0.##', _localeTag).format(value);

  /// "Do., 5. Nov." / "Thu, Nov 5".
  String shortDate(DateTime date) => DateFormat.MMMEd(_dateLocale).format(date);

  /// "Samstag, 7. November" / "Saturday, November 7" (VoiceOver).
  String longDate(DateTime date) =>
      DateFormat.MMMMEEEEd(_dateLocale).format(date);

  /// "Anfang März", "Mitte Februar", "Ende Februar 2027" (S13, S14): when a
  /// target weight is about reached.
  String roughDate(DateTime at, DateTime now) {
    final month = at.year == now.year
        ? DateFormat.MMMM(_dateLocale).format(at)
        : DateFormat.yMMMM(_dateLocale).format(at);
    final key = at.day <= 10
        ? 'cal_when_early'
        : at.day <= 20
            ? 'cal_when_mid'
            : 'cal_when_late';
    return tr(key, params: {'month': month});
  }

  /// "16:10" / "4:10 PM".
  String clockTime(DateTime time) => DateFormat.jm(_dateLocale).format(time);

  /// Short weekday for chart axes: "Mo" / "Mon".
  String weekdayShort(DateTime date) {
    final text = DateFormat.E(_dateLocale).format(date);
    return text.endsWith('.') ? text.substring(0, text.length - 1) : text;
  }

  /// "Heute, Sa., 7. Nov.", "Gestern, Fr., 6. Nov." or "Do., 5. Nov.".
  String diaryDate(String dateKey, String todayKey) {
    final date = shortDate(parseCalorieDayKey(dateKey));
    if (dateKey == todayKey) return tr('cal_date_today', params: {'date': date});
    if (dateKey == shiftCalorieDayKey(todayKey, -1)) {
      return tr('cal_date_yesterday', params: {'date': date});
    }
    return date;
  }

  /// The spoken form of [diaryDate]: "Heute, Samstag, 7. November".
  String diaryDateSpoken(String dateKey, String todayKey) {
    final date = longDate(parseCalorieDayKey(dateKey));
    if (dateKey == todayKey) return tr('cal_date_today', params: {'date': date});
    if (dateKey == shiftCalorieDayKey(todayKey, -1)) {
      return tr('cal_date_yesterday', params: {'date': date});
    }
    return date;
  }

  /// "Frühstück", "Mittagessen", "Snacks", "Abendessen".
  String mealName(MealType meal) => tr('cal_meal_${meal.dbValue}');

  /// "250 g", "1 Portion", "2 Portionen"; null when there is nothing to say
  /// (one piece without a unit).
  String? entryAmount(FoodLogEntry entry) {
    final unit = entry.unit?.trim().toLowerCase();
    final q = entry.quantity;
    if (unit == 'g' || unit == 'ml') return '${amount(q)} $unit';
    if (unit == 'serving' || unit == 'portion') {
      return tr(q == 1 ? 'cal_servings_one' : 'cal_servings_other',
          params: {'n': amount(q)});
    }
    if (unit == 'piece') {
      return tr(q == 1 ? 'cal_pieces_one' : 'cal_pieces_other', params: {'n': amount(q)});
    }
    if (unit == null || unit.isEmpty) return q == 1 ? null : amount(q);
    return '${amount(q)} ${entry.unit!.trim()}';
  }

  /// The unit of an entry's amount as shown after a number field ("g",
  /// "Portion", "Stück"); null without a unit.
  String? entryUnitLabel(FoodLogEntry entry) {
    final unit = entry.unit?.trim();
    if (unit == null || unit.isEmpty) return null;
    return switch (unit.toLowerCase()) {
      'g' || 'ml' => unit.toLowerCase(),
      'serving' || 'portion' => tr('cal_unit_portion'),
      'piece' => tr('cal_unit_piece'),
      _ => unit,
    };
  }

  /// Second line of a diary row: "60 g", "1 Portion · geschätzt",
  /// "250 g · Milbona".
  String? entrySubtitle(FoodLogEntry entry) {
    final brand = entry.brand?.trim();
    final parts = [
      ?entryAmount(entry),
      if (entry.estimated) tr('cal_estimated_suffix'),
      if (brand != null && brand.isNotEmpty) brand,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

/// The meal to suggest at [time] (`kalorien.md` §3.3): until 10:29
/// breakfast, 10:30–14:59 lunch, 15:00–16:59 snacks, 17:00–21:29 dinner,
/// then snacks.
MealType mealForTime(DateTime time) {
  final minutes = time.hour * 60 + time.minute;
  if (minutes < 10 * 60 + 30) return MealType.breakfast;
  if (minutes < 15 * 60) return MealType.lunch;
  if (minutes < 17 * 60) return MealType.snack;
  if (minutes < 21 * 60 + 30) return MealType.dinner;
  return MealType.snack;
}

/// The four meals in the order of the day.
const List<MealType> kMealOrder = [
  MealType.breakfast,
  MealType.lunch,
  MealType.snack,
  MealType.dinner,
];

/// Parses a `meal=` query value; null for anything unknown.
MealType? mealFromQuery(String? value) => switch (value) {
      'breakfast' => MealType.breakfast,
      'lunch' => MealType.lunch,
      'snack' => MealType.snack,
      'dinner' => MealType.dinner,
      _ => null,
    };

/// A valid `date=` query value up to [todayKey]; null otherwise.
String? dateKeyFromQuery(String? value, String todayKey) {
  if (value == null) return null;
  try {
    final key = calorieDayKey(parseCalorieDayKey(value));
    return key.compareTo(todayKey) > 0 ? null : key;
  } on FormatException {
    return null;
  }
}

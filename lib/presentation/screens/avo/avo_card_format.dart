import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/workout.dart';
import 'package:shoply/presentation/screens/offers/offer_text.dart';

// Numbers, dates and names of Avo's answer cards in the person's language
// (Kap. 2.3: "3,20 €", "1.840 kcal"). Dates and money use the same helpers
// as the offer screens, so the app writes them one way.

/// 'de' or 'en'.
String avoLang(BuildContext context) => offerLanguageOf(context);

/// "1.360" / "1,360".
String avoInt(BuildContext context, num value) =>
    NumberFormat.decimalPattern(avoLang(context)).format(value.round());

/// "78,4" / "78.4": at most [decimals] decimals, none when whole.
String avoDecimal(BuildContext context, double value, {int decimals = 1}) =>
    NumberFormat('0.${'#' * decimals}', avoLang(context)).format(value);

/// "Sa., 7. Nov." / "Sat, Nov 7".
String avoDay(BuildContext context, DateTime date) =>
    formatOfferDate(date, avoLang(context));

/// "21,40 €" / "€21.40".
String avoEuro(BuildContext context, double euros) =>
    formatEuro(euros, avoLang(context));

const _deWeekdays = [
  'Montag',
  'Dienstag',
  'Mittwoch',
  'Donnerstag',
  'Freitag',
  'Samstag',
  'Sonntag',
];
const _enWeekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// "Mittwoch" / "Wednesday".
String avoWeekday(BuildContext context, DateTime date) =>
    (avoLang(context) == 'de' ? _deWeekdays : _enWeekdays)[date.weekday - 1];

const _deMonths = [
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
const _enMonths = [
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

/// "November".
String avoMonth(BuildContext context, DateTime date) =>
    (avoLang(context) == 'de' ? _deMonths : _enMonths)[date.month - 1];

/// "Mittagessen" / "Lunch".
String avoMealName(BuildContext context, MealType meal) =>
    context.tr('avo_meal_${meal.name}');

/// "Laufen" / "Running".
String avoWorkoutName(BuildContext context, WorkoutType type) =>
    context.tr('avo_workout_${type.name}');

/// Today, for "Heute: …".
bool avoIsToday(DateTime date, DateTime now) =>
    date.year == now.year && date.month == now.month && date.day == now.day;

/// "Linsencurry", "Linsencurry und Salat", "A, B und C".
String avoAnd(BuildContext context, List<String> names) {
  if (names.length <= 1) return names.join();
  final and = context.tr('avo_and');
  return '${names.sublist(0, names.length - 1).join(', ')} $and ${names.last}';
}

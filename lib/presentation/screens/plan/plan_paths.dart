import 'package:shoply/data/models/meal_plan.dart';
import 'package:shoply/routes/route_paths.dart';

// Paths of the Wochenplan (`wochenplan.md` 1.2). Every full-screen route is
// absolute under `/plan`, so it opens over the tab it comes from.

const String kPlanAddPath = '${RoutePaths.plan}/add';
const String kPlanToListPath = '${RoutePaths.plan}/to-list';
const String kPlanAmountPath = '$kPlanToListPath/amount';
const String kPlanPantryPath = '$kPlanToListPath/pantry';
const String kPlanMovePath = '${RoutePaths.plan}/move';
const String kPlanWeekPath = '${RoutePaths.plan}/week';
const String kPlanSchedulePattern = '${RoutePaths.plan}/schedule/:recipeId';
const String kPlanSettingsListPath = '${RoutePaths.settingsPlan}/list';
const String kPlanSettingsPantryPath = '${RoutePaths.settingsPlan}/pantry';

String _q(String path, Map<String, String?> query) {
  final q = {for (final e in query.entries) if (e.value != null) e.key: e.value!};
  return Uri(path: path, queryParameters: q.isEmpty ? null : q).toString();
}

/// The overview at [day]'s week, scrolled to it (`/plan?day=`).
String planDayLocation(DateTime day) => _q(RoutePaths.plan, {'day': planDateKey(day)});

/// The overview at [weekStart]'s week (`/plan?week=`).
String planWeekLocation(DateTime weekStart) => _q(RoutePaths.plan, {'week': planDateKey(planWeekStart(weekStart))});

/// S2 "Rezept wählen" for [day].
String planAddLocation(DateTime day) => _q(kPlanAddPath, {'day': planDateKey(day)});

/// S3 "Zutaten der Woche"; [fromAvo] only for analytics.
String planToListLocation(DateTime weekStart, {bool fromAvo = false}) =>
    _q(kPlanToListPath, {'week': planDateKey(planWeekStart(weekStart)), 'from': fromAvo ? 'avo' : null});

/// S4 "Menge ändern" for one line of S3.
String planAmountLocation(DateTime weekStart, String lineKey) =>
    _q(kPlanAmountPath, {'week': planDateKey(planWeekStart(weekStart)), 'key': lineKey});

/// S6 "Verschieben".
String planMoveLocation(String entryId) => _q(kPlanMovePath, {'entry': entryId});

/// S7 "Woche wählen".
String planWeekPickerLocation(DateTime from) => _q(kPlanWeekPath, {'from': planDateKey(planWeekStart(from))});

/// S8 "Zum Wochenplan" for a recipe.
String planScheduleLocation(String recipeId, {int? servings, DateTime? day}) => _q(
      '${RoutePaths.plan}/schedule/${Uri.encodeComponent(recipeId)}',
      {'servings': servings?.toString(), 'day': day == null ? null : planDateKey(day)},
    );

/// A `YYYY-MM-DD` query value as a local day, or null.
DateTime? planDayFromQuery(String? value) {
  if (value == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
  try {
    return parsePlanDate(value);
  } catch (_) {
    return null;
  }
}

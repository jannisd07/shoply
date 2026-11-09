import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_meal_section.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';
import 'package:shoply/routes/route_paths.dart';

/// A new diary row with the food, amount and numbers of [template] for
/// [dateKey] and [meal] (re-logging from "Zuletzt gegessen" or "Heute
/// nochmal eintragen"). Keeps the source and "geschätzt" of the original,
/// never its photo.
FoodLogEntry copyFoodEntry(
  FoodLogEntry template, {
  required String dateKey,
  required MealType meal,
  required DateTime now,
}) {
  return FoodLogEntry(
    id: '',
    userId: '',
    loggedDate: parseCalorieDayKey(dateKey),
    mealType: meal,
    origin: template.origin,
    sourceRecipeId: template.sourceRecipeId,
    foodName: template.foodName,
    brand: template.brand,
    quantity: template.quantity,
    unit: template.unit,
    calories: template.calories,
    proteinG: template.proteinG,
    carbsG: template.carbsG,
    fatG: template.fatG,
    barcode: template.barcode,
    estimated: template.estimated,
    confidence: template.confidence,
    loggedTime: FoodLogTime.of(now),
    createdAt: now,
  );
}

/// What a failed write may log: the error code or type, never its text (it
/// can hold food names).
String calorieErrorKind(Object e) => e is CalorieDataException ? e.code.name : '${e.runtimeType}';

/// "Das konnte nicht gespeichert werden." with the error haptic.
void showCalorieWriteFailed(BuildContext context) {
  unawaited(AvoHaptics.error());
  if (context.mounted) AvoToast.show(context, message: context.tr('cal_write_failed'));
}

/// Logs [template] again for [dateKey]/[meal] with the light impact in the
/// same frame and "{name} eingetragen · Widerrufen". A null [dateKey] means
/// today at the moment of the tap. Returns the new row, or null when it
/// could not be queued (the person then sees why).
Future<FoodLogEntry?> logFoodAgain(
  BuildContext context,
  WidgetRef ref,
  FoodLogEntry template, {
  required String? dateKey,
  required MealType meal,
}) async {
  final message = context.tr('cal_logged_toast', params: {'name': template.foodName});
  final undo = context.tr('common_undo');
  final diary = ref.read(calorieDiaryProvider);
  final now = ref.read(calorieClockProvider)();
  unawaited(AvoHaptics.light());
  final FoodLogEntry saved;
  try {
    saved = await diary.addFood(
      copyFoodEntry(template, dateKey: dateKey ?? calorieDayKey(now), meal: meal, now: now),
    );
  } catch (e) {
    debugPrint('❌ [CalorieDiary] Logging again failed: ${calorieErrorKind(e)}');
    if (context.mounted) showCalorieWriteFailed(context);
    return null;
  }
  if (context.mounted) {
    AvoToast.show(context, message: message, actionLabel: undo, onAction: () => diary.deleteFood(saved));
  }
  return saved;
}

/// Logs a new [entry] (S5, S7, S8, S10) with the light impact in the same
/// frame and "{name} eingetragen · Widerrufen". Returns the saved row, or
/// null when it could not be queued (the person then sees why).
Future<FoodLogEntry?> logNewFood(BuildContext context, WidgetRef ref, FoodLogEntry entry) async {
  final message = context.tr('cal_logged_toast', params: {'name': entry.foodName});
  final undo = context.tr('common_undo');
  final diary = ref.read(calorieDiaryProvider);
  unawaited(AvoHaptics.light());
  final FoodLogEntry saved;
  try {
    saved = await diary.addFood(entry);
  } catch (e) {
    debugPrint('❌ [CalorieDiary] Logging failed: ${calorieErrorKind(e)}');
    if (context.mounted) showCalorieWriteFailed(context);
    return null;
  }
  if (context.mounted) {
    AvoToast.show(context, message: message, actionLabel: undo, onAction: () => diary.deleteFood(saved));
  }
  return saved;
}

/// The diary's row actions (S1 Interaktion): delete with "Widerrufen", move
/// to another meal, retry a "Nicht gespeichert" row, log a past row again
/// today.
class CalorieEntryActions {
  CalorieEntryActions({required this.context, required this.ref});

  final BuildContext context;
  final WidgetRef ref;

  FoodEntryActions forEntry(FoodLogEntry entry, {required bool pastDay}) {
    final diary = ref.read(calorieDiaryProvider);
    return FoodEntryActions(
      onDelete: () => _delete(entry),
      onMove: (meal) => diary.updateFood(entry, entry.copyWith(mealType: meal)),
      onRetry: () => diary.retry(entry.id),
      onEdit: () => unawaited(context.push(
            Uri(path: '${RoutePaths.calories}/entry/${entry.id}', queryParameters: {'date': entry.dateKey}).toString(),
            extra: entry,
          )),
      onLogAgainToday: pastDay
          // Today as it is at the tap (the screen may have been open since
          // yesterday).
          ? () => logFoodAgain(context, ref, entry, dateKey: null, meal: entry.mealType)
          : null,
    );
  }

  /// True when the row is gone; false brings a swiped row back.
  Future<bool> _delete(FoodLogEntry entry) async {
    final message = context.tr('cal_deleted', params: {'name': entry.foodName});
    final undo = context.tr('common_undo');
    final diary = ref.read(calorieDiaryProvider);
    final FoodLogEntry removed;
    try {
      removed = await diary.deleteFood(entry);
    } catch (e) {
      debugPrint('❌ [CalorieDiary] Deleting failed: ${calorieErrorKind(e)}');
      if (context.mounted) showCalorieWriteFailed(context);
      return false;
    }
    if (context.mounted) {
      AvoToast.show(context, message: message, actionLabel: undo, onAction: () => diary.restoreFood(removed));
    }
    return true;
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/food_product.dart';
import 'package:shoply/data/models/nutrition_goal.dart';
import 'package:shoply/data/models/weight_log_entry.dart';
import 'package:shoply/data/services/food_log_service.dart';
import 'package:shoply/data/services/nutrition_goal_service.dart';
import 'package:shoply/data/services/open_food_facts_service.dart';
import 'package:shoply/data/services/water_log_service.dart';
import 'package:shoply/data/services/weight_log_service.dart';
import 'package:shoply/presentation/state/auth_provider.dart';

final nutritionGoalServiceProvider = Provider<NutritionGoalService>((ref) {
  return NutritionGoalService.instance;
});

final foodLogServiceProvider = Provider<FoodLogService>((ref) {
  return FoodLogService.instance;
});

final weightLogServiceProvider = Provider<WeightLogService>((ref) {
  return WeightLogService.instance;
});

final waterLogServiceProvider = Provider<WaterLogService>((ref) {
  return WaterLogService.instance;
});

final openFoodFactsServiceProvider = Provider<OpenFoodFactsService>((ref) {
  return OpenFoodFactsService.instance;
});

/// The current user's saved goal/targets, or null if never configured.
/// Invalidate after `saveGoal`/`setTrackingEnabled` to refresh dependents.
final nutritionGoalProvider = FutureProvider.autoDispose<NutritionGoal?>((ref) async {
  final authUser = await ref.watch(authUserProvider.future);
  if (authUser == null) return null;
  final service = ref.watch(nutritionGoalServiceProvider);
  return service.getGoal();
});

/// The date currently shown on the calorie dashboard — defaults to today,
/// changeable via the day-switcher.
final selectedLogDateProvider = StateProvider.autoDispose<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// Food log entries for [selectedLogDateProvider]'s date.
final dailyFoodLogProvider = FutureProvider.autoDispose<List<FoodLogEntry>>((ref) async {
  final date = ref.watch(selectedLogDateProvider);
  final service = ref.watch(foodLogServiceProvider);
  return service.getEntriesForDate(date);
});

/// Calorie/macro totals for the selected date, derived from the log.
final dailyNutritionTotalsProvider = Provider.autoDispose<DailyNutritionTotals>((ref) {
  final entries = ref.watch(dailyFoodLogProvider).valueOrNull ?? const [];
  return DailyNutritionTotals.fromEntries(entries);
});

/// Water logged for the selected date, in ml.
final dailyWaterTotalProvider = FutureProvider.autoDispose<int>((ref) async {
  final date = ref.watch(selectedLogDateProvider);
  final service = ref.watch(waterLogServiceProvider);
  return service.getTotalForDate(date);
});

/// Weight history for the progress chart (last 90 days).
final weightHistoryProvider = FutureProvider.autoDispose<List<WeightLogEntry>>((ref) async {
  final service = ref.watch(weightLogServiceProvider);
  return service.getHistory();
});

/// Open Food Facts search results for a (debounced) query string.
final foodSearchProvider =
    FutureProvider.autoDispose.family<List<FoodProduct>, String>((ref, query) async {
  final service = ref.watch(openFoodFactsServiceProvider);
  return service.search(query);
});

/// Open Food Facts barcode lookup for a manually-entered code.
final barcodeLookupProvider =
    FutureProvider.autoDispose.family<FoodProduct?, String>((ref, barcode) async {
  final service = ref.watch(openFoodFactsServiceProvider);
  return service.lookupBarcode(barcode);
});

/// Invalidates every provider that a food/weight/water log mutation should
/// refresh — call after adding/deleting an entry so the dashboard, weekly
/// summary and weight chart all pick it up.
void invalidateNutritionLog(WidgetRef ref) {
  ref.invalidate(dailyFoodLogProvider);
  ref.invalidate(dailyWaterTotalProvider);
  ref.invalidate(weightHistoryProvider);
}

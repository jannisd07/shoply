// Shared fakes for the calories screens (B6 W3): a server that answers from
// memory, a fixed clock (Saturday 7 Nov 2026, 12:00) and every provider the
// diary, "Essen eintragen" and the Home sections read, so no test touches
// Supabase or the network.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/data/models/diet_challenge.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/nutrition_goal.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/water_log_entry.dart';
import 'package:shoply/data/models/weight_log_entry.dart';
import 'package:shoply/data/services/calorie_day_store.dart';
import 'package:shoply/data/services/calorie_recipe_nudge_service.dart';
import 'package:shoply/data/services/calorie_write_queue.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/calorie_diary_provider.dart';
import 'package:shoply/presentation/state/diet_challenge_provider.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';

const kUser = 'u1';
final kNow = DateTime(2026, 11, 7, 12);
const kToday = '2026-11-07';

class FakeCalorieRemote implements CalorieRemote {
  final Map<String, CalorieDay> days = {};
  Object? fetchError;
  Object? writeError;
  final List<QueuedWrite> executed = [];

  @override
  Future<CalorieDay> fetchDay(String dateKey) async {
    if (fetchError != null) throw fetchError!;
    return days[dateKey] ?? CalorieDay(dateKey: dateKey);
  }

  /// Keeps food and water writes like a server would, so a later fetch
  /// returns them.
  @override
  Future<void> execute(QueuedWrite write) async {
    if (writeError != null) throw writeError!;
    executed.add(write);
    final key = write.dateKey;
    if (key == null) return;
    final day = days[key] ?? CalorieDay(dateKey: key);
    final upsert = write.op == QueuedWriteOp.upsert;
    switch (write.kind) {
      case CalorieWriteKinds.food:
        days[key] = day.copyWith(entries: [
          ...day.entries.where((e) => e.id != write.entityId),
          if (upsert) FoodLogEntry.fromJson(write.payload),
        ]);
      case CalorieWriteKinds.water:
        days[key] = day.copyWith(water: [
          ...day.water.where((w) => w.id != write.entityId),
          if (upsert) WaterLogEntry.fromJson(write.payload),
        ]);
    }
  }

  @override
  Future<Map<String, DailyNutritionTotals>> fetchFoodTotals(String startKey, String endKey) async {
    if (fetchError != null) throw fetchError!;
    return {
      for (final d in days.values)
        if (d.dateKey.compareTo(startKey) >= 0 && d.dateKey.compareTo(endKey) <= 0 && d.hasFoodEntries)
          d.dateKey: d.totals,
    };
  }

  @override
  Future<Map<String, int>> fetchWaterTotals(String startKey, String endKey) async => {};
}

FoodLogEntry food(
  String id,
  String name,
  int kcal, {
  MealType meal = MealType.lunch,
  String date = kToday,
  double protein = 20,
  double carbs = 40,
  double fat = 10,
  double quantity = 1,
  String? unit,
  String? brand,
  bool estimated = false,
  DateTime? created,
}) =>
    FoodLogEntry(
      id: id,
      userId: kUser,
      loggedDate: parseCalorieDayKey(date),
      mealType: meal,
      foodName: name,
      brand: brand,
      quantity: quantity,
      unit: unit,
      calories: kcal,
      proteinG: protein,
      carbsG: carbs,
      fatG: fat,
      estimated: estimated,
      createdAt: created ?? parseCalorieDayKey(date).add(const Duration(hours: 9)),
    );

WaterLogEntry water(String id, int ml, {String date = kToday, DateTime? created}) => WaterLogEntry(
      id: id,
      userId: kUser,
      loggedDate: parseCalorieDayKey(date),
      amountMl: ml,
      createdAt: (created ?? parseCalorieDayKey(date).add(const Duration(hours: 10))).toUtc(),
    );

NutritionGoal goal({int kcal = 2000, int water = 2000}) => NutritionGoal(
      userId: kUser,
      calorieTrackingEnabled: true,
      dailyCalorieTarget: kcal,
      proteinTargetG: 133,
      carbsTargetG: 227,
      fatTargetG: 62,
      waterTargetMl: water,
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 1),
    );

/// The usual day: 1.360 kcal eaten (breakfast 420, lunch 940), 1,25 l water.
CalorieDay usualDay({String date = kToday}) => CalorieDay(
      dateKey: date,
      entries: [
        food('e1', 'Haferflocken', 220, meal: MealType.breakfast, date: date, quantity: 60, unit: 'g',
            created: parseCalorieDayKey(date).add(const Duration(hours: 8))),
        food('e2', 'Banane', 200, meal: MealType.breakfast, date: date,
            created: parseCalorieDayKey(date).add(const Duration(hours: 8, minutes: 5))),
        food('e3', 'Spaghetti Bolognese', 940, date: date, estimated: true, quantity: 1, unit: 'serving',
            protein: 42, carbs: 86, fat: 21, created: parseCalorieDayKey(date).add(const Duration(hours: 12, minutes: 30))),
      ],
      water: [
        water('w1', 750, date: date),
        water('w2', 500, date: date, created: parseCalorieDayKey(date).add(const Duration(hours: 16, minutes: 10))),
      ],
    );

/// Test setup for one test: preferences (optionally with stored days), the
/// fake server and the overrides.
class CalorieTestEnv {
  CalorieTestEnv._(this.prefs, this.remote);

  final SharedPreferences prefs;
  final FakeCalorieRemote remote;

  /// Module choices written through `appModulesProvider` (S1a "ausschalten").
  final modules = FakeModuleStore();

  static Future<CalorieTestEnv> create({
    Map<String, CalorieDay> stored = const {},
    Map<String, CalorieDay> server = const {},
    NutritionGoal? storedGoal,
    Map<String, Object> extraPrefs = const {},
  }) async {
    final values = <String, Object>{
      ...extraPrefs,
      for (final d in stored.values) CalorieDayStore.keyFor(kUser, d.dateKey): jsonEncode(d.toJson()),
      if (storedGoal != null)
        'cal_goal_v1_$kUser': jsonEncode({
          ...storedGoal.toUpsertJson(schemaV2: true),
          'created_at': storedGoal.createdAt.toIso8601String(),
          'updated_at': storedGoal.updatedAt.toIso8601String(),
        }),
    };
    SharedPreferences.setMockInitialValues(values);
    final prefs = await SharedPreferences.getInstance();
    final remote = FakeCalorieRemote()..days.addAll(server);
    return CalorieTestEnv._(prefs, remote);
  }

  List<Override> overrides({
    Object? goalValue = _defaultGoal,
    bool goalError = false,
    bool goalLoading = false,
    bool module = true,
    bool offline = false,
    List<FoodLogEntry> recent = const [],
    Object? recentError,
    int ideas = 6,
    DateTime? now,
    DateTime Function()? clock,
  }) {
    final g = identical(goalValue, _defaultGoal) ? goal() : goalValue as NutritionGoal?;
    return [
      calorieSharedPreferencesProvider.overrideWith((ref) => prefs),
      calorieRemoteProvider.overrideWithValue(remote),
      authUserIdProvider.overrideWithValue(kUser),
      calorieClockProvider.overrideWithValue(clock ?? () => now ?? kNow),
      calorieOnlineStreamProvider.overrideWithValue(const Stream<bool>.empty()),
      healthBridgeProvider.overrideWithValue(null),
      testOfflineProvider.overrideWith((ref) => offline),
      isOfflineProvider.overrideWith((ref) => ref.watch(testOfflineProvider)),
      moduleEnabledProvider(AppModule.calories).overrideWithValue(module),
      moduleStoreProvider.overrideWithValue(modules),
      nutritionGoalProvider.overrideWith((ref) {
        if (goalError) return Future<NutritionGoal?>.error(StateError('offline'));
        if (goalLoading) return Completer<NutritionGoal?>().future;
        return Future.value(g);
      }),
      calorieRecentRemoteProvider.overrideWithValue(() async {
        if (recentError != null) throw recentError;
        return recent;
      }),
      calorieIdeasProvider.overrideWith((ref, bucket) async => [
            for (var i = 0; i < ideas; i++) RecipeSuggestionStub.make(i),
          ]),
      weightHistoryProvider.overrideWith((ref) async => [
            WeightLogEntry(
              id: 'wt',
              userId: kUser,
              loggedDate: DateTime(2026, 11, 6),
              weightKg: 72.4,
              createdAt: DateTime(2026, 11, 6),
            ),
          ]),
      activeChallengesProvider.overrideWith((ref) async => [
            DietChallenge(
              id: 'c1',
              userId: kUser,
              type: ChallengeType.fasting16_8,
              status: ChallengeStatus.active,
              startedAt: DateTime.now().subtract(const Duration(days: 4)),
              createdAt: DateTime(2026, 11, 3),
            ),
          ]),
    ];
  }
}

const Object _defaultGoal = Object();

/// The connection in tests; set it to false to "come back online".
final testOfflineProvider = StateProvider<bool>((ref) => false);

class FakeModuleStore implements ModuleStore {
  Map<String, bool>? written;

  @override
  Future<Map<String, dynamic>?> readLocal() async => null;
  @override
  Future<void> writeLocal(Map<String, bool> json) async => written = json;
  @override
  Future<bool?> readLegacyCalories() async => true;
  @override
  Future<Map<String, dynamic>?> readRemote() async => null;
  @override
  Future<void> writeRemote(Map<String, bool> json) async {}
}

/// Recipes for "Was passt noch?" without network images.
abstract final class RecipeSuggestionStub {
  static RecipeSuggestion make(int i) => RecipeSuggestion(
        recipe: Recipe(
          id: 'r$i',
          name: 'Rezept $i',
          description: '',
          imageUrl: '',
          prepTimeMinutes: 10,
          cookTimeMinutes: 10,
          defaultServings: 2,
          ingredients: const [],
          instructions: const [],
          authorId: 'a',
          authorName: 'Avo',
          createdAt: DateTime(2026, 11, 1),
        ),
      );
}

/// Pumps [child] in an app like the real one: Material theme, design scope,
/// toast host, and a GoRouter whose other calories routes record where the
/// screen went.
Future<List<String>> pumpCalories(
  WidgetTester tester,
  Widget child, {
  required List<Override> overrides,
  Locale locale = const Locale('en'),
  Size size = const Size(390, 844),
  String initial = '/screen',
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final visited = <String>[];
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(path: '/screen', builder: (_, __) => child),
      GoRoute(path: '/home', builder: (_, __) => const SizedBox()),
      GoRoute(
        path: '/calories',
        builder: (_, state) {
          visited.add(state.uri.toString());
          return const SizedBox();
        },
        routes: [
          GoRoute(
            path: ':rest(.*)',
            builder: (_, state) {
              visited.add(state.uri.toString());
              return const SizedBox();
            },
          ),
        ],
      ),
    ],
  );
  await tester.pumpWidget(ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      routerConfig: router,
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('de')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(platform: TargetPlatform.iOS, fontFamily: 'CupertinoSystemText'),
      builder: (context, child) => AvoDesignScope(
        reduceTransparencyOverride: false,
        child: AvoToastHost(child: child!),
      ),
    ),
  ));
  await tester.pump();
  await tester.pump();
  return visited;
}

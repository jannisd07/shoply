// Layout matrix (widths 320–440, text 1.0–3.1, bold, dark, contrast) for
// logging food and the goal screens (B6 W3b: S3 segments, S4–S10, S13, S14)
// and their B building blocks.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/nutrition_goal.dart';
import 'package:shoply/data/models/nutrition_info.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/user_model.dart';
import 'package:shoply/data/services/meal_photo_analysis_service.dart';
import 'package:shoply/data/services/native/barcode_scanner_channel.dart';
import 'package:shoply/presentation/screens/calories/calories_add_screen.dart';
import 'package:shoply/presentation/screens/calories/calories_amount_screen.dart';
import 'package:shoply/presentation/screens/calories/calories_entry_screen.dart';
import 'package:shoply/presentation/screens/calories/calories_estimate_screen.dart';
import 'package:shoply/presentation/screens/calories/calories_goal_setup_screen.dart';
import 'package:shoply/presentation/screens/calories/calories_goals_screen.dart';
import 'package:shoply/presentation/screens/calories/calories_manual_screen.dart';
import 'package:shoply/presentation/screens/calories/calories_photo_screen.dart';
import 'package:shoply/presentation/screens/calories/calories_recipe_screen.dart';
import 'package:shoply/presentation/screens/calories/calories_scan_screen.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_amount_food.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_camera_chrome.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_choice_row.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_estimate_parts.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_nutrition_row.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_stepper.dart';
import 'package:shoply/presentation/state/calorie_entry_provider.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';

import '../../../screens/calories/calorie_fakes.dart';
import '../../layout_matrix.dart';

late CalorieTestEnv _env;

const _code = '4056489123453';

Widget _scope(Widget child, List<Override> overrides) => ProviderScope(overrides: overrides, child: child);

final _user = UserModel(
  id: kUser,
  email: 'a@example.invalid',
  displayName: 'A',
  age: 34,
  gender: 'female',
  height: 168,
  allergies: const ['peanuts'],
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

final _goal = goal().copyWith(
  goalType: NutritionGoalType.loseWeight,
  activityLevel: ActivityLevel.moderate,
  currentWeightKg: 74,
  targetWeightKg: 70,
  heightCm: 168,
  pace: GoalPace.normal,
);

final _estimate = photoEstimate(
  dish: 'Spaghetti Bolognese mit Parmesan und frischem Basilikum',
  components: [
    {'name': 'Spaghetti, gekocht', 'grams': 220, 'kcal': 345},
    {'name': 'Bolognese-Soße mit Rinderhack', 'grams': 150, 'kcal': 305},
    {'name': 'Erdnusssoße', 'grams': 30, 'kcal': 150},
  ],
);

Recipe _recipe({NutritionInfo? nutrition = const NutritionInfo(calories: 520, proteinG: 18, carbsG: 40, fatG: 30)}) => Recipe(
      id: 'r1',
      name: 'Ofengemüse mit Feta und einer langen Kräuterkruste',
      description: '',
      imageUrl: '',
      prepTimeMinutes: 10,
      cookTimeMinutes: 30,
      defaultServings: 2,
      ingredients: const [],
      instructions: const [],
      authorId: 'a',
      authorName: 'Avo',
      createdAt: DateTime(2026, 11, 1),
      nutrition: nutrition,
    );

final _photoEntry = FoodLogEntry(
  id: 'p1',
  userId: kUser,
  loggedDate: DateTime(2026, 11, 7),
  mealType: MealType.lunch,
  origin: FoodEntryOrigin.photo,
  foodName: 'Rotes Linsen-Dal mit Kokosmilch und Koriander',
  quantity: 1,
  unit: 'serving',
  calories: 470,
  proteinG: 22,
  carbsG: 58,
  fatG: 14,
  estimated: true,
  confidence: EstimateConfidence.medium,
  loggedTime: const FoodLogTime(12, 41),
  createdAt: DateTime(2026, 11, 7, 12, 41),
);

void main() {
  setUpAll(() async {
    final day = CalorieDay(dateKey: kToday, entries: [...usualDay().entries, _photoEntry]);
    _env = await CalorieTestEnv.create(stored: {kToday: day}, server: {kToday: day}, storedGoal: _goal);
  });

  List<Override> o({
    bool offline = false,
    FakeCalorieCamera? camera,
    Future<MealPhotoEstimate> Function(Uint8List photo)? analyzer,
    NutritionGoal? goalValue,
  }) =>
      _env.overrides(
        offline: offline,
        camera: camera,
        user: _user,
        goalValue: goalValue ?? _goal,
        offHits: [offProduct(_code, 'Skyr Natur Magerstufe extra cremig', brand: 'Milbona')],
        analyzer: analyzer,
      );

  // ── S3 segments ───────────────────────────────────────────────────────

  layoutMatrix(
    'Essen eintragen, photo segment (S3)',
    (context) => _scope(const CaloriesAddScreen(), o()),
    checkTapTargets: true,
    afterPump: (tester) async {
      final container = ProviderScope.containerOf(tester.element(find.byType(CaloriesAddScreen)));
      container.read(calorieInputMethodProvider.notifier).choose(CalorieInputMethod.photo);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Take photo', skipOffstage: false), findsOneWidget);
    },
  );

  layoutMatrix(
    'Essen eintragen, barcode segment (S3)',
    (context) => _scope(const CaloriesAddScreen(), o()),
    checkTapTargets: true,
    afterPump: (tester) async {
      final container = ProviderScope.containerOf(tester.element(find.byType(CaloriesAddScreen)));
      container.read(calorieInputMethodProvider.notifier).choose(CalorieInputMethod.barcode);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Open camera', skipOffstage: false), findsOneWidget);
    },
  );

  // ── S4, S6 ────────────────────────────────────────────────────────────

  layoutMatrix(
    'Foto aufnehmen, camera refused (S4)',
    (context) => _scope(
      const CaloriesPhotoScreen(),
      o(camera: FakeCalorieCamera(permissionValue: CameraPermission.denied)),
    ),
    checkTapTargets: true,
  );

  layoutMatrix(
    'Barcode-Kamera, no scanner (S6)',
    (context) => _scope(const CaloriesScanScreen(), o(camera: FakeCalorieCamera(supported: false))),
    checkTapTargets: true,
  );

  layoutMatrix(
    'Barcode-Kamera, unknown code (S6)',
    (context) => _scope(
      const CaloriesScanScreen(),
      o(camera: FakeCalorieCamera(scanResult: const BarcodeScanResult(BarcodeScanStatus.scanned, code: '4000000000099'))),
    ),
    afterPump: (tester) async {
      expect(find.text('Nothing is known about this barcode.', skipOffstage: false), findsOneWidget);
    },
  );

  // ── S5 ────────────────────────────────────────────────────────────────

  layoutMatrix(
    'Schätzung prüfen, result with allergy (S5)',
    (context) => _scope(CaloriesEstimateScreen(photo: kJpeg), o(analyzer: (_) async => _estimate)),
    checkTapTargets: true,
    afterPump: (tester) async {
      expect(find.textContaining('May contain', skipOffstage: false), findsOneWidget);
    },
  );

  layoutMatrix(
    'Schätzung prüfen, estimating (S5)',
    (context) => _scope(CaloriesEstimateScreen(photo: kJpeg), o()),
  );

  layoutMatrix(
    'Schätzung prüfen, no food (S5)',
    (context) => _scope(
      CaloriesEstimateScreen(photo: kJpeg),
      o(analyzer: (_) async => throw const MealPhotoException('no_food_detected')),
    ),
    checkTapTargets: true,
  );

  // ── S7, S8 ────────────────────────────────────────────────────────────

  layoutMatrix(
    'Menge, serving and pack (S7)',
    (context) => _scope(
      CaloriesAmountScreen(
        foodId: _code,
        food: CalorieAmountFood.fromProduct(
          offProduct(_code, 'Skyr Natur Magerstufe extra cremig', brand: 'Milbona', servingG: 150, packageG: 500),
          origin: FoodEntryOrigin.barcode,
        ),
      ),
      o(),
    ),
    checkTapTargets: true,
  );

  layoutMatrix(
    'Menge, nutrition missing (S7)',
    (context) => _scope(
      CaloriesAmountScreen(
        foodId: _code,
        food: CalorieAmountFood.fromProduct(offProduct(_code, 'Haferdrink', kcal: null), origin: FoodEntryOrigin.barcode),
      ),
      o(),
    ),
  );

  layoutMatrix(
    'Manuell eintragen (S8)',
    (context) => _scope(const CaloriesManualScreen(name: 'Käsebrötchen mit Butter und Schnittlauch'), o()),
    checkTapTargets: true,
  );

  // ── S9, S10 ───────────────────────────────────────────────────────────

  layoutMatrix(
    'Eintrag bearbeiten, photo estimate (S9)',
    (context) => _scope(const CaloriesEntryScreen(entryId: 'p1', dateKey: kToday), o()),
    checkTapTargets: true,
  );

  layoutMatrix(
    'Eintrag bearbeiten, grams (S9)',
    (context) => _scope(const CaloriesEntryScreen(entryId: 'e1', dateKey: kToday), o()),
  );

  layoutMatrix(
    'Rezept ins Tagebuch (S10)',
    (context) => _scope(CaloriesRecipeScreen(recipeId: 'r1', recipe: _recipe(), planDateKey: '2026-11-09'), o()),
    checkTapTargets: true,
  );

  layoutMatrix(
    'Rezept ins Tagebuch, no nutrition offline (S10)',
    (context) => _scope(CaloriesRecipeScreen(recipeId: 'r1', recipe: _recipe(nutrition: null)), o(offline: true)),
  );

  // ── S13, S14 ──────────────────────────────────────────────────────────

  layoutMatrix(
    'Ziele (S13)',
    (context) => _scope(const CaloriesGoalsScreen(), o()),
    checkTapTargets: true,
  );

  layoutMatrix(
    'Ziele, low kcal and an open value (S13)',
    (context) => _scope(const CaloriesGoalsScreen(), o(goalValue: _goal.copyWith(dailyCalorieTarget: 1100))),
    afterPump: (tester) async {
      await tester.tap(find.text('Calories'));
      await tester.pump(const Duration(milliseconds: 300));
    },
  );

  layoutMatrix(
    'Ziel berechnen (S14)',
    (context) => _scope(const CaloriesGoalSetupScreen(from: 'goals'), o()),
    checkTapTargets: true,
  );

  // ── Building blocks ───────────────────────────────────────────────────

  layoutMatrix(
    'CalorieStepper with value',
    (context) => CalorieStepper(
      value: 1.5,
      step: 0.5,
      min: 0.5,
      max: 20,
      showValue: true,
      format: (v) => '$v',
      semanticLabel: 'Portionen',
      spokenValue: (v) => '$v',
      onChanged: (_) {},
    ),
    checkTapTargets: true,
  );

  layoutMatrix(
    'NutritionRow and ConfidenceRow',
    (context) => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          nutritionRowFor(context, kcal: 1158, protein: 27.5, carbs: 102, fat: 0.5),
          const SizedBox(height: 12),
          const ConfidenceRow(confidence: EstimateConfidence.low, suffix: 'geschätzt, von dir angepasst'),
        ],
      ),
    ),
  );

  layoutMatrix(
    'CalorieChoiceRow',
    (context) => InsetSection(children: [
      CalorieChoiceRow(title: 'Extrem aktiv', subtitle: 'Körperliche Arbeit und Sport', selected: true, onTap: () {}),
      CalorieChoiceRow(
        title: 'Abnehmen',
        subtitle: 'Für unter 18-Jährige berechnen wir kein Abnehm-Ziel.',
        selected: false,
        enabled: false,
        onTap: () {},
      ),
    ]),
    scrollable: true,
    checkTapTargets: true,
  );

  layoutMatrix(
    'ComponentRow, open',
    (context) => InsetSection(children: [
      ComponentRow(
        part: const EstimatePart(id: 1, name: 'Bolognese-Soße mit Rinderhack und Rotwein', grams: 150, kcalPerGram: 2),
        expanded: true,
        onToggle: () {},
        onGrams: (_) {},
        onRemove: () {},
      ),
      AddComponentRow(onAdd: (_, __, ___) {}),
    ]),
    scrollable: true,
    checkTapTargets: true,
  );

  layoutMatrix(
    'CameraHintCapsule',
    (context) => const CameraBackdrop(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: CameraHintCapsule(text: '4 056489 123453 · wird gesucht …'),
      ),
    ),
  );
}

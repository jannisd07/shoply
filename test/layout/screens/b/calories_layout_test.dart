// Layout matrix (widths 320–440, text 1.0–3.1, bold, dark, contrast) for the
// calories diary, "Essen eintragen" and the Home sections (B6 W3).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/presentation/screens/calories/calories_add_screen.dart';
import 'package:shoply/presentation/screens/calories/calories_diary_screen.dart';
import 'package:shoply/presentation/widgets/design/home_card.dart';
import 'package:shoply/presentation/widgets/home_sections/home_calories.dart';

import '../../../screens/calories/calorie_fakes.dart';
import '../../layout_matrix.dart';

late CalorieTestEnv _env;

const _past = '2026-11-05';

final _history = [
  food('h1', 'Haferflocken mit Heidelbeeren und Mandelmus', 380, quantity: 60, unit: 'g', date: '2026-11-06'),
  food('h2', 'Skyr Natur', 130, quantity: 250, unit: 'g', brand: 'Milbona', date: '2026-11-06'),
  food('h3', 'Apfel', 80, date: '2026-11-04'),
];

Widget _scope(Widget child, List<Override> overrides) =>
    ProviderScope(overrides: overrides, child: child);

Widget _home() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          HomeCaloriesToday(),
          SizedBox(height: 24),
          AvoTileGrid(children: [SizedBox(), HomeWaterTile()]),
          SizedBox(height: 24),
          HomeCalorieIdeasHint(),
        ],
      ),
    );

void main() {
  setUpAll(() async {
    final day = usualDay().copyWith(entries: [
      ...usualDay().entries,
      food('e9', 'Ofengemüse mit Feta und einer sehr langen Beschreibung', 520,
          meal: MealType.dinner, estimated: true, brand: 'Selbst gekocht'),
    ]);
    _env = await CalorieTestEnv.create(
      stored: {kToday: day, _past: usualDay(date: _past)},
      server: {kToday: day, _past: usualDay(date: _past)},
      storedGoal: goal(),
      extraPrefs: {'cal_ideas_v1_$kUser': '{"date":"$kToday","count":4}'},
    );
  });

  layoutMatrix(
    'Calories diary (S1)',
    (context) => _scope(const CaloriesDiaryScreen(), _env.overrides()),
    checkTapTargets: true,
    afterPump: (tester) async {
      expect(find.text('Spaghetti Bolognese', skipOffstage: false), findsOneWidget);
      expect(find.text('This week', skipOffstage: false), findsOneWidget);
    },
  );

  layoutMatrix(
    'Calories diary, past day over the goal (S1)',
    (context) => _scope(
      const CaloriesDiaryScreen(initialDateKey: _past),
      _env.overrides(goalValue: goal(kcal: 1200)),
    ),
  );

  layoutMatrix(
    'Calories diary without a goal (S1a)',
    (context) => _scope(const CaloriesDiaryScreen(), _env.overrides(goalValue: null)),
  );

  layoutMatrix(
    'Calories diary offline, first start (S1)',
    (context) => _scope(
      const CaloriesDiaryScreen(initialDateKey: '2026-10-01'),
      _env.overrides(offline: true, goalLoading: true),
    ),
  );

  layoutMatrix(
    'Essen eintragen (S3)',
    (context) => _scope(
      const CaloriesAddScreen(dateKey: _past),
      _env.overrides(recent: _history, offline: true),
    ),
    checkTapTargets: true,
    afterPump: (tester) async {
      expect(find.text('Skyr Natur', skipOffstage: false), findsOneWidget);
    },
  );

  layoutMatrix(
    'Essen eintragen, first start (S3)',
    (context) => _scope(const CaloriesAddScreen(), _env.overrides()),
  );

  layoutMatrix(
    'Home: Kalorien heute, Wasser heute, hint (S0)',
    (context) => _scope(_home(), _env.overrides(now: DateTime(2026, 11, 7, 18))),
    scrollable: true,
    checkTapTargets: true,
    afterPump: (tester) async {
      expect(find.text('CALORIES', skipOffstage: false), findsOneWidget);
      expect(find.text('Water today', skipOffstage: false), findsOneWidget);
    },
  );

  layoutMatrix(
    'Home: no goal (S0)',
    (context) => _scope(_home(), _env.overrides(goalValue: null)),
    scrollable: true,
  );

  layoutMatrix(
    'Home: over the goal (S0)',
    (context) => _scope(_home(), _env.overrides(goalValue: goal(kcal: 1200, water: 4000))),
    scrollable: true,
  );

  layoutMatrix(
    'Home: first start (S0)',
    (context) => _scope(
      const Padding(padding: EdgeInsets.all(16), child: HomeCaloriesToday()),
      _env.overrides(goalLoading: true),
    ),
    scrollable: true,
  );
}

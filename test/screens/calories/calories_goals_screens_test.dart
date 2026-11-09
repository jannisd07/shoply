// S13 "Ziele" and S14 "Ziel berechnen" of docs/redesign/b-screens/kalorien.md:
// values open in place with field and stepper (no slider anywhere), saved
// on closing with undo, warnings, "Richtwerte, kein ärztlicher Rat."; the
// goal form with the result on top, every check, and "Übernehmen".
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shoply/data/models/nutrition_goal.dart';
import 'package:shoply/data/models/user_model.dart';
import 'package:shoply/data/services/nutrition_goal_service.dart';
import 'package:shoply/presentation/screens/calories/calories_goal_setup_screen.dart';
import 'package:shoply/presentation/screens/calories/calories_goals_screen.dart';
import 'package:shoply/presentation/widgets/design/segmented_control.dart';

import 'calorie_fakes.dart';

UserModel _user({int? age = 34, String? gender = 'female', double? height = 168}) => UserModel(
      id: kUser,
      email: 'a@example.invalid',
      displayName: 'A',
      age: age,
      gender: gender,
      height: height,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

NutritionGoal _goal({int kcal = 2000, NutritionGoalType type = NutritionGoalType.loseWeight}) => goal(kcal: kcal).copyWith(
      goalType: type,
      activityLevel: ActivityLevel.light,
      currentWeightKg: 74,
      targetWeightKg: 70,
      heightCm: 168,
      pace: GoalPace.normal,
    );

void _expectNoSlider() {
  expect(find.byType(Slider), findsNothing);
  expect(find.byType(CupertinoSlider), findsNothing);
}

void main() {
  group('S13 Goals', () {
    testWidgets('per day, your goal, workouts and the guide-values note; no slider', (tester) async {
      final env = await CalorieTestEnv.create();
      await pumpCalories(tester, const CaloriesGoalsScreen(), overrides: env.overrides(goalValue: _goal()));
      await settleFrames(tester);

      expect(find.text('Goals'), findsOneWidget);
      expect(find.text('PER DAY'), findsOneWidget);
      expect(find.text('2,000 kcal'), findsOneWidget);
      expect(find.text('133 g'), findsOneWidget);
      expect(find.text('2 L'), findsOneWidget);
      expect(find.textContaining('Tap a value to set it yourself.'), findsOneWidget);
      expect(find.text('Lose weight'), findsOneWidget);
      expect(find.textContaining('70 kg · around'), findsOneWidget);
      expect(find.text('Lightly active'), findsOneWidget);
      expect(find.text('Add workout calories to my budget'), findsOneWidget);
      expect(find.text('Guide values, not medical advice.'), findsOneWidget);
      _expectNoSlider();
    });

    testWidgets('a value opens in place; closing saves it as own values, with undo', (tester) async {
      final env = await CalorieTestEnv.create();
      final semantics = tester.ensureSemantics();
      await pumpCalories(tester, const CaloriesGoalsScreen(), overrides: env.overrides(goalValue: _goal()));
      await settleFrames(tester);

      await tester.tap(find.text('Calories'));
      await settleFrames(tester);
      await tester.tap(find.bySemanticsLabel('Increase'));
      await settleFrames(tester);
      expect(find.text('2,050 kcal'), findsOneWidget);
      expect(env.remote.goals, isEmpty, reason: 'saved when the value closes');

      await tester.tap(find.text('Calories'));
      await settleFrames(tester);
      expect(env.remote.goals.last['daily_calorie_target'], 2050);
      expect(env.remote.goals.last['goal_type'], 'custom');
      expect(find.text('Calorie goal changed'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await settleFrames(tester);
      expect(env.remote.goals.last['daily_calorie_target'], 2000);
      semantics.dispose();
    });

    testWidgets('under 1,200 kcal: the warning; macros that do not add up: the footnote', (tester) async {
      final env = await CalorieTestEnv.create();
      await pumpCalories(tester, const CaloriesGoalsScreen(), overrides: env.overrides(goalValue: _goal(kcal: 1100)));
      await settleFrames(tester);

      expect(find.text('Below 1,200 kcal a day isn\'t recommended without medical supervision.'), findsOneWidget);
      expect(find.text('Your macros add up to 1,998 kcal; your goal is 1,100.'), findsOneWidget);
    });

    testWidgets('own values: "Your own values." with "Recalculate"', (tester) async {
      final env = await CalorieTestEnv.create();
      await pumpCalories(tester, const CaloriesGoalsScreen(),
          overrides: env.overrides(goalValue: _goal(type: NutritionGoalType.custom)));
      await settleFrames(tester);

      expect(find.text('Your own values.'), findsOneWidget);
      expect(find.text('Recalculate'), findsWidgets);
      expect(find.textContaining('Tap a value to set it yourself.'), findsNothing);
    });

    testWidgets('the workout switch is saved', (tester) async {
      final env = await CalorieTestEnv.create();
      await pumpCalories(tester, const CaloriesGoalsScreen(), overrides: env.overrides(goalValue: _goal()));
      await settleFrames(tester);

      await tester.ensureVisible(find.text('Add workout calories to my budget'));
      await tester.tap(find.text('Add workout calories to my budget'));
      await settleFrames(tester);
      expect(env.remote.goals.last['credit_workouts'], isTrue);
    });

    testWidgets('no goal yet: S14 instead', (tester) async {
      final env = await CalorieTestEnv.create();
      final router = await pumpCaloriesFlow(tester, overrides: env.overrides(goalValue: null));
      router.go('/calories');
      await settleFrames(tester);
      router.push('/calories/goals');
      await settleFrames(tester);
      expect(find.byType(CaloriesGoalSetupScreen), findsOneWidget);
      expect(find.byType(CaloriesGoalsScreen), findsNothing);
    });

    testWidgets('/settings/health/goals is the same screen in the Profil tab', (tester) async {
      final env = await CalorieTestEnv.create();
      final router = await pumpCaloriesFlow(tester, overrides: env.overrides(goalValue: _goal()));
      router.go('/settings/health/goals');
      await settleFrames(tester);
      expect(find.byType(CaloriesGoalsScreen), findsOneWidget);
    });
  });

  group('S14 Goal setup', () {
    Future<void> pump(WidgetTester tester, CalorieTestEnv env, {NutritionGoal? goalValue, UserModel? user}) async {
      await pumpCalories(tester, const CaloriesGoalSetupScreen(from: 'goals'),
          overrides: env.overrides(goalValue: goalValue, user: user));
      await settleFrames(tester);
    }

    testWidgets('filled from goal and profile; the result on top; no slider', (tester) async {
      final env = await CalorieTestEnv.create();
      final semantics = tester.ensureSemantics();
      await pump(tester, env, goalValue: _goal(), user: _user());

      final expected = NutritionGoalCalculator.calculate(
        goalType: NutritionGoalType.loseWeight,
        activityLevel: ActivityLevel.light,
        currentWeightKg: 74,
        heightCm: 168,
        age: 34,
        gender: 'female',
        targetWeightKg: 70,
        pace: GoalPace.normal,
      );
      expect(find.bySemanticsLabel('Result: ${_thousands(expected.dailyCalorieTarget)} calories a day'), findsOneWidget);
      expect(find.text('Calculated with the Mifflin-St Jeor formula from your details. Guide values, not medical advice.'),
          findsOneWidget);
      expect(find.byType(AppSegmentedControl<GoalPace>), findsOneWidget);
      expect(find.textContaining('About 0.5 kg a week. Target weight around'), findsOneWidget);
      expect(find.text('Age, height and sex are saved in your personal details and only used for this calculation.'),
          findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Lose weight')),
        isSemantics(isInMutuallyExclusiveGroup: true, isChecked: true, hasCheckedState: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Mostly sitting')),
        isSemantics(isInMutuallyExclusiveGroup: true, isChecked: false, hasCheckedState: true),
      );
      _expectNoSlider();
      semantics.dispose();
    });

    testWidgets('missing inputs: a dash, the sentence, "Use this goal" off', (tester) async {
      final env = await CalorieTestEnv.create();
      await pump(tester, env, goalValue: null, user: _user(age: null, height: null));

      expect(find.text('–'), findsWidgets);
      expect(find.text('Age, height and weight are still missing.'), findsWidgets);
      await tester.tap(find.text('Use this goal'));
      await settleFrames(tester);
      expect(env.remote.goals, isEmpty);
    });

    testWidgets('"1,68" becomes 168 cm; out-of-range values say so', (tester) async {
      final env = await CalorieTestEnv.create();
      await pump(tester, env, goalValue: _goal(), user: _user());
      final fields = find.byType(EditableText);

      await tester.enterText(fields.at(1), '1,68');
      await settleFrames(tester);
      expect(find.text('Saved as 168 cm'), findsOneWidget);

      await tester.enterText(fields.at(0), '9');
      await tester.enterText(fields.at(2), '400');
      await settleFrames(tester);
      expect(find.text('Enter an age between 13 and 110.'), findsOneWidget);
      expect(find.text('Enter a weight between 30 and 300 kg.'), findsOneWidget);
    });

    testWidgets('losing with a target above the weight: the question and "Switch"', (tester) async {
      final env = await CalorieTestEnv.create();
      await pump(tester, env, goalValue: _goal(), user: _user());

      await tester.enterText(find.byType(EditableText).at(3), '80');
      await settleFrames(tester);
      expect(find.text('Your target is above your current weight. Did you mean “Build muscle”?'), findsOneWidget);
      await tester.ensureVisible(find.text('Switch'));
      await settleFrames(tester);
      await tester.tap(find.text('Switch'));
      await settleFrames(tester);
      expect(find.textContaining('Did you mean'), findsNothing);
    });

    testWidgets('under 18: "Lose weight" is off and says why', (tester) async {
      final env = await CalorieTestEnv.create();
      await pump(tester, env, goalValue: _goal(type: NutritionGoalType.maintain), user: _user(age: 16));

      expect(find.text('We don\'t calculate a weight-loss goal for anyone under 18.'), findsOneWidget);
    });

    testWidgets('"Use this goal" saves through the queue, logs a changed weight and leaves', (tester) async {
      final env = await CalorieTestEnv.create();
      await pump(tester, env, goalValue: _goal(), user: _user());

      await tester.enterText(find.byType(EditableText).at(2), '75');
      await settleFrames(tester);
      await tester.tap(find.text('Use this goal'));
      await settleFrames(tester);

      final saved = env.remote.goals.last;
      expect(saved['goal_type'], 'lose_weight');
      expect(saved['current_weight_kg'], 75);
      expect(saved['pace'], 'normal');
      expect(saved['daily_calorie_target'], isA<int>());
      expect(env.remote.weights.single['weight_kg'], 75);
      expect(find.byType(CaloriesGoalSetupScreen), findsNothing);
    });

    testWidgets('leaving with changes asks "Discard changes?"', (tester) async {
      final env = await CalorieTestEnv.create();
      await pump(tester, env, goalValue: _goal(), user: _user());

      await tester.ensureVisible(find.text('Very active'));
      await settleFrames(tester);
      await tester.tap(find.text('Very active'));
      await settleFrames(tester);
      await tester.tap(find.bySemanticsLabel('Back'));
      await settleFrames(tester);
      expect(find.text('Discard changes?'), findsOneWidget);
      expect(find.text('Your goal stays as it was.'), findsOneWidget);
    });
  });
}

String _thousands(int v) => v >= 1000 ? '${v ~/ 1000},${(v % 1000).toString().padLeft(3, '0')}' : '$v';

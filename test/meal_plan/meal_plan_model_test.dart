// Wochenplan (B7): data classes, local calendar days and the row format of
// meal_plan_entries / meal_plans / meal_plan_settings.
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/meal_plan.dart';
import 'package:shoply/data/models/nutrition_info.dart';
import 'package:shoply/data/models/recipe.dart';

Recipe _recipe({int servings = 4, int? kcal = 480}) => Recipe(
      id: 'recipe_001',
      name: 'Chili sin Carne',
      description: '',
      imageUrl: 'https://example.test/chili.jpg',
      prepTimeMinutes: 10,
      cookTimeMinutes: 30,
      defaultServings: servings,
      ingredients: const [
        Ingredient(name: 'Zwiebel', amount: 1, unit: ''),
        Ingredient(name: 'Kidneybohnen', amount: 2, unit: 'Dose'),
      ],
      instructions: const [],
      authorId: 'a',
      authorName: 'A',
      createdAt: DateTime(2026, 1, 1),
      language: 'de',
      nutrition: kcal == null ? null : NutritionInfo(calories: kcal),
    );

MealPlanEntry _entry({
  int servings = 2,
  int? sentServings,
  DateTime? sentAt,
}) =>
    MealPlanEntry(
      id: 'e1',
      userId: 'u1',
      planDate: DateTime(2026, 11, 11),
      recipeId: 'recipe_001',
      snapshot: PlanRecipeSnapshot.fromRecipe(_recipe()),
      servings: servings,
      position: 0,
      sentServings: sentServings,
      sentAt: sentAt,
      sentListId: sentAt == null ? null : 'list-1',
      createdAt: DateTime(2026, 11, 7),
      updatedAt: DateTime(2026, 11, 7),
    );

void main() {
  group('calendar days', () {
    test('the week starts on Monday (ISO)', () {
      expect(planWeekStart(DateTime(2026, 11, 11, 23, 59)), DateTime(2026, 11, 9));
      expect(planWeekStart(DateTime(2026, 11, 9)), DateTime(2026, 11, 9));
      expect(planWeekStart(DateTime(2026, 11, 15, 8)), DateTime(2026, 11, 9));
      expect(planWeekStart(DateTime(2026, 11, 16)), DateTime(2026, 11, 16));
    });

    test('a week across the DST change still starts at local midnight', () {
      // 25.10.2026 is the last Sunday of October (clocks go back).
      final start = planWeekStart(DateTime(2026, 10, 28, 12));
      expect(start, DateTime(2026, 10, 26));
      expect(planWeekDays(DateTime(2026, 10, 19)).last, DateTime(2026, 10, 25));
      expect(planWeekDays(DateTime(2026, 10, 19)).map((d) => d.hour).toSet(), {0});
    });

    test('plan dates are local days, written as YYYY-MM-DD', () {
      expect(planDateKey(DateTime(2026, 3, 5, 23, 30)), '2026-03-05');
      expect(parsePlanDate('2026-03-05'), DateTime(2026, 3, 5));
      expect(parsePlanDate('2026-03-05T00:00:00+00:00'), DateTime(2026, 3, 5));
      expect(planDay(DateTime(2026, 3, 5, 18, 12)), DateTime(2026, 3, 5));
    });
  });

  group('PlanRecipeSnapshot', () {
    test('keeps what the plan needs offline, ingredients included', () {
      final s = PlanRecipeSnapshot.fromRecipe(_recipe());
      expect(s.name, 'Chili sin Carne');
      expect(s.kcalPerServing, 480);
      expect(s.totalMinutes, 40);
      expect(s.defaultServings, 4);
      expect(s.language, 'de');
      expect(s.ingredients, hasLength(2));
      expect(PlanRecipeSnapshot.fromJson(s.toJson()), s);
    });

    test('reads damaged or partial json without throwing', () {
      final s = PlanRecipeSnapshot.fromJson({
        'name': null,
        'default_servings': 'x',
        'ingredients': [
          {'name': 'Salz', 'amount': null, 'unit': null},
          'garbage',
          {'name': 'Mehl', 'amount': '150', 'unit': 'g'},
        ],
      });
      expect(s.name, '');
      expect(s.defaultServings, 0);
      expect(s.ingredients.map((i) => i.name), ['Salz', 'Mehl']);
      expect(s.ingredients.first.amount, 0);
      expect(s.ingredients.last.amount, 150);
    });
  });

  group('MealPlanEntry', () {
    test('open servings: all before sending, only the difference after', () {
      expect(_entry(servings: 3).openServings, 3);
      expect(_entry(servings: 5, sentServings: 3, sentAt: DateTime(2026, 11, 7)).openServings, 2);
      expect(_entry(servings: 2, sentServings: 4, sentAt: DateTime(2026, 11, 7)).openServings, 0);
    });

    test('row round trip with the table columns', () {
      final e = _entry(sentServings: 2, sentAt: DateTime.utc(2026, 11, 7, 10))
          .copyWith(mealType: MealType.lunch, position: 2);
      final row = e.toRow();
      expect(row['plan_date'], '2026-11-11');
      expect(row['meal_type'], 'lunch');
      expect(row['user_id'], 'u1');
      expect(row['recipe_snapshot'], isA<Map<String, dynamic>>());
      expect(row.containsKey('created_at'), isFalse,
          reason: 'the database sets created_at/updated_at');
      final back = MealPlanEntry.fromRow({
        ...row,
        'created_at': '2026-11-07T00:00:00Z',
        'updated_at': '2026-11-07T00:00:00Z',
      });
      expect(back.planDate, DateTime(2026, 11, 11));
      expect(back.mealType, MealType.lunch);
      expect(back.sentAt, DateTime.utc(2026, 11, 7, 10));
      expect(back.copyWith(createdAt: e.createdAt, updatedAt: e.updatedAt), e);
    });

    test('servings are kept within 1..20', () {
      expect(_entry().copyWith(servings: 0).servings, 1);
      expect(_entry().copyWith(servings: 99).servings, 20);
    });

    test('clearing the sent marker', () {
      final sent = _entry(sentServings: 2, sentAt: DateTime(2026, 11, 7));
      final cleared = sent.clearSent();
      expect(cleared.sentAt, isNull);
      expect(cleared.sentServings, isNull);
      expect(cleared.sentListId, isNull);
    });
  });

  group('MealPlanSettings', () {
    test('defaults match the migration', () {
      const s = MealPlanSettings.defaults;
      expect(s.defaultServings, 2);
      expect(s.pantry, ['Salz', 'Pfeffer', 'Wasser', 'Öl', 'Zucker', 'Mehl']);
      expect(s.showTodayHint, isTrue);
      expect(s.reminderEnabled, isFalse);
      expect(s.reminderWeekday, 7);
      expect(s.reminderHour, 18);
      expect(s.reminderMinute, 0);
    });

    test('row round trip, time as HH:MM:SS', () {
      final s = MealPlanSettings.defaults.copyWith(
        defaultServings: 3,
        targetListId: 'list-1',
        reminderHour: 9,
        reminderMinute: 5,
      );
      final row = s.toRow('u1');
      expect(row['reminder_time'], '09:05:00');
      expect(MealPlanSettings.fromRow(row), s);
    });
  });

  group('MealPlanWeek', () {
    test('row round trip', () {
      final w = MealPlanWeek(
        weekStart: DateTime(2026, 11, 9),
        targetListId: 'list-1',
        firstSentAt: DateTime.utc(2026, 11, 7, 9),
      );
      final row = w.toRow('u1');
      expect(row['week_start'], '2026-11-09');
      expect(MealPlanWeek.fromRow(row), w);
    });
  });
}

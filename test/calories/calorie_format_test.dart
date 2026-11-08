import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:shoply/core/localization/app_translations.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_format.dart';

FoodLogEntry _entry({double quantity = 1, String? unit, String? brand, bool estimated = false}) => FoodLogEntry(
      id: 'e',
      userId: 'u',
      loggedDate: DateTime(2026, 11, 7),
      mealType: MealType.lunch,
      foodName: 'Skyr',
      quantity: quantity,
      unit: unit,
      brand: brand,
      estimated: estimated,
      createdAt: DateTime(2026, 11, 7),
    );

Future<BuildContext> _context(WidgetTester tester, Locale locale) async {
  late BuildContext ctx;
  await tester.pumpWidget(Localizations(
    locale: locale,
    delegates: GlobalMaterialLocalizations.delegates,
    child: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    }),
  ));
  return ctx;
}

void main() {
  setUpAll(() => initializeDateFormatting('de'));

  test('meal by time of day (§3.3)', () {
    MealType at(int h, int m) => mealForTime(DateTime(2026, 11, 7, h, m));
    expect(at(10, 29), MealType.breakfast);
    expect(at(10, 30), MealType.lunch);
    expect(at(14, 59), MealType.lunch);
    expect(at(15, 0), MealType.snack);
    expect(at(17, 0), MealType.dinner);
    expect(at(21, 29), MealType.dinner);
    expect(at(21, 30), MealType.snack);
  });

  test('query values: unknown meals and future dates are ignored', () {
    expect(mealFromQuery('dinner'), MealType.dinner);
    expect(mealFromQuery('brunch'), isNull);
    expect(dateKeyFromQuery('2026-11-05', '2026-11-07'), '2026-11-05');
    expect(dateKeyFromQuery('2026-11-08', '2026-11-07'), isNull);
    expect(dateKeyFromQuery('gestern', '2026-11-07'), isNull);
  });

  testWidgets('German formats: kcal, litres, dates, amounts', (tester) async {
    final c = await _context(tester, const Locale('de'));
    expect(c.kcal(1360), '1.360');
    expect(c.liters(1250), '1,25');
    expect(c.liters(2000), '2');
    expect(c.grams(0.5), '0,5');
    expect(c.grams(82.4), '82');
    expect(c.shortDate(DateTime(2026, 11, 5)), 'Do., 5. Nov.');
    expect(c.diaryDate('2026-11-07', '2026-11-07'), 'Heute, Sa., 7. Nov.');
    expect(c.diaryDate('2026-11-06', '2026-11-07'), 'Gestern, Fr., 6. Nov.');
    expect(c.weekdayShort(DateTime(2026, 11, 2)), 'Mo');
    expect(c.entrySubtitle(_entry(quantity: 250, unit: 'g', brand: 'Milbona')), '250 g · Milbona');
    expect(c.entrySubtitle(_entry(unit: 'serving', estimated: true)), '1 Portion · geschätzt');
    expect(c.entrySubtitle(_entry()), isNull);
    expect(c.mealName(MealType.snack), 'Snacks');
  });

  testWidgets('English formats', (tester) async {
    final c = await _context(tester, const Locale('en'));
    expect(c.kcal(1360), '1,360');
    expect(c.liters(1250), '1.25');
    expect(c.shortDate(DateTime(2026, 11, 5)), 'Thu, Nov 5');
    expect(c.entrySubtitle(_entry(quantity: 2, unit: 'serving')), '2 servings');
  });

  test('keys built at run time exist in both languages', () {
    const keys = [
      'cal_meal_breakfast', 'cal_meal_lunch', 'cal_meal_snack', 'cal_meal_dinner', //
      'cal_unit_left', 'cal_unit_over', 'cal_unit_eaten',
      'cal_recipes_count_one', 'cal_recipes_count_other',
      'cal_status_pending_one', 'cal_status_pending_other',
      'cal_servings_one', 'cal_servings_other',
      'cal_past_goal_under', 'cal_past_goal_over',
    ];
    for (final key in keys) {
      for (final lang in ['de', 'en']) {
        expect(AppTranslations.get(key, lang), isNot(key), reason: '$key ($lang)');
      }
    }
  });
}

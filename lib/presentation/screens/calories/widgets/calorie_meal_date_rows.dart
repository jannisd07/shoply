import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_date_menu.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_format.dart';
import 'package:shoply/presentation/state/calorie_diary_provider.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';

/// "Mahlzeit" with the meal menu (Frühstück … Abendessen, the current one
/// checked), anchored at the row.
class CalorieMealRow extends StatelessWidget {
  const CalorieMealRow({super.key, required this.meal, required this.onChanged});

  final MealType meal;
  final ValueChanged<MealType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (anchor) => NavRow(
        title: context.tr('cal_meal'),
        value: context.mealName(meal),
        onTap: () => showAvoMenu(anchor, items: [
          for (final m in kMealOrder)
            AvoMenuItem(label: context.mealName(m), checked: m == meal, onSelected: () => onChanged(m)),
        ]),
      ),
    );
  }
}

/// "Datum" with the S2 date menu (today, yesterday, five days before with
/// their kcal, "Datum wählen …"); never a day after [todayKey].
class CalorieDateRow extends ConsumerWidget {
  const CalorieDateRow({super.key, required this.dateKey, required this.todayKey, required this.onChanged});

  final String dateKey;
  final String todayKey;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(calorieRecentDayTotalsProvider(todayKey));
    final value = dateKey == todayKey
        ? context.tr('cal_today')
        : dateKey == shiftCalorieDayKey(todayKey, -1)
            ? context.tr('cal_yesterday')
            : context.shortDate(parseCalorieDayKey(dateKey));
    return Builder(
      builder: (anchor) => NavRow(
        title: context.tr('cal_date'),
        value: value,
        onTap: () => showCalorieDateMenu(
          anchor,
          shownKey: dateKey,
          todayKey: todayKey,
          kcalByDay: calorieMenuDaysKcal(ref, todayKey),
          onPick: (key) => onChanged(key.compareTo(todayKey) > 0 ? todayKey : key),
        ),
      ),
    );
  }
}

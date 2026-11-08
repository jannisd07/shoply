import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/nutrition_goal.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_colors.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_format.dart';
import 'package:shoply/presentation/widgets/design/bar_chart.dart';

/// One macro with its eaten grams and (optional) target.
class _Macro {
  const _Macro(this.nameKey, this.eaten, this.goal, this.color);

  final String nameKey;
  final double eaten;
  final int? goal;
  final Color color;
}

List<_Macro> _macros(BuildContext context, DailyNutritionTotals totals, NutritionGoal? goal) {
  final c = CalorieColors.of(context);
  return [
    _Macro('cal_macro_protein', totals.proteinG, goal?.proteinTargetG, c.protein),
    _Macro('cal_macro_carbs', totals.carbsG, goal?.carbsTargetG, c.carbs),
    _Macro('cal_macro_fat', totals.fatG, goal?.fatTargetG, c.fat),
  ];
}

/// "Protein 82 von 133 Gramm, Kohlenhydrate …": the macros as one spoken
/// sentence, for elements that read the whole summary at once.
String calorieMacrosSpoken(BuildContext context, DailyNutritionTotals totals, NutritionGoal? goal) {
  return [
    for (final m in _macros(context, totals, goal))
      m.goal != null && m.goal! > 0
          ? context.tr('cal_macro_a11y', params: {
              'name': context.tr(m.nameKey),
              'eaten': context.grams(m.eaten),
              'goal': '${m.goal}',
            })
          : context.tr('cal_macro_a11y_plain', params: {
              'name': context.tr(m.nameKey),
              'g': context.grams(m.eaten),
            }),
  ].join(', ');
}

/// The three macro rows of D2 (`MacroRow`): label left, "62 von 110 g"
/// right, a 6 pt bar below in protein blue, carbohydrate orange and fat
/// purple. Without a target for a macro the row is plain text ("Protein
/// 82 g") without a bar (S1a). The value moves below the label when both do
/// not fit (large text, narrow column).
class CalorieMacroRows extends StatelessWidget {
  const CalorieMacroRows({
    super.key,
    required this.totals,
    required this.goal,
    this.gap = AvoSpacing.m,
  });

  final DailyNutritionTotals totals;

  /// The goal with the macro targets; null without a goal.
  final NutritionGoal? goal;

  /// Space between the rows (11 on the Home card, 12 in the diary).
  final double gap;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (final m in _macros(context, totals, goal)) {
      if (rows.isNotEmpty) rows.add(SizedBox(height: gap));
      final name = context.tr(m.nameKey);
      final eaten = context.grams(m.eaten);
      final target = m.goal;
      if (target != null && target > 0) {
        rows.add(AvoHorizontalBar(
          label: name,
          value: context.tr('cal_macro_of', params: {'eaten': eaten, 'goal': '$target'}),
          semanticValue: context.tr('cal_macro_of_a11y', params: {'eaten': eaten, 'goal': '$target'}),
          fraction: m.eaten / target,
          color: m.color,
        ));
      } else {
        rows.add(Semantics(
          label: context.tr('cal_macro_a11y_plain', params: {'name': name, 'g': eaten}),
          excludeSemantics: true,
          child: Text(
            context.tr('cal_macro_plain', params: {'name': name, 'g': eaten}),
            style: context.text(AvoTextStyle.footnote, tabular: true),
          ),
        ));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }
}

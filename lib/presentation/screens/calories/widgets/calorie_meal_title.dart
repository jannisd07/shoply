import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_format.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';

const double _kTitleChevron = 11; // D2 X-Essen
const double _kTitleChevronStroke = 2.8; // D2 semibold chevron

/// The inline title of S3 and S5 as a menu button ("Mittagessen eintragen
/// ⌄", the meal menu with the current meal checked) and, on another day,
/// the date line below it as a second button ("Für Do., 5. Nov.").
class CalorieMealTitle extends StatelessWidget {
  const CalorieMealTitle({
    super.key,
    required this.meal,
    required this.onMeal,
    this.dateLine,
    this.onDate,
  });

  final MealType meal;
  final ValueChanged<MealType> onMeal;

  /// "Für Do., 5. Nov."; null on today.
  final String? dateLine;
  final ValueChanged<BuildContext>? onDate;

  void _openMealMenu(BuildContext anchor) {
    showAvoMenu(anchor, items: [
      for (final m in kMealOrder)
        AvoMenuItem(label: anchor.mealName(m), checked: m == meal, onSelected: () => onMeal(m)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final title = context.tr('cal_add_title', params: {'meal': context.mealName(meal)});
    final date = dateLine;
    final openDate = onDate;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Builder(
          builder: (anchor) => Semantics(
            container: true,
            button: true,
            header: true,
            label: title,
            hint: context.tr('cal_change_meal'),
            onTap: () => _openMealMenu(anchor),
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openMealMenu(anchor),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
                child: Center(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: title),
                      const TextSpan(text: ' '),
                      const WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: AvoIcon(AvoIcons.chevronDown, size: _kTitleChevron, strokeWidth: _kTitleChevronStroke),
                      ),
                    ]),
                    textAlign: TextAlign.center,
                    style: context.text(AvoTextStyle.headline),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (date != null)
          Builder(
            builder: (anchor) => Semantics(
              container: true,
              button: openDate != null,
              label: date,
              hint: openDate == null ? null : context.tr('cal_date_hint'),
              onTap: openDate == null ? null : () => openDate(anchor),
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: openDate == null ? null : () => openDate(anchor),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
                  child: Center(
                    child: Text(
                      date,
                      textAlign: TextAlign.center,
                      style: context.text(AvoTextStyle.footnote, color: colors.secondaryLabel),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

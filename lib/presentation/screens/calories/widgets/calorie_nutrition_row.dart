import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_format.dart';
import 'package:shoply/presentation/widgets/design/rolling_number.dart';

/// Below this width the four columns become 2 × 2 (320 pt screens).
const double _kTwoByTwoBelow = 300;

/// D2 X-Essen `.mac`: value 17/22 semibold over a 12/16 label.
const double _kDotSize = 8; // D2
const double _kDotStroke = 1.5; // D2
const double _kDotGap = 4; // D2

/// One column of a [NutritionRow].
class NutritionCell {
  const NutritionCell({
    required this.value,
    required this.label,
    this.unit,
    this.fractionDigits = 0,
    this.placeholder = false,
  });

  /// The number; null shows "–".
  final num? value;

  /// "Protein", "Kohlenh.", "Portion".
  final String label;

  /// "g", "kcal"; null for a bare number ("1" Portion).
  final String? unit;
  final int fractionDigits;

  /// Shows a quiet tone block at the final size (while estimating).
  final bool placeholder;
}

/// Nutrition in four columns (A-C13 `NutritionRow` is not built; B's
/// version from A's tokens): value 17/22 semibold, label 12/16 grey under
/// it, numbers roll when they change. 2 × 2 on narrow screens and from xxxL
/// on. VoiceOver reads one sentence ([semanticLabel]).
class NutritionRow extends StatelessWidget {
  const NutritionRow({super.key, required this.cells, required this.semanticLabel});

  final List<NutritionCell> cells;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final large = context.typography.category.index >= ContentSizeCategory.xxxLarge.index;
    return Semantics(
      container: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, box) {
          final grid = large || box.maxWidth < _kTwoByTwoBelow;
          final columns = [for (final c in cells) Expanded(child: _Cell(cell: c))];
          if (!grid || cells.length < 4) {
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: columns);
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: columns.sublist(0, 2)),
              const SizedBox(height: AvoSpacing.m),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: columns.sublist(2)),
            ],
          );
        },
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.cell});

  final NutritionCell cell;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final valueStyle = context.text(AvoTextStyle.body, weight: FontWeight.w600, tabular: true);
    final value = cell.value;
    final unit = cell.unit;
    final Widget number;
    if (cell.placeholder) {
      number = SizedBox(
        width: context.typography.lineHeightOf(AvoTextStyle.body) * 2,
        height: context.typography.lineHeightOf(AvoTextStyle.body),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.fill,
            borderRadius: BorderRadius.circular(AvoSpacing.xs),
          ),
        ),
      );
    } else if (value == null) {
      number = Text('–', style: valueStyle.copyWith(color: colors.secondaryLabel));
    } else {
      number = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RollingNumber(value: value, fractionDigits: cell.fractionDigits, style: valueStyle),
          if (unit != null) Text(' $unit', style: valueStyle),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(fit: BoxFit.scaleDown, child: number),
        const SizedBox(height: AvoSpacing.xxs),
        Text(
          cell.label,
          textAlign: TextAlign.center,
          style: context.text(AvoTextStyle.caption1, color: colors.secondaryLabel),
        ),
      ],
    );
  }
}

/// Digits after the decimal mark for grams: one under 10 g, none above
/// (`kalorien.md` §3.3).
int gramDigits(num? grams) => grams != null && grams.abs() < 10 && grams != grams.roundToDouble() ? 1 : 0;

/// The usual four columns: kcal, protein, carbs, fat ("158 kcal", "27,5 g
/// Protein", …), with the sentence VoiceOver reads ("158 Kilokalorien, 27,5
/// Gramm Protein, …").
NutritionRow nutritionRowFor(
  BuildContext context, {
  required num? kcal,
  required num? protein,
  required num? carbs,
  required num? fat,
  bool estimated = false,
}) {
  String grams(num? g) => g == null ? '–' : context.grams(g);
  final unknown = context.tr('cal_value_unknown');
  final spoken = [
    if (kcal == null)
      '${context.tr('cal_calories')} $unknown'
    else
      context.tr(estimated ? 'cal_about_kcal_a11y' : 'cal_kcal_value', params: {'kcal': context.kcal(kcal)}),
    context.tr('cal_grams_of', params: {'g': grams(protein), 'name': context.tr('cal_macro_protein')}),
    context.tr('cal_grams_of', params: {'g': grams(carbs), 'name': context.tr('cal_macro_carbs_long')}),
    context.tr('cal_grams_of', params: {'g': grams(fat), 'name': context.tr('cal_macro_fat')}),
  ].join(', ');
  return NutritionRow(
    semanticLabel: spoken,
    cells: [
      NutritionCell(value: kcal?.round(), label: context.tr('cal_unit_kcal')),
      NutritionCell(value: protein, unit: 'g', fractionDigits: gramDigits(protein), label: context.tr('cal_macro_protein')),
      NutritionCell(value: carbs, unit: 'g', fractionDigits: gramDigits(carbs), label: context.tr('cal_macro_carbs_short')),
      NutritionCell(value: fat, unit: 'g', fractionDigits: gramDigits(fat), label: context.tr('cal_macro_fat')),
    ],
  );
}

/// How sure an AI estimate is: three 8 pt dots (filled, empty as outline)
/// and the word, never percent (`ConfidenceRow`). The dots are hidden from
/// VoiceOver; the word is read where the row sits.
class ConfidenceRow extends StatelessWidget {
  const ConfidenceRow({super.key, required this.confidence, this.suffix});

  final EstimateConfidence confidence;

  /// Appended after the word ("· von dir angepasst").
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final filled = switch (confidence) {
      EstimateConfidence.high => 3,
      EstimateConfidence.medium => 2,
      EstimateConfidence.low => 1,
    };
    final text = [context.confidenceWord(confidence), ?suffix].join(' · ');
    return Row(
      children: [
        ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: _kDotGap),
                SizedBox.square(
                  dimension: _kDotSize,
                  child: DecoratedBox(
                    decoration: i < filled
                        ? BoxDecoration(color: colors.label, shape: BoxShape.circle)
                        : BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.uncheckedRing, width: _kDotStroke),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: AvoSpacing.s),
        Flexible(
          child: Text(text, style: context.text(AvoTextStyle.footnote, color: colors.secondaryLabel)),
        ),
      ],
    );
  }
}

extension CalorieConfidenceWords on BuildContext {
  /// "Recht sicher", "Unsicher", "Grob geschätzt".
  String confidenceWord(EstimateConfidence c) => tr(switch (c) {
        EstimateConfidence.high => 'cal_conf_high',
        EstimateConfidence.medium => 'cal_conf_medium',
        EstimateConfidence.low => 'cal_conf_low',
      });
}

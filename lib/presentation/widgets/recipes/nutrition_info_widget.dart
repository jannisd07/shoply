import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/nutrition_info.dart';
import 'package:shoply/presentation/widgets/design/bar_chart.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';

/// Daily reference intakes of an average adult (EU 1169/2011, Annex XIII),
/// what the bars are measured against.
const double _referenceKcal = 2000;
const double _referenceProteinG = 50;
const double _referenceCarbsG = 260;
const double _referenceFatG = 70;

/// Vertical room around one bar row (inset rows are at least 44 high).
const double _rowVertical = AvoSpacing.m;

/// "Nährwerte" of a recipe (Konzept 13 §12.1 Nr. 6): energy, protein,
/// carbohydrates and fat per serving, each as an [AvoHorizontalBar] against
/// the daily reference, in an [InsetSection] with the footnote "pro
/// Portion". The values never change with the servings stepper.
///
/// Renders nothing without values.
class RecipeNutritionSection extends StatelessWidget {
  const RecipeNutritionSection({super.key, required this.nutrition});

  /// Per serving.
  final NutritionInfo nutrition;

  @override
  Widget build(BuildContext context) {
    if (!nutrition.hasData) return const SizedBox.shrink();
    final language = Localizations.localeOf(context).languageCode;
    final grams = NumberFormat('0.#', language);
    String g(double v) => context.tr(
      'recipe_detail_grams',
      params: {'n': v >= 10 ? '${v.round()}' : grams.format(v)},
    );

    Widget bar(String label, String value, double amount, double reference) {
      final fraction = (amount / reference).clamp(0.0, 1.0);
      final percent = (amount / reference * 100).round();
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AvoSpacing.l,
          vertical: _rowVertical,
        ),
        child: AvoHorizontalBar(
          label: label,
          value: value,
          fraction: fraction,
          semanticValue: context.tr(
            'recipe_detail_nutrition_value',
            params: {'value': value, 'percent': '$percent'},
          ),
        ),
      );
    }

    final kcal = nutrition.calories;
    final protein = nutrition.proteinG;
    final carbs = nutrition.carbsG;
    final fat = nutrition.fatG;
    return InsetSection(
      header: context.tr('recipe_detail_nutrition'),
      footer: context.tr('recipe_detail_nutrition_footer'),
      showSeparators: false,
      children: [
        if (kcal != null)
          bar(
            context.tr('recipe_detail_energy'),
            context.tr('recipe_detail_kcal', params: {'n': '$kcal'}),
            kcal.toDouble(),
            _referenceKcal,
          ),
        if (protein != null)
          bar(
            context.tr('recipe_detail_protein'),
            g(protein),
            protein,
            _referenceProteinG,
          ),
        if (carbs != null)
          bar(
            context.tr('recipe_detail_carbs'),
            g(carbs),
            carbs,
            _referenceCarbsG,
          ),
        if (fat != null)
          bar(context.tr('recipe_detail_fat'), g(fat), fat, _referenceFatG),
      ],
    );
  }
}

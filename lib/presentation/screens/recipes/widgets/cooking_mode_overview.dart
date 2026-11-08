import 'package:flutter/widgets.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/presentation/screens/recipes/widgets/cooking_mode_logic.dart';
import 'package:shoply/presentation/screens/recipes/widgets/cooking_mode_theme.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/full_screen_editor.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';
import 'package:shoply/presentation/widgets/design/value_stepper.dart';

/// Longest step preview in the overview before it is shortened.
const int _previewLength = 80;

/// Servings in the cooking mode, the same limits as in the detail.
const int kCookingMinServings = 1;
const int kCookingMaxServings = 20;

const double _checkSize = 20;

/// Full-screen overview of the cooking mode (`list.bullet`; Konzept 13
/// §16.3, a sheet there): "Zutaten", every step, "Fertig", with a tick at
/// pages already seen. Tapping a row closes it with that page index.
class CookingOverviewScreen extends StatelessWidget {
  const CookingOverviewScreen({
    super.key,
    required this.steps,
    required this.current,
    required this.visited,
  });

  final List<String> steps;

  /// The page open in the cooking mode.
  final int current;
  final Set<int> visited;

  String _preview(String text) {
    final line = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (line.length <= _previewLength) return line;
    return '${line.substring(0, _previewLength).trimRight()}…';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final pages = <({String title, String? subtitle})>[
      (title: context.tr('recipe_cook_page_ingredients'), subtitle: null),
      for (var i = 0; i < steps.length; i++)
        (
          title: context.tr(
            'recipe_cook_step_label',
            params: {'n': '${i + 1}'},
          ),
          subtitle: _preview(steps[i]),
        ),
      (title: context.tr('recipe_cook_page_done'), subtitle: null),
    ];
    return FullScreenEditor(
      title: context.tr('recipe_cook_overview'),
      child: Padding(
        padding: const EdgeInsets.only(top: AvoSpacing.s),
        child: InsetSection(
          separatorIndent: AvoSpacing.l + _checkSize + AvoSpacing.m,
          children: [
            for (var i = 0; i < pages.length; i++)
              NavRow(
                title: pages[i].title,
                subtitle: pages[i].subtitle,
                value: i == current ? context.tr('recipe_cook_here') : null,
                leading: SizedBox.square(
                  dimension: _checkSize,
                  child: visited.contains(i) && i != current
                      ? AvoIcon(
                          AvoIcons.check,
                          size: _checkSize,
                          color: colors.tint,
                          semanticLabel: context.tr('recipe_cook_seen'),
                        )
                      : null,
                ),
                onTap: () => Navigator.of(context).pop(i),
              ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen servings of the cooking mode (Konzept 13 §16.3, a sheet
/// there): a stepper 1 to 20 and two amounts that follow. "Fertig" closes
/// with the new number.
class CookingServingsScreen extends StatefulWidget {
  const CookingServingsScreen({
    super.key,
    required this.recipe,
    required this.servings,
  });

  final Recipe recipe;
  final int servings;

  @override
  State<CookingServingsScreen> createState() => _CookingServingsScreenState();
}

class _CookingServingsScreenState extends State<CookingServingsScreen> {
  late int _servings = widget.servings.clamp(
    kCookingMinServings,
    kCookingMaxServings,
  );

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final ax = context.isAccessibilityText;
    final recipe = widget.recipe;
    final preview = recipe.ingredients
        .where((i) => i.amount > 0)
        .take(2)
        .map((i) => scaleIngredient(i, recipe.defaultServings, _servings))
        .toList();
    final label = Text(
      context.tr('recipe_cook_servings_title'),
      style: context.text(AvoTextStyle.body),
    );
    final stepper = ValueStepper(
      value: _servings,
      min: kCookingMinServings,
      max: kCookingMaxServings,
      semanticLabel: context.tr('recipe_cook_servings_title'),
      onChanged: (v) => setState(() => _servings = v),
    );
    return FullScreenEditor(
      title: context.tr('recipe_cook_servings_title'),
      onDone: () => Navigator.of(context).pop(_servings),
      child: Padding(
        padding: const EdgeInsets.only(top: AvoSpacing.s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InsetSection(
              footer: context.tr('recipe_cook_servings_footer'),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AvoSpacing.l,
                    vertical: AvoSpacing.s,
                  ),
                  child: ax
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            label,
                            const SizedBox(height: AvoSpacing.s),
                            stepper,
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: label),
                            const SizedBox(width: AvoSpacing.m),
                            stepper,
                          ],
                        ),
                ),
              ],
            ),
            if (preview.isNotEmpty) ...[
              const SizedBox(height: AvoSpacing.section),
              InsetSection(
                header: context.tr('recipe_cook_servings_preview'),
                children: [
                  for (final ing in preview)
                    ValueRow(
                      title: ing.name,
                      value: formatIngredientAmount(ing, lang) ?? '',
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Opens the overview above the cooking mode; resolves to the page index
/// to jump to, or null.
Future<int?> openCookingOverview(
  BuildContext context, {
  required List<String> steps,
  required int current,
  required Set<int> visited,
}) => pushFullScreenEditor<int>(
  context,
  (_) => CookingModeTheme(
    child: CookingOverviewScreen(
      steps: steps,
      current: current,
      visited: visited,
    ),
  ),
);

/// Opens the servings screen above the cooking mode; resolves to the new
/// number, or null when closed without "Fertig".
Future<int?> openCookingServings(
  BuildContext context, {
  required Recipe recipe,
  required int servings,
}) => pushFullScreenEditor<int>(
  context,
  (_) => CookingModeTheme(
    child: CookingServingsScreen(recipe: recipe, servings: servings),
  ),
);

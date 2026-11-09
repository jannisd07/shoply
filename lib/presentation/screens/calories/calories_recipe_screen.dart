import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/services/claude_service.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_entry_actions.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_fields.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_flow_scaffold.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_format.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_meal_date_rows.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_nutrition_row.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_stepper.dart';
import 'package:shoply/presentation/state/calorie_entry_provider.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/skeleton.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:shoply/routes/route_paths.dart';

// D2: recipe image 64, radius 14; servings 0,5 to 20 in halves.
const double _kImage = 64; // D2
const double _kImageRadius = 14; // D2
const double _kMinServings = 0.5;
const double _kMaxServings = 20;
const double _kServingStep = 0.5;

/// `MAX_TEXT_CHARS` of the `ai` function's input check.
const int _kMaxEstimateText = 4000;

/// Path segment for a recipe that has no id yet (draft, imported).
const String kUnsavedRecipeId = 'draft';

/// Slot for Teil A (`b_slots.dart`): "Ins Tagebuch" for [recipe] on its own
/// full-screen route (`/calories/add/recipe/:recipeId`, the recipe as
/// `extra`), pushed from the right over the recipe or the week plan and
/// back to it after "Eintragen". A recipe without nutrition opens the state
/// "ohne Nährwerte".
Future<void> openLogRecipe(BuildContext context, Recipe recipe) async {
  final id = recipe.id.isEmpty ? kUnsavedRecipeId : recipe.id;
  if (GoRouter.maybeOf(context) != null) {
    await context.push('${RoutePaths.calories}/add/recipe/$id', extra: recipe);
    return;
  }
  // Outside the app router (isolated screens): the same page on the
  // navigator.
  await Navigator.of(context).push<void>(
    CupertinoPageRoute(builder: (_) => CaloriesRecipeScreen(recipeId: id, recipe: recipe)),
  );
}

/// S10 "Rezept ins Tagebuch": servings (0,5 to 20), meal and day, the
/// numbers live, then "Eintragen". From the week plan with `?servings=`,
/// `?date=` (the plan day, today when it lies ahead) and `?meal=`.
class CaloriesRecipeScreen extends ConsumerStatefulWidget {
  const CaloriesRecipeScreen({
    super.key,
    required this.recipeId,
    this.recipe,
    this.servings,
    this.planDateKey,
    this.meal,
  });

  final String recipeId;

  /// The recipe as the opening screen had it (route `extra`).
  final Recipe? recipe;
  final double? servings;

  /// The plan day (`?date=`), also when it is in the future.
  final String? planDateKey;
  final MealType? meal;

  @override
  ConsumerState<CaloriesRecipeScreen> createState() => _CaloriesRecipeScreenState();
}

class _CaloriesRecipeScreenState extends ConsumerState<CaloriesRecipeScreen> {
  Recipe? _recipe;
  bool _loadFailed = false;
  late double _servings = (widget.servings ?? 1).clamp(_kMinServings, _kMaxServings).toDouble();
  late MealType _meal = widget.meal ?? mealForTime(ref.read(calorieClockProvider)());
  String? _dateKey;
  bool _logging = false;

  CalorieNutritionEstimate? _estimate;
  bool _estimating = false;
  bool _estimateFailed = false;
  final _kcalField = TextEditingController();

  @override
  void initState() {
    super.initState();
    _recipe = widget.recipe;
    final plan = widget.planDateKey;
    final today = calorieTodayKeyNow(ref);
    if (plan != null && plan.compareTo(today) < 0) _dateKey = plan;
    if (_recipe == null) unawaited(_load());
  }

  @override
  void dispose() {
    _kcalField.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final recipe = await ref.read(calorieRecipeLoaderProvider)(widget.recipeId);
      if (mounted) setState(() => _recipe = recipe);
    } catch (e) {
      debugPrint('⚠️ [CalorieRecipe] Loading the recipe failed: ${e.runtimeType}');
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  /// Per serving: the recipe's values, the estimate, or the typed kcal.
  ({int? kcal, double? protein, double? carbs, double? fat, bool estimated}) get _perServing {
    final n = _recipe?.nutrition;
    if (n != null && n.calories != null) {
      return (kcal: n.calories, protein: n.proteinG, carbs: n.carbsG, fat: n.fatG, estimated: false);
    }
    final e = _estimate;
    final typed = parseCalorieNumber(_kcalField.text, integer: true, max: 10000).value?.round();
    if (e != null && (typed == null || typed == e.kcal)) {
      return (kcal: e.kcal, protein: e.proteinG, carbs: e.carbsG, fat: e.fatG, estimated: true);
    }
    return (kcal: typed, protein: null, carbs: null, fat: null, estimated: false);
  }

  bool get _hasNutrition => _recipe?.nutrition?.calories != null;

  Future<void> _runEstimate() async {
    final recipe = _recipe;
    if (recipe == null || _estimating) return;
    setState(() {
      _estimating = true;
      _estimateFailed = false;
    });
    final text = [
      recipe.name,
      for (final i in recipe.ingredients) '- ${i.amount} ${i.unit} ${i.name}'.trim(),
    ].join('\n');
    try {
      // Per serving even when the recipe names none; the server takes at most
      // 4.000 characters.
      final e = await ref.read(calorieNutritionEstimatorProvider)(
        text.length > _kMaxEstimateText ? text.substring(0, _kMaxEstimateText) : text,
        servings: recipe.defaultServings > 0 ? recipe.defaultServings : 1,
      );
      if (!mounted) return;
      setState(() {
        _estimating = false;
        _estimate = e;
        _kcalField.text = '${e.kcal}';
      });
    } on ClaudeException catch (e) {
      debugPrint('⚠️ [CalorieRecipe] Estimate failed: ${e.code}');
      if (!mounted) return;
      if (e.code == 'quota_exceeded') {
        // A retry cannot work today: the limit sentence instead.
        ref.read(calorieTextEstimateLimitReachedProvider.notifier).markReached();
        setState(() => _estimating = false);
        return;
      }
      unawaited(AvoHaptics.error());
      setState(() {
        _estimating = false;
        _estimateFailed = true;
      });
    }
  }

  Future<void> _log() async {
    final recipe = _recipe;
    final per = _perServing;
    final kcal = per.kcal;
    if (recipe == null || kcal == null || _logging) return;
    setState(() => _logging = true);
    final now = ref.read(calorieClockProvider)();
    double? s(double? v) => v == null ? null : v * _servings;
    final entry = FoodLogEntry(
      id: '',
      userId: '',
      loggedDate: parseCalorieDayKey(_dateKey ?? calorieTodayKeyNow(ref)),
      mealType: _meal,
      origin: FoodEntryOrigin.recipe,
      sourceRecipeId: recipe.id.isEmpty ? null : recipe.id,
      foodName: recipe.name,
      quantity: _servings,
      unit: 'serving',
      calories: (kcal * _servings).round(),
      proteinG: s(per.protein),
      carbsG: s(per.carbs),
      fatG: s(per.fat),
      estimated: per.estimated,
      confidence: per.estimated ? _estimate?.confidence : null,
      loggedTime: FoodLogTime.of(now),
      createdAt: now,
    );
    final saved = await logNewFood(context, ref, entry);
    if (!mounted) return;
    if (saved == null) {
      setState(() => _logging = false);
      return;
    }
    CalorieFlowScaffold.leave(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final recipe = _recipe;
    final title = CalorieFlowTitle(context.tr('cal_log_recipe_title'));
    if (recipe == null) {
      return CalorieFlowScaffold(
        leading: CalorieFlowLeading.back,
        title: title,
        children: [
          const SizedBox(height: AvoSpacing.l),
          if (_loadFailed)
            StatusRow(
              kind: StatusKind.sectionError,
              text: context.tr('cal_recipe_load_error'),
              actionLabel: context.tr('retry'),
              onAction: () {
                setState(() => _loadFailed = false);
                unawaited(_load());
              },
            )
          else
            InsetSection(children: [SkeletonSection(rows: 2, loadingLabel: context.tr('cal_loading'))]),
        ],
      );
    }

    final today = ref.watch(calorieTodayKeyProvider);
    final offline = ref.watch(isOfflineProvider);
    final aiOn = ref.watch(aiRemoteEnabledProvider);
    final estimateLimit = ref.watch(calorieTextEstimateLimitReachedProvider);
    final per = _perServing;
    final kcal = per.kcal;
    double? s(double? v) => v == null ? null : v * _servings;
    final plan = widget.planDateKey;
    final future = plan != null && plan.compareTo(today) > 0;
    final shownDate = switch (_dateKey) {
      final k? when k.compareTo(today) < 0 => k,
      _ => today,
    };
    final perServingText = kcal == null
        ? null
        : context.tr(per.estimated ? 'cal_about_kcal_per_serving' : 'cal_kcal_per_serving',
            params: {'kcal': context.kcal(kcal)});
    final kcalFieldInput = parseCalorieNumber(_kcalField.text, integer: true, max: 10000);

    return CalorieFlowScaffold(
      leading: CalorieFlowLeading.back,
      title: title,
      bottom: AppButton.primary(
        label: context.tr('cal_log_button'),
        size: AppButtonSize.large,
        expand: true,
        floating: true,
        working: _logging,
        onPressed: kcal != null && !_logging ? _log : null,
      ),
      children: [
        InsetSection(children: [
          Padding(
            padding: const EdgeInsets.all(AvoSpacing.l),
            child: Row(
              children: [
                if (recipe.imageUrl.isNotEmpty && !context.isAccessibilityText) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(_kImageRadius),
                    child: SizedBox.square(
                      dimension: _kImage,
                      child: Image.network(
                        recipe.imageUrl,
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                        errorBuilder: (context, _, __) => ColoredBox(color: colors.fill),
                      ),
                    ),
                  ),
                  const SizedBox(width: AvoSpacing.m),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(recipe.name, style: context.text(AvoTextStyle.headline)),
                      if (perServingText != null)
                        Text(perServingText, style: context.text(AvoTextStyle.subhead, color: colors.secondaryLabel, tabular: true)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ]),
        if (!_hasNutrition) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(AvoSpacing.screen + AvoSpacing.l, AvoSpacing.l, AvoSpacing.screen, 0),
            child: Text(context.tr('cal_recipe_no_nutrition'), style: context.text(AvoTextStyle.subhead)),
          ),
          if (estimateLimit && !offline && aiOn)
            Padding(
              padding: const EdgeInsets.fromLTRB(AvoSpacing.screen + AvoSpacing.l, AvoSpacing.s, AvoSpacing.screen, 0),
              child: Text(
                context.tr('cal_estimate_limit'),
                style: context.text(AvoTextStyle.footnote, color: colors.secondaryLabel),
              ),
            )
          else if (!offline && aiOn)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: AppButton.plain(
                  label: context.tr('cal_estimate_kcal'),
                  icon: const AvoIcon(AvoIcons.sparkle),
                  working: _estimating,
                  workingLabel: context.tr('cal_estimating'),
                  onPressed: _estimating ? null : _runEstimate,
                ),
              ),
            ),
          if (_estimateFailed)
            StatusRow(
              kind: StatusKind.sectionError,
              text: context.tr('cal_estimate_error'),
              actionLabel: context.tr('retry'),
              onAction: _runEstimate,
            ),
          if (offline || !aiOn || estimateLimit || _estimate != null || _estimateFailed)
            InsetSection(children: [
              CalorieFieldRow(
                label: context.tr('cal_kcal_per_serving_field'),
                controller: _kcalField,
                unit: context.tr('cal_unit_kcal'),
                spokenUnit: context.tr('cal_kcal_spoken'),
                integer: true,
                error: _kcalField.text.trim().isNotEmpty && !kcalFieldInput.isValid
                    ? context.tr('cal_number_invalid')
                    : null,
                onChanged: (_) => setState(() {}),
              ),
            ]),
        ],
        const SizedBox(height: AvoSpacing.section),
        InsetSection(children: [
          _ServingsRow(value: _servings, onChanged: (v) => setState(() => _servings = v)),
        ]),
        const SizedBox(height: AvoSpacing.section),
        InsetSection(
          footer: future
              ? context.tr('cal_recipe_future', params: {'date': context.shortDate(parseCalorieDayKey(plan))})
              : null,
          children: [
            CalorieMealRow(meal: _meal, onChanged: (m) => setState(() => _meal = m)),
            CalorieDateRow(
              dateKey: shownDate,
              todayKey: today,
              onChanged: (k) => setState(() => _dateKey = k == today ? null : k),
            ),
          ],
        ),
        InsetSection(
          footer: kcal == null ? null : context.tr(per.estimated ? 'cal_recipe_note_estimated' : 'cal_recipe_note'),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.l, vertical: AvoSpacing.m),
              child: nutritionRowFor(
                context,
                kcal: kcal == null ? null : kcal * _servings,
                protein: s(per.protein),
                carbs: s(per.carbs),
                fat: s(per.fat),
                estimated: per.estimated,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// "Portionen" with the stepper on the right (under the label from xxL on).
class _ServingsRow extends StatelessWidget {
  const _ServingsRow({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = Text(context.tr('cal_servings'), style: context.text(AvoTextStyle.body));
    final stepper = CalorieStepper(
      value: value,
      step: _kServingStep,
      min: _kMinServings,
      max: _kMaxServings,
      showValue: true,
      format: context.amount,
      semanticLabel: context.tr('cal_servings'),
      spokenValue: context.amount,
      onChanged: onChanged,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.l, vertical: AvoSpacing.s),
      child: calorieLabelsAbove(context)
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [ExcludeSemantics(child: label), const SizedBox(height: AvoSpacing.s), stepper],
            )
          : Row(children: [Expanded(child: ExcludeSemantics(child: label)), stepper]),
    );
  }
}

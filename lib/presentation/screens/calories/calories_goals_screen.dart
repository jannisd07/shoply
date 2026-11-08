import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/data/models/nutrition_goal.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_entry_actions.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_fields.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_format.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_stepper.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/glass_icon_button.dart';
import 'package:shoply/presentation/widgets/design/glass_toolbar.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';
import 'package:shoply/presentation/widgets/design/skeleton.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';
import 'package:shoply/routes/route_paths.dart';

/// Under this many kcal a day the screen warns (the value is still saved).
const int _kLowKcal = 1200;

/// Macros that miss the kcal goal by more than this share get a footnote.
const double _kMacroTolerance = 0.1;
const double _kTitleGap = AvoSpacing.s; // D2
const double _kWarningGlyph = 17; // D2
const double _kRowMinHeight = 52; // D2 X-Profil `.row`
const double _kRowVertical = 9; // D2

/// The daily values S13 lets the person set.
enum _Field { kcal, protein, carbs, fat, water }

/// S13 "Ziele" (`/calories/goals` in the Home tab, `/settings/health/goals`
/// in the Profil tab, the same widget). Every daily value opens in place
/// with a number field and a stepper (no slider) and is saved when it
/// closes ("Kalorienziel geändert · Widerrufen"). No goal yet: S14 instead.
class CaloriesGoalsScreen extends ConsumerStatefulWidget {
  const CaloriesGoalsScreen({super.key});

  @override
  ConsumerState<CaloriesGoalsScreen> createState() => _CaloriesGoalsScreenState();
}

class _CaloriesGoalsScreenState extends ConsumerState<CaloriesGoalsScreen> {
  _Field? _open;
  final Map<_Field, double> _draft = {};
  bool _redirected = false;

  int? _valueOf(NutritionGoal goal, _Field f) => switch (f) {
        _Field.kcal => goal.dailyCalorieTarget,
        _Field.protein => goal.proteinTargetG,
        _Field.carbs => goal.carbsTargetG,
        _Field.fat => goal.fatTargetG,
        _Field.water => goal.waterTargetMl,
      };

  double? _current(NutritionGoal goal, _Field f) => _draft[f] ?? _valueOf(goal, f)?.toDouble();

  /// Saves the open value (if it changed) and closes it.
  void _commit(NutritionGoal goal, {bool toast = true}) {
    final field = _open;
    _open = null;
    if (field == null) return;
    final value = _draft.remove(field)?.round();
    if (value == null || value == _valueOf(goal, field)) return;
    final changed = goal.copyWith(
      goalType: field == _Field.water ? goal.goalType : NutritionGoalType.custom,
      dailyCalorieTarget: field == _Field.kcal ? value : null,
      proteinTargetG: field == _Field.protein ? value : null,
      carbsTargetG: field == _Field.carbs ? value : null,
      fatTargetG: field == _Field.fat ? value : null,
      waterTargetMl: field == _Field.water ? value : null,
    );
    final diary = ref.read(calorieDiaryProvider);
    unawaited(diary.saveGoal(changed).then<void>((_) {}, onError: (Object e) {
      debugPrint('❌ [CalorieGoals] Saving failed: ${calorieErrorKind(e)}');
    }));
    if (toast && mounted) {
      AvoToast.show(
        context,
        message: context.tr(field == _Field.kcal ? 'cal_goal_changed' : 'cal_goals_changed'),
        actionLabel: context.tr('common_undo'),
        onAction: () => diary.saveGoal(goal),
      );
    }
  }

  void _toggle(NutritionGoal goal, _Field f) {
    setState(() {
      final wasOpen = _open == f;
      _commit(goal);
      if (!wasOpen) _open = f;
    });
  }

  void _back(NutritionGoal? goal) {
    if (goal != null) _commit(goal);
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RoutePaths.home);
    }
  }

  String _formatted(BuildContext context, _Field f, double v) => switch (f) {
        _Field.kcal => context.tr('cal_meal_sum', params: {'kcal': context.kcal(v)}),
        _Field.water => context.tr('cal_water_plain', params: {'amount': context.liters(v.round())}),
        _ => '${context.grams(v.round())} g',
      };

  String _spoken(BuildContext context, _Field f, double v) => switch (f) {
        _Field.kcal => context.tr('cal_kcal_value', params: {'kcal': context.kcal(v)}),
        _Field.water => context.tr('cal_liters_spoken', params: {'n': context.liters(v.round())}),
        _ => context.tr('cal_grams_spoken', params: {'n': context.grams(v.round())}),
      };

  String _label(BuildContext context, _Field f) => context.tr(switch (f) {
        _Field.kcal => 'cal_calories',
        _Field.protein => 'cal_macro_protein',
        _Field.carbs => 'cal_macro_carbs_long',
        _Field.fat => 'cal_macro_fat',
        _Field.water => 'cal_water',
      });

  String _goalType(BuildContext context, NutritionGoalType t) => context.tr(switch (t) {
        NutritionGoalType.loseWeight => 'cal_goal_lose',
        NutritionGoalType.gainMuscle => 'cal_goal_gain',
        NutritionGoalType.maintain => 'cal_goal_keep',
        NutritionGoalType.custom => 'cal_goal_custom',
      });

  String _activity(BuildContext context, ActivityLevel a) => context.tr(switch (a) {
        ActivityLevel.sedentary => 'cal_act_sedentary',
        ActivityLevel.light => 'cal_act_light',
        ActivityLevel.moderate => 'cal_act_moderate',
        ActivityLevel.active => 'cal_act_active',
        ActivityLevel.veryActive => 'cal_act_very_active',
      });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = ref.watch(calorieGoalStateProvider);
    final goal = state.goal;

    if (state.status == CalorieGoalStatus.none && !_redirected) {
      _redirected = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.pushReplacement('${RoutePaths.calories}/goals/setup?from=goals');
      });
    }

    final List<Widget> body;
    if (goal == null) {
      body = [
        const SizedBox(height: AvoSpacing.l),
        if (state.status == CalorieGoalStatus.error)
          StatusRow(
            kind: StatusKind.sectionError,
            text: context.tr('cal_goal_error'),
            actionLabel: context.tr('retry'),
            onAction: () => ref.invalidate(nutritionGoalProvider),
          )
        else
          InsetSection(children: [SkeletonSection(rows: 4, withImage: false, loadingLabel: context.tr('cal_loading'))]),
      ];
    } else {
      body = _content(context, goal);
    }

    return PopScope<Object?>(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && goal != null && _open != null) _commit(goal);
      },
      child: ColoredBox(
        color: colors.background,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.only(
                top: GlassToolbar.topOffset(context) + AvoSizes.toolbarButton + _kTitleGap,
                bottom: ShellInsets.bottom(context),
              ),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
                    child: Semantics(
                      header: true,
                      child: Text(context.tr('cal_goals_title'), style: context.text(AvoTextStyle.largeTitle)),
                    ),
                  ),
                  ...body,
                ],
              ),
            ),
            const Positioned(top: 0, left: 0, right: 0, child: ScrollEdgeFade()),
            Positioned(
              top: GlassToolbar.topOffset(context),
              left: 0,
              right: 0,
              child: GlassToolbar(
                leading: GlassIconButton(
                  icon: const AvoIcon(AvoIcons.chevronBack),
                  semanticLabel: context.tr('back'),
                  onPressed: () => _back(goal),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, NutritionGoal goal) {
    final colors = context.colors;
    final custom = goal.goalType == NutritionGoalType.custom;
    final kcal = _current(goal, _Field.kcal);
    final p = _current(goal, _Field.protein), c = _current(goal, _Field.carbs), f = _current(goal, _Field.fat);
    final macroKcal = p == null || c == null || f == null ? null : (p * 4 + c * 4 + f * 9).round();
    final mismatch = kcal != null && macroKcal != null && (macroKcal - kcal).abs() > kcal * _kMacroTolerance;
    final target = goal.targetWeightKg;
    final pace = goal.pace;
    final current = goal.currentWeightKg;
    final perWeek = pace?.kgPerWeek(goal.goalType) ?? 0;
    final weeks = target != null && current != null && perWeek > 0 ? (target - current).abs() / perWeek : null;
    final now = ref.read(calorieClockProvider)();

    return [
      InsetSection(
        header: context.tr('cal_sec_per_day'),
        footer: custom ? null : context.tr('cal_goals_calc_note', params: {'date': context.shortDate(goal.updatedAt.toLocal())}),
        children: [
          for (final field in _Field.values) ...[
            _GoalValueRow(
              key: ValueKey('cal-goal-${field.name}'),
              label: _label(context, field),
              value: _current(goal, field),
              format: (v) => _formatted(context, field, v),
              spoken: (v) => _spoken(context, field, v),
              unit: switch (field) {
                _Field.kcal => context.tr('cal_unit_kcal'),
                _Field.water => 'ml',
                _ => 'g',
              },
              step: switch (field) {
                _Field.kcal => 50,
                _Field.water => 250,
                _ => 5,
              },
              max: field == _Field.kcal ? 10000 : (field == _Field.water ? 6000 : 1000),
              open: _open == field,
              onToggle: () => _toggle(goal, field),
              onChanged: (v) => setState(() => _draft[field] = v),
            ),
            if (field == _Field.kcal && kcal != null && kcal < _kLowKcal)
              CalorieGroupNote(
                text: context.tr('cal_below_1200'),
                color: colors.warning,
                liveRegion: true,
                icon: AvoIcon(AvoIcons.exclamationmarkTriangleFill, size: _kWarningGlyph, color: colors.warning),
              ),
          ],
        ],
      ),
      if (mismatch)
        _Footnote(text: context.tr('cal_macros_mismatch', params: {
          'macroKcal': context.kcal(macroKcal),
          'goal': context.kcal(kcal),
        })),
      if (custom)
        Padding(
          padding: const EdgeInsets.fromLTRB(AvoSpacing.screen + AvoSpacing.l, AvoSpacing.xs, AvoSpacing.screen, 0),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AvoSpacing.xs,
            children: [
              Text(context.tr('cal_goals_custom'), style: context.text(AvoTextStyle.footnote, color: colors.secondaryLabel)),
              AppButton.plain(
                label: context.tr('cal_recalculate'),
                onPressed: () => context.push('${RoutePaths.calories}/goals/setup?from=goals'),
              ),
            ],
          ),
        ),
      InsetSection(
        header: context.tr('cal_sec_your_goal'),
        children: [
          ValueRow(title: context.tr('cal_goal'), value: _goalType(context, goal.goalType)),
          if (target != null)
            ValueRow(
              title: context.tr('cal_target_weight'),
              value: weeks == null
                  ? context.tr('cal_target_weight_plain', params: {'kg': context.amount(target)})
                  : context.tr('cal_target_weight_value', params: {
                      'kg': context.amount(target),
                      'when': context.roughDate(now.add(Duration(days: (weeks * 7).round())), now),
                    }),
            ),
          ValueRow(title: context.tr('cal_activity'), value: _activity(context, goal.activityLevel)),
          NavRow(
            title: context.tr('cal_recalculate'),
            onTap: () => context.push('${RoutePaths.calories}/goals/setup?from=goals'),
          ),
        ],
      ),
      InsetSection(
        header: context.tr('cal_sec_workouts'),
        footer: context.tr('cal_credit_workouts_note'),
        children: [
          ToggleRow(
            title: context.tr('cal_credit_workouts'),
            value: goal.creditWorkouts,
            onChanged: (v) => unawaited(ref.read(calorieDiaryProvider).saveGoal(goal.copyWith(creditWorkouts: v))),
          ),
        ],
      ),
      _Footnote(text: context.tr('cal_guide_values')),
    ];
  }
}

class _Footnote extends StatelessWidget {
  const _Footnote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(AvoSpacing.screen + AvoSpacing.l, AvoSpacing.l, AvoSpacing.screen + AvoSpacing.l, 0),
        child: Text(text, style: context.text(AvoTextStyle.footnote, color: context.colors.secondaryLabel)),
      );
}

/// A daily value: title and value ("Kalorien · 2.000 kcal"); a tap opens a
/// number field and a stepper in place (below the field from xxL on).
class _GoalValueRow extends StatefulWidget {
  const _GoalValueRow({
    super.key,
    required this.label,
    required this.value,
    required this.format,
    required this.spoken,
    required this.unit,
    required this.step,
    required this.max,
    required this.open,
    required this.onToggle,
    required this.onChanged,
  });

  final String label;
  final double? value;
  final String Function(double) format;
  final String Function(double) spoken;
  final String unit;
  final double step;
  final double max;
  final bool open;
  final VoidCallback onToggle;
  final ValueChanged<double> onChanged;

  @override
  State<_GoalValueRow> createState() => _GoalValueRowState();
}

class _GoalValueRowState extends State<_GoalValueRow> {
  final _field = TextEditingController();
  bool _invalid = false;

  @override
  void didUpdateWidget(_GoalValueRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final v = widget.value;
    if (widget.open && (!oldWidget.open || parseCalorieNumber(_field.text).value?.round() != v?.round())) {
      _field.text = v == null ? '' : '${v.round()}';
    }
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _typed(String text) {
    final input = parseCalorieNumber(text, integer: true, required: true, max: widget.max);
    setState(() => _invalid = !input.isValid);
    if (input.isValid) widget.onChanged(input.value!);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final value = widget.value;
    final shown = value == null ? '–' : widget.format(value);
    final header = Semantics(
      container: true,
      button: true,
      expanded: widget.open,
      label: widget.label,
      value: value == null ? null : widget.spoken(value),
      hint: context.tr('cal_tap_to_change'),
      onTap: widget.onToggle,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onToggle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _kRowMinHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.l, vertical: _kRowVertical),
            child: context.isAccessibilityText
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.label, style: context.text(AvoTextStyle.body)),
                      Text(shown, style: context.text(AvoTextStyle.body, color: colors.secondaryLabel, tabular: true)),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: Text(widget.label, style: context.text(AvoTextStyle.body))),
                      const SizedBox(width: AvoSpacing.m),
                      Text(shown, style: context.text(AvoTextStyle.body, color: colors.secondaryLabel, tabular: true)),
                    ],
                  ),
          ),
        ),
      ),
    );
    if (!widget.open) return header;
    final field = MergeSemantics(
      child: Semantics(
        label: widget.label,
        hint: _invalid ? context.tr('cal_number_invalid') : null,
        child: CupertinoTextField(
          controller: _field,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: calorieNumberFormatters,
          style: context.text(AvoTextStyle.body, tabular: true),
          padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.m, vertical: AvoSpacing.s),
          decoration: BoxDecoration(color: colors.fill, borderRadius: BorderRadius.circular(AvoRadii.imageSmall)),
          suffix: Padding(
            padding: const EdgeInsetsDirectional.only(end: AvoSpacing.m),
            child: ExcludeSemantics(
              child: Text(widget.unit, style: context.text(AvoTextStyle.body, color: colors.secondaryLabel)),
            ),
          ),
          onChanged: _typed,
        ),
      ),
    );
    final stepper = CalorieStepper(
      value: value ?? 0,
      step: widget.step,
      min: 0,
      max: widget.max,
      semanticLabel: widget.label,
      spokenValue: widget.spoken,
      onChanged: (v) {
        _field.text = '${v.round()}';
        widget.onChanged(v);
      },
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        header,
        Padding(
          padding: const EdgeInsets.fromLTRB(AvoSpacing.l, 0, AvoSpacing.l, AvoSpacing.m),
          child: calorieLabelsAbove(context)
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [field, const SizedBox(height: AvoSpacing.s), stepper],
                )
              : Row(children: [Expanded(child: field), const SizedBox(width: AvoSpacing.m), stepper]),
        ),
        if (_invalid)
          Padding(
            padding: const EdgeInsets.fromLTRB(AvoSpacing.l, 0, AvoSpacing.l, AvoSpacing.m),
            child: Text(context.tr('cal_number_invalid'), style: context.text(AvoTextStyle.footnote, color: colors.destructive)),
          ),
      ],
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/utils/number_parsing.dart';
import 'package:shoply/data/models/nutrition_goal.dart';
import 'package:shoply/data/services/nutrition_goal_service.dart';
import 'package:shoply/data/services/onboarding_answers_service.dart';
import 'package:shoply/presentation/screens/onboarding/onboarding_controller.dart';
import 'package:shoply/presentation/screens/onboarding/steps/step_common.dart';
import 'package:shoply/presentation/screens/onboarding/widgets/onboarding_step_scaffold.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/value_stepper.dart';

/// Range of "Zeitraum" in weeks (Konzept 17 §3.10).
const int _kMinWeeks = 4;
const int _kMaxWeeks = 52;

/// Plausible "Eigenes Ziel" values in kcal per day.
const int _kMinKcal = 800;
const int _kMaxKcal = 6000;

/// Width of a number field in a value row; it grows with the text.
const double _kFieldMinWidth = 64;

/// "Dein Ziel" (Konzept 17 §3.10, only with the calories module): goal,
/// body data, activity and the estimate in the action bar. No slider: number
/// fields, a pull-down menu for "Geschlecht" and a stepper for the weeks.
/// The estimate comes from Teil B's `NutritionGoalCalculator`.
class GoalStep extends ConsumerStatefulWidget {
  const GoalStep({
    super.key,
    required this.onNext,
    required this.onSkip,
    this.onBack,
    this.progress,
  });

  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback? onBack;
  final Widget? progress;

  @override
  ConsumerState<GoalStep> createState() => _GoalStepState();
}

String _formatNumber(num? value) {
  if (value == null) return '';
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toString().replaceAll('.', ',');
}

class _GoalStepState extends ConsumerState<GoalStep> {
  late final OnboardingGoalDraft _initial = ref
      .read(onboardingControllerProvider)
      .goal;
  late final _age = TextEditingController(text: _formatNumber(_initial.age));
  late final _height = TextEditingController(
    text: _formatNumber(_initial.heightCm),
  );
  late final _weight = TextEditingController(
    text: _formatNumber(_initial.currentWeightKg),
  );
  late final _target = TextEditingController(
    text: _formatNumber(_initial.targetWeightKg),
  );
  late final _kcal = TextEditingController(
    text: _formatNumber(_initial.customCalories),
  );

  /// "1,68" was taken as 168 cm.
  double? _heightConverted;

  @override
  void dispose() {
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    _target.dispose();
    _kcal.dispose();
    super.dispose();
  }

  OnboardingController get _controller =>
      ref.read(onboardingControllerProvider.notifier);

  OnboardingGoalDraft get _goal => ref.read(onboardingControllerProvider).goal;

  void _update(OnboardingGoalDraft goal) => _controller.setGoal(goal);

  void _onAge(String text) {
    final value = int.tryParse(text.trim());
    _update(_goal.copyWith(age: () => value));
  }

  void _onHeight(String text) {
    final raw = parseLocaleDouble(text);
    final cm = raw == null
        ? null
        : NutritionGoalCalculator.normalizeHeightCm(raw);
    setState(() => _heightConverted = raw != null && cm != raw ? cm : null);
    _update(_goal.copyWith(heightCm: () => cm));
  }

  void _onWeight(String text) =>
      _update(_goal.copyWith(currentWeightKg: () => parseLocaleDouble(text)));

  void _onTarget(String text) =>
      _update(_goal.copyWith(targetWeightKg: () => parseLocaleDouble(text)));

  void _onKcal(String text) {
    final value = int.tryParse(text.trim().replaceAll('.', ''));
    _update(_goal.copyWith(customCalories: () => value));
  }

  @override
  Widget build(BuildContext context) {
    final goal = ref.watch(onboardingControllerProvider.select((s) => s.goal));
    final colors = context.colors;
    final custom = goal.goalType == NutritionGoalType.custom;
    final minor =
        goal.age != null &&
        !NutritionGoalCalculator.weightLossAllowed(goal.age!);
    final problems = _problems(context, goal);

    Widget choice(
      NutritionGoalType type, {
      String? subtitle,
      bool enabled = true,
    }) => ChoiceRow(
      title: context.tr('goal_type_${type.dbValue}'),
      subtitle: subtitle,
      selected: goal.goalType == type,
      enabled: enabled,
      onTap: () => _update(goal.copyWith(goalType: type)),
    );

    return OnboardingStepPage(
      title: context.tr('onb_target_title'),
      message: context.tr('onb_target_sentence'),
      progress: widget.progress,
      onBack: widget.onBack,
      onSkip: () => runIfCurrent(context, widget.onSkip),
      status: const OnboardingSyncStatus(),
      actionHeader: _ResultLine(goal: goal),
      primaryAction: AppButton.primary(
        label: context.tr('next'),
        onPressed: () => runIfCurrent(context, widget.onNext),
        size: AppButtonSize.large,
        expand: true,
      ),
      children: [
        InsetSection(
          header: context.tr('onb_target_goal_heading'),
          children: [
            choice(
              NutritionGoalType.loseWeight,
              enabled: !minor,
              subtitle: minor ? context.tr('onb_target_minor') : null,
            ),
            choice(NutritionGoalType.maintain),
            choice(NutritionGoalType.gainMuscle),
            choice(NutritionGoalType.custom),
          ],
        ),
        const SizedBox(height: AvoSpacing.section),
        InsetSection(
          header: context.tr('onb_target_about_heading'),
          children: custom
              ? [
                  NumberRow(
                    label: context.tr('onb_target_kcal'),
                    unit: 'kcal',
                    controller: _kcal,
                    onChanged: _onKcal,
                    decimal: false,
                  ),
                ]
              : [
                  _GenderRow(
                    value: goal.gender,
                    onChanged: (g) => _update(goal.copyWith(gender: g)),
                  ),
                  NumberRow(
                    label: context.tr('onb_target_age'),
                    controller: _age,
                    onChanged: _onAge,
                    decimal: false,
                  ),
                  NumberRow(
                    label: context.tr('onb_target_height'),
                    unit: 'cm',
                    controller: _height,
                    onChanged: _onHeight,
                  ),
                  NumberRow(
                    label: context.tr('onb_target_weight'),
                    unit: 'kg',
                    controller: _weight,
                    onChanged: _onWeight,
                  ),
                  if (goal.needsTargetWeight)
                    NumberRow(
                      label: context.tr('onb_target_target_weight'),
                      unit: 'kg',
                      controller: _target,
                      onChanged: _onTarget,
                    ),
                  if (goal.needsTargetWeight && goal.targetWeightKg != null)
                    _StepperRow(
                      label: context.tr('onb_target_weeks'),
                      value: goal.timelineWeeks.clamp(_kMinWeeks, _kMaxWeeks),
                      unit: context.tr('onb_target_weeks_unit'),
                      onChanged: (w) =>
                          _update(goal.copyWith(timelineWeeks: w)),
                    ),
                ],
        ),
        for (final p in problems) _ProblemLine(problem: p),
        if (!custom) ...[
          const SizedBox(height: AvoSpacing.section),
          InsetSection(
            header: context.tr('onb_target_activity_heading'),
            children: [
              for (final level in ActivityLevel.values)
                ChoiceRow(
                  title: context.tr('activity_${level.dbValue}'),
                  subtitle: context.tr('activity_${level.dbValue}_sub'),
                  selected: goal.activityLevel == level,
                  onTap: () => _update(goal.copyWith(activityLevel: level)),
                ),
            ],
          ),
        ],
        const SizedBox(height: AvoSpacing.l),
        Text(
          context.tr('onb_target_footnote'),
          style: context.text(
            AvoTextStyle.footnote,
            color: colors.secondaryLabel,
          ),
        ),
      ],
    );
  }

  List<_Problem> _problems(BuildContext context, OnboardingGoalDraft goal) {
    final out = <_Problem>[];
    if (goal.goalType == NutritionGoalType.custom) {
      final kcal = goal.customCalories;
      if (_kcal.text.trim().isNotEmpty &&
          (kcal == null || kcal < _kMinKcal || kcal > _kMaxKcal)) {
        out.add(_Problem(context.tr('onb_target_kcal_range')));
      }
      return out;
    }
    final age = goal.age;
    if (_age.text.trim().isNotEmpty &&
        (age == null || !NutritionGoalCalculator.isPlausibleAge(age))) {
      out.add(_Problem(context.tr('onb_target_age_range')));
    }
    final height = goal.heightCm;
    if (_height.text.trim().isNotEmpty &&
        (height == null ||
            !NutritionGoalCalculator.isPlausibleHeightCm(height))) {
      out.add(_Problem(context.tr('onb_target_height_range')));
    } else if (_heightConverted != null) {
      out.add(
        _Problem(
          context.tr(
            'onb_target_height_converted',
            params: {'cm': _formatNumber(_heightConverted!.round())},
          ),
          info: true,
        ),
      );
    }
    final weight = goal.currentWeightKg;
    if (_weight.text.trim().isNotEmpty &&
        (weight == null ||
            !NutritionGoalCalculator.isPlausibleWeightKg(weight))) {
      out.add(_Problem(context.tr('onb_target_weight_range')));
    }
    final target = goal.targetWeightKg;
    if (goal.needsTargetWeight && target != null && weight != null) {
      if (!NutritionGoalCalculator.isPlausibleWeightKg(target)) {
        out.add(_Problem(context.tr('onb_target_weight_range')));
      } else if (goal.goalType == NutritionGoalType.loseWeight &&
          target > weight) {
        out.add(_Problem(context.tr('onb_target_above'), warning: true));
      } else if (goal.goalType == NutritionGoalType.gainMuscle &&
          target < weight) {
        out.add(_Problem(context.tr('onb_target_below'), warning: true));
      }
    }
    return out;
  }
}

class _Problem {
  const _Problem(this.text, {this.warning = false, this.info = false});

  final String text;
  final bool warning;
  final bool info;
}

/// A line under the section: danger for implausible values, warning for a
/// target that does not fit the goal, plain for "Als 168 cm übernommen".
class _ProblemLine extends StatelessWidget {
  const _ProblemLine({required this.problem});

  final _Problem problem;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = problem.info
        ? colors.secondaryLabel
        : problem.warning
        ? colors.warning
        : colors.destructive;
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AvoSpacing.l,
          AvoSpacing.s,
          AvoSpacing.l,
          0,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!problem.info) ...[
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: AvoIcon(
                  AvoIcons.exclamationmarkCircle,
                  size: 15,
                  color: color,
                ),
              ),
              const SizedBox(width: AvoSpacing.xs + AvoSpacing.xxs),
            ],
            Expanded(
              child: Text(
                problem.text,
                style: context.text(AvoTextStyle.footnote, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The estimate above "Weiter" (Konzept 17 §3.10, item 7).
class _ResultLine extends StatelessWidget {
  const _ResultLine({required this.goal});

  final OnboardingGoalDraft goal;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final number = NumberFormat.decimalPattern(locale);
    String title;
    String? detail;
    if (goal.goalType == NutritionGoalType.custom) {
      final kcal = goal.customCalories;
      title = goal.isComplete && kcal != null
          ? context.tr(
              'onb_target_result_custom',
              params: {'kcal': number.format(kcal)},
            )
          : context.tr('onb_target_result_custom_empty');
    } else {
      final targets = goal.targets();
      if (targets == null) {
        title = context.tr('onb_target_result_empty');
      } else {
        final rounded = (targets.dailyCalorieTarget / 10).round() * 10;
        title = context.tr(
          targets.floorReached
              ? 'onb_target_result_floor'
              : 'onb_target_result',
          params: {'kcal': number.format(rounded)},
        );
        detail = context.tr(
          'onb_target_result_macros',
          params: {
            'protein': '${targets.proteinTargetG}',
            'carbs': '${targets.carbsTargetG}',
            'fat': '${targets.fatTargetG}',
          },
        );
      }
    }
    return Semantics(
      liveRegion: true,
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.text(AvoTextStyle.headline)),
          if (detail != null)
            Text(
              detail,
              style: context.text(
                AvoTextStyle.subhead,
                color: colors.secondaryLabel,
              ),
            ),
        ],
      ),
    );
  }
}

/// A value row with a number field at the end ("Größe 168 cm"). Tapping the
/// row focuses the field. From AX1 on the label sits above the field.
class NumberRow extends StatefulWidget {
  const NumberRow({
    super.key,
    required this.label,
    required this.controller,
    required this.onChanged,
    this.unit,
    this.decimal = true,
  });

  final String label;
  final String? unit;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool decimal;

  @override
  State<NumberRow> createState() => _NumberRowState();
}

class _NumberRowState extends State<NumberRow> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ax = context.isAccessibilityText;
    final style = context.text(AvoTextStyle.body);
    final field = IntrinsicWidth(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: _kFieldMinWidth),
        child: CupertinoTextField(
          controller: widget.controller,
          focusNode: _focus,
          onChanged: widget.onChanged,
          keyboardType: TextInputType.numberWithOptions(
            decimal: widget.decimal,
          ),
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          textAlign: ax ? TextAlign.start : TextAlign.end,
          style: style,
          cursorColor: colors.tint,
          placeholder: '0',
          placeholderStyle: style.copyWith(color: colors.placeholder),
          decoration: null,
          padding: EdgeInsets.zero,
        ),
      ),
    );
    final unit = widget.unit == null
        ? null
        : Text(
            widget.unit!,
            style: context.text(
              AvoTextStyle.body,
              color: colors.secondaryLabel,
            ),
          );
    final valueBlock = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        field,
        if (unit != null) ...[const SizedBox(width: AvoSpacing.xs), unit],
      ],
    );
    final label = Text(widget.label, style: style);
    return Semantics(
      textField: true,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _focus.requestFocus,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AvoSpacing.l,
              vertical: AvoSpacing.m - AvoSpacing.xxs,
            ),
            child: ax
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      label,
                      const SizedBox(height: AvoSpacing.xs),
                      valueBlock,
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: label),
                      const SizedBox(width: AvoSpacing.m),
                      valueBlock,
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// "Geschlecht": the value opens a pull-down menu (Konzept 00 §12.24).
class _GenderRow extends StatelessWidget {
  const _GenderRow({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String> onChanged;

  static const _options = ['female', 'male', 'other'];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ax = context.isAccessibilityText;
    final shown = value == null
        ? context.tr('onb_target_gender_choose')
        : context.tr('gender_$value');
    final label = Text(
      context.tr('onb_target_gender'),
      style: context.text(AvoTextStyle.body),
    );
    final valueText = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            shown,
            style: context.text(
              AvoTextStyle.body,
              color: colors.secondaryLabel,
            ),
          ),
        ),
        const SizedBox(width: AvoSpacing.xs),
        AvoIcon(
          AvoIcons.chevronUpChevronDown,
          size: 13,
          color: colors.secondaryLabel,
        ),
      ],
    );
    return Builder(
      builder: (rowContext) {
        void open() => showAvoMenu(
          rowContext,
          semanticLabel: context.tr('onb_target_gender'),
          items: [
            for (final g in _options)
              AvoMenuItem(
                label: context.tr('gender_$g'),
                checked: g == value,
                onSelected: () => onChanged(g),
              ),
          ],
        );
        return Semantics(
          container: true,
          button: true,
          label: context.tr('onb_target_gender'),
          value: shown,
          onTap: open,
          child: ExcludeSemantics(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: open,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AvoSizes.hitTarget,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AvoSpacing.l,
                    vertical: AvoSpacing.m - AvoSpacing.xxs,
                  ),
                  child: ax
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            label,
                            const SizedBox(height: AvoSpacing.xs),
                            valueText,
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: label),
                            const SizedBox(width: AvoSpacing.m),
                            Flexible(child: valueText),
                          ],
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// "Zeitraum" with a stepper (no slider, owner rule).
class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.value,
    required this.unit,
    required this.onChanged,
  });

  final String label;
  final int value;
  final String unit;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final ax = context.isAccessibilityText;
    final text = Text(label, style: context.text(AvoTextStyle.body));
    final stepper = ValueStepper(
      value: value,
      min: _kMinWeeks,
      max: _kMaxWeeks,
      unit: unit,
      semanticLabel: label,
      onChanged: onChanged,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AvoSpacing.l,
        vertical: AvoSpacing.s,
      ),
      child: ax
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                text,
                const SizedBox(height: AvoSpacing.s),
                stepper,
              ],
            )
          : Row(
              children: [
                Expanded(child: text),
                const SizedBox(width: AvoSpacing.m),
                stepper,
              ],
            ),
    );
  }
}

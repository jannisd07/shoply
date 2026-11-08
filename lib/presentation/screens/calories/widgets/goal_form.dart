import 'package:flutter/cupertino.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/data/models/nutrition_goal.dart';
import 'package:shoply/data/services/nutrition_goal_service.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_choice_row.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_fields.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_format.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/segmented_control.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';

const double _kWarningGlyph = 17; // D2 exclamationmark.triangle.fill

/// The sexes the profile stores (`users.gender`), in menu order.
const List<String> kGoalSexes = ['female', 'male', 'other', 'prefer_not_to_say'];

/// Everything "Ziel berechnen" asks, as typed (S14, and Teil A's onboarding
/// step through [GoalForm], request A-P2). Pure: the numbers come from
/// [NutritionGoalCalculator].
@immutable
class GoalDraft {
  const GoalDraft({
    this.goal = NutritionGoalType.maintain,
    this.sex = 'female',
    this.age = '',
    this.height = '',
    this.weight = '',
    this.target = '',
    this.pace = GoalPace.normal,
    this.activity = ActivityLevel.light,
  });

  /// [NutritionGoalType.loseWeight], [NutritionGoalType.maintain] or
  /// [NutritionGoalType.gainMuscle].
  final NutritionGoalType goal;
  final String sex;
  final String age;
  final String height;
  final String weight;
  final String target;
  final GoalPace pace;
  final ActivityLevel activity;

  /// From a stored goal and profile ("Neu berechnen").
  factory GoalDraft.from({
    NutritionGoal? goal,
    int? age,
    String? sex,
    double? heightCm,
    double? latestWeightKg,
    required String Function(num) format,
  }) {
    final type = goal?.goalType;
    final weight = goal?.currentWeightKg ?? latestWeightKg;
    final height = goal?.heightCm ?? heightCm;
    return GoalDraft(
      goal: type == NutritionGoalType.loseWeight || type == NutritionGoalType.gainMuscle ? type! : NutritionGoalType.maintain,
      sex: kGoalSexes.contains(sex) ? sex! : 'female',
      age: age == null ? '' : '$age',
      height: height == null ? '' : format(height.round()),
      weight: weight == null ? '' : format(weight),
      target: goal?.targetWeightKg == null ? '' : format(goal!.targetWeightKg!),
      pace: goal?.pace ?? GoalPace.normal,
      activity: goal?.activityLevel ?? ActivityLevel.light,
    );
  }

  GoalDraft copyWith({
    NutritionGoalType? goal,
    String? sex,
    String? age,
    String? height,
    String? weight,
    String? target,
    GoalPace? pace,
    ActivityLevel? activity,
  }) =>
      GoalDraft(
        goal: goal ?? this.goal,
        sex: sex ?? this.sex,
        age: age ?? this.age,
        height: height ?? this.height,
        weight: weight ?? this.weight,
        target: target ?? this.target,
        pace: pace ?? this.pace,
        activity: activity ?? this.activity,
      );

  bool get changesWeight => goal == NutritionGoalType.loseWeight || goal == NutritionGoalType.gainMuscle;

  CalorieNumberInput get _ageInput => parseCalorieNumber(age, integer: true, required: true);
  CalorieNumberInput get _heightInput => parseCalorieNumber(height, required: true);
  CalorieNumberInput get _weightInput => parseCalorieNumber(weight, required: true);
  CalorieNumberInput get _targetInput => parseCalorieNumber(target);

  int? get ageYears {
    final v = _ageInput.value?.round();
    return v != null && NutritionGoalCalculator.isPlausibleAge(v) ? v : null;
  }

  /// Height in cm; "1,68" means metres.
  double? get heightCm {
    final v = _heightInput.value;
    if (v == null) return null;
    final cm = NutritionGoalCalculator.normalizeHeightCm(v);
    return NutritionGoalCalculator.isPlausibleHeightCm(cm) ? cm.roundToDouble() : null;
  }

  /// The typed height was in metres and became [heightCm].
  bool get heightConverted {
    final v = _heightInput.value;
    return v != null && v < 3 && heightCm != null;
  }

  double? get weightKg {
    final v = _weightInput.value;
    return v != null && NutritionGoalCalculator.isPlausibleWeightKg(v) ? v : null;
  }

  /// The target weight, when the goal has one and it is plausible.
  double? get targetKg {
    if (!changesWeight) return null;
    final v = _targetInput.value;
    return v != null && NutritionGoalCalculator.isPlausibleWeightKg(v) ? v : null;
  }

  bool get minor => (ageYears ?? 99) < NutritionGoalCalculator.minAdultAgeForWeightLoss;

  /// Errors under the fields (translation keys); null when fine or empty.
  String? get ageError => age.trim().isEmpty
      ? null
      : !_ageInput.isValid
          ? 'cal_number_invalid'
          : ageYears == null
              ? 'cal_age_range'
              : null;
  String? get heightError => height.trim().isEmpty
      ? null
      : !_heightInput.isValid
          ? 'cal_number_invalid'
          : heightCm == null
              ? 'cal_height_range'
              : null;
  String? get weightError => weight.trim().isEmpty
      ? null
      : !_weightInput.isValid
          ? 'cal_number_invalid'
          : weightKg == null
              ? 'cal_weight_range'
              : null;
  String? get targetError => target.trim().isEmpty || !changesWeight
      ? null
      : !_targetInput.isValid
          ? 'cal_number_invalid'
          : targetKg == null
              ? 'cal_weight_range'
              : null;

  bool get hasInputs => ageYears != null && heightCm != null && weightKg != null;

  CalculatedTargets? get result {
    final a = ageYears, h = heightCm, w = weightKg;
    if (a == null || h == null || w == null) return null;
    return NutritionGoalCalculator.calculate(
      goalType: goal,
      activityLevel: activity,
      currentWeightKg: w,
      heightCm: h,
      age: a,
      gender: sex,
      targetWeightKg: targetKg,
      pace: changesWeight ? pace : null,
    );
  }

  /// "Übernehmen" is possible: all inputs valid, no conflict, no
  /// weight-loss goal under 18.
  bool get canApply {
    final r = result;
    if (r == null || targetError != null) return false;
    if (goal == NutritionGoalType.loseWeight && minor) return false;
    return !r.targetWeightConflict;
  }

  @override
  bool operator ==(Object other) =>
      other is GoalDraft &&
      other.goal == goal &&
      other.sex == sex &&
      other.age == age &&
      other.height == height &&
      other.weight == weight &&
      other.target == target &&
      other.pace == pace &&
      other.activity == activity;

  @override
  int get hashCode => Object.hash(goal, sex, age, height, weight, target, pace, activity);
}

/// The questions of "Ziel berechnen" (`GoalForm`, S14): ZIEL, ÜBER DICH,
/// ZIELGEWICHT (losing and gaining only) and ALLTAG, one column, checks
/// under each field. No slider: the pace is a segmented control
/// ("Gemütlich | Normal | Zügig"). Teil A's onboarding can show it as is.
class GoalForm extends StatefulWidget {
  const GoalForm({super.key, required this.initial, required this.onChanged, this.now});

  final GoalDraft initial;
  final ValueChanged<GoalDraft> onChanged;

  /// For "Zielgewicht etwa Ende Februar"; defaults to the clock.
  final DateTime? now;

  @override
  State<GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends State<GoalForm> {
  late GoalDraft _draft = widget.initial;
  late final _age = TextEditingController(text: widget.initial.age);
  late final _height = TextEditingController(text: widget.initial.height);
  late final _weight = TextEditingController(text: widget.initial.weight);
  late final _target = TextEditingController(text: widget.initial.target);

  @override
  void dispose() {
    for (final c in [_age, _height, _weight, _target]) {
      c.dispose();
    }
    super.dispose();
  }

  void _set(GoalDraft next) {
    if (next == _draft) return;
    setState(() => _draft = next);
    widget.onChanged(next);
  }

  String _sexLabel(BuildContext context, String sex) => context.tr(switch (sex) {
        'male' => 'cal_sex_male',
        'other' => 'cal_sex_diverse',
        'prefer_not_to_say' => 'cal_sex_none',
        _ => 'cal_sex_female',
      });

  /// "Ende Februar", "Mitte März 2027".
  String _when(BuildContext context, double weeks) {
    final now = widget.now ?? DateTime.now();
    return context.roughDate(now.add(Duration(days: (weeks * 7).round())), now);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final d = _draft;
    final r = d.result;
    String? err(String? key) => key == null ? null : context.tr(key);

    final goals = [
      (NutritionGoalType.loseWeight, 'cal_goal_lose'),
      (NutritionGoalType.maintain, 'cal_goal_keep'),
      (NutritionGoalType.gainMuscle, 'cal_goal_gain'),
    ];
    final activities = [
      (ActivityLevel.sedentary, 'cal_act_sedentary'),
      (ActivityLevel.light, 'cal_act_light'),
      (ActivityLevel.moderate, 'cal_act_moderate'),
      (ActivityLevel.active, 'cal_act_active'),
      (ActivityLevel.veryActive, 'cal_act_very_active'),
    ];

    final heightNote = d.heightConverted
        ? context.tr('cal_height_converted', params: {'cm': context.amount(d.heightCm!)})
        : null;

    final paceKg = d.pace.kgPerWeek(d.goal);
    final weeks = r?.estimatedWeeksToTarget;
    final paceLine = !d.changesWeight
        ? null
        : weeks != null && d.targetKg != null
            ? context.tr('cal_pace_line', params: {'kg': context.amount(r?.effectiveKgPerWeek ?? paceKg), 'when': _when(context, weeks)})
            : context.tr('cal_pace_line_plain', params: {'kg': context.amount(r?.effectiveKgPerWeek ?? paceKg)});

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          container: true,
          explicitChildNodes: true,
          child: InsetSection(
            header: context.tr('cal_goal'),
            children: [
              for (final (type, key) in goals)
                CalorieChoiceRow(
                  title: context.tr(key),
                  selected: d.goal == type,
                  enabled: !(type == NutritionGoalType.loseWeight && d.minor),
                  subtitle: type == NutritionGoalType.loseWeight && d.minor ? context.tr('cal_under_18') : null,
                  onTap: () => _set(d.copyWith(goal: type)),
                ),
            ],
          ),
        ),
        InsetSection(
          header: context.tr('cal_sec_about'),
          children: [
            Builder(
              builder: (anchor) => NavRow(
                title: context.tr('cal_sex'),
                value: _sexLabel(context, d.sex),
                onTap: () => showAvoMenu(anchor, items: [
                  for (final s in kGoalSexes)
                    AvoMenuItem(
                      label: _sexLabel(context, s),
                      checked: s == d.sex,
                      onSelected: () => _set(_draft.copyWith(sex: s)),
                    ),
                ]),
              ),
            ),
            CalorieFieldRow(
              label: context.tr('cal_age'),
              controller: _age,
              unit: context.tr('cal_years_unit'),
              integer: true,
              error: err(d.ageError),
              onChanged: (v) => _set(_draft.copyWith(age: v)),
            ),
            CalorieFieldRow(
              label: context.tr('cal_height'),
              controller: _height,
              unit: 'cm',
              spokenUnit: context.tr('cal_cm_spoken'),
              error: err(d.heightError),
              onChanged: (v) => _set(_draft.copyWith(height: v)),
            ),
            if (heightNote != null) CalorieGroupNote(text: heightNote, color: colors.secondaryLabel),
            CalorieFieldRow(
              label: context.tr('cal_weight'),
              controller: _weight,
              unit: 'kg',
              spokenUnit: context.tr('cal_kg_spoken'),
              error: err(d.weightError),
              onChanged: (v) => _set(_draft.copyWith(weight: v)),
            ),
          ],
        ),
        if (d.changesWeight)
          InsetSection(
            header: context.tr('cal_target_weight'),
            children: [
              CalorieFieldRow(
                label: context.tr('cal_target_weight'),
                controller: _target,
                unit: 'kg',
                spokenUnit: context.tr('cal_kg_spoken'),
                error: err(d.targetError),
                onChanged: (v) => _set(_draft.copyWith(target: v)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.l, vertical: AvoSpacing.m),
                child: AppSegmentedControl<GoalPace>(
                  semanticLabel: context.tr('cal_pace'),
                  segments: [
                    SegmentItem(value: GoalPace.gemuetlich, label: context.tr('cal_pace_relaxed')),
                    SegmentItem(value: GoalPace.normal, label: context.tr('cal_pace_normal')),
                    SegmentItem(value: GoalPace.zuegig, label: context.tr('cal_pace_fast')),
                  ],
                  selected: d.pace,
                  onChanged: (p) => _set(_draft.copyWith(pace: p)),
                ),
              ),
              if (paceLine != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(AvoSpacing.l, 0, AvoSpacing.l, AvoSpacing.m),
                  child: Text(paceLine, style: context.text(AvoTextStyle.subhead, tabular: true)),
                ),
              if (r != null && r.targetWeightConflict) ...[
                CalorieGroupNote(
                  text: context.tr(d.goal == NutritionGoalType.loseWeight ? 'cal_target_above' : 'cal_target_below'),
                  color: colors.warning,
                  liveRegion: true,
                  icon: AvoIcon(AvoIcons.exclamationmarkTriangleFill, size: _kWarningGlyph, color: colors.warning),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.s),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: AppButton.plain(
                      label: context.tr('cal_switch'),
                      onPressed: () => _set(_draft.copyWith(
                        goal: d.goal == NutritionGoalType.loseWeight
                            ? NutritionGoalType.gainMuscle
                            : NutritionGoalType.loseWeight,
                      )),
                    ),
                  ),
                ),
              ],
              if (r != null && r.floorReached)
                CalorieGroupNote(
                  text: context.tr('cal_floor', params: {'floor': context.kcal(r.floorKcal)}),
                  color: colors.secondaryLabel,
                  liveRegion: true,
                ),
            ],
          ),
        InsetSection(
          header: context.tr('cal_sec_activity'),
          children: [
            for (final (level, key) in activities)
              CalorieChoiceRow(
                title: context.tr(key),
                subtitle: context.tr('${key}_sub'),
                selected: d.activity == level,
                onTap: () => _set(d.copyWith(activity: level)),
              ),
          ],
        ),
      ],
    );
  }
}

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/nutrition_goal.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_entry_actions.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_flow_scaffold.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_format.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_nutrition_row.dart';
import 'package:shoply/presentation/screens/calories/widgets/goal_form.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/calorie_entry_provider.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/rolling_number.dart';

/// The result is announced after this much calm (S14 Barrierefreiheit).
const Duration _kAnnounceAfter = Duration(seconds: 1);

/// The inline title becomes "Ziel · 2.000 kcal" once the result scrolled
/// away.
const double _kCollapseAfter = 120;

/// Default water goal when none was set yet.
const int _kDefaultWaterMl = 2000;

/// S14 "Ziel berechnen" (`/calories/goals/setup?from=onboarding|empty|goals`):
/// one form, the result always on top and rolling live, no wizard and no
/// slider. "Übernehmen" saves through the write queue (offline too), logs the
/// weight only when it changed and keeps age, height and sex in the profile.
class CaloriesGoalSetupScreen extends ConsumerStatefulWidget {
  const CaloriesGoalSetupScreen({super.key, this.from});

  /// `onboarding`, `empty` or `goals` (where it was opened).
  final String? from;

  @override
  ConsumerState<CaloriesGoalSetupScreen> createState() => _CaloriesGoalSetupScreenState();
}

class _CaloriesGoalSetupScreenState extends ConsumerState<CaloriesGoalSetupScreen> {
  GoalDraft? _initial;
  GoalDraft? _draft;
  double? _latestWeight;
  bool _saving = false;
  bool _saved = false;
  Timer? _announce;
  final _scroll = ScrollController();
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final collapsed = _scroll.offset > _kCollapseAfter;
      if (collapsed != _collapsed) setState(() => _collapsed = collapsed);
    });
  }

  @override
  void dispose() {
    _announce?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  /// Fills the form once the profile is known (or failed to load).
  void _prefill() {
    if (_initial != null) return;
    final profile = ref.read(calorieUserProfileProvider);
    if (profile.isLoading) return;
    final user = profile.valueOrNull;
    final weights = ref.read(weightHistoryProvider).valueOrNull;
    _latestWeight = weights == null || weights.isEmpty
        ? null
        : (weights.toList()..sort((a, b) => b.loggedDate.compareTo(a.loggedDate))).first.weightKg;
    final draft = GoalDraft.from(
      goal: ref.read(calorieGoalStateProvider).goal,
      age: user?.age,
      sex: user?.gender,
      heightCm: user?.height,
      latestWeightKg: _latestWeight,
      format: context.amount,
    );
    _initial = draft;
    _draft = draft;
  }

  void _changed(GoalDraft draft) {
    setState(() => _draft = draft);
    _announce?.cancel();
    _announce = Timer(_kAnnounceAfter, () {
      final r = _draft?.result;
      if (!mounted || r == null) return;
      unawaited(SemanticsService.sendAnnouncement(
        View.of(context),
        context.tr('cal_result_a11y', params: {'kcal': context.kcal(r.dailyCalorieTarget)}),
        Directionality.of(context),
      ));
    });
  }

  Future<void> _apply() async {
    final draft = _draft;
    final r = draft?.result;
    if (draft == null || r == null || !draft.canApply || _saving) return;
    setState(() => _saving = true);
    final existing = ref.read(calorieGoalStateProvider).goal;
    final now = DateTime.now().toUtc();
    final goal = NutritionGoal(
      userId: existing?.userId ?? ref.read(authUserIdProvider) ?? '',
      calorieTrackingEnabled: true,
      goalType: draft.goal,
      activityLevel: draft.activity,
      currentWeightKg: draft.weightKg,
      targetWeightKg: draft.targetKg,
      heightCm: draft.heightCm,
      dailyCalorieTarget: r.dailyCalorieTarget,
      proteinTargetG: r.proteinTargetG,
      carbsTargetG: r.carbsTargetG,
      fatTargetG: r.fatTargetG,
      waterTargetMl: existing?.waterTargetMl ?? _kDefaultWaterMl,
      creditWorkouts: existing?.creditWorkouts ?? false,
      pace: draft.changesWeight ? draft.pace : null,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    final diary = ref.read(calorieDiaryProvider);
    try {
      await diary.saveGoal(goal);
    } catch (e) {
      debugPrint('❌ [CalorieGoal] Saving failed: ${calorieErrorKind(e)}');
      if (!mounted) return;
      setState(() => _saving = false);
      showCalorieWriteFailed(context);
      return;
    }
    final weight = draft.weightKg!;
    if (_latestWeight == null || (weight - _latestWeight!).abs() > 0.05) {
      unawaited(diary.logWeight(weight, date: ref.read(calorieClockProvider)()).catchError((Object e) {
        debugPrint('⚠️ [CalorieGoal] Weight not queued: ${calorieErrorKind(e)}');
      }));
      ref.invalidate(weightHistoryProvider);
    }
    unawaited(ref
        .read(calorieProfileWriterProvider)(age: draft.ageYears!, heightCm: draft.heightCm!, gender: draft.sex)
        .catchError((Object e) {
      debugPrint('⚠️ [CalorieGoal] Profile not updated: ${e.runtimeType}');
    }));
    if (!mounted) return;
    setState(() => _saved = true);
    CalorieFlowScaffold.leave(context);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(calorieUserProfileProvider);
    ref.watch(weightHistoryProvider);
    ref.watch(calorieGoalStateProvider);
    _prefill();
    final colors = context.colors;
    final draft = _draft;
    final r = draft?.result;
    final dirty = draft != null && draft != _initial && !_saved;
    final title = _collapsed && r != null
        ? context.tr('cal_setup_collapsed', params: {'kcal': context.kcal(r.dailyCalorieTarget)})
        : context.tr('cal_setup_title');
    final water = ref.read(calorieGoalStateProvider).goal?.waterTargetMl ?? _kDefaultWaterMl;

    return CalorieFlowScaffold(
      leading: CalorieFlowLeading.back,
      title: CalorieFlowTitle(title),
      scrollController: _scroll,
      discard: dirty
          ? CalorieDiscardTexts(
              title: context.tr('cal_discard_changes_title'),
              message: context.tr('cal_discard_changes_body'),
              confirm: context.tr('cal_discard'),
              cancel: context.tr('cal_keep_editing'),
            )
          : null,
      bottom: AppButton.primary(
        label: context.tr('cal_apply'),
        size: AppButtonSize.large,
        expand: true,
        floating: true,
        working: _saving,
        onPressed: draft != null && draft.canApply && !_saving ? _apply : null,
      ),
      children: [
        InsetSection(
          header: context.tr('cal_sec_result'),
          footer: r == null ? context.tr('cal_missing_inputs') : context.tr('cal_formula_note'),
          children: [
            Semantics(
              container: true,
              liveRegion: false,
              label: r == null
                  ? context.tr('cal_missing_inputs')
                  : context.tr('cal_result_a11y', params: {'kcal': context.kcal(r.dailyCalorieTarget)}),
              excludeSemantics: true,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AvoSpacing.l, AvoSpacing.l, AvoSpacing.l, AvoSpacing.s),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: AvoSpacing.s,
                  children: [
                    if (r == null)
                      Text('–', style: context.text(AvoTextStyle.largeTitle, weight: FontWeight.w700, color: colors.secondaryLabel))
                    else
                      RollingNumber(
                        value: r.dailyCalorieTarget,
                        style: context.text(AvoTextStyle.largeTitle, weight: FontWeight.w700, tabular: true),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: AvoSpacing.xs),
                      child: Text(context.tr('cal_kcal_per_day'), style: context.text(AvoTextStyle.body)),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.l, vertical: AvoSpacing.s),
              child: NutritionRow(
                semanticLabel: r == null
                    ? context.tr('cal_missing_inputs')
                    : [
                        context.tr('cal_grams_of', params: {'g': context.grams(r.proteinTargetG), 'name': context.tr('cal_macro_protein')}),
                        context.tr('cal_grams_of', params: {'g': context.grams(r.carbsTargetG), 'name': context.tr('cal_macro_carbs_long')}),
                        context.tr('cal_grams_of', params: {'g': context.grams(r.fatTargetG), 'name': context.tr('cal_macro_fat')}),
                      ].join(', '),
                cells: [
                  NutritionCell(value: r?.proteinTargetG, unit: 'g', label: context.tr('cal_macro_protein')),
                  NutritionCell(value: r?.carbsTargetG, unit: 'g', label: context.tr('cal_macro_carbs_short')),
                  NutritionCell(value: r?.fatTargetG, unit: 'g', label: context.tr('cal_macro_fat')),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AvoSpacing.l, AvoSpacing.xs, AvoSpacing.l, AvoSpacing.l),
              child: Text(
                context.tr('cal_water_goal_line', params: {'amount': context.liters(water)}),
                style: context.text(AvoTextStyle.subhead, color: colors.secondaryLabel),
              ),
            ),
          ],
        ),
        if (draft != null)
          GoalForm(
            initial: draft,
            onChanged: _changed,
            now: ref.read(calorieClockProvider)(),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AvoSpacing.screen + AvoSpacing.l, AvoSpacing.s, AvoSpacing.screen + AvoSpacing.l, 0),
          child: Text(context.tr('cal_privacy_note'), style: context.text(AvoTextStyle.footnote, color: colors.secondaryLabel)),
        ),
      ],
    );
  }
}

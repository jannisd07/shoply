import 'package:flutter/material.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/widgets/paper/paper_widgets.dart';
import 'package:shoply/data/models/nutrition_goal.dart';
import 'package:shoply/data/services/onboarding_answers_service.dart';

/// Follow-up goal questionnaire, shown only when the previous onboarding
/// page's calorie-tracking opt-in is "yes". Same fields/calculation as the
/// standalone `GoalSetupScreen` (reachable later from the calories tab), so
/// answering here or skipping-and-doing-it-later produce identical targets
/// via the same `NutritionGoalCalculator`. Reports a draft up to the parent
/// on every change; a null draft (incomplete) is a valid, non-blocking
/// state — onboarding's primary button never requires this page to be
/// filled in.
class OnboardingGoalPage extends StatefulWidget {
  final ValueChanged<OnboardingGoalDraft?> onDraftChanged;

  const OnboardingGoalPage({super.key, required this.onDraftChanged});

  @override
  State<OnboardingGoalPage> createState() => _OnboardingGoalPageState();
}

class _OnboardingGoalPageState extends State<OnboardingGoalPage> {
  NutritionGoalType _goalType = NutritionGoalType.maintain;
  ActivityLevel _activityLevel = ActivityLevel.moderate;
  String _gender = 'female';
  int _timelineWeeks = 12;

  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _currentWeightController = TextEditingController();
  final _targetWeightController = TextEditingController();

  @override
  void initState() {
    super.initState();
    for (final c in [
      _ageController,
      _heightController,
      _currentWeightController,
      _targetWeightController,
    ]) {
      c.addListener(_reportDraft);
    }
  }

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _currentWeightController.dispose();
    _targetWeightController.dispose();
    super.dispose();
  }

  bool get _needsTargetWeight =>
      _goalType == NutritionGoalType.loseWeight ||
      _goalType == NutritionGoalType.gainMuscle;

  int? get _age => int.tryParse(_ageController.text.trim());
  double? get _height => double.tryParse(_heightController.text.trim());
  double? get _currentWeight => double.tryParse(_currentWeightController.text.trim());
  double? get _targetWeight => double.tryParse(_targetWeightController.text.trim());

  void _reportDraft() {
    final age = _age;
    final height = _height;
    final weight = _currentWeight;
    final target = _needsTargetWeight ? _targetWeight : null;

    final complete = age != null &&
        age > 0 &&
        height != null &&
        height > 0 &&
        weight != null &&
        weight > 0 &&
        (!_needsTargetWeight || (target != null && target > 0));

    widget.onDraftChanged(
      complete
          ? OnboardingGoalDraft(
              goalType: _goalType,
              activityLevel: _activityLevel,
              gender: _gender,
              age: age,
              heightCm: height,
              currentWeightKg: weight,
              targetWeightKg: target,
              timelineWeeks: _needsTargetWeight ? _timelineWeeks : null,
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          PaperKicker(context.tr('onb_goal_kicker'), color: PaperColors.terracotta),
          const SizedBox(height: 10),
          Text(context.tr('onb_goal_title'), style: PaperTextStyles.serif(28)),
          const SizedBox(height: 12),
          Text(
            context.tr('onb_goal_sub'),
            style: PaperTextStyles.body(color: PaperColors.muted),
          ),
          const SizedBox(height: 22),
          _sectionLabel(context.tr('goal_setup_goal_type')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: NutritionGoalType.values.map((g) {
              return _Chip(
                label: context.tr('goal_type_${g.dbValue}'),
                selected: _goalType == g,
                onTap: () => setState(() {
                  _goalType = g;
                  _reportDraft();
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          _sectionLabel(context.tr('goal_setup_gender')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['female', 'male', 'other'].map((g) {
              return _Chip(
                label: context.tr('gender_$g'),
                selected: _gender == g,
                onTap: () => setState(() {
                  _gender = g;
                  _reportDraft();
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: PaperUnderlineField(
                  controller: _ageController,
                  label: context.tr('goal_setup_age'),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: PaperUnderlineField(
                  controller: _heightController,
                  label: context.tr('goal_setup_height_cm'),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: PaperUnderlineField(
                  controller: _currentWeightController,
                  label: context.tr('goal_setup_current_weight_kg'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              if (_needsTargetWeight) ...[
                const SizedBox(width: 20),
                Expanded(
                  child: PaperUnderlineField(
                    controller: _targetWeightController,
                    label: context.tr('goal_setup_target_weight_kg'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          _sectionLabel(context.tr('goal_setup_activity_level')),
          ...ActivityLevel.values.map((a) {
            final selected = _activityLevel == a;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ActivityRow(
                title: context.tr('activity_${a.dbValue}'),
                subtitle: context.tr('activity_${a.dbValue}_sub'),
                selected: selected,
                onTap: () => setState(() {
                  _activityLevel = a;
                  _reportDraft();
                }),
              ),
            );
          }),
          if (_needsTargetWeight) ...[
            const SizedBox(height: 12),
            _sectionLabel(
              context.tr('goal_setup_timeline', params: {'weeks': '$_timelineWeeks'}),
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: PaperColors.terracotta,
                thumbColor: PaperColors.terracotta,
                inactiveTrackColor: PaperColors.hairline,
              ),
              child: Slider(
                value: _timelineWeeks.toDouble(),
                min: 4,
                max: 52,
                divisions: 48,
                label: '$_timelineWeeks',
                onChanged: (v) => setState(() {
                  _timelineWeeks = v.round();
                  _reportDraft();
                }),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            context.tr('onb_goal_skip_hint'),
            style: const TextStyle(fontSize: 12.5, color: PaperColors.faint),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: PaperColors.ink,
          ),
        ),
      );
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? PaperColors.ink : PaperColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? PaperColors.ink : PaperColors.hairline),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: selected ? PaperColors.paper : PaperColors.ink,
          ),
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _ActivityRow({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: PaperColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? PaperColors.ink : PaperColors.hairline,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: PaperColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: PaperColors.muted),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_rounded, size: 18, color: PaperColors.ink),
          ],
        ),
      ),
    );
  }
}

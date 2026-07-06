import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/app_dimensions.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/widgets/design_system.dart';
import 'package:shoply/data/models/nutrition_goal.dart';
import 'package:shoply/data/services/nutrition_goal_service.dart';
import 'package:shoply/data/services/user_service.dart';
import 'package:shoply/data/services/weight_log_service.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';

/// Goal questionnaire: goal type, activity level, current/target weight,
/// height, age, gender, timeline. Calculates and saves calorie/macro
/// targets. Reachable from the calorie dashboard ("set up goals") and from
/// Profile once tracking is enabled.
class GoalSetupScreen extends ConsumerStatefulWidget {
  const GoalSetupScreen({super.key});

  @override
  ConsumerState<GoalSetupScreen> createState() => _GoalSetupScreenState();
}

class _GoalSetupScreenState extends ConsumerState<GoalSetupScreen> {
  NutritionGoalType _goalType = NutritionGoalType.maintain;
  ActivityLevel _activityLevel = ActivityLevel.moderate;
  String _gender = 'female';
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _currentWeightController = TextEditingController();
  final _targetWeightController = TextEditingController();
  int _timelineWeeks = 12;

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final user = await ref.read(currentUserProvider.future);
    final goal = await ref.read(nutritionGoalProvider.future);
    final latestWeight = await WeightLogService.instance.getLatest();

    if (user?.age != null) _ageController.text = user!.age.toString();
    if (user?.gender != null &&
        ['male', 'female'].contains(user!.gender)) {
      _gender = user.gender!;
    }
    final heightCm = goal?.heightCm ?? user?.height;
    if (heightCm != null) _heightController.text = heightCm.round().toString();
    final currentWeight = goal?.currentWeightKg ?? latestWeight?.weightKg;
    if (currentWeight != null) {
      _currentWeightController.text = currentWeight.toStringAsFixed(1);
    }
    if (goal?.targetWeightKg != null) {
      _targetWeightController.text = goal!.targetWeightKg!.toStringAsFixed(1);
    }
    if (goal != null) {
      _goalType = goal.goalType;
      _activityLevel = goal.activityLevel;
      _timelineWeeks = goal.timelineWeeks ?? 12;
    }

    if (mounted) setState(() => _loading = false);
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
      _goalType == NutritionGoalType.loseWeight || _goalType == NutritionGoalType.gainMuscle;

  double? get _age => double.tryParse(_ageController.text.trim());
  double? get _height => double.tryParse(_heightController.text.trim());
  double? get _currentWeight => double.tryParse(_currentWeightController.text.trim());
  double? get _targetWeight => double.tryParse(_targetWeightController.text.trim());

  bool get _canSave =>
      _age != null &&
      _age! > 0 &&
      _height != null &&
      _height! > 0 &&
      _currentWeight != null &&
      _currentWeight! > 0 &&
      (!_needsTargetWeight || (_targetWeight != null && _targetWeight! > 0));

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    try {
      final authUser = ref.read(authUserProvider).valueOrNull;
      if (authUser == null) throw Exception('Not authenticated');

      final targets = NutritionGoalCalculator.calculate(
        goalType: _goalType,
        activityLevel: _activityLevel,
        currentWeightKg: _currentWeight!,
        heightCm: _height!,
        age: _age!.round(),
        gender: _gender,
        targetWeightKg: _needsTargetWeight ? _targetWeight : null,
        timelineWeeks: _needsTargetWeight ? _timelineWeeks : null,
      );

      final existing = await ref.read(nutritionGoalProvider.future);
      final now = DateTime.now();
      final goal = NutritionGoal(
        userId: authUser.id,
        calorieTrackingEnabled: true,
        goalType: _goalType,
        activityLevel: _activityLevel,
        currentWeightKg: _currentWeight,
        targetWeightKg: _needsTargetWeight ? _targetWeight : null,
        heightCm: _height,
        timelineWeeks: _needsTargetWeight ? _timelineWeeks : null,
        dailyCalorieTarget: targets.dailyCalorieTarget,
        proteinTargetG: targets.proteinTargetG,
        carbsTargetG: targets.carbsTargetG,
        fatTargetG: targets.fatTargetG,
        waterTargetMl: existing?.waterTargetMl ?? 2000,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );

      await ref.read(nutritionGoalServiceProvider).saveGoal(goal);
      await WeightLogService.instance.logWeight(weightKg: _currentWeight!);

      // Keep the user's profile fields in sync — they're used elsewhere
      // (personal info screen, recipe/diet logic) so this isn't a
      // calorie-tracking-only value.
      final user = await ref.read(currentUserProvider.future);
      if (user != null) {
        await UserService.instance.updateUserProfile(user.copyWith(
          age: _age!.round(),
          height: _height,
          heightUnit: 'cm',
          gender: _gender,
        ));
      }

      ref.invalidate(nutritionGoalProvider);
      ref.invalidate(weightHistoryProvider);
      ref.invalidate(currentUserProvider);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('goal_setup_save_error', params: {'error': '$e'}))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final accent = AppColors.accentColor(context);

    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        elevation: 0,
        title: Text(context.tr('goal_setup_title'),
            style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.screenHorizontalPadding, 8, AppDimensions.screenHorizontalPadding, 32),
          children: [
            Text(
              context.tr('goal_setup_subtitle'),
              style: TextStyle(fontSize: 14, color: textSecondary, height: 1.4),
            ),
            const SizedBox(height: 24),
            _sectionLabel(context.tr('goal_setup_goal_type')),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: NutritionGoalType.values.map((g) {
                return AppChip(
                  label: context.tr('goal_type_${g.dbValue}'),
                  isSelected: _goalType == g,
                  onTap: () => setState(() => _goalType = g),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            _sectionLabel(context.tr('goal_setup_gender')),
            Wrap(
              spacing: 8,
              children: ['female', 'male', 'other'].map((g) {
                return AppChip(
                  label: context.tr('gender_$g'),
                  isSelected: _gender == g,
                  onTap: () => setState(() => _gender = g),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _ageController,
                    labelText: context.tr('goal_setup_age'),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    controller: _heightController,
                    labelText: context.tr('goal_setup_height_cm'),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _currentWeightController,
                    labelText: context.tr('goal_setup_current_weight_kg'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                if (_needsTargetWeight) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      controller: _targetWeightController,
                      labelText: context.tr('goal_setup_target_weight_kg'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
            _sectionLabel(context.tr('goal_setup_activity_level')),
            Column(
              children: ActivityLevel.values.map((a) {
                final selected = _activityLevel == a;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppListTile(
                    title: context.tr('activity_${a.dbValue}'),
                    subtitle: context.tr('activity_${a.dbValue}_sub'),
                    trailing: selected
                        ? Icon(Icons.check_circle, color: accent)
                        : Icon(Icons.circle_outlined, color: AppColors.border(context)),
                    onTap: () => setState(() => _activityLevel = a),
                  ),
                );
              }).toList(),
            ),
            if (_needsTargetWeight) ...[
              const SizedBox(height: 24),
              _sectionLabel(context.tr('goal_setup_timeline', params: {'weeks': '$_timelineWeeks'})),
              Slider(
                value: _timelineWeeks.toDouble(),
                min: 4,
                max: 52,
                divisions: 48,
                activeColor: accent,
                label: '$_timelineWeeks',
                onChanged: (v) => setState(() => _timelineWeeks = v.round()),
              ),
            ],
            const SizedBox(height: 16),
            AppButton(
              text: context.tr('goal_setup_save'),
              onPressed: _canSave ? _save : null,
              isLoading: _saving,
            ),
            if (!_canSave) ...[
              const SizedBox(height: 8),
              Text(
                context.tr('goal_setup_missing_fields'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary(context),
          ),
        ),
      );
}

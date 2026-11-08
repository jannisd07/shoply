import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/user_food.dart';
import 'package:shoply/data/services/claude_service.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_entry_actions.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_fields.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_flow_scaffold.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_format.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_meal_date_rows.dart';
import 'package:shoply/presentation/state/calorie_entry_provider.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/filter_chip.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';

/// The units S8 offers for the optional amount.
enum _ManualUnit { g, ml, piece, serving }

/// S8 "Manuell eintragen" (`/calories/add/manual`, `?name=`, `?barcode=`,
/// `?meal=`, `?date=`): name and kcal typed in, optional macros and amount,
/// "Kalorien schätzen lassen" when online. After "Eintragen" the food with
/// its amount in g or ml becomes an own food ("Eigene" on S3), with the
/// barcode if one came along.
class CaloriesManualScreen extends ConsumerStatefulWidget {
  const CaloriesManualScreen({super.key, this.name, this.barcode, this.meal, this.dateKey});

  final String? name;
  final String? barcode;
  final MealType? meal;
  final String? dateKey;

  @override
  ConsumerState<CaloriesManualScreen> createState() => _CaloriesManualScreenState();
}

class _CaloriesManualScreenState extends ConsumerState<CaloriesManualScreen> {
  late final _name = TextEditingController(text: widget.name?.trim() ?? '');
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  final _amount = TextEditingController();
  _ManualUnit? _unit;
  late MealType _meal = widget.meal ?? mealForTime(ref.read(calorieClockProvider)());
  late String? _dateKey = widget.dateKey;

  bool _estimating = false;
  bool _estimateFailed = false;
  CalorieNutritionEstimate? _estimate;
  bool _logging = false;
  bool _done = false;

  @override
  void dispose() {
    for (final c in [_name, _kcal, _protein, _carbs, _fat, _amount]) {
      c.dispose();
    }
    super.dispose();
  }

  CalorieNumberInput get _kcalInput => parseCalorieNumber(_kcal.text, integer: true, required: true, max: 20000);
  CalorieNumberInput _grams(TextEditingController c) => parseCalorieNumber(c.text, max: 2000);
  CalorieNumberInput get _amountInput => parseCalorieNumber(_amount.text, max: 10000);

  bool get _nameValid => _name.text.trim().isNotEmpty;

  bool get _valid =>
      _nameValid &&
      _kcalInput.isValid &&
      [_protein, _carbs, _fat].every((c) => _grams(c).isValid || _grams(c).isEmpty) &&
      (_amountInput.isValid || _amountInput.isEmpty);

  bool get _dirty =>
      !_done &&
      ([_kcal, _protein, _carbs, _fat, _amount].any((c) => c.text.trim().isNotEmpty) ||
          _name.text.trim() != (widget.name?.trim() ?? ''));

  /// The estimate stands as long as the kcal field still shows it.
  bool get _usesEstimate {
    final e = _estimate;
    return e != null && _kcalInput.value?.round() == e.kcal;
  }

  String? _errorOf(TextEditingController c, CalorieNumberInput input) =>
      c.text.trim().isNotEmpty && !input.isValid ? context.tr('cal_number_invalid') : null;

  Future<void> _runEstimate() async {
    final name = _name.text.trim();
    if (name.isEmpty || _estimating) return;
    setState(() {
      _estimating = true;
      _estimateFailed = false;
    });
    try {
      final amount = _amountInput.value;
      final unit = _unit;
      final text = amount != null && unit != null ? '${context.amount(amount)} ${_unitText(unit)} $name' : name;
      final e = await ref.read(calorieNutritionEstimatorProvider)(text);
      if (!mounted) return;
      setState(() {
        _estimating = false;
        _estimate = e;
        _kcal.text = '${e.kcal}';
        if (e.proteinG != null) _protein.text = context.amount(_round1(e.proteinG!));
        if (e.carbsG != null) _carbs.text = context.amount(_round1(e.carbsG!));
        if (e.fatG != null) _fat.text = context.amount(_round1(e.fatG!));
      });
    } on ClaudeException catch (e) {
      debugPrint('⚠️ [CalorieManual] Estimate failed: ${e.code}');
      if (!mounted) return;
      unawaited(AvoHaptics.error());
      setState(() {
        _estimating = false;
        _estimateFailed = true;
      });
    }
  }

  static double _round1(double v) => (v * 10).round() / 10;

  String _unitText(_ManualUnit u) => switch (u) {
        _ManualUnit.g => 'g',
        _ManualUnit.ml => 'ml',
        _ManualUnit.piece => context.tr('cal_unit_piece'),
        _ManualUnit.serving => context.tr('cal_unit_portion'),
      };

  Future<void> _log() async {
    if (!_valid || _logging) return;
    setState(() => _logging = true);
    final now = ref.read(calorieClockProvider)();
    final amount = _amountInput.value;
    final unit = _unit;
    final estimated = _usesEstimate;
    final entry = FoodLogEntry(
      id: '',
      userId: '',
      loggedDate: parseCalorieDayKey(_dateKey ?? calorieTodayKeyNow(ref)),
      mealType: _meal,
      origin: estimated ? FoodEntryOrigin.manualEstimated : FoodEntryOrigin.manual,
      foodName: _name.text.trim(),
      quantity: amount ?? 1,
      unit: amount == null || unit == null
          ? null
          : switch (unit) {
              _ManualUnit.g => 'g',
              _ManualUnit.ml => 'ml',
              _ManualUnit.piece => 'piece',
              _ManualUnit.serving => 'serving',
            },
      calories: _kcalInput.value!.round(),
      proteinG: _grams(_protein).value,
      carbsG: _grams(_carbs).value,
      fatG: _grams(_fat).value,
      barcode: widget.barcode,
      estimated: estimated,
      confidence: estimated ? _estimate!.confidence : null,
      loggedTime: FoodLogTime.of(now),
      createdAt: now,
    );
    final saved = await logNewFood(context, ref, entry);
    if (!mounted) return;
    if (saved == null) {
      setState(() => _logging = false);
      return;
    }
    final own = UserFood.fromEntry(saved, id: '');
    if (own != null) unawaited(ref.read(userFoodsProvider.notifier).save(own));
    setState(() => _done = true);
    popCalorieFlow(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final today = ref.watch(calorieTodayKeyProvider);
    final offline = ref.watch(isOfflineProvider);
    final aiOn = ref.watch(aiRemoteEnabledProvider);
    final canEstimate = !offline && aiOn;
    final shownDate = switch (_dateKey) {
      final k? when k.compareTo(today) < 0 => k,
      _ => today,
    };
    final direct = !Navigator.of(context).canPop();

    return CalorieFlowScaffold(
      leading: direct ? CalorieFlowLeading.close : CalorieFlowLeading.back,
      title: CalorieFlowTitle(context.tr('cal_manual_title')),
      discard: _dirty
          ? CalorieDiscardTexts(
              title: context.tr('cal_discard_input_title'),
              message: context.tr('cal_discard_food_body'),
              confirm: context.tr('cal_discard'),
              cancel: context.tr('cal_keep_editing'),
            )
          : null,
      bottom: AppButton.primary(
        label: context.tr('cal_log_button'),
        size: AppButtonSize.large,
        expand: true,
        floating: true,
        working: _logging,
        onPressed: _valid && !_logging ? _log : null,
      ),
      children: [
        InsetSection(children: [
          CalorieFieldRow(
            label: context.tr('cal_name'),
            controller: _name,
            number: false,
            placeholder: context.tr('cal_name_placeholder'),
            textInputAction: TextInputAction.next,
            autofocus: widget.name == null || widget.name!.trim().isEmpty,
            onChanged: (_) => setState(() {}),
          ),
          CalorieFieldRow(
            label: context.tr('cal_calories'),
            controller: _kcal,
            unit: context.tr('cal_unit_kcal'),
            spokenUnit: context.tr('cal_kcal_spoken'),
            integer: true,
            error: _errorOf(_kcal, _kcalInput),
            onChanged: (_) => setState(() {}),
          ),
        ]),
        if (canEstimate && _nameValid) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(AvoSpacing.screen, AvoSpacing.s, AvoSpacing.screen, 0),
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
          if (_usesEstimate)
            Padding(
              padding: const EdgeInsets.fromLTRB(AvoSpacing.screen + AvoSpacing.l, 0, AvoSpacing.screen, 0),
              child: Text(
                context.tr('cal_estimated_check'),
                style: context.text(AvoTextStyle.footnote, color: colors.secondaryLabel),
              ),
            ),
          if (_estimateFailed)
            StatusRow(
              kind: StatusKind.sectionError,
              text: context.tr('cal_estimate_error'),
              actionLabel: context.tr('retry'),
              onAction: _runEstimate,
            ),
        ],
        InsetSection(
          header: context.tr('cal_sec_nutrients'),
          footer: context.tr('cal_nutrients_optional'),
          children: [
            for (final (c, key) in [(_protein, 'cal_macro_protein'), (_carbs, 'cal_macro_carbs_long'), (_fat, 'cal_macro_fat')])
              CalorieFieldRow(
                label: context.tr(key),
                controller: c,
                unit: 'g',
                spokenUnit: context.tr('cal_grams'),
                error: _errorOf(c, _grams(c)),
                onChanged: (_) => setState(() {}),
              ),
          ],
        ),
        InsetSection(
          header: context.tr('cal_sec_amount'),
          children: [
            CalorieFieldRow(
              label: context.tr('cal_sec_amount'),
              controller: _amount,
              unit: _unit == null ? null : _unitText(_unit!),
              error: _errorOf(_amount, _amountInput),
              onChanged: (_) => setState(() {}),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AvoSpacing.s),
              child: Semantics(
                container: true,
                label: context.tr('cal_unit_a11y'),
                explicitChildNodes: true,
                child: ChipRow(
                  padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.l),
                  chips: [
                    for (final u in _ManualUnit.values)
                      Semantics(
                        inMutuallyExclusiveGroup: true,
                        child: AppFilterChip(
                          label: _unitText(u),
                          selected: _unit == u,
                          onSelected: (on) => setState(() => _unit = on ? u : null),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AvoSpacing.section),
        InsetSection(children: [
          CalorieMealRow(meal: _meal, onChanged: (m) => setState(() => _meal = m)),
          CalorieDateRow(
            dateKey: shownDate,
            todayKey: today,
            onChanged: (k) => setState(() => _dateKey = k == today ? null : k),
          ),
        ]),
      ],
    );
  }
}

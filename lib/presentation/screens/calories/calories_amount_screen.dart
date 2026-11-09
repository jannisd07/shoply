import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/food_product.dart';
import 'package:shoply/data/models/user_food.dart';
import 'package:shoply/data/services/native/barcode_scanner_channel.dart';
import 'package:shoply/data/services/open_food_facts_service.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_amount_food.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_entry_actions.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_fields.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_flow_scaffold.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_format.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_meal_date_rows.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_nutrition_row.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_stepper.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_timing.dart';
import 'package:shoply/presentation/state/calorie_entry_provider.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/filter_chip.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/skeleton.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:shoply/routes/route_paths.dart';

/// Product header image (D2: 64 pt, radius 14).
const double _kProductImage = 64; // D2
const double _kProductRadius = 14; // D2

/// The amount field: up to the largest Open Food Facts packs.
const double _kMaxAmount = 5000;

/// S7 "Menge" (`/calories/add/food/:foodId`): the amount of a known product
/// with its numbers live, then "Eintragen". Opened from the search, a scan
/// (replacing the camera), the number field and "Andere Menge …". Without
/// nutrition the person types them in per 100 g from the pack; they are
/// remembered (own food with the barcode).
class CaloriesAmountScreen extends ConsumerStatefulWidget {
  const CaloriesAmountScreen({super.key, required this.foodId, this.food, this.meal, this.dateKey});

  /// Barcode, `own:<id>` or `recent:<entry id>`.
  final String foodId;

  /// The food as the opening screen knew it (route `extra`).
  final CalorieAmountFood? food;
  final MealType? meal;
  final String? dateKey;

  @override
  ConsumerState<CaloriesAmountScreen> createState() => _CaloriesAmountScreenState();
}

enum _Load { ready, loading, notFound, failed }

class _CaloriesAmountScreenState extends ConsumerState<CaloriesAmountScreen> {
  CalorieAmountFood? _food;
  _Load _load = _Load.ready;
  late MealType _meal = widget.meal ?? mealForTime(ref.read(calorieClockProvider)());
  late String? _dateKey = widget.dateKey;

  CalorieAmountUnit _unit = CalorieAmountUnit.base;
  final _amount = TextEditingController();
  bool _amountTouched = false;
  bool _logging = false;
  Timer? _announce;

  // Nutrition per 100 g typed in from the pack ("Nährwerte fehlen").
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();

  @override
  void initState() {
    super.initState();
    final food = widget.food;
    if (food != null) {
      _setFood(food);
    } else {
      _load = _Load.loading;
      unawaited(_resolve());
    }
  }

  /// The start amount is formatted in the device language, so it is set
  /// once the context can be read.
  bool _amountSet = false;

  void _setFood(CalorieAmountFood food) {
    _food = food;
    _unit = food.start.unit;
    _amountSet = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final food = _food;
    if (food != null && !_amountSet) {
      _amountSet = true;
      _amount.text = context.amount(food.start.amount);
    }
  }

  /// A deep link or a reload without the food in `extra`.
  Future<void> _resolve() async {
    final id = widget.foodId;
    try {
      CalorieAmountFood? food;
      if (id.startsWith('own:')) {
        final own = ref.read(userFoodsProvider).where((f) => 'own:${f.id}' == id).firstOrNull;
        if (own != null) food = CalorieAmountFood.fromUserFood(own);
      } else if (BarcodeScannerChannel.normalizeGtin(id) case final code?) {
        final product = await ref.read(calorieBarcodeLookupProvider)(code);
        if (product != null) food = CalorieAmountFood.fromProduct(product, origin: FoodEntryOrigin.barcode);
      }
      if (!mounted) return;
      setState(() {
        if (food == null) {
          _load = _Load.notFound;
        } else {
          _load = _Load.ready;
          _setFood(food);
          _amountSet = true;
          _amount.text = context.amount(food.start.amount);
        }
      });
    } on OffRequestFailed {
      if (mounted) setState(() => _load = _Load.failed);
    }
  }

  @override
  void dispose() {
    _announce?.cancel();
    for (final c in [_amount, _kcal, _protein, _carbs, _fat]) {
      c.dispose();
    }
    super.dispose();
  }

  CalorieNumberInput get _amountInput => parseCalorieNumber(_amount.text, required: true, max: _kMaxAmount);

  double? get _amountValue {
    final v = _amountInput.value;
    return v == null || v <= 0 ? null : v;
  }

  CalorieNumberInput get _kcalInput => parseCalorieNumber(_kcal.text, integer: true, required: true, max: 900);
  CalorieNumberInput _gramInput(TextEditingController c) => parseCalorieNumber(c.text, max: 100);

  /// Typed-in values per 100 g; null while kcal is missing or a field is
  /// invalid.
  ({int kcal, double? protein, double? carbs, double? fat})? get _per100 {
    final kcal = _kcalInput.value;
    final macros = [_protein, _carbs, _fat].map(_gramInput).toList();
    if (kcal == null || macros.any((m) => !m.isValid && !m.isEmpty)) return null;
    return (kcal: kcal.round(), protein: macros[0].value, carbs: macros[1].value, fat: macros[2].value);
  }

  bool get _needsNutrition => !(_food?.hasNutrition ?? true);

  void _changed() {
    setState(() {});
    _announce?.cancel();
    _announce = Timer(CalorieTiming.announceAfter, _announceNutrition);
  }

  void _announceNutrition() {
    final food = _food;
    final amount = _amountValue;
    if (!mounted || food == null || amount == null) return;
    final n = food.nutritionFor(amount, _unit, per100: _needsNutrition ? _per100 : null);
    final row = nutritionRowFor(context, kcal: n.kcal, protein: n.protein, carbs: n.carbs, fat: n.fat);
    unawaited(SemanticsService.sendAnnouncement(View.of(context), row.semanticLabel, Directionality.of(context)));
  }

  void _setUnit(CalorieAmountUnit unit) {
    final food = _food;
    if (food == null || unit == _unit) return;
    final grams = food.gramsOf(_amountValue ?? 0, _unit);
    setState(() {
      _unit = unit;
      _amount.text = context.amount(unit == CalorieAmountUnit.base ? (grams ?? 100).roundToDouble() : 1);
    });
    unawaited(AvoHaptics.selection());
  }

  Future<void> _log() async {
    final food = _food;
    final amount = _amountValue;
    if (food == null || amount == null || _logging) return;
    final per100 = _needsNutrition ? _per100 : null;
    if (_needsNutrition && per100 == null) return;
    setState(() => _logging = true);
    final today = calorieTodayKeyNow(ref);
    final entry = food.entryFor(
      amount: amount,
      unit: _unit,
      dateKey: _dateKey ?? today,
      meal: _meal,
      now: ref.read(calorieClockProvider)(),
      per100: per100,
    );
    final saved = await logNewFood(context, ref, entry);
    if (!mounted) return;
    if (saved == null) {
      setState(() => _logging = false);
      return;
    }
    if (per100 != null) _remember(food, per100);
    popCalorieFlow(context);
  }

  /// "Wir merken uns die Werte für das nächste Mal." The product on this
  /// device gets the values, and with a barcode it becomes an own food.
  void _remember(CalorieAmountFood food, ({int kcal, double? protein, double? carbs, double? fat}) per100) {
    final code = food.barcode;
    if (code == null) return;
    final cache = ref.read(calorieProductCacheProvider.notifier);
    final product =
        cache.find(code) ?? FoodProduct(barcode: code, name: food.name, brand: food.brand, imageUrl: food.imageUrl);
    cache.put(product.withNutrition(kcal: per100.kcal, protein: per100.protein, carbs: per100.carbs, fat: per100.fat));
    unawaited(
      ref
          .read(userFoodsProvider.notifier)
          .save(
            UserFood(
              id: '',
              userId: '',
              name: UserFood.cutName(food.name),
              barcode: UserFood.validBarcode(code),
              kcal100: per100.kcal.toDouble(),
              protein100: per100.protein,
              carbs100: per100.carbs,
              fat100: per100.fat,
              servingG: UserFood.sizeOrNull(food.servingG),
              packageG: UserFood.sizeOrNull(food.packageG),
              createdAt: DateTime.now().toUtc(),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final food = _food;
    final title = CalorieFlowTitle(context.tr('cal_amount_title'));
    if (food == null) {
      return CalorieFlowScaffold(
        leading: CalorieFlowLeading.back,
        title: title,
        children: [
          if (_load == _Load.loading)
            Padding(
              padding: const EdgeInsets.only(top: AvoSpacing.l),
              child: InsetSection(children: [SkeletonSection(rows: 2, loadingLabel: context.tr('cal_loading'))]),
            )
          else ...[
            const SizedBox(height: AvoSpacing.l),
            StatusRow(
              kind: _load == _Load.failed ? StatusKind.offline : StatusKind.sectionError,
              text: context.tr(_load == _Load.failed ? 'cal_scan_offline' : 'cal_scan_not_found'),
            ),
            const SizedBox(height: AvoSpacing.l),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
              child: AppButton.primary(
                label: context.tr('cal_manual_row'),
                onPressed: () => context.pushReplacement(
                  Uri(
                    path: '${RoutePaths.calories}/add/manual',
                    queryParameters: {
                      if (BarcodeScannerChannel.normalizeGtin(widget.foodId) case final code?) 'barcode': code,
                      'meal': _meal.dbValue,
                      if (_dateKey != null) 'date': _dateKey!,
                    },
                  ).toString(),
                ),
              ),
            ),
          ],
        ],
      );
    }

    final colors = context.colors;
    final today = ref.watch(calorieTodayKeyProvider);
    final amount = _amountValue;
    final per100 = _needsNutrition ? _per100 : null;
    final n = amount == null ? null : food.nutritionFor(amount, _unit, per100: per100);
    final amountError = _amountTouched && amount == null ? context.tr('cal_number_invalid') : null;
    final canLog = amount != null && (!_needsNutrition || per100 != null) && !_logging;
    final shownDate = switch (_dateKey) {
      final k? when k.compareTo(today) < 0 => k,
      _ => today,
    };

    return CalorieFlowScaffold(
      leading: CalorieFlowLeading.back,
      title: title,
      bottom: AppButton.primary(
        label: context.tr('cal_log_button'),
        size: AppButtonSize.large,
        expand: true,
        floating: true,
        working: _logging,
        onPressed: canLog ? _log : null,
      ),
      children: [
        InsetSection(children: [_ProductHeader(food: food)]),
        if (_needsNutrition) ...[
          const SizedBox(height: AvoSpacing.section),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen + AvoSpacing.l),
            child: Text(context.tr('cal_nutrients_missing'), style: context.text(AvoTextStyle.subhead)),
          ),
          InsetSection(
            header: context.tr('cal_sec_per_100g'),
            footer: context.tr('cal_nutrients_remembered'),
            children: [
              CalorieFieldRow(
                label: context.tr('cal_calories'),
                controller: _kcal,
                unit: context.tr('cal_unit_kcal'),
                spokenUnit: context.tr('cal_kcal_spoken'),
                integer: true,
                error: _kcal.text.isNotEmpty && !_kcalInput.isValid ? context.tr('cal_number_invalid') : null,
                onChanged: (_) => _changed(),
              ),
              for (final (c, key) in [
                (_protein, 'cal_macro_protein'),
                (_carbs, 'cal_macro_carbs_long'),
                (_fat, 'cal_macro_fat'),
              ])
                CalorieFieldRow(
                  label: context.tr(key),
                  controller: c,
                  unit: 'g',
                  spokenUnit: context.tr('cal_grams'),
                  error: c.text.isNotEmpty && !_gramInput(c).isValid ? context.tr('cal_number_invalid') : null,
                  onChanged: (_) => _changed(),
                ),
            ],
          ),
        ],
        InsetSection(
          header: context.tr('cal_sec_amount'),
          children: [
            _AmountEditor(
              food: food,
              unit: _unit,
              controller: _amount,
              error: amountError,
              autofocus: !_needsNutrition,
              onChanged: () {
                _amountTouched = true;
                _changed();
              },
              onStep: (v) {
                _amount.text = context.amount(v);
                _amountTouched = true;
                _changed();
              },
              onUnit: _setUnit,
            ),
          ],
        ),
        const SizedBox(height: AvoSpacing.section),
        InsetSection(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.l, vertical: AvoSpacing.m),
              child: nutritionRowFor(context, kcal: n?.kcal, protein: n?.protein, carbs: n?.carbs, fat: n?.fat),
            ),
          ],
        ),
        const SizedBox(height: AvoSpacing.section),
        InsetSection(
          children: [
            CalorieMealRow(meal: _meal, onChanged: (m) => setState(() => _meal = m)),
            CalorieDateRow(
              dateKey: shownDate,
              todayKey: today,
              onChanged: (k) => setState(() => _dateKey = k == today ? null : k),
            ),
          ],
        ),
        if (food.fromOpenFoodFacts && food.barcode != null)
          _OffAttribution(barcode: food.barcode!, color: colors.secondaryLabel),
      ],
    );
  }
}

/// The product group: photo 64 (Open Food Facts, on white, never cut out;
/// gone from AX1 on), name, brand and package, kcal per 100 g or per portion.
class _ProductHeader extends StatelessWidget {
  const _ProductHeader({required this.food});

  final CalorieAmountFood food;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final image = food.imageUrl;
    final brand = food.brand?.trim();
    final pack = food.packageG;
    final second = [
      if (brand != null && brand.isNotEmpty) brand,
      if (pack != null) context.tr('cal_unit_pack', params: {'g': context.amount(pack)}),
    ].join(' · ');
    final portion = food.portion;
    final third = portion != null
        ? [
            ?context.entryAmount(portion),
            context.tr('cal_meal_sum', params: {'kcal': context.kcal(portion.calories)}),
          ].join(' · ')
        : food.kcal100 == null
        ? null
        : context.tr(
            food.liquid ? 'cal_kcal_per_100ml' : 'cal_kcal_per_100g',
            params: {'kcal': context.kcal(food.kcal100!)},
          );
    return Padding(
      padding: const EdgeInsets.all(AvoSpacing.l),
      child: Row(
        children: [
          if (image != null && !context.isAccessibilityText) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(_kProductRadius),
              child: ColoredBox(
                color: colors.surface,
                child: SizedBox.square(
                  dimension: _kProductImage,
                  child: Image.network(
                    image,
                    fit: BoxFit.contain,
                    // The name stands next to it.
                    excludeFromSemantics: true,
                    frameBuilder: (context, child, frame, sync) =>
                        frame == null && !sync ? ColoredBox(color: colors.fill) : child,
                    errorBuilder: (context, _, __) => ColoredBox(color: colors.fill),
                  ),
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
                Text(food.name, style: context.text(AvoTextStyle.headline)),
                if (second.isNotEmpty)
                  Text(second, style: context.text(AvoTextStyle.subhead, color: colors.secondaryLabel)),
                if (third != null)
                  Text(third, style: context.text(AvoTextStyle.subhead, color: colors.secondaryLabel, tabular: true)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The amount: a large number field (decimal pad, focused on open) with its
/// unit, the stepper beside it (below it from xxL on) and the unit chips.
class _AmountEditor extends StatelessWidget {
  const _AmountEditor({
    required this.food,
    required this.unit,
    required this.controller,
    required this.error,
    required this.autofocus,
    required this.onChanged,
    required this.onStep,
    required this.onUnit,
  });

  final CalorieAmountFood food;
  final CalorieAmountUnit unit;
  final TextEditingController controller;
  final String? error;
  final bool autofocus;
  final VoidCallback onChanged;
  final ValueChanged<double> onStep;
  final ValueChanged<CalorieAmountUnit> onUnit;

  String _unitLabel(BuildContext context, CalorieAmountUnit u) => switch (u) {
    CalorieAmountUnit.base => food.baseUnit,
    CalorieAmountUnit.serving => context.tr('cal_unit_serving', params: {'g': context.amount(food.servingG ?? 0)}),
    CalorieAmountUnit.pack => context.tr('cal_unit_pack', params: {'g': context.amount(food.packageG ?? 0)}),
    CalorieAmountUnit.portion =>
      food.portion?.unit == 'serving' || food.portion?.unit == null
          ? context.tr('cal_unit_portion')
          : food.portion!.unit!,
  };

  /// The unit after the number ("g", "Portion").
  String _shortUnit(BuildContext context) => switch (unit) {
    CalorieAmountUnit.base => food.baseUnit,
    CalorieAmountUnit.serving => context.tr('cal_unit_portion'),
    CalorieAmountUnit.pack => context.tr('cal_unit_pack_short'),
    CalorieAmountUnit.portion => _unitLabel(context, unit),
  };

  String _spoken(BuildContext context, double v) => switch (unit) {
    CalorieAmountUnit.base => context.tr(
      food.liquid ? 'cal_ml_spoken' : 'cal_grams_spoken',
      params: {'n': context.amount(v)},
    ),
    _ => '${context.amount(v)} ${_shortUnit(context)}',
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final below = calorieLabelsAbove(context);
    final value = parseCalorieNumber(controller.text).value ?? 0;
    final step = CalorieAmountFood.stepOf(unit);
    final field = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: MergeSemantics(
            child: Semantics(
              label: context.tr('cal_sec_amount'),
              hint: error,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
                child: CupertinoTextField(
                  key: const ValueKey('cal-amount-field'),
                  controller: controller,
                  autofocus: autofocus,
                  decoration: null,
                  padding: EdgeInsets.zero,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: calorieNumberFormatters,
                  style: context.text(AvoTextStyle.largeTitle, weight: FontWeight.w700, tabular: true),
                  onChanged: (_) => onChanged(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AvoSpacing.s),
        ExcludeSemantics(
          child: Text(_shortUnit(context), style: context.text(AvoTextStyle.body, color: colors.secondaryLabel)),
        ),
      ],
    );
    final stepper = CalorieStepper(
      value: value,
      step: step,
      min: step,
      max: _kMaxAmount,
      semanticLabel: context.tr('cal_sec_amount'),
      spokenValue: (v) => _spoken(context, v),
      onChanged: onStep,
    );
    final units = food.units;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AvoSpacing.l, AvoSpacing.m, AvoSpacing.l, AvoSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (below) ...[
            field,
            const SizedBox(height: AvoSpacing.s),
            Align(alignment: AlignmentDirectional.centerStart, child: stepper),
          ] else
            Row(
              children: [
                Expanded(child: field),
                const SizedBox(width: AvoSpacing.m),
                stepper,
              ],
            ),
          if (error != null) ...[
            const SizedBox(height: AvoSpacing.xs),
            ExcludeSemantics(
              child: Text(error!, style: context.text(AvoTextStyle.footnote, color: colors.destructive)),
            ),
          ],
          if (units.length > 1 || food.liquid) ...[
            const SizedBox(height: AvoSpacing.s),
            Semantics(
              container: true,
              label: context.tr('cal_unit_a11y'),
              explicitChildNodes: true,
              child: ChipRow(
                padding: EdgeInsets.zero,
                chips: [
                  for (final u in units)
                    Semantics(
                      inMutuallyExclusiveGroup: true,
                      child: AppFilterChip(
                        label: _unitLabel(context, u),
                        selected: u == unit,
                        onSelected: (_) => onUnit(u),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Nährwerte und Foto: Open Food Facts (ODbL, Foto CC BY-SA). …" as a link
/// to the product page.
class _OffAttribution extends StatelessWidget {
  const _OffAttribution({required this.barcode, required this.color});

  final String barcode;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = context.tr('cal_off_attribution');
    void open() => unawaited(launchUrl(offProductPageUrl(barcode), mode: LaunchMode.externalApplication));
    return Semantics(
      link: true,
      label: text,
      onTap: open,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: open,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AvoSpacing.screen + AvoSpacing.l,
              AvoSpacing.s,
              AvoSpacing.screen + AvoSpacing.l,
              0,
            ),
            child: Text(text, style: context.text(AvoTextStyle.footnote, color: color)),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/user_food.dart';
import 'package:shoply/data/services/meal_photo_storage_service.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_barcode.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_entry_actions.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_fields.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_flow_scaffold.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_format.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_meal_date_rows.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_nutrition_row.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_stepper.dart';
import 'package:shoply/presentation/state/calorie_entry_provider.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/glass_icon_button.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';
import 'package:shoply/routes/route_paths.dart';

/// D2: photo 4:3, radius 20; the time wheel at the iOS height.
const double _kPhotoAspect = 4 / 3; // D2
const double _kWheelHeight = 216; // UIDatePicker

/// Narrower than this, the stepper goes under the amount field.
const double _kStackBelow = 320;

/// S9 "Eintrag bearbeiten" (`/calories/entry/:entryId?date=`): amount, meal,
/// day, time, name and numbers of a diary entry, saved when the screen is
/// left ("Eintrag geändert · Widerrufen" in the diary), or "Eintrag
/// löschen" (at once, with undo, no dialog). Closes without a word when the
/// entry was deleted on another device.
class CaloriesEntryScreen extends ConsumerStatefulWidget {
  const CaloriesEntryScreen({super.key, required this.entryId, required this.dateKey, this.entry});

  final String entryId;

  /// The day the entry is on (`?date=`).
  final String dateKey;

  /// The entry as the diary showed it (route `extra`), for the first frame.
  final FoodLogEntry? entry;

  @override
  ConsumerState<CaloriesEntryScreen> createState() => _CaloriesEntryScreenState();
}

class _CaloriesEntryScreenState extends ConsumerState<CaloriesEntryScreen> {
  FoodLogEntry? _original;
  final _name = TextEditingController();
  final _quantity = TextEditingController();
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  late MealType _meal;
  late String _dateKey;
  FoodLogTime? _time;
  bool _timeOpen = false;
  bool _nutrientsEdited = false;
  bool _gone = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _dateKey = widget.dateKey;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_original == null) {
      final entry = widget.entry ?? ref.read(calorieEntryProvider((dateKey: widget.dateKey, id: widget.entryId)));
      if (entry != null) _fill(entry);
    }
  }

  void _fill(FoodLogEntry e) {
    _original = e;
    _name.text = e.foodName;
    _quantity.text = context.amount(e.quantity);
    _lastQuantity = e.quantity;
    _kcal.text = '${e.calories}';
    _protein.text = e.proteinG == null ? '' : context.amount(_round1(e.proteinG!));
    _carbs.text = e.carbsG == null ? '' : context.amount(_round1(e.carbsG!));
    _fat.text = e.fatG == null ? '' : context.amount(_round1(e.fatG!));
    _meal = e.mealType;
    _dateKey = e.dateKey;
    _time = e.loggedTime;
  }

  static double _round1(double v) => (v * 10).round() / 10;

  @override
  void dispose() {
    for (final c in [_name, _quantity, _kcal, _protein, _carbs, _fat]) {
      c.dispose();
    }
    super.dispose();
  }

  CalorieNumberInput get _quantityInput => parseCalorieNumber(_quantity.text, required: true, max: 10000);
  CalorieNumberInput get _kcalInput => parseCalorieNumber(_kcal.text, integer: true, required: true, max: 20000);
  CalorieNumberInput _grams(TextEditingController c) => parseCalorieNumber(c.text, max: 2000);

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      _quantityInput.isValid &&
      (_quantityInput.value ?? 0) > 0 &&
      _kcalInput.isValid &&
      [_protein, _carbs, _fat].every((c) => _grams(c).isValid || _grams(c).isEmpty);

  /// The entry as the fields describe it; null while one is invalid.
  FoodLogEntry? get _edited {
    final o = _original;
    if (o == null || !_valid) return null;
    return FoodLogEntry(
      id: o.id,
      userId: o.userId,
      loggedDate: parseCalorieDayKey(_dateKey),
      mealType: _meal,
      origin: o.origin,
      sourceRecipeId: o.sourceRecipeId,
      foodName: _name.text.trim(),
      brand: o.brand,
      quantity: _quantityInput.value!,
      unit: o.unit,
      calories: _kcalInput.value!.round(),
      proteinG: _grams(_protein).value,
      carbsG: _grams(_carbs).value,
      fatG: _grams(_fat).value,
      barcode: o.barcode,
      photoUrl: o.photoUrl,
      photoPath: o.photoPath,
      estimated: o.estimated,
      confidence: o.confidence,
      healthUuid: o.healthUuid,
      loggedTime: _time,
      createdAt: o.createdAt,
      updatedAt: o.updatedAt,
    );
  }

  bool _differs(FoodLogEntry a, FoodLogEntry b) =>
      a.foodName != b.foodName ||
      a.quantity != b.quantity ||
      a.calories != b.calories ||
      a.proteinG != b.proteinG ||
      a.carbsG != b.carbsG ||
      a.fatG != b.fatG ||
      a.mealType != b.mealType ||
      a.dateKey != b.dateKey ||
      a.loggedTime != b.loggedTime;

  bool _saving = false;
  bool _saveFailed = false;

  /// Something differs from the entry as it was opened.
  bool get _changed {
    final o = _original;
    final edited = _edited;
    return o != null && edited != null && _differs(o, edited);
  }

  /// Saves on the way out; the toast in the diary offers "Widerrufen". A
  /// failed save keeps the screen open with "Nicht gespeichert." and retry.
  Future<bool> _saveBeforeLeave() async {
    final o = _original;
    final edited = _edited;
    if (_gone || o == null || edited == null || !_differs(o, edited)) return true;
    if (_saving) return false;
    setState(() => _saving = true);
    final diary = ref.read(calorieDiaryProvider);
    final message = context.tr('cal_entry_changed');
    final undo = context.tr('common_undo');
    try {
      await diary.updateFood(o, edited);
    } catch (e) {
      debugPrint('❌ [CalorieEntry] Saving failed: ${calorieErrorKind(e)}');
      if (mounted) {
        unawaited(AvoHaptics.error());
        setState(() {
          _saving = false;
          _saveFailed = true;
        });
      }
      return false;
    }
    _closing = true;
    if (mounted) {
      AvoToast.show(context, message: message, actionLabel: undo, onAction: () => diary.updateFood(edited, o));
    }
    return true;
  }

  Future<void> _retrySave() async {
    if (await _saveBeforeLeave() && mounted) CalorieFlowScaffold.leave(context);
  }

  /// The amount the numbers last matched; typed or stepped amounts scale
  /// the numbers from here.
  double? _lastQuantity;

  void _scaleTo(double next) {
    final previous = _lastQuantity;
    if (previous == null || previous <= 0 || next <= 0 || next == previous) return;
    _lastQuantity = next;
    final f = next / previous;
    final kcal = _kcalInput.value;
    if (kcal != null) _kcal.text = '${(kcal * f).round()}';
    for (final c in [_protein, _carbs, _fat]) {
      final v = _grams(c).value;
      if (v != null) c.text = context.amount(_round1(v * f));
    }
  }

  Future<void> _delete() async {
    final o = _original;
    if (o == null) return;
    _gone = true;
    final diary = ref.read(calorieDiaryProvider);
    final message = context.tr('cal_deleted', params: {'name': o.foodName});
    final undo = context.tr('common_undo');
    try {
      await diary.deleteFood(o);
    } catch (e) {
      debugPrint('❌ [CalorieEntry] Deleting failed: ${calorieErrorKind(e)}');
      _gone = false;
      if (mounted) showCalorieWriteFailed(context);
      return;
    }
    if (!mounted) return;
    AvoToast.show(context, message: message, actionLabel: undo, onAction: () => diary.restoreFood(o));
    CalorieFlowScaffold.leave(context);
  }

  void _openMore(BuildContext anchor) {
    final o = _original;
    if (o == null) return;
    final ownable = ref.read(calorieSchemaV2Provider) && UserFood.fromEntry(o, id: '') != null;
    showAvoMenu(anchor, items: [
      AvoMenuItem(
        label: context.tr('cal_menu_again'),
        onSelected: () => logFoodAgain(context, ref, _edited ?? o, dateKey: null, meal: _meal),
      ),
      if (ownable)
        AvoMenuItem(
          label: context.tr('cal_save_as_own'),
          onSelected: () async {
            final own = UserFood.fromEntry(_edited ?? o, id: '');
            if (own == null) return;
            await ref.read(userFoodsProvider.notifier).save(own);
            if (mounted) AvoToast.show(context, message: context.tr('cal_saved_as_own'));
          },
        ),
    ]);
  }

  String _source(BuildContext context, FoodLogEntry e) {
    switch (e.origin) {
      case FoodEntryOrigin.photo:
        final time = e.loggedTime;
        final date = context.shortDate(e.loggedDate);
        return time == null
            ? context.tr('cal_src_photo_day', params: {'date': date})
            : context.tr('cal_src_photo', params: {
                'date': date,
                'time': context.clockTime(DateTime(2000, 1, 1, time.hour, time.minute)),
              });
      case FoodEntryOrigin.barcode:
        final code = e.barcode;
        return code == null
            ? context.tr('cal_src_search')
            : context.tr('cal_src_barcode', params: {'code': formatGtin(code)});
      case FoodEntryOrigin.search:
        return context.tr('cal_src_search');
      case FoodEntryOrigin.recipe:
        return context.tr('cal_src_recipe', params: {
          'recipe': e.foodName,
          'servings': context.entryAmount(e) ?? context.tr('cal_servings_one', params: {'n': '1'}),
        });
      case FoodEntryOrigin.manual:
      case FoodEntryOrigin.manualEstimated:
        return context.tr('cal_src_manual');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final live = ref.watch(calorieEntryProvider((dateKey: widget.dateKey, id: widget.entryId)));
    final dayKnown = ref.watch(calorieDayProvider(widget.dateKey)).day != null;
    final o = _original;
    if (o == null && live != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _original == null) setState(() => _fill(live));
      });
    }
    // Deleted here or on another device: close without a word.
    if (o != null && live == null && dayKnown && !_gone && !_closing) {
      _gone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) CalorieFlowScaffold.leave(context);
      });
    }
    final today = ref.watch(calorieTodayKeyProvider);

    final trailing = Builder(
      builder: (anchor) => GlassIconButton(
        icon: const AvoIcon(AvoIcons.more),
        semanticLabel: context.tr('cal_more_a11y'),
        onPressed: o == null ? null : () => _openMore(anchor),
      ),
    );

    if (o == null) {
      return CalorieFlowScaffold(
        leading: CalorieFlowLeading.back,
        title: const SizedBox.shrink(),
        children: const [],
      );
    }

    final estimatedNote = o.estimated
        ? context.tr(_nutrientsEdited ? 'cal_estimated_adjusted' : 'cal_estimated_suffix')
        : null;
    String? err(TextEditingController c, CalorieNumberInput input) =>
        c.text.trim().isNotEmpty && !input.isValid ? context.tr('cal_number_invalid') : null;
    final grams = o.unit?.toLowerCase() == 'g' || o.unit?.toLowerCase() == 'ml';
    final quantity = _quantityInput.value ?? 0;
    final photoPath = MealPhotoStorageService.pathOf(o.photoPath ?? o.photoUrl);
    final recipeId = o.sourceRecipeId;

    return CalorieFlowScaffold(
      leading: CalorieFlowLeading.back,
      title: const SizedBox.shrink(),
      trailing: trailing,
      canLeave: _valid,
      beforeLeave: _changed ? _saveBeforeLeave : null,
      children: [
        if (_saveFailed) ...[
          StatusRow(
            kind: StatusKind.failed,
            text: context.tr('cal_not_saved_status'),
            actionLabel: context.tr('retry'),
            onAction: _retrySave,
          ),
          const SizedBox(height: AvoSpacing.s),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(AvoSpacing.screen, 0, AvoSpacing.screen, AvoSpacing.l),
          child: Semantics(
            header: true,
            child: Text(
              _name.text.trim().isEmpty ? o.foodName : _name.text.trim(),
              style: context.text(AvoTextStyle.largeTitle, weight: FontWeight.w700),
            ),
          ),
        ),
        if (photoPath != null) _EntryPhoto(path: photoPath),
        InsetSection(children: [
          CalorieFieldRow(
            label: context.tr('cal_name'),
            maxLength: kCalorieNameMaxLength,
            controller: _name,
            number: false,
            error: _name.text.trim().isEmpty ? context.tr('cal_name_required') : null,
            onChanged: (_) => setState(() {}),
          ),
        ]),
        InsetSection(
          header: context.tr('cal_sec_amount'),
          children: [
            _AmountRow(
              field: CalorieFieldRow(
                label: context.tr('cal_sec_amount'),
                controller: _quantity,
                unit: context.entryUnitLabel(o),
                error: err(_quantity, _quantityInput),
                // Typed like stepped: kcal and macros follow.
                onChanged: (_) => setState(() {
                  final v = _quantityInput.value;
                  if (v != null && v > 0) _scaleTo(v);
                }),
              ),
              stepper: CalorieStepper(
                value: quantity,
                step: grams ? 10 : 0.5,
                min: grams ? 10 : 0.5,
                max: 10000,
                semanticLabel: context.tr('cal_sec_amount'),
                spokenValue: (v) => grams
                    ? context.tr(o.unit?.toLowerCase() == 'ml' ? 'cal_ml_spoken' : 'cal_grams_spoken',
                        params: {'n': context.amount(v)})
                    : [context.amount(v), ?context.entryUnitLabel(o)].join(' '),
                onChanged: (v) => setState(() {
                  _scaleTo(v);
                  _quantity.text = context.amount(v);
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: AvoSpacing.section),
        InsetSection(children: [
          CalorieMealRow(meal: _meal, onChanged: (m) => setState(() => _meal = m)),
          CalorieDateRow(dateKey: _dateKey, todayKey: today, onChanged: (k) => setState(() => _dateKey = k)),
          NavRow(
            title: context.tr('cal_time'),
            value: _time == null ? '–' : context.clockTime(DateTime(2000, 1, 1, _time!.hour, _time!.minute)),
            onTap: () => setState(() => _timeOpen = !_timeOpen),
          ),
          if (_timeOpen)
            SizedBox(
              height: _kWheelHeight,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime: DateTime(2000, 1, 1, _time?.hour ?? 12, _time?.minute ?? 0),
                use24hFormat: MediaQuery.alwaysUse24HourFormatOf(context) || Localizations.localeOf(context).languageCode == 'de',
                onDateTimeChanged: (t) => setState(() => _time = FoodLogTime(t.hour, t.minute)),
              ),
            ),
        ]),
        InsetSection(
          header: context.tr('cal_sec_nutrients'),
          children: [
            CalorieFieldRow(
              label: context.tr('cal_calories'),
              controller: _kcal,
              unit: context.tr('cal_unit_kcal'),
              spokenUnit: context.tr('cal_kcal_spoken'),
              integer: true,
              error: _kcal.text.trim().isEmpty ? context.tr('cal_number_invalid') : err(_kcal, _kcalInput),
              onChanged: (_) => setState(() => _nutrientsEdited = true),
            ),
            for (final (c, key) in [(_protein, 'cal_macro_protein'), (_carbs, 'cal_macro_carbs_long'), (_fat, 'cal_macro_fat')])
              CalorieFieldRow(
                label: context.tr(key),
                controller: c,
                unit: 'g',
                spokenUnit: context.tr('cal_grams'),
                error: err(c, _grams(c)),
                onChanged: (_) => setState(() => _nutrientsEdited = true),
              ),
            if (o.confidence case final confidence? when o.estimated)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.l, vertical: AvoSpacing.m),
                child: ConfidenceRow(confidence: confidence, suffix: estimatedNote),
              )
            else if (estimatedNote != null)
              CalorieGroupNote(text: estimatedNote, color: colors.secondaryLabel),
          ],
        ),
        _SourceLine(
          text: _source(context, o),
          onTap: o.origin == FoodEntryOrigin.recipe && recipeId != null
              ? () => context.push('${RoutePaths.recipes}/$recipeId')
              : null,
        ),
        const SizedBox(height: AvoSpacing.section),
        InsetSection(children: [
          MergeSemantics(
            child: Semantics(
              hint: context.tr('cal_delete_hint'),
              child: DestructiveRow(title: context.tr('cal_delete_entry'), onTap: _delete),
            ),
          ),
        ]),
      ],
    );
  }
}

/// The amount field with the stepper beside it, below it from xxL on.
class _AmountRow extends StatelessWidget {
  const _AmountRow({required this.field, required this.stepper});

  final Widget field;
  final Widget stepper;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) => _layout(context, stacked: calorieLabelsAbove(context) || box.maxWidth < _kStackBelow));
  }

  Widget _layout(BuildContext context, {required bool stacked}) {
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          field,
          Padding(padding: const EdgeInsets.fromLTRB(AvoSpacing.l, 0, AvoSpacing.l, AvoSpacing.m), child: stepper),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: field),
        Padding(padding: const EdgeInsets.only(right: AvoSpacing.l), child: stepper),
      ],
    );
  }
}

/// The entry's photo from the private bucket (signed URL, cached by path).
class _EntryPhoto extends ConsumerWidget {
  const _EntryPhoto({required this.path});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final url = ref.watch(mealPhotoUrlProvider(path)).valueOrNull;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AvoSpacing.screen, 0, AvoSpacing.screen, AvoSpacing.l),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AvoRadii.card),
        child: AspectRatio(
          aspectRatio: _kPhotoAspect,
          child: url == null
              ? ColoredBox(color: colors.fill)
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  semanticLabel: context.tr('cal_photo_a11y'),
                  errorBuilder: (context, _, __) => ColoredBox(color: colors.fill),
                ),
        ),
      ),
    );
  }
}

/// The source footnote ("Open Food Facts, Strichcode 4 056489 123457"); a
/// link to the recipe for recipe entries.
class _SourceLine extends StatelessWidget {
  const _SourceLine({required this.text, this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tap = onTap;
    final line = Padding(
      padding: const EdgeInsets.fromLTRB(AvoSpacing.screen + AvoSpacing.l, AvoSpacing.s, AvoSpacing.screen + AvoSpacing.l, 0),
      child: Text(
        text,
        style: context.text(AvoTextStyle.footnote, color: tap == null ? colors.secondaryLabel : colors.tint),
      ),
    );
    if (tap == null) return line;
    return Semantics(
      link: true,
      label: text,
      onTap: tap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tap,
        child: ConstrainedBox(constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget), child: line),
      ),
    );
  }
}

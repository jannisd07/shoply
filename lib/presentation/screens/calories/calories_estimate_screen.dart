import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/constants/app_brand.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/services/allergen_matcher.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/data/services/meal_photo_analysis_service.dart';
import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_add_parts.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_colors.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_entry_actions.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_estimate_parts.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_fields.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_flow_scaffold.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_format.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_meal_title.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_nutrition_row.dart';
import 'package:shoply/presentation/state/calorie_entry_provider.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:shoply/routes/route_paths.dart';

// D2 X-Essen: photo 300 high, radius 26; result card padding 14/16; the
// pill 12 in from the photo's corner; Health heart 20.
const double _kPhotoHeight = 300; // D2
const double _kCardVertical = 14; // D2
const double _kPillInset = 12; // D2
const double _kHeart = 20; // D2
const double _kProblemGlyph = 48; // D2 questionmark.circle

/// What went wrong, as the screen shows it.
enum _Problem { noFood, unreadable, refused, failed, offline, quota, aiOff }

_Problem _problemOf(String code) => switch (code) {
      'no_food_detected' => _Problem.noFood,
      'unreadable_image' => _Problem.unreadable,
      'refused' => _Problem.refused,
      'quota_exceeded' => _Problem.quota,
      'ai_disabled' => _Problem.aiOff,
      'network_error' => _Problem.offline,
      _ => _Problem.failed,
    };

/// S5 "Schätzung prüfen" (`/calories/add/estimate`, the photo as `extra`,
/// D2 X-Essen): the photo with the pill, the result card ("ca. 650 kcal",
/// the confidence word, macros), allergy hints, the parts with their grams,
/// "Foto im Tagebuch behalten", then "Eintragen". Nothing is saved before
/// the person checks it; the entry stays "geschätzt" with its level.
class CaloriesEstimateScreen extends ConsumerStatefulWidget {
  const CaloriesEstimateScreen({super.key, required this.photo, this.meal, this.dateKey});

  /// JPEG, only in memory.
  final Uint8List photo;
  final MealType? meal;
  final String? dateKey;

  @override
  ConsumerState<CaloriesEstimateScreen> createState() => _CaloriesEstimateScreenState();
}

class _CaloriesEstimateScreenState extends ConsumerState<CaloriesEstimateScreen> {
  late MealType _meal = widget.meal ?? mealForTime(ref.read(calorieClockProvider)());

  MealPhotoEstimate? _estimate;
  _Problem? _problem;
  bool _running = false;
  int _run = 0;

  String _name = '';
  bool _editingName = false;
  final _nameController = TextEditingController();
  List<EstimatePart> _parts = const [];
  int _nextPartId = 0;
  int? _expanded;
  bool _adjusted = false;
  bool _keepPhoto = true;
  bool _logging = false;
  bool _warned = false;

  @override
  void initState() {
    super.initState();
    unawaited(_analyze());
  }

  @override
  void dispose() {
    _run++;
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    final run = ++_run;
    setState(() {
      _running = true;
      _problem = null;
    });
    try {
      final estimate = await ref.read(mealPhotoAnalyzerProvider)(widget.photo);
      if (!mounted || run != _run) return;
      setState(() {
        _running = false;
        _estimate = estimate;
        _name = estimate.foodName;
        _nameController.text = estimate.foodName;
        _parts = [
          for (final c in estimate.components)
            EstimatePart(
              id: _nextPartId++,
              name: c.name,
              grams: c.grams,
              kcalPerGram: c.grams > 0 ? c.kcal / c.grams : 0,
            ),
        ];
      });
      _announceDone();
      _warnOnce();
    } on MealPhotoException catch (e) {
      if (!mounted || run != _run) return;
      final problem = ref.read(isOfflineProvider) ? _Problem.offline : _problemOf(e.code);
      if (problem == _Problem.quota) ref.read(caloriePhotoLimitReachedProvider.notifier).markReached();
      if (problem == _Problem.failed || problem == _Problem.offline) unawaited(AvoHaptics.error());
      setState(() {
        _running = false;
        _problem = problem;
      });
    }
  }

  // ── Numbers ──────────────────────────────────────────────────────────

  /// Total kcal: the parts when there are any (they follow their grams),
  /// else the estimate's total.
  int get _kcal {
    final e = _estimate;
    if (e == null) return 0;
    if (_parts.isEmpty) return e.components.isEmpty ? e.calories : 0;
    return _parts.fold(0, (s, p) => s + p.kcal);
  }

  /// Macros scale with the kcal (the parts carry no macros of their own).
  double? _scaled(double? v) {
    final e = _estimate;
    if (v == null || e == null || e.calories <= 0) return v;
    return v * _kcal / e.calories;
  }

  List<AllergenMatch> get _allergies {
    final e = _estimate;
    if (e == null) return const [];
    return estimateAllergyMatches(
      ref.read(calorieAllergiesProvider),
      dish: _name,
      components: _parts.map((p) => p.name),
      named: _parts.isEmpty && e.components.isNotEmpty ? const [] : e.allergens,
    );
  }

  void _announceDone() {
    final e = _estimate;
    if (e == null || !mounted) return;
    final text = context.tr('cal_estimate_done_a11y', params: {
      'name': _name,
      'kcal': context.kcal(_kcal),
      'confidence': context.confidenceWord(e.confidenceLevel),
    });
    unawaited(SemanticsService.sendAnnouncement(View.of(context), text, Directionality.of(context)));
  }

  /// The warning haptic once per estimate when an allergy matches.
  void _warnOnce() {
    if (_warned || ref.read(calorieAllergiesProvider).allergies.isEmpty) return;
    if (_allergies.isEmpty) return;
    _warned = true;
    unawaited(AvoHaptics.warning());
  }

  void _changed(VoidCallback change) {
    setState(() {
      change();
      _adjusted = true;
    });
  }

  // ── Leaving ──────────────────────────────────────────────────────────

  bool get _hasResult => _estimate != null && !_logging;

  Future<void> _log() async {
    final e = _estimate;
    if (e == null || _logging) return;
    setState(() => _logging = true);
    final now = ref.read(calorieClockProvider)();
    final entry = FoodLogEntry(
      id: '',
      userId: '',
      loggedDate: parseCalorieDayKey(widget.dateKey ?? calorieTodayKeyNow(ref)),
      mealType: _meal,
      origin: FoodEntryOrigin.photo,
      foodName: _name.trim().isEmpty ? e.foodName : _name.trim(),
      quantity: 1,
      unit: 'serving',
      calories: _kcal,
      proteinG: _scaled(e.proteinG),
      carbsG: _scaled(e.carbsG),
      fatG: _scaled(e.fatG),
      estimated: true,
      confidence: e.confidenceLevel,
      loggedTime: FoodLogTime.of(now),
      createdAt: now,
    );
    final diary = ref.read(calorieDiaryProvider);
    final saved = await logNewFood(context, ref, entry);
    if (!mounted) return;
    if (saved == null) {
      setState(() => _logging = false);
      return;
    }
    // The diary uploads and attaches the photo; it outlives this screen.
    if (_keepPhoto) unawaited(diary.attachPhoto(saved, widget.photo));
    popCalorieFlow(context);
  }

  void _newPhoto() => context.pushReplacement(Uri(
        path: '${RoutePaths.calories}/add/photo',
        queryParameters: {
          'meal': _meal.dbValue,
          if (widget.dateKey case final d?) 'date': d,
        },
      ).toString());

  void _manual() => context.pushReplacement(Uri(
        path: '${RoutePaths.calories}/add/manual',
        queryParameters: {
          'meal': _meal.dbValue,
          if (widget.dateKey case final d?) 'date': d,
          if (_name.trim().isNotEmpty) 'name': _name.trim(),
        },
      ).toString());

  // ── Building ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final today = ref.watch(calorieTodayKeyProvider);
    final dateKey = widget.dateKey;
    final e = _estimate;
    final problem = _problem;
    ref.watch(calorieAllergiesProvider);
    // Allergies that arrive after the estimate still warn once.
    ref.listen(calorieAllergiesProvider, (_, __) => _warnOnce());
    final allergies = _allergies;
    final health = ref.watch(calorieHealthWritesProvider);
    final aiOn = ref.watch(aiRemoteEnabledProvider);
    final effectiveProblem = problem ?? (!aiOn && e == null && !_running ? _Problem.aiOff : null);

    final photo = Semantics(
      image: true,
      label: context.tr('cal_photo_a11y'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AvoRadii.group),
          child: SizedBox(
            height: _kPhotoHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(widget.photo, fit: BoxFit.cover, excludeFromSemantics: true, gaplessPlayback: true),
                if (effectiveProblem == null)
                  PositionedDirectional(
                    top: _kPillInset,
                    start: _kPillInset,
                    end: _kPillInset,
                    child: Align(
                      alignment: AlignmentDirectional.topStart,
                      child: ExcludeSemantics(child: EstimatePill(estimating: _running)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    final children = <Widget>[photo, const SizedBox(height: AvoSpacing.l)];
    if (effectiveProblem != null) {
      children.addAll(_problemContent(context, effectiveProblem));
    } else {
      children.add(_resultCard(context, e));
      if (e != null) {
        if (allergies.isNotEmpty) {
          children.add(InsetSection(
            header: context.tr('cal_sec_allergy'),
            footer: context.tr('cal_allergy_note'),
            children: [
              for (final m in allergies)
                Semantics(
                  liveRegion: true,
                  child: CalorieGroupNote(
                    text: _allergyText(context, m),
                    color: colors.warning,
                    icon: AvoIcon(AvoIcons.exclamationmarkTriangleFill, color: colors.warning, size: _kHeart),
                  ),
                ),
            ],
          ));
        }
        if (_parts.isNotEmpty || e.components.isNotEmpty) {
          children.add(InsetSection(
            header: context.tr('cal_sec_components'),
            children: [
              for (final p in _parts)
                ComponentRow(
                  key: ValueKey('cal-part-row-${p.id}'),
                  part: p,
                  expanded: _expanded == p.id,
                  onToggle: () => setState(() => _expanded = _expanded == p.id ? null : p.id),
                  onGrams: (g) => _changed(() => _parts = [for (final x in _parts) x.id == p.id ? x.withGrams(g) : x]),
                  onRemove: () => _changed(() => _parts = _parts.where((x) => x.id != p.id).toList()),
                ),
              AddComponentRow(
                onAdd: (name, grams, kcal100) => _changed(() => _parts = [
                      ..._parts,
                      EstimatePart(id: _nextPartId++, name: name, grams: grams, kcalPerGram: kcal100 / 100),
                    ]),
              ),
            ],
          ));
        }
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(AvoSpacing.screen + AvoSpacing.l, AvoSpacing.s, AvoSpacing.screen + AvoSpacing.l, 0),
          child: Text(
            [context.tr('cal_estimate_note'), if (_adjusted) context.tr('cal_adjusted_by_you')].join(' '),
            style: context.text(AvoTextStyle.footnote, color: colors.secondaryLabel),
          ),
        ));
        children.add(InsetSection(
          footer: context.tr('cal_keep_photo_note'),
          children: [
            ToggleRow(
              title: context.tr('cal_keep_photo'),
              value: _keepPhoto,
              onChanged: (v) => setState(() => _keepPhoto = v),
            ),
          ],
        ));
        if (health) children.add(_HealthLine(text: context.tr('cal_health_write_line')));
      }
    }

    return CalorieFlowScaffold(
      leading: CalorieFlowLeading.back,
      title: CalorieMealTitle(
        meal: _meal,
        onMeal: (m) => setState(() => _meal = m),
        dateLine: dateKey == null || dateKey == today
            ? null
            : context.tr('cal_add_for_date', params: {'date': context.shortDate(parseCalorieDayKey(dateKey))}),
      ),
      discard: _hasResult
          ? CalorieDiscardTexts(
              title: context.tr('cal_discard_estimate_title'),
              message: context.tr('cal_discard_food_body'),
              confirm: context.tr('cal_discard'),
              cancel: context.tr('cal_keep_editing'),
            )
          : null,
      onLeave: () => _run++,
      bottom: effectiveProblem != null
          ? null
          : AppButton.primary(
              label: context.tr('cal_log_button'),
              size: AppButtonSize.large,
              expand: true,
              floating: true,
              working: _logging,
              onPressed: e != null && !_logging ? _log : null,
            ),
      children: children,
    );
  }

  String _allergyText(BuildContext context, AllergenMatch m) {
    final type = m.type;
    if (type == null) {
      return context.tr('cal_allergy_warning_free', params: {'allergen': m.allergy});
    }
    return context.tr('cal_allergy_warning', params: {
      'allergen': context.tr('cal_allergen_${type.name}'),
      'condition': context.tr('cal_condition_${type.name}'),
    });
  }

  /// The result card: name (a tap edits it in place), "ca. 650 kcal", the
  /// confidence, then protein, carbs, fat and the serving. While estimating
  /// tone blocks hold the final sizes.
  Widget _resultCard(BuildContext context, MealPhotoEstimate? e) {
    final colors = context.colors;
    final kcal = _kcal;
    final placeholder = e == null;
    final kcalText = context.tr('cal_about_kcal', params: {'kcal': context.kcal(kcal)});
    final protein = _scaled(e?.proteinG);
    final carbs = _scaled(e?.carbsG);
    final fat = _scaled(e?.fatG);
    String g(double? v) => v == null ? '–' : context.grams(v);
    final spoken = e == null
        ? context.tr('cal_estimating')
        : context.tr('cal_estimate_card_a11y', params: {
            'name': _name,
            'kcal': context.kcal(kcal),
            'confidence': context.confidenceWord(e.confidenceLevel),
            'protein': g(protein),
            'carbs': g(carbs),
            'fat': g(fat),
          });
    final ax = context.isAccessibilityText;
    final titleStyle = context.text(AvoTextStyle.title3, weight: FontWeight.w600);
    final kcalStyle = context.text(AvoTextStyle.title3, weight: FontWeight.w700, tabular: true);
    final name = _editingName
        ? CupertinoTextField(
            controller: _nameController,
            autofocus: true,
            maxLength: kCalorieNameMaxLength,
            decoration: null,
            padding: EdgeInsets.zero,
            style: titleStyle,
            textInputAction: TextInputAction.done,
            onChanged: (v) => _changed(() => _name = v),
            onSubmitted: (_) => setState(() => _editingName = false),
          )
        : Text(placeholder ? ' ' : _name, style: titleStyle);
    final kcalWidget = placeholder
        ? SizedBox(
            width: context.typography.lineHeightOf(AvoTextStyle.title3) * 4,
            height: context.typography.lineHeightOf(AvoTextStyle.title3),
            child: DecoratedBox(
              decoration: BoxDecoration(color: colors.fill, borderRadius: BorderRadius.circular(AvoSpacing.xs)),
            ),
          )
        : Text(kcalText, style: kcalStyle);

    final head = ax
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [name, kcalWidget])
        : Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [Expanded(child: name), const SizedBox(width: AvoSpacing.s), kcalWidget],
          );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
      child: DecoratedBox(
        decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(AvoRadii.group)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.l, vertical: _kCardVertical),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                container: true,
                label: spoken,
                customSemanticsActions: e == null
                    ? null
                    : {
                        CustomSemanticsAction(label: context.tr('cal_rename')): () => setState(() => _editingName = true),
                      },
                excludeSemantics: !_editingName,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: e == null ? null : () => setState(() => _editingName = true),
                  child: head,
                ),
              ),
              const SizedBox(height: AvoSpacing.xxs),
              if (e != null)
                ExcludeSemantics(child: ConfidenceRow(confidence: e.confidenceLevel))
              else
                const SizedBox(height: AvoSpacing.l),
              const SizedBox(height: AvoSpacing.m),
              Container(height: AvoSizes.hairline, color: colors.separator),
              const SizedBox(height: AvoSpacing.s + AvoSpacing.xxs),
              ExcludeSemantics(
                child: NutritionRow(
                  semanticLabel: spoken,
                  cells: [
                    NutritionCell(value: protein, unit: 'g', fractionDigits: gramDigits(protein), label: context.tr('cal_macro_protein'), placeholder: placeholder),
                    NutritionCell(value: carbs, unit: 'g', fractionDigits: gramDigits(carbs), label: context.tr('cal_macro_carbs_short'), placeholder: placeholder),
                    NutritionCell(value: fat, unit: 'g', fractionDigits: gramDigits(fat), label: context.tr('cal_macro_fat'), placeholder: placeholder),
                    NutritionCell(value: 1, label: context.tr('cal_serving'), placeholder: placeholder),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _problemContent(BuildContext context, _Problem problem) {
    final colors = context.colors;
    final offerPro = ref.watch(caloriePhotoLimitOffersProProvider);
    switch (problem) {
      case _Problem.failed:
      case _Problem.offline:
        return [
          StatusRow(
            kind: problem == _Problem.offline ? StatusKind.offline : StatusKind.sectionError,
            text: context.tr(problem == _Problem.offline ? 'cal_estimate_offline' : 'cal_estimate_error'),
            actionLabel: context.tr('retry'),
            onAction: _analyze,
          ),
          const SizedBox(height: AvoSpacing.l),
          _centredButton(AppButton.secondary(label: context.tr('cal_manual_row'), onPressed: _manual)),
        ];
      case _Problem.quota:
        return [
          _problemText(
            context,
            !offerPro
                ? context.tr('cal_photo_limit_pro')
                : context.tr('cal_photo_limit_free', params: {'pro': AppBrand.proName, 'n': '${ref.watch(caloriePhotosPerDayProProvider)}'}),
          ),
          _centredButton(AppButton.primary(label: context.tr('cal_manual_row'), onPressed: _manual)),
          if (offerPro) _centredButton(const CalorieSeeProButton()),
        ];
      case _Problem.noFood:
      case _Problem.unreadable:
      case _Problem.refused:
      case _Problem.aiOff:
        final key = switch (problem) {
          _Problem.noFood => 'cal_no_food',
          _Problem.unreadable => 'cal_photo_unreadable',
          _Problem.refused => 'cal_photo_refused',
          _ => 'cal_ai_off',
        };
        final newPhoto = problem == _Problem.noFood || problem == _Problem.unreadable;
        return [
          ExcludeSemantics(
            child: AvoIcon(AvoIcons.questionmarkCircle, size: _kProblemGlyph, color: colors.secondaryLabel),
          ),
          const SizedBox(height: AvoSpacing.s),
          _problemText(context, context.tr(key)),
          if (newPhoto) _centredButton(AppButton.primary(label: context.tr('cal_new_photo'), onPressed: _newPhoto)),
          _centredButton(
            newPhoto
                ? AppButton.plain(label: context.tr('cal_manual_row'), onPressed: _manual)
                : AppButton.primary(label: context.tr('cal_manual_row'), onPressed: _manual),
          ),
        ];
    }
  }

  Widget _problemText(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(AvoSpacing.xxxl, 0, AvoSpacing.xxxl, AvoSpacing.l),
        child: Semantics(
          liveRegion: true,
          child: Text(text, textAlign: TextAlign.center, style: context.text(AvoTextStyle.body)),
        ),
      );

  Widget _centredButton(Widget button) => Padding(
        padding: const EdgeInsets.only(bottom: AvoSpacing.s),
        child: Center(child: button),
      );
}

/// "Wird auch in Apple Health gespeichert" with the heart (only with Health
/// connected and writing allowed).
class _HealthLine extends StatelessWidget {
  const _HealthLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AvoSpacing.screen, AvoSpacing.l, AvoSpacing.screen, 0),
      child: Row(
        children: [
          ExcludeSemantics(
            child: AvoIcon(AvoIcons.heart, filled: true, size: _kHeart, color: CalorieColors.of(context).health),
          ),
          const SizedBox(width: AvoSpacing.s + AvoSpacing.xxs),
          Expanded(child: Text(text, style: context.text(AvoTextStyle.subhead, color: colors.secondaryLabel))),
        ],
      ),
    );
  }
}

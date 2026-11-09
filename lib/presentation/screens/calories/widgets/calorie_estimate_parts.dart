import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_fields.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_format.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_stepper.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_figure.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/glass_surface.dart';

// D2 X-Essen pill on the photo: 28 high, radius 14, 13/18 semibold, sparkle
// 14 in green; the mini Avo 22 × 27 while estimating.
const double _kPillHeight = 28; // D2
const double _kPillSparkle = 14; // D2
const double _kMiniAvo = 27; // D2 (22 × 27)

/// The pill breathes while the estimate runs (the one looping animation of
/// the area, `kalorien.md` §3.4); Reduce Motion keeps it still.
const Duration _kPulse = Duration(milliseconds: 1200); // D2
const double _kPulseMin = 0.55;

/// D2 component rows are at least 60 high.
const double _kRowMinHeight = 60; // D2
const double _kRowVertical = 9; // D2
const double _kDeleteThreshold = 0.6;
const double _kPlusGlyph = 17; // D2

/// One part of the photographed meal, as the estimate saw it and the
/// person corrected it. kcal follow the grams at the estimate's density.
@immutable
class EstimatePart {
  const EstimatePart({required this.id, required this.name, required this.grams, required this.kcalPerGram});

  final int id;
  final String name;
  final int grams;
  final double kcalPerGram;

  int get kcal => (grams * kcalPerGram).round();

  EstimatePart withGrams(int g) => EstimatePart(id: id, name: name, grams: g, kcalPerGram: kcalPerGram);
}

/// "Wird geschätzt …" with the mini Avo (pulsing gently), then "Geschätzt"
/// with the green sparkle: glass on the photo (`ContentGlass`). Part of the
/// photo for VoiceOver; from AX3 on without the figure.
class EstimatePill extends StatefulWidget {
  const EstimatePill({super.key, required this.estimating});

  final bool estimating;

  @override
  State<EstimatePill> createState() => _EstimatePillState();
}

class _EstimatePillState extends State<EstimatePill> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: _kPulse);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(EstimatePill oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.estimating && !context.reduceMotion) {
      if (!_pulse.isAnimating) unawaited(_pulse.repeat(reverse: true));
    } else {
      _pulse
        ..stop()
        ..value = 1;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final estimating = widget.estimating;
    final withFigure = estimating && context.typography.category.index < ContentSizeCategory.ax3.index;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (withFigure)
          const AvoFigure(pose: AvoPose.thinking, size: _kMiniAvo)
        else if (!estimating)
          AvoIcon(AvoIcons.sparkle, size: _kPillSparkle, color: colors.tint, filled: true),
        if (withFigure || !estimating) const SizedBox(width: AvoSpacing.xs),
        Flexible(
          child: Text(
            context.tr(estimating ? 'cal_estimating' : 'cal_estimated'),
            style: context.text(AvoTextStyle.footnote, weight: FontWeight.w600),
          ),
        ),
      ],
    );
    return FadeTransition(
      opacity: Tween<double>(begin: _kPulseMin, end: 1).animate(_pulse),
      child: ContentGlass(
        radius: _kPillHeight / 2,
        padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.s + AvoSpacing.xxs),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _kPillHeight),
          child: content,
        ),
      ),
    );
  }
}

/// A part of the estimate (`ComponentRow`): name, "ca. 220 g", kcal on the
/// right (under the grams from AX1 on). A tap opens a gram field and a
/// stepper (±10 g) in place; swipe left or the VoiceOver action removes it.
class ComponentRow extends StatefulWidget {
  const ComponentRow({
    super.key,
    required this.part,
    required this.expanded,
    required this.onToggle,
    required this.onGrams,
    required this.onRemove,
  });

  final EstimatePart part;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<int> onGrams;
  final VoidCallback onRemove;

  @override
  State<ComponentRow> createState() => _ComponentRowState();
}

class _ComponentRowState extends State<ComponentRow> {
  late final _grams = TextEditingController();
  bool _invalid = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncText();
  }

  @override
  void didUpdateWidget(ComponentRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.part.grams != widget.part.grams) _syncText();
  }

  void _syncText() {
    final text = '${widget.part.grams}';
    if (parseCalorieNumber(_grams.text).value?.round() != widget.part.grams) _grams.text = text;
  }

  @override
  void dispose() {
    _grams.dispose();
    super.dispose();
  }

  void _typed(String text) {
    final input = parseCalorieNumber(text, integer: true, required: true, max: 5000);
    setState(() => _invalid = !input.isValid);
    if (input.isValid) widget.onGrams(input.value!.round());
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final part = widget.part;
    final ax = context.isAccessibilityText;
    final grams = context.tr('cal_about_grams', params: {'g': context.amount(part.grams)});
    final kcal = context.tr('cal_meal_sum', params: {'kcal': context.kcal(part.kcal)});
    final spoken = context.tr(
      'cal_component_a11y',
      params: {'name': part.name, 'g': context.amount(part.grams), 'kcal': context.kcal(part.kcal)},
    );

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(part.name, style: context.text(AvoTextStyle.body)),
        Text(grams, style: context.text(AvoTextStyle.subhead, color: colors.secondaryLabel, tabular: true)),
        if (ax) Text(kcal, style: context.text(AvoTextStyle.subhead, tabular: true)),
      ],
    );
    final header = Semantics(
      container: true,
      button: true,
      label: spoken,
      hint: context.tr('cal_component_change'),
      onTap: widget.onToggle,
      customSemanticsActions: {
        CustomSemanticsAction(label: context.tr('cal_component_change')): widget.onToggle,
        CustomSemanticsAction(label: context.tr('cal_component_remove')): widget.onRemove,
      },
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onToggle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _kRowMinHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.l, vertical: _kRowVertical),
            child: Row(
              children: [
                Expanded(child: text),
                if (!ax) ...[
                  const SizedBox(width: AvoSpacing.m),
                  Text(kcal, style: context.text(AvoTextStyle.body, tabular: true)),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    final editor = !widget.expanded
        ? null
        : Padding(
            padding: const EdgeInsets.fromLTRB(AvoSpacing.l, 0, AvoSpacing.l, AvoSpacing.m),
            child: Wrap(
              spacing: AvoSpacing.m,
              runSpacing: AvoSpacing.s,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: AvoSizes.hitTarget * 2, maxWidth: AvoSizes.hitTarget * 3),
                  child: MergeSemantics(
                    child: Semantics(
                      label: context.tr('cal_grams'),
                      hint: _invalid ? context.tr('cal_number_invalid') : null,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
                        child: CupertinoTextField(
                          controller: _grams,
                          keyboardType: TextInputType.number,
                          inputFormatters: calorieNumberFormatters,
                          style: context.text(AvoTextStyle.body, tabular: true),
                          padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.m, vertical: AvoSpacing.s),
                          decoration: BoxDecoration(
                            color: colors.fill,
                            borderRadius: BorderRadius.circular(AvoRadii.imageSmall),
                          ),
                          suffix: Padding(
                            padding: const EdgeInsetsDirectional.only(end: AvoSpacing.m),
                            child: ExcludeSemantics(
                              child: Text('g', style: context.text(AvoTextStyle.body, color: colors.secondaryLabel)),
                            ),
                          ),
                          onChanged: _typed,
                        ),
                      ),
                    ),
                  ),
                ),
                CalorieStepper(
                  value: part.grams.toDouble(),
                  step: 10,
                  min: 0,
                  max: 5000,
                  semanticLabel: part.name,
                  spokenValue: (v) => context.tr('cal_grams_spoken', params: {'n': context.amount(v)}),
                  onChanged: (v) => widget.onGrams(v.round()),
                ),
                if (_invalid)
                  Text(
                    context.tr('cal_number_invalid'),
                    style: context.text(AvoTextStyle.footnote, color: colors.destructive),
                  ),
              ],
            ),
          );

    return Dismissible(
      key: ValueKey('cal-part-${part.id}'),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: _kDeleteThreshold},
      onDismissed: (_) => widget.onRemove(),
      background: ColoredBox(
        color: colors.destructive,
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: AvoSpacing.xl),
            child: Text(
              context.tr('cal_component_remove'),
              style: context.text(AvoTextStyle.body, color: colors.onTint),
            ),
          ),
        ),
      ),
      child: ColoredBox(
        color: colors.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [header, ?editor],
        ),
      ),
    );
  }
}

/// "Bestandteil hinzufügen": a green row that opens name, grams and kcal per
/// 100 g in place, then "Hinzufügen".
class AddComponentRow extends StatefulWidget {
  const AddComponentRow({super.key, required this.onAdd});

  /// Name, grams, kcal per 100 g.
  final void Function(String name, int grams, int kcal100) onAdd;

  @override
  State<AddComponentRow> createState() => _AddComponentRowState();
}

class _AddComponentRowState extends State<AddComponentRow> {
  bool _open = false;
  final _name = TextEditingController();
  final _grams = TextEditingController();
  final _kcal = TextEditingController();

  @override
  void dispose() {
    for (final c in [_name, _grams, _kcal]) {
      c.dispose();
    }
    super.dispose();
  }

  CalorieNumberInput get _gramsInput => parseCalorieNumber(_grams.text, integer: true, required: true, max: 5000);
  CalorieNumberInput get _kcalInput => parseCalorieNumber(_kcal.text, integer: true, required: true, max: 900);

  bool get _valid => _name.text.trim().isNotEmpty && _gramsInput.isValid && _kcalInput.isValid;

  void _add() {
    if (!_valid) return;
    widget.onAdd(_name.text.trim(), _gramsInput.value!.round(), _kcalInput.value!.round());
    setState(() {
      _open = false;
      _name.clear();
      _grams.clear();
      _kcal.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (!_open) {
      return Semantics(
        container: true,
        button: true,
        label: context.tr('cal_component_add'),
        onTap: () => setState(() => _open = true),
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _open = true),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget + AvoSpacing.s),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.l, vertical: AvoSpacing.s),
              child: Row(
                children: [
                  AvoIcon(AvoIcons.plus, size: _kPlusGlyph, color: colors.tint),
                  const SizedBox(width: AvoSpacing.m),
                  Expanded(
                    child: Text(
                      context.tr('cal_component_add'),
                      style: context.text(AvoTextStyle.body, color: colors.tint),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    String? err(TextEditingController c, CalorieNumberInput i) =>
        c.text.trim().isNotEmpty && !i.isValid ? context.tr('cal_number_invalid') : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        CalorieFieldRow(
          label: context.tr('cal_name'),
          maxLength: kCalorieNameMaxLength,
          controller: _name,
          number: false,
          autofocus: true,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() {}),
        ),
        CalorieFieldRow(
          label: context.tr('cal_grams'),
          controller: _grams,
          unit: 'g',
          integer: true,
          error: err(_grams, _gramsInput),
          onChanged: (_) => setState(() {}),
        ),
        CalorieFieldRow(
          label: context.tr('cal_kcal_per_100g_field'),
          controller: _kcal,
          unit: context.tr('cal_unit_kcal'),
          spokenUnit: context.tr('cal_kcal_spoken'),
          integer: true,
          error: err(_kcal, _kcalInput),
          onChanged: (_) => setState(() {}),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.s),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppButton.plain(label: context.tr('cal_add'), onPressed: _valid ? _add : null),
          ),
        ),
      ],
    );
  }
}

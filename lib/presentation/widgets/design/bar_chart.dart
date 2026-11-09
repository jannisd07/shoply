import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';

// D2-FuerDich "Ausgaben im Vergleich": columns 48 wide, the value 12/16 sits
// 4 above its bar, bars radius 10, the month 13/18 6 below; the column is
// 128 high, so the tallest bar is 128 − 16 − 4 − 6 − 18 = 84.
const double _kBarWidth = 48; // D2
const double _kBarRadius = 10; // D2
const double _kValueGap = AvoSpacing.xs; // D2
const double _kLabelGap = 6; // D2
const double _kMaxBarHeight = 84; // D2

/// On narrow screens bars get thinner, the gaps stay at least this wide.
const double _kMinBarGap = AvoSpacing.s;

// Goal line: dashed in secondaryLabel (Konzept 00 §12.16; D2 has none).
const double _kGoalStroke = 1;
const double _kGoalDash = 4;
const double _kGoalGap = 3;

// D2-FuerDich `.mrow` (macro rows): 13/18 text, a 6 pt track with radius 3
// 6 below it, rows 11 apart.
const double _kTrackHeight = 6; // D2
const double _kTrackRadius = 3; // D2
const double _kTrackGap = 6; // D2
const double _kRowGap = 11; // D2

/// Space between a row's label and its value when both fit on one line.
const double _kRowTextGap = AvoSpacing.s;

/// One bar of an [AvoBarChart].
@immutable
class AvoBarEntry {
  /// Describes one bar.
  const AvoBarEntry({
    required this.label,
    this.value,
    this.semanticLabel,
    this.semanticValue,
    this.secondaryLabel,
  });

  /// Axis label below the bar ("Jun", "Mo").
  final String label;

  /// Optional second axis line below [label] ("bisher" under the running
  /// month), 11/13 in secondaryLabel. Spoken after [label] unless
  /// [semanticLabel] is given.
  final String? secondaryLabel;

  /// The value; null means no data (an unlogged day): no bar, the value
  /// shows as [AvoBarChart.missingText]. Zero is a real zero.
  final double? value;

  /// Spoken name of the bar ("Juni" for "Jun"); defaults to [label].
  final String? semanticLabel;

  /// Spoken value; defaults to the formatted value or
  /// [AvoBarChart.missingText]. Pass one for missing values ("nicht
  /// erfasst").
  final String? semanticValue;

  @override
  bool operator ==(Object other) =>
      other is AvoBarEntry &&
      other.label == label &&
      other.value == value &&
      other.semanticLabel == semanticLabel &&
      other.semanticValue == semanticValue &&
      other.secondaryLabel == secondaryLabel;

  @override
  int get hashCode =>
      Object.hash(label, value, semanticLabel, semanticValue, secondaryLabel);

  /// What VoiceOver says for the bar's name.
  String get spokenLabel {
    final second = secondaryLabel;
    return semanticLabel ?? (second == null ? label : '$label $second');
  }
}

/// Simple vertical bars, one question and one series (Konzept 00 §12.16,
/// optics D2-FuerDich "Ausgaben im Vergleich"): six months of spending,
/// seven days of calories.
///
/// The tallest value (or [goal]) fills [maxBarHeight]. Each value sits just
/// above its bar, the label below (and an optional second line,
/// [AvoBarEntry.secondaryLabel]). The [highlightIndex] bar ("now") is
/// [AvoColors.chartHighlight] with a semibold tinted value and a semibold
/// label; the others are [AvoColors.chartBar]. With [tintAllBars] every bar
/// is highlighted and only the label weight marks the highlight (Konzept:
/// "today" by the bold axis label, not by a second colour). An optional
/// dashed [goal] line crosses the chart.
///
/// With [onSelected] the chart is a picker (A-V4): tapping a bar or dragging
/// across the bars selects the column under the finger, with a selection
/// haptic per new column; [selectedIndex] is then the highlighted bar.
/// Entries without a value cannot be picked. VoiceOver gets one adjustable
/// element (swipe up and down), never a slider.
///
/// Bars grow from zero on the [AvoMotion.digits] spring when the chart
/// appears and follow value changes from where they are; Reduce Motion
/// shows them at once. Values are shown above all bars or above none
/// (A-V4): when one value does not fit its column at full size (long
/// amounts, narrow screens, larger text) all of them are left out, their
/// line stays empty and VoiceOver still reads every value. Axis labels that
/// do not fit shrink rather than wrap. From AX1 on the chart turns into a
/// list (label and value per row with a small horizontal bar), because axis
/// labels no longer fit.
///
/// VoiceOver: one element reads [semanticSummary] ("Ausgaben pro Monat,
/// November bisher 183 €, 12 % weniger als im Oktober"), then every bar is
/// its own element ("Juni, 212 €"). As a picker it is one adjustable
/// element: the summary, the selected bar as value. Needs a bounded width.
class AvoBarChart extends StatefulWidget {
  /// Creates a bar chart.
  const AvoBarChart({
    super.key,
    required this.entries,
    required this.formatValue,
    required this.semanticSummary,
    this.highlightIndex,
    this.tintAllBars = false,
    this.goal,
    this.showValues = true,
    this.maxBarHeight = _kMaxBarHeight,
    this.missingText = '–',
    this.emptyText,
    this.selectedIndex,
    this.onSelected,
  });

  /// The bars, leading to trailing (oldest first).
  final List<AvoBarEntry> entries;

  /// Turns a value into its visible text ("212 €", "1.910").
  final String Function(double value) formatValue;

  /// The chart as one sentence for VoiceOver.
  final String semanticSummary;

  /// The bar to emphasise (current month, today); null for none.
  /// [selectedIndex] wins when both are given.
  final int? highlightIndex;

  /// The picked bar while the chart is a picker ([onSelected]); it is
  /// highlighted like [highlightIndex].
  final int? selectedIndex;

  /// Makes the chart a picker: called with the index of the bar tapped or
  /// dragged over (only bars with a value, only on a change). The parent
  /// passes it back as [selectedIndex].
  final ValueChanged<int>? onSelected;

  /// Tint every bar; the highlight is then shown by the label weight only.
  final bool tintAllBars;

  /// Draws a dashed goal line at this value (calorie goal). It runs behind
  /// bars and values; charts with a goal usually set [showValues] to false.
  final double? goal;

  /// Shows each value above its bar (D2), as long as every value fits its
  /// column; otherwise none is shown. Off for dense charts.
  final bool showValues;

  /// Height of the tallest bar in points (D2 84; Konzept calories week 120).
  final double maxBarHeight;

  /// Shown instead of a value for entries without data.
  final String missingText;

  /// One sentence instead of the chart when no entry has a value ("Noch
  /// keine Woche erfasst."). Null draws empty bars instead.
  final String? emptyText;

  @override
  State<AvoBarChart> createState() => _AvoBarChartState();
}

class _AvoBarChartState extends State<AvoBarChart>
    with SingleTickerProviderStateMixin {
  /// Progress from [_from] to [_to], 0 to 1. Created eagerly: dispose must
  /// never be the first access.
  late final AnimationController _t;

  /// Bar heights as fractions of [AvoBarChart.maxBarHeight]; null = no bar.
  List<double?> _from = const [];
  List<double?> _to = const [];
  double? _goalFrom;
  double? _goalTo;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _t = AnimationController.unbounded(vsync: this);
    final target = _targets(widget);
    _to = target.bars;
    _from = [for (final f in _to) f == null ? null : 0.0];
    _goalTo = target.goal;
    _goalFrom = target.goal;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _run();
  }

  @override
  void didUpdateWidget(AvoBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = _targets(widget);
    if (listEquals(target.bars, _to) && target.goal == _goalTo) return;
    // Start from what is on screen now, so an interrupted growth continues
    // without a jump.
    final now = [for (var i = 0; i < _to.length; i++) _bar(i)];
    _from = [
      for (var i = 0; i < target.bars.length; i++)
        i < now.length ? now[i] : null,
    ];
    _goalFrom = _goal;
    _to = target.bars;
    _goalTo = target.goal;
    _t.value = 0;
    _run();
  }

  void _run() {
    if (context.reduceMotion) {
      _t
        ..stop()
        ..value = 1;
      return;
    }
    _t.animateWith(
      SpringSimulation(AvoMotion.digits, _t.value, 1, 0, snapToEnd: true),
    );
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  /// Target fractions: every value against the largest value or the goal.
  static ({List<double?> bars, double? goal}) _targets(AvoBarChart w) {
    var top = math.max(0.0, w.goal ?? 0);
    for (final e in w.entries) {
      final v = e.value;
      if (v != null && v > top) top = v;
    }
    double fraction(double v) => top <= 0 ? 0 : (v / top).clamp(0.0, 1.0);
    final goal = w.goal;
    return (
      bars: [
        for (final e in w.entries)
          if (e.value case final v?) fraction(v) else null,
      ],
      goal: goal == null ? null : fraction(goal),
    );
  }

  double get _progress => _t.value.clamp(0.0, 1.0);

  /// The fraction bar [i] shows in this frame; null = no bar.
  double? _bar(int i) {
    final to = i < _to.length ? _to[i] : null;
    if (to == null) return null;
    final from = (i < _from.length ? _from[i] : null) ?? 0;
    return from + (to - from) * _progress;
  }

  double? get _goal {
    final to = _goalTo;
    if (to == null) return null;
    final from = _goalFrom ?? to;
    return from + (to - from) * _progress;
  }

  String _valueText(AvoBarEntry e) {
    final v = e.value;
    return v == null ? widget.missingText : widget.formatValue(v);
  }

  int? get _selected => widget.selectedIndex ?? widget.highlightIndex;

  bool _highlighted(int i) => i == _selected;

  /// The last column picked by this gesture, so a drag fires once per new
  /// column even before the parent rebuilds with the new [selectedIndex].
  int? _picked;

  bool _pickable(int i) =>
      i >= 0 && i < widget.entries.length && widget.entries[i].value != null;

  void _choose(int i) {
    final pick = widget.onSelected;
    if (pick == null || !_pickable(i)) return;
    if (i == (_picked ?? _selected)) return;
    _picked = i;
    unawaited(AvoHaptics.selection());
    pick(i);
  }

  /// The next pickable bar from the selection in [step] direction, or null.
  int? _next(int step) {
    final from = _selected;
    if (from == null) {
      for (var i = 0; i < widget.entries.length; i++) {
        final j = step > 0 ? i : widget.entries.length - 1 - i;
        if (_pickable(j)) return j;
      }
      return null;
    }
    for (var i = from + step; i >= 0 && i < widget.entries.length; i += step) {
      if (_pickable(i)) return i;
    }
    return null;
  }

  String _spokenEntry(int i) {
    final e = widget.entries[i];
    return '${e.spokenLabel}, ${e.semanticValue ?? _valueText(e)}';
  }

  /// Memo of [_valuesFit]: the measurement runs once per input, not once
  /// per animation frame.
  Object? _fitKey;
  bool _fit = true;

  /// Whether every value fits [slot] on one line at full size. Measured in
  /// the semibold style of the highlighted bar for all of them, so picking
  /// another bar never switches the values on or off.
  bool _valuesFit(BuildContext context, double slot) {
    final style = _valueStyle(context, true);
    final scaler = MediaQuery.textScalerOf(context);
    final bold = MediaQuery.boldTextOf(context);
    final texts = [for (final e in widget.entries) _valueText(e)];
    final key = Object.hash(
      Object.hashAll(texts),
      slot,
      style.fontSize,
      scaler,
      bold,
    );
    if (key == _fitKey) return _fit;
    final measured = bold ? style.copyWith(fontWeight: FontWeight.bold) : style;
    var fit = true;
    for (final text in texts) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: measured),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      if (width > slot + 0.5) {
        fit = false;
        break;
      }
    }
    _fitKey = key;
    return _fit = fit;
  }

  Color _barColor(BuildContext context, int i) =>
      _highlighted(i) || widget.tintAllBars
      ? context.colors.chartHighlight
      : context.colors.chartBar;

  @override
  Widget build(BuildContext context) {
    final empty = widget.emptyText;
    if (empty != null && widget.entries.every((e) => e.value == null)) {
      return Text(
        empty,
        style: context.text(
          AvoTextStyle.footnote,
          color: context.colors.secondaryLabel,
        ),
      );
    }
    if (widget.entries.isEmpty) return const SizedBox.shrink();
    final list = context.isAccessibilityText;
    final chart = AnimatedBuilder(
      animation: _t,
      builder: (context, _) => list ? _buildList(context) : _buildBars(),
    );
    if (widget.onSelected == null) {
      return Semantics(
        container: true,
        label: widget.semanticSummary,
        explicitChildNodes: true,
        child: chart,
      );
    }
    _picked = null;
    final selected = _selected;
    final up = _next(1);
    final down = _next(-1);
    return Semantics(
      container: true,
      label: widget.semanticSummary,
      value: selected != null && selected < widget.entries.length
          ? _spokenEntry(selected)
          : null,
      increasedValue: up == null ? null : _spokenEntry(up),
      decreasedValue: down == null ? null : _spokenEntry(down),
      onIncrease: up == null ? null : () => _choose(up),
      onDecrease: down == null ? null : () => _choose(down),
      child: ExcludeSemantics(child: chart),
    );
  }

  Widget _buildBars() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final colors = context.colors;
        final typography = context.typography;
        final entries = widget.entries;
        final n = entries.length;
        final width = constraints.maxWidth;
        final barWidth = math.max(
          0.0,
          math.min(_kBarWidth, (width - (n - 1) * _kMinBarGap) / n),
        );
        final gap = n > 1 ? (width - n * barWidth) / (n - 1) : 0.0;
        // A label may use its bar plus one gap (half on each side).
        final slot = barWidth + gap;
        final valueBlock = widget.showValues
            ? typography.lineHeightOf(AvoTextStyle.caption1) + _kValueGap
            : 0.0;
        // The value line keeps its height when the values are left out, so
        // the chart does not jump when an amount gets one digit longer.
        final plotHeight = valueBlock + widget.maxBarHeight;
        final valuesShown = widget.showValues && _valuesFit(context, slot);
        final goal = _goal;

        final columns = <Widget>[
          for (var i = 0; i < n; i++)
            _BarColumn(
              entry: entries[i],
              valueText: _valueText(entries[i]),
              fraction: _bar(i),
              highlighted: _highlighted(i),
              barColor: _barColor(context, i),
              showValue: valuesShown,
              barWidth: barWidth,
              slot: slot,
              plotHeight: plotHeight,
              maxBarHeight: widget.maxBarHeight,
            ),
        ];

        final stack = Stack(
          children: [
            if (goal != null)
              Positioned(
                left: 0,
                right: 0,
                top: plotHeight - goal * widget.maxBarHeight - _kGoalStroke / 2,
                height: _kGoalStroke,
                child: CustomPaint(
                  painter: _DashPainter(colors.secondaryLabel),
                ),
              ),
            Row(
              mainAxisAlignment: n == 1
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: columns,
            ),
          ],
        );
        if (widget.onSelected == null) return stack;

        // The column under [x]; each column owns its bar plus half a gap on
        // each side, so the whole width picks something.
        int indexAt(double x) {
          final i = n == 1
              ? 0
              : ((x + gap / 2) / (barWidth + gap)).floor().clamp(0, n - 1);
          return Directionality.of(context) == TextDirection.rtl
              ? n - 1 - i
              : i;
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTapUp: (d) => _choose(indexAt(d.localPosition.dx)),
          onHorizontalDragStart: (d) => _choose(indexAt(d.localPosition.dx)),
          onHorizontalDragUpdate: (d) => _choose(indexAt(d.localPosition.dx)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
            child: stack,
          ),
        );
      },
    );
  }

  Widget _buildList(BuildContext context) {
    final entries = widget.entries;
    final pickable = widget.onSelected != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < entries.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : _kRowGap),
            child: Semantics(
              container: true,
              label: entries[i].spokenLabel,
              value: entries[i].semanticValue ?? _valueText(entries[i]),
              child: ExcludeSemantics(
                child: _pickableRow(
                  pickable: pickable,
                  onTap: () => _choose(i),
                  child: _BarRow(
                    label: entries[i].label,
                    secondaryLabel: entries[i].secondaryLabel,
                    value: _valueText(entries[i]),
                    fraction: _bar(i),
                    color: _barColor(context, i),
                    labelStyle: _labelStyle(context, _highlighted(i)),
                    secondaryStyle: _secondaryStyle(context),
                    valueStyle: _valueStyle(context, _highlighted(i)),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A row of the AX list that picks its bar on tap (44 pt at least).
Widget _pickableRow({
  required bool pickable,
  required VoidCallback onTap,
  required Widget child,
}) {
  if (!pickable) return child;
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    excludeFromSemantics: true,
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
      child: child,
    ),
  );
}

/// Second axis line ("bisher"): 11/13 in secondaryLabel.
TextStyle _secondaryStyle(BuildContext context) =>
    context.text(AvoTextStyle.caption2, color: context.colors.secondaryLabel);

/// Axis label: 13/18 secondary; highlighted 600 in [AvoColors.label] (D2).
TextStyle _labelStyle(BuildContext context, bool highlighted) => context.text(
  AvoTextStyle.footnote,
  color: highlighted ? context.colors.label : context.colors.secondaryLabel,
  weight: highlighted ? FontWeight.w600 : null,
);

/// Value: 12/16 tertiary, tabular; highlighted 600 in [AvoColors.tint] (D2).
TextStyle _valueStyle(BuildContext context, bool highlighted) => context.text(
  AvoTextStyle.caption1,
  color: highlighted ? context.colors.tint : context.colors.tertiaryLabel,
  weight: highlighted ? FontWeight.w600 : null,
  tabular: true,
);

/// One column: value, bar, label. The bar's foot sits [plotHeight] below
/// the top in every column, so the bars share one baseline.
class _BarColumn extends StatelessWidget {
  const _BarColumn({
    required this.entry,
    required this.valueText,
    required this.fraction,
    required this.highlighted,
    required this.barColor,
    required this.showValue,
    required this.barWidth,
    required this.slot,
    required this.plotHeight,
    required this.maxBarHeight,
  });

  final AvoBarEntry entry;
  final String valueText;
  final double? fraction;
  final bool highlighted;
  final Color barColor;
  final bool showValue;
  final double barWidth;
  final double slot;
  final double plotHeight;
  final double maxBarHeight;

  @override
  Widget build(BuildContext context) {
    final f = fraction;
    final second = entry.secondaryLabel;
    return Semantics(
      container: true,
      label: entry.spokenLabel,
      value: entry.semanticValue ?? valueText,
      child: ExcludeSemantics(
        child: SizedBox(
          width: barWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: plotHeight),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showValue) ...[
                        _FitLabel(
                          text: valueText,
                          style: _valueStyle(context, highlighted),
                          maxWidth: slot,
                        ),
                        const SizedBox(height: _kValueGap),
                      ],
                      SizedBox(
                        width: barWidth,
                        height: (f ?? 0) * maxBarHeight,
                        child: f == null
                            ? null
                            : DecoratedBox(
                                decoration: BoxDecoration(
                                  color: barColor,
                                  borderRadius: BorderRadius.circular(
                                    _kBarRadius,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: _kLabelGap),
              _FitLabel(
                text: entry.label,
                style: _labelStyle(context, highlighted),
                maxWidth: slot,
              ),
              if (second != null)
                _FitLabel(
                  text: second,
                  style: _secondaryStyle(context),
                  maxWidth: slot,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One line of text centred on its column. It may spill into the gaps up to
/// [maxWidth] and shrinks to fit there instead of wrapping (like iOS
/// `adjustsFontSizeToFitWidth`); it is never cut.
class _FitLabel extends StatelessWidget {
  const _FitLabel({
    required this.text,
    required this.style,
    required this.maxWidth,
  });

  final String text;
  final TextStyle style;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return OverflowBox(
      minWidth: 0,
      maxWidth: maxWidth,
      fit: OverflowBoxFit.deferToChild,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          style: style,
          maxLines: 1,
          softWrap: false,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Label and value on one line (the value moves below when both do not
/// fit), a 6 pt bar under them.
class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.value,
    required this.fraction,
    required this.color,
    required this.labelStyle,
    required this.valueStyle,
    this.track,
    this.secondaryLabel,
    this.secondaryStyle,
  });

  final String label;
  final String? secondaryLabel;
  final TextStyle? secondaryStyle;
  final String value;
  final double? fraction;
  final Color color;
  final Color? track;
  final TextStyle labelStyle;
  final TextStyle valueStyle;

  @override
  Widget build(BuildContext context) {
    final f = fraction;
    final trackColor = track;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: _kRowTextGap,
          children: [
            if (secondaryLabel case final second?)
              Text.rich(
                TextSpan(
                  text: label,
                  children: [
                    const TextSpan(text: ' '),
                    TextSpan(text: second, style: secondaryStyle),
                  ],
                ),
                style: labelStyle,
              )
            else
              Text(label, style: labelStyle),
            Text(value, style: valueStyle),
          ],
        ),
        const SizedBox(height: _kTrackGap),
        SizedBox(
          height: _kTrackHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: trackColor,
              borderRadius: BorderRadius.circular(_kTrackRadius),
            ),
            child: f == null
                ? null
                : Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FractionallySizedBox(
                      widthFactor: f.clamp(0.0, 1.0),
                      heightFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(_kTrackRadius),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// One comparison or progress row (D2-FuerDich macro rows and "Sparziel"):
/// label and value 13/18 on one line, below them a 6 pt bar on a
/// [AvoColors.fill] track.
///
/// The bar starts at the first [fraction] and follows changes on the
/// [AvoMotion.digits] spring from where it is (Reduce Motion: it jumps).
/// When label and value do not fit side by side the value moves below the
/// label. VoiceOver reads one element: [label] and [semanticValue] (default
/// [value]). Fills the width it gets.
class AvoHorizontalBar extends StatefulWidget {
  /// Creates a bar row.
  const AvoHorizontalBar({
    super.key,
    required this.label,
    required this.value,
    required this.fraction,
    this.color,
    this.semanticValue,
  });

  /// What is measured ("Protein").
  final String label;

  /// The value text at the end ("62 / 110 g"), tabular figures.
  final String value;

  /// Filled share of the track, 0 to 1; values outside are clamped.
  final double fraction;

  /// Bar colour; defaults to [AvoColors.tint]. Pass a token.
  final Color? color;

  /// Spoken value ("62 von 110 Gramm"); defaults to [value].
  final String? semanticValue;

  @override
  State<AvoHorizontalBar> createState() => _AvoHorizontalBarState();
}

class _AvoHorizontalBarState extends State<AvoHorizontalBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _value;

  double get _target => widget.fraction.clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    _value = AnimationController.unbounded(vsync: this, value: _target);
  }

  @override
  void didUpdateWidget(AvoHorizontalBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fraction == widget.fraction) return;
    if (context.reduceMotion) {
      _value
        ..stop()
        ..value = _target;
      return;
    }
    _value.animateWith(
      SpringSimulation(
        AvoMotion.digits,
        _value.value,
        _target,
        _value.velocity,
        snapToEnd: true,
      ),
    );
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      container: true,
      label: widget.label,
      value: widget.semanticValue ?? widget.value,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _value,
          builder: (context, _) => _BarRow(
            label: widget.label,
            value: widget.value,
            fraction: _value.value,
            color: widget.color ?? colors.tint,
            track: colors.fill,
            labelStyle: context.text(AvoTextStyle.footnote),
            valueStyle: context.text(
              AvoTextStyle.footnote,
              color: colors.secondaryLabel,
              tabular: true,
            ),
          ),
        ),
      ),
    );
  }
}

/// A horizontal dashed line across the whole width.
class _DashPainter extends CustomPainter {
  const _DashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height
      ..style = PaintingStyle.stroke;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += _kGoalDash + _kGoalGap) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + _kGoalDash, size.width), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

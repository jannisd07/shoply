import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' show Intl, NumberFormat;
import 'package:shoply/core/design/design.dart';

/// A number whose changed digits roll into place (Konzept 00 §12.15).
///
/// Only the characters that differ move: upwards when the value grows,
/// downwards when it shrinks, each on the [AvoMotion.digits] spring. Every
/// roll starts from the column's current position and speed, so quick
/// changes (a held stepper) keep rolling without jumps. Figures are tabular,
/// so the width stays steady. Under Reduce Motion the new value cross-fades
/// in. VoiceOver reads only the final value.
class RollingNumber extends StatefulWidget {
  /// Creates a rolling number.
  const RollingNumber({
    super.key,
    required this.value,
    this.style,
    this.fractionDigits = 0,
    this.locale,
  }) : assert(fractionDigits >= 0);

  /// The number to show.
  final num value;

  /// Text style; defaults to body. Tabular figures are always switched on.
  final TextStyle? style;

  /// Digits after the decimal separator (2 for "1,50").
  final int fractionDigits;

  /// Locale for separators (`de`, `en_US`); defaults to the app locale.
  final String? locale;

  /// [value] formatted the way a [RollingNumber] shows it, for example
  /// "1.234,5" in German. Use it for semantics around the number.
  static String format(
    BuildContext context,
    num value, {
    int fractionDigits = 0,
    String? locale,
  }) {
    final tag =
        locale ?? Localizations.maybeLocaleOf(context)?.toString() ?? 'en';
    final resolved = Intl.verifiedLocale(
      tag,
      NumberFormat.localeExists,
      onFailure: (_) => 'en',
    );
    return NumberFormat.decimalPatternDigits(
      locale: resolved,
      decimalDigits: fractionDigits,
    ).format(value);
  }

  @override
  State<RollingNumber> createState() => _RollingNumberState();
}

class _RollingNumberState extends State<RollingNumber>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  Duration _now = Duration.zero;

  /// Character columns from the right: index 0 is the last character, so
  /// units stay aligned when the number gains or loses a digit.
  final List<_Column> _columns = [];
  String _text = '';
  bool _ready = false;

  String _format() => RollingNumber.format(
    context,
    widget.value,
    fractionDigits: widget.fractionDigits,
    locale: widget.locale,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final text = _format();
    // First build or a locale change: show the value without rolling.
    if (!_ready || text != _text) {
      _ready = true;
      _jumpTo(text);
    }
  }

  @override
  void didUpdateWidget(RollingNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    final text = _format();
    if (text == _text) return;
    if (context.reduceMotion) {
      _jumpTo(text);
      return;
    }
    _rollTo(text, widget.value >= oldWidget.value ? 1 : -1);
  }

  void _jumpTo(String text) {
    _text = text;
    _columns
      ..clear()
      ..addAll(text.split('').reversed.map(_Column.new));
    if (_ticker.isActive) _ticker.stop();
  }

  void _rollTo(String text, int direction) {
    _text = text;
    final chars = text.split('').reversed.toList();
    if (_columns.length > chars.length) {
      _columns.removeRange(chars.length, _columns.length);
    }
    final now = _ticker.isActive ? _now : Duration.zero;
    for (var i = 0; i < chars.length; i++) {
      if (i >= _columns.length) _columns.add(_Column(''));
      final column = _columns[i];
      if (column.char != chars[i]) column.rollTo(chars[i], direction, now);
    }
    if (!_ticker.isActive && _columns.any((c) => c.rolling)) {
      _now = Duration.zero;
      _ticker.start();
    }
  }

  void _tick(Duration elapsed) {
    _now = elapsed;
    var active = false;
    for (final column in _columns) {
      if (column.advance(elapsed)) active = true;
    }
    if (!active) _ticker.stop();
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  TextStyle _style(BuildContext context) {
    final base = widget.style ?? context.text(AvoTextStyle.body, tabular: true);
    final features = base.fontFeatures ?? const <FontFeature>[];
    if (features.any((f) => f.feature == 'tnum')) return base;
    return base.copyWith(
      fontFeatures: [...features, const FontFeature.tabularFigures()],
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = _style(context);
    final Widget visual;
    if (context.reduceMotion) {
      visual = AnimatedSwitcher(
        duration: AvoMotion.fadeReduced,
        child: Text(
          _text,
          key: ValueKey(_text),
          style: style,
          maxLines: 1,
          softWrap: false,
        ),
      );
    } else {
      visual = Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: TextDirection.ltr,
        children: [
          for (var i = _columns.length - 1; i >= 0; i--)
            _ColumnView(column: _columns[i], style: style),
        ],
      );
    }
    return Semantics(
      label: _text,
      child: ExcludeSemantics(child: visual),
    );
  }
}

/// One character position. Its glyphs sit on a vertical tape (slot → char);
/// [pos] is the tape position in slots and follows a spring towards
/// [_target]. A new character is added one slot beyond the motion's far end,
/// so an interrupted roll simply continues to the new slot.
class _Column {
  _Column(String char) : _glyphs = {0: char};

  final Map<int, String> _glyphs;
  int _target = 0;
  double pos = 0;
  double _velocity = 0;
  SpringSimulation? _sim;
  Duration _start = Duration.zero;

  String get char => _glyphs[_target]!;

  bool get rolling => _sim != null;

  /// Glyphs at most one slot away from the current position.
  Iterable<MapEntry<int, String>> get visible =>
      _glyphs.entries.where((e) => (e.key - pos).abs() < 1);

  void rollTo(String char, int direction, Duration now) {
    final slot = direction > 0
        ? math.max(_target, pos.ceil()) + 1
        : math.min(_target, pos.floor()) - 1;
    _glyphs[slot] = char;
    _target = slot;
    _sim = SpringSimulation(
      AvoMotion.digits,
      pos,
      slot.toDouble(),
      _velocity,
      snapToEnd: true,
    );
    _start = now;
    final lo = math.min(pos, slot.toDouble()).floor() - 1;
    final hi = math.max(pos, slot.toDouble()).ceil() + 1;
    _glyphs.removeWhere((k, _) => k < lo || k > hi);
  }

  /// Moves to the position at [now]; returns whether still rolling.
  bool advance(Duration now) {
    final sim = _sim;
    if (sim == null) return false;
    final t = (now - _start).inMicroseconds / Duration.microsecondsPerSecond;
    if (sim.isDone(t)) {
      pos = _target.toDouble();
      _velocity = 0;
      _sim = null;
      _glyphs.removeWhere((k, _) => k != _target);
      return false;
    }
    pos = sim.x(t);
    _velocity = sim.dx(t);
    return true;
  }
}

class _ColumnView extends StatelessWidget {
  const _ColumnView({required this.column, required this.style});

  final _Column column;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (!column.rolling) {
      return Text(column.char, style: style, maxLines: 1, softWrap: false);
    }
    return ClipRect(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Sizes the column to the character it is rolling to.
          Opacity(
            opacity: 0,
            child: Text(column.char, style: style, softWrap: false),
          ),
          for (final glyph in column.visible)
            Positioned.fill(
              child: OverflowBox(
                minWidth: 0,
                maxWidth: double.infinity,
                minHeight: 0,
                maxHeight: double.infinity,
                child: FractionalTranslation(
                  translation: Offset(0, glyph.key - column.pos),
                  child: Opacity(
                    opacity: (1 - (glyph.key - column.pos).abs()).clamp(
                      0.0,
                      1.0,
                    ),
                    child: Text(glyph.value, style: style, softWrap: false),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

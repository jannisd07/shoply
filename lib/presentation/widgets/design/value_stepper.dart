import 'dart:async';

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/design/rolling_number.dart';

// D2 "Stepper" (D2-Komponenten): group 44 high, minus/plus 44 x 44, value
// at least 28 wide. Compact (D2-Artikel): visible 34 high inside a 44 hit
// height, value at least 24 wide, 16 pt glyphs.
const double _compactHeight = 34; // D2
const double _valueMinWidth = 28; // D2
const double _valueMinWidthCompact = 24; // D2
const double _glyph = 18; // D2
const double _glyphCompact = 16; // D2
const double _glyphStroke = 2.4; // D2, in 24-unit icon space

/// iOS dims unavailable glyphs to about a third.
const double _disabledAlpha = 0.3;

// Holding a button repeats, faster the longer it is held (Konzept 00
// §12.21). These are repeat intervals, not animation durations.
const Duration _repeatFirst = Duration(milliseconds: 220);
const Duration _repeatFastest = Duration(milliseconds: 50);
const double _repeatAcceleration = 0.8;

/// Konzept 00 §12.20: pressed controls also drop to 90 % opacity.
const double _pressedOpacity = 0.9;

/// A minus / value / plus capsule for quantities and servings (D2 Stepper,
/// Konzept 00 §12.21).
///
/// The value rolls ([RollingNumber]); minus and plus are disabled at [min]
/// and [max]; holding a button repeats and speeds up. Every step plays the
/// selection haptic. VoiceOver sees one adjustable element (swipe up/down)
/// plus the two labelled buttons. At accessibility text sizes the stepper
/// stays on one line and grows in height.
class ValueStepper extends StatefulWidget {
  /// Creates a stepper.
  const ValueStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 999,
    this.semanticLabel,
    this.compact = false,
    this.unit,
  }) : assert(min <= max);

  /// The current value.
  final int value;

  /// Called with the new value after each step.
  final ValueChanged<int> onChanged;

  /// Lowest value; minus is disabled there.
  final int min;

  /// Highest value; plus is disabled there.
  final int max;

  /// What the value is, for VoiceOver ("Menge", "Portionen").
  final String? semanticLabel;

  /// D2-Artikel size: 34 pt visible inside the 44 pt hit height.
  final bool compact;

  /// Unit shown after the value ("St.", "Portionen").
  final String? unit;

  @override
  State<ValueStepper> createState() => _ValueStepperState();
}

class _ValueStepperState extends State<ValueStepper> {
  Timer? _repeat;
  Duration _interval = _repeatFirst;
  int _repeatDelta = 0;

  bool get _canDecrease => widget.value > widget.min;
  bool get _canIncrease => widget.value < widget.max;

  void _step(int delta) {
    final next = (widget.value + delta).clamp(widget.min, widget.max);
    if (next == widget.value) {
      _stopRepeat();
      return;
    }
    widget.onChanged(next);
    unawaited(AvoHaptics.selection());
  }

  void _startRepeat(int delta) {
    _stopRepeat();
    _repeatDelta = delta;
    _interval = _repeatFirst;
    _step(delta);
    _scheduleRepeat();
  }

  void _scheduleRepeat() {
    _repeat = Timer(_interval, () {
      if (!mounted) return;
      _step(_repeatDelta);
      if (_repeatDelta == 0) return; // stopped at a bound
      final next = _interval * _repeatAcceleration;
      _interval = next < _repeatFastest ? _repeatFastest : next;
      _scheduleRepeat();
    });
  }

  void _stopRepeat() {
    _repeat?.cancel();
    _repeat = null;
    _repeatDelta = 0;
  }

  @override
  void didUpdateWidget(ValueStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((_repeatDelta < 0 && !_canDecrease) ||
        (_repeatDelta > 0 && !_canIncrease)) {
      _stopRepeat();
    }
  }

  @override
  void dispose() {
    _stopRepeat();
    super.dispose();
  }

  String _valueText(BuildContext context, int value) {
    final number = RollingNumber.format(context, value);
    final unit = widget.unit;
    return unit == null || unit.isEmpty ? number : '$number $unit';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final compact = widget.compact;
    final inset = compact ? (AvoSizes.hitTarget - _compactHeight) / 2 : 0.0;
    // Padding around the 22 pt value line that makes the default height
    // 44 (regular) or 34 (compact); larger text grows the capsule.
    final valuePad =
        ((compact ? _compactHeight : AvoSizes.hitTarget) -
            context.typography.lineHeightOf(AvoTextStyle.body)) /
        2;
    final valueStyle = context.text(
      AvoTextStyle.body,
      weight: FontWeight.w600,
      tabular: true,
    );
    final unit = widget.unit;

    final value = Padding(
      padding: EdgeInsets.symmetric(
        vertical: inset + (valuePad < 0 ? 0 : valuePad),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: compact ? _valueMinWidthCompact : _valueMinWidth,
        ),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RollingNumber(value: widget.value, style: valueStyle),
                if (unit != null && unit.isNotEmpty) ...[
                  const SizedBox(width: AvoSpacing.xs),
                  Text(unit, style: context.text(AvoTextStyle.body)),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return Semantics(
      container: true,
      label: widget.semanticLabel,
      value: _valueText(context, widget.value),
      increasedValue: _canIncrease
          ? _valueText(context, widget.value + 1)
          : null,
      decreasedValue: _canDecrease
          ? _valueText(context, widget.value - 1)
          : null,
      onIncrease: _canIncrease ? () => _step(1) : null,
      onDecrease: _canDecrease ? () => _step(-1) : null,
      child: IntrinsicHeight(
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: inset),
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: colors.fill,
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StepButton(
                  plus: false,
                  compact: compact,
                  label: context.tr('common_decrease'),
                  enabled: _canDecrease,
                  onTap: () => _step(-1),
                  onHoldStart: () => _startRepeat(-1),
                  onHoldEnd: _stopRepeat,
                ),
                value,
                _StepButton(
                  plus: true,
                  compact: compact,
                  label: context.tr('common_increase'),
                  enabled: _canIncrease,
                  onTap: () => _step(1),
                  onHoldStart: () => _startRepeat(1),
                  onHoldEnd: _stopRepeat,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.plus,
    required this.compact,
    required this.label,
    required this.enabled,
    required this.onTap,
    required this.onHoldStart,
    required this.onHoldEnd,
  });

  final bool plus;
  final bool compact;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final size = compact ? _glyphCompact : _glyph;
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: label,
      onTap: enabled ? onTap : null,
      child: _Pressable(
        onTap: enabled ? onTap : null,
        onHoldStart: enabled ? onHoldStart : null,
        onHoldEnd: onHoldEnd,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: AvoSizes.hitTarget,
            minHeight: AvoSizes.hitTarget,
          ),
          child: Center(
            child: CustomPaint(
              size: Size.square(size),
              painter: _GlyphPainter(
                plus: plus,
                compact: compact,
                color: enabled
                    ? colors.label
                    : colors.label.withValues(alpha: _disabledAlpha),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Minus and plus as drawn in D2 (24-unit icon space, round caps).
class _GlyphPainter extends CustomPainter {
  const _GlyphPainter({
    required this.plus,
    required this.compact,
    required this.color,
  });

  final bool plus;
  final bool compact;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 24;
    // D2: M6 12h12 (18 pt) and M5 12h14 (16 pt, compact).
    final from = compact ? 5.0 : 6.0;
    final to = 24 - from;
    final paint = Paint()
      ..color = color
      ..strokeWidth = _glyphStroke * unit
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(from, 12) * unit, Offset(to, 12) * unit, paint);
    if (plus) {
      canvas.drawLine(Offset(12, from) * unit, Offset(12, to) * unit, paint);
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.plus != plus || old.compact != compact || old.color != color;
}

/// Scales its child to [AvoMotion.pressedScale] and 90 % opacity while a
/// finger is down, on the quick spring (instant opacity only under Reduce
/// Motion). Holding reports [onHoldStart] / [onHoldEnd].
class _Pressable extends StatefulWidget {
  const _Pressable({
    required this.child,
    this.onTap,
    this.onHoldStart,
    this.onHoldEnd,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onHoldStart;
  final VoidCallback? onHoldEnd;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(vsync: this);
  }

  /// Read in build: gesture callbacks can fire while the element is being
  /// unmounted, when looking up MediaQuery is no longer allowed.
  bool _reduceMotion = false;

  void _set(bool down) {
    if (!mounted) return;
    final target = down ? 1.0 : 0.0;
    if (_reduceMotion) {
      _press.value = target;
      return;
    }
    _press.animateWith(
      SpringSimulation(
        AvoMotion.quick,
        _press.value,
        target,
        _press.velocity,
        snapToEnd: true,
      ),
    );
  }

  @override
  void didUpdateWidget(_Pressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Became disabled mid-press (a held stepper reached its bound).
    if (widget.onTap == null && _press.value != 0) _set(false);
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _holdEnd() {
    _set(false);
    widget.onHoldEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    _reduceMotion = context.reduceMotion;
    final enabled = widget.onTap != null;
    final hold = widget.onHoldStart;
    // The end callbacks stay registered while disabled so a hold that hits
    // a bound still ends cleanly.
    final holds = hold != null || widget.onHoldEnd != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: widget.onTap,
      onLongPressStart: hold == null
          ? null
          : (_) {
              _set(true);
              hold();
            },
      onLongPressEnd: holds ? (_) => _holdEnd() : null,
      onLongPressCancel: holds ? _holdEnd : null,
      child: AnimatedBuilder(
        animation: _press,
        child: widget.child,
        builder: (context, child) {
          final p = _press.value;
          if (p == 0) return child!;
          final scaled = context.reduceMotion
              ? child!
              : Transform.scale(
                  scale: 1 - (1 - AvoMotion.pressedScale) * p,
                  child: child,
                );
          return Opacity(opacity: 1 - (1 - _pressedOpacity) * p, child: scaled);
        },
      ),
    );
  }
}

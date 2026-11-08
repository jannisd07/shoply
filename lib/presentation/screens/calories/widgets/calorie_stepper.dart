import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';

// D2 "Stepper": 44 high, radius 22, `fill`, minus and plus 44 × 44, value
// 17/22 semibold tabular, at least 28 wide.
const double _kValueMinWidth = 28; // D2
const double _kGlyph = 18; // D2
const double _kGlyphStroke = 2.4; // D2

/// iOS dims unavailable glyphs to about a third.
const double _kDisabledAlpha = 0.3;

/// Konzept 00 §12.20: pressed controls drop to 90 % opacity.
const double _kPressedAlpha = 0.9;

// Holding a button repeats, faster the longer it is held (Konzept 00
// §12.21). Repeat intervals, not animation durations.
const Duration _kRepeatFirst = Duration(milliseconds: 220);
const Duration _kRepeatFastest = Duration(milliseconds: 50);
const double _kRepeatAcceleration = 0.8;

/// A minus / plus capsule for amounts that are not whole steps of one
/// (±10 g, ±0,5 Portionen, ±50 kcal, ±0,25 l): A's `ValueStepper` counts in
/// ones and cannot show "1,5" (request A-C5).
///
/// [value] is shown between the buttons when [showValue] is set (S10
/// "Portionen 1,5"); otherwise the number sits in the field next to it (S7,
/// S13). Each step plays the selection haptic, holding repeats and speeds
/// up, minus and plus are off at [min] and [max]. VoiceOver reads one
/// adjustable element ("Menge, 250 Gramm", swipe up/down) plus the two
/// buttons.
class CalorieStepper extends StatefulWidget {
  const CalorieStepper({
    super.key,
    required this.value,
    required this.step,
    required this.onChanged,
    required this.semanticLabel,
    required this.spokenValue,
    this.min = 0,
    this.max = 100000,
    this.showValue = false,
    this.format,
  });

  final double value;
  final double step;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  /// What is set ("Menge", "Portionen").
  final String semanticLabel;

  /// The value as VoiceOver says it ("250 Gramm").
  final String Function(double value) spokenValue;

  final bool showValue;

  /// The value as shown between the buttons ("1,5").
  final String Function(double value)? format;

  @override
  State<CalorieStepper> createState() => _CalorieStepperState();
}

class _CalorieStepperState extends State<CalorieStepper> {
  Timer? _repeat;
  Duration _interval = _kRepeatFirst;
  int _direction = 0;

  bool get _canDecrease => widget.value > widget.min + 1e-9;
  bool get _canIncrease => widget.value < widget.max - 1e-9;

  /// The next value one step away, snapped to the step grid ("153" + 10 →
  /// "160"), so a typed odd value joins the grid.
  double _next(int direction) {
    final step = widget.step;
    final grid = widget.value / step;
    final snapped = direction > 0 ? (grid + 1e-9).floor() + 1 : (grid - 1e-9).ceil() - 1;
    return (snapped * step).clamp(widget.min, widget.max).toDouble();
  }

  void _step(int direction) {
    if ((direction < 0 && !_canDecrease) || (direction > 0 && !_canIncrease)) {
      _stop();
      return;
    }
    widget.onChanged(_next(direction));
    unawaited(AvoHaptics.selection());
  }

  void _start(int direction) {
    _stop();
    _direction = direction;
    _interval = _kRepeatFirst;
    _step(direction);
    _schedule();
  }

  void _schedule() {
    _repeat = Timer(_interval, () {
      if (!mounted || _direction == 0) return;
      _step(_direction);
      if (_direction == 0) return;
      final next = _interval * _kRepeatAcceleration;
      _interval = next < _kRepeatFastest ? _kRepeatFastest : next;
      _schedule();
    });
  }

  void _stop() {
    _repeat?.cancel();
    _repeat = null;
    _direction = 0;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final format = widget.format;
    final showValue = widget.showValue && format != null;
    return Semantics(
      container: true,
      label: widget.semanticLabel,
      value: widget.spokenValue(widget.value),
      increasedValue: _canIncrease ? widget.spokenValue(_next(1)) : null,
      decreasedValue: _canDecrease ? widget.spokenValue(_next(-1)) : null,
      onIncrease: _canIncrease ? () => _step(1) : null,
      onDecrease: _canDecrease ? () => _step(-1) : null,
      child: DecoratedBox(
        decoration: ShapeDecoration(color: colors.fill, shape: const StadiumBorder()),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StepButton(
              plus: false,
              label: context.tr('common_decrease'),
              enabled: _canDecrease,
              onTap: () => _step(-1),
              onHoldStart: () => _start(-1),
              onHoldEnd: _stop,
            ),
            if (showValue)
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: _kValueMinWidth),
                child: ExcludeSemantics(
                  child: Text(
                    format(widget.value),
                    textAlign: TextAlign.center,
                    style: context.text(AvoTextStyle.body, weight: FontWeight.w600, tabular: true),
                  ),
                ),
              ),
            _StepButton(
              plus: true,
              label: context.tr('common_increase'),
              enabled: _canIncrease,
              onTap: () => _step(1),
              onHoldStart: () => _start(1),
              onHoldEnd: _stop,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatefulWidget {
  const _StepButton({
    required this.plus,
    required this.label,
    required this.enabled,
    required this.onTap,
    required this.onHoldStart,
    required this.onHoldEnd,
  });

  final bool plus;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;

  @override
  State<_StepButton> createState() => _StepButtonState();
}

class _StepButtonState extends State<_StepButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = widget.enabled;
    final alpha = !enabled ? _kDisabledAlpha : (_pressed ? _kPressedAlpha : 1.0);
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      onTap: enabled ? widget.onTap : null,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _setPressed(true) : null,
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        onTap: enabled ? widget.onTap : null,
        onLongPressStart: enabled ? (_) => widget.onHoldStart() : null,
        onLongPressEnd: (_) {
          _setPressed(false);
          widget.onHoldEnd();
        },
        child: SizedBox.square(
          dimension: AvoSizes.hitTarget,
          child: Center(
            child: Opacity(
              opacity: alpha,
              child: AvoIcon(
                widget.plus ? AvoIcons.plus : AvoIcons.minus,
                size: _kGlyph,
                strokeWidth: _kGlyphStroke,
                color: colors.label,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/physics.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';

/// Symbol size at the default text size (Konzept 17 §6.1: 16 pt); it grows
/// with the text.
const double _kSymbolSize = 16;

/// Callout size at the default category (Large), the reference for scaling
/// the symbol.
const double _kCalloutAtLarge = 16;

/// Gap between symbol and text.
const double _kSymbolGap = AvoSpacing.m;

/// A swipe past this share of the width hides the tip.
const double _kHideShare = 0.4;

/// A fling faster than this (points per second) hides it too.
const double _kHideVelocity = 700;

/// Below this share the row counts as resting (no background).
const double _kResting = 0.001;

/// Pressed opacity of the action (Konzept 00 §12.20).
const double _kPressedOpacity = 0.6;

/// One-time tip (Konzept 17 §6.1, 00 §12.12 variant "Tipp"): light bulb
/// ([AvoIcons.lightbulb]) in `secondaryLabel`, the sentence with "Tipp:" at
/// its start in `callout`, no card and no frame; it sits in an
/// `InsetSection`.
///
/// - Swiping to the left (to the start in right-to-left text) follows the
///   finger and shows "Ausblenden"; past 40 % or with a fling the row slides
///   out and [onHide] runs at once (the parent collapses it).
/// - Only T7 has an [actionLabel] ("Einstellen"); from AX1 on it moves below
///   the text.
/// - VoiceOver: one element; the action is its double tap, "Ausblenden" a
///   custom action.
/// - Reduce Motion: the row does not fly out, it is just gone.
class TipRow extends StatefulWidget {
  const TipRow({
    super.key,
    required this.text,
    required this.hideLabel,
    required this.onHide,
    this.actionLabel,
    this.onAction,
  });

  /// The whole sentence, "Tipp: …".
  final String text;

  /// "Ausblenden".
  final String hideLabel;

  /// Swiped away (or the VoiceOver action).
  final VoidCallback onHide;

  /// Tinted action after the text; needs [onAction].
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  State<TipRow> createState() => _TipRowState();
}

class _TipRowState extends State<TipRow> with SingleTickerProviderStateMixin {
  /// 0 = resting, 1 = slid out by its whole width.
  late final AnimationController _slide = AnimationController.unbounded(
    vsync: this,
  );
  double _width = 1;
  bool _gone = false;

  /// Read in build; the drag callbacks run outside of it.
  bool _reduceMotion = false;
  bool _rtl = false;

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  /// Finger movement towards the hide side is positive.
  double _towardsHide(double dx) => _rtl ? dx : -dx;

  void _onDragUpdate(DragUpdateDetails details) {
    if (_gone) return;
    final delta = _towardsHide(details.primaryDelta ?? 0) / _width;
    _slide.value = (_slide.value + delta).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails details) {
    if (_gone) return;
    final velocity = _towardsHide(details.primaryVelocity ?? 0);
    if (_slide.value >= _kHideShare || velocity >= _kHideVelocity) {
      _hide(velocity: velocity);
    } else {
      _springTo(0, velocity);
    }
  }

  void _springTo(double target, double velocity) {
    if (_reduceMotion) {
      _slide.value = target;
      return;
    }
    _slide.animateWith(
      SpringSimulation(
        AvoMotion.standard,
        _slide.value,
        target,
        velocity / _width,
      ),
    );
  }

  void _hide({double velocity = 0}) {
    if (_gone) return;
    _gone = true;
    if (_reduceMotion) {
      _slide.value = 1;
    } else {
      _slide.animateWith(
        SpringSimulation(AvoMotion.fling, _slide.value, 1, velocity / _width),
      );
    }
    widget.onHide();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    _reduceMotion = context.reduceMotion;
    _rtl = Directionality.of(context) == TextDirection.rtl;

    final lineHeight = typography.lineHeightOf(AvoTextStyle.callout);
    final symbolSize =
        _kSymbolSize *
        typography.sizeOf(AvoTextStyle.callout) /
        _kCalloutAtLarge;
    final label = widget.actionLabel;
    final onAction = widget.onAction;
    final hasAction = label != null && onAction != null;

    final message = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: lineHeight,
          child: Center(
            widthFactor: 1,
            child: AvoIcon(
              AvoIcons.lightbulb,
              size: symbolSize,
              color: colors.secondaryLabel,
            ),
          ),
        ),
        const SizedBox(width: _kSymbolGap),
        Expanded(
          child: Text(
            widget.text,
            style: context.text(AvoTextStyle.callout, color: colors.label),
          ),
        ),
      ],
    );

    final stacked = context.isAccessibilityText;
    Widget content = message;
    if (hasAction) {
      final action = _TipAction(label: label, onTap: onAction);
      content = stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                message,
                Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: symbolSize + _kSymbolGap,
                  ),
                  child: action,
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: message),
                const SizedBox(width: AvoSpacing.s),
                action,
              ],
            );
    }

    final row = ColoredBox(
      color: colors.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AvoSizes.hitTarget,
          minWidth: double.infinity,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AvoSpacing.l,
            // Beside the text the action's 44 pt target sets the height.
            vertical: hasAction && !stacked ? AvoSpacing.xs : AvoSpacing.m,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            heightFactor: 1,
            child: content,
          ),
        ),
      ),
    );

    final hideBackground = ColoredBox(
      color: Color.alphaBlend(colors.fillStrong, colors.surface),
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(end: AvoSpacing.xl),
          // From AX1 on only the symbol: the word would not fit beside it.
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AvoIcon(AvoIcons.eyeSlash, size: symbolSize, color: colors.label),
              if (!stacked) ...[
                const SizedBox(width: AvoSpacing.s),
                Text(
                  widget.hideLabel,
                  style: context.text(
                    AvoTextStyle.callout,
                    color: colors.label,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    final sliding = LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth > 0 ? constraints.maxWidth : 1;
        return AnimatedBuilder(
          animation: _slide,
          builder: (context, child) {
            final t = _slide.value;
            // A spring ends within its tolerance, not exactly at 0.
            if (t < _kResting) return child!;
            return Stack(
              children: [
                Positioned.fill(child: hideBackground),
                FractionalTranslation(
                  translation: Offset(_rtl ? t : -t, 0),
                  child: child,
                ),
              ],
            );
          },
          child: row,
        );
      },
    );

    return Semantics(
      container: true,
      label: widget.text,
      hint: hasAction ? label : null,
      button: hasAction,
      onTap: hasAction ? onAction : null,
      customSemanticsActions: {
        CustomSemanticsAction(label: widget.hideLabel): () => _hide(),
      },
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          child: ClipRect(child: sliding),
        ),
      ),
    );
  }
}

/// Tinted text action with a 44 pt target that dims while touched.
class _TipAction extends StatefulWidget {
  const _TipAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_TipAction> createState() => _TipActionState();
}

class _TipActionState extends State<_TipAction> {
  bool _pressed = false;

  void _set(bool pressed) {
    if (mounted && pressed != _pressed) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AvoSizes.hitTarget,
          minWidth: AvoSizes.hitTarget,
        ),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          widthFactor: 1,
          heightFactor: 1,
          child: Opacity(
            opacity: _pressed ? _kPressedOpacity : 1,
            child: Text(
              widget.label,
              style: context.text(
                AvoTextStyle.callout,
                color: colors.tint,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

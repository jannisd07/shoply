import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/avo_figure.dart';

/// Figure size in empty states (A2 task: 96 pt).
const double _kFigureSize = 96;

/// Symbol size when an [EmptyState.icon] is given (Konzept: 48 pt, light).
const double _kIconSize = 48;

/// Pressed opacity next to [AvoMotion.pressedScale] (Konzept 00 §12.20).
const double _kPressedOpacity = 0.9;

/// What a screen or section shows instead of content that is not there yet
/// (Konzept 00 §12.26, §13): a title, one sentence, one action, and either
/// the mascot or a symbol.
///
/// Place it where the content would be (it does not centre itself in the
/// space it gets). The mascot is shown only below AX1 and only if no other
/// figure is on the same screen height; from AX1 on [icon] is used instead,
/// if given. Never use a figure for errors, offline or deletions.
class EmptyState extends StatelessWidget {
  /// Creates an empty state.
  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.pose,
    this.icon,
  });

  /// Short title, 20/25 semibold ("Noch nichts auf der Liste.").
  final String title;

  /// One sentence, 15/20 `secondaryLabel`.
  final String? message;

  /// The one action, a plain tinted text button; needs [onAction].
  final String? actionLabel;

  /// Runs the action.
  final VoidCallback? onAction;

  /// Shows the 3D figure in this pose (96 pt, decorative) below AX1.
  final AvoPose? pose;

  /// A symbol instead of the figure, e.g. `Icon(CupertinoIcons.checkmark)`;
  /// drawn 48 pt in `secondaryLabel` unless the icon sets its own values.
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ax = context.isAccessibilityText;
    final figurePose = pose;
    final symbol = icon;
    final label = actionLabel;
    final action = onAction;

    Widget? art;
    if (figurePose != null && !ax) {
      art = AvoFigure(pose: figurePose, size: _kFigureSize);
    } else if (symbol != null) {
      art = ExcludeSemantics(
        child: IconTheme.merge(
          data: IconThemeData(color: colors.secondaryLabel, size: _kIconSize),
          child: symbol,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AvoSpacing.xxxl,
        vertical: AvoSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (art != null) ...[art, const SizedBox(height: AvoSpacing.l)],
          Semantics(
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: context.text(AvoTextStyle.title3),
            ),
          ),
          if (message case final text?) ...[
            const SizedBox(height: AvoSpacing.xs),
            Text(
              text,
              textAlign: TextAlign.center,
              style: context.text(
                AvoTextStyle.subhead,
                color: colors.secondaryLabel,
              ),
            ),
          ],
          if (label != null && action != null) ...[
            const SizedBox(height: AvoSpacing.s),
            _PlainButton(label: label, onPressed: action),
          ],
        ],
      ),
    );
  }
}

/// Plain text button, 17/22 tint, at least 44 × 44, shrinking and dimming the
/// moment it is touched (spring, interruptible; Reduce Motion: dim only).
class _PlainButton extends StatefulWidget {
  const _PlainButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  State<_PlainButton> createState() => _PlainButtonState();
}

class _PlainButtonState extends State<_PlainButton>
    with SingleTickerProviderStateMixin {
  /// 0 = resting, 1 = fully pressed. Created eagerly: dispose must never be
  /// the first access (a lazy controller would look up TickerMode there).
  late final AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController.unbounded(vsync: this);
  }

  /// Read in build: [_to] also runs from onTapCancel while the tree is being
  /// torn down, when the context may no longer be used.
  bool _reduceMotion = false;

  void _to(double target) {
    if (!mounted) return;
    if (_reduceMotion) {
      _press
        ..stop()
        ..value = target;
      return;
    }
    _press.animateWith(
      SpringSimulation(AvoMotion.quick, _press.value, target, _press.velocity),
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = _reduceMotion = context.reduceMotion;
    return Semantics(
      container: true,
      button: true,
      label: widget.label,
      onTap: widget.onPressed,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTapDown: (_) => _to(1),
          onTapUp: (_) => _to(0),
          onTapCancel: () => _to(0),
          onTap: widget.onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AvoSizes.hitTarget,
              minWidth: AvoSizes.hitTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.s),
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: AnimatedBuilder(
                  animation: _press,
                  builder: (context, child) {
                    final t = _press.value.clamp(0.0, 1.0);
                    final scale = reduce
                        ? 1.0
                        : 1 - (1 - AvoMotion.pressedScale) * t;
                    return Opacity(
                      opacity: 1 - (1 - _kPressedOpacity) * t,
                      child: Transform.scale(scale: scale, child: child),
                    );
                  },
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: context.text(
                      AvoTextStyle.body,
                      color: context.colors.tint,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

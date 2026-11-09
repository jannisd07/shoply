import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/physics.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';

/// Size of a [CheckCircle].
enum CheckCircleSize {
  /// 26 pt circle in a 44 pt hit area (lists, D2).
  regular,

  /// 36 pt circle in a 56 pt hit area (shopping mode, Konzept 00 §12.7).
  large,

  /// 22 pt circle in a 44 pt hit area (compact rows, D2 `X-Avo`).
  small,
}

/// Sync and ownership state of a [CheckCircle] beyond checked / unchecked.
enum CheckState {
  /// Not done.
  open,

  /// Done by the current user.
  done,

  /// Done by someone else; their initial shows for 2 s after the change.
  doneByOther,

  /// The change waits for a connection: a small sync mark at the edge.
  pending,

  /// The change could not be saved: red ring with an exclamation mark.
  failed,
}

// D2 check circle (D2-Komponenten, D2-Liste, X-Einkaufsmodus).
const double _ringRegular = 1.6; // D2
const double _ringLarge = 2; // D2 X-Einkaufsmodus
const double _hitLarge = 56; // Konzept 00 §12.7
const double _markBoxRegular = 16; // D2
const double _markBoxLarge = 18; // D2 X-Einkaufsmodus
const double _ringSmall = 1.5; // D2 X-Avo
const double _markBoxSmall = 14; // D2 X-Avo
const double _markStroke = 3; // D2, in 24-unit icon space

/// The check mark starts drawing once the fill has covered this share.
const double _markStart = 0.35;

/// Badges at the circle's edge (Konzept 00 §12.7).
const double _avatarSize = 16;
const double _avatarRing = 1.5;
const double _syncGlyph = 10;
const double _syncDisc = 14;

/// How long the other person's initial stays (Konzept 00 §12.7). A display
/// time, not an animation duration.
const Duration _byOtherVisible = Duration(seconds: 2);

/// iOS dims unavailable controls to about half.
const double _disabledOpacity = 0.45;

/// Konzept 00 §12.20: pressed controls also drop to 90 % opacity.
const double _pressedOpacity = 0.9;

class _Metrics {
  const _Metrics({
    required this.diameter,
    required this.hit,
    required this.ring,
    required this.markBox,
    required this.mark,
  });

  final double diameter;
  final double hit;
  final double ring;
  final double markBox;

  /// The check mark's three points in 24-unit icon space.
  final List<Offset> mark;
}

const _regular = _Metrics(
  diameter: AvoSizes.checkCircle,
  hit: AvoSizes.hitTarget,
  ring: _ringRegular,
  markBox: _markBoxRegular,
  mark: [Offset(6, 12.6), Offset(10, 16.6), Offset(18, 8)], // D2
);

const _large = _Metrics(
  diameter: AvoSizes.checkCircleLarge,
  hit: _hitLarge,
  ring: _ringLarge,
  markBox: _markBoxLarge,
  mark: [Offset(5, 12.5), Offset(9.5, 17), Offset(19, 7.5)], // D2
);

const _small = _Metrics(
  diameter: CheckCircle.smallDiameter,
  hit: AvoSizes.hitTarget,
  ring: _ringSmall,
  markBox: _markBoxSmall,
  mark: [Offset(6, 12.6), Offset(10, 16.6), Offset(18, 8)], // as regular
);

_Metrics _metricsOf(CheckCircleSize size) => switch (size) {
  CheckCircleSize.regular => _regular,
  CheckCircleSize.large => _large,
  CheckCircleSize.small => _small,
};

/// The D2 check circle of an item row (Konzept 00 §12.7).
///
/// Checking fills the circle from its centre on the quick spring while the
/// check mark draws itself; tapping again mid-way reverses from where it
/// is. The tap reports `!checked` and plays the light haptic in the same
/// frame. Under Reduce Motion it switches at once. VoiceOver reads
/// "Milch abhaken" / "Milch wieder öffnen" with the checked state.
class CheckCircle extends StatefulWidget {
  /// Diameter of [CheckCircleSize.small]; also the glyph of `SelectCircle`.
  static const double smallDiameter = 22;

  /// Creates a check circle.
  const CheckCircle({
    super.key,
    required this.checked,
    required this.itemName,
    this.onChanged,
    this.size = CheckCircleSize.regular,
    this.state,
    this.byName,
    this.statusLabel,
  });

  /// Whether the item is done (filled with a check mark).
  final bool checked;

  /// The item's name, for the VoiceOver label.
  final String itemName;

  /// Called with `!checked` on tap; null disables the circle.
  final ValueChanged<bool>? onChanged;

  /// Regular (lists), large (shopping mode) or small (compact rows).
  final CheckCircleSize size;

  /// Extra state; defaults to [CheckState.done] / [CheckState.open] from
  /// [checked].
  final CheckState? state;

  /// Who checked it, for [CheckState.doneByOther] (their initial shows).
  final String? byName;

  /// VoiceOver text added to the value for pending, failed or done-by-other,
  /// for example "von Lena". Failed defaults to "Nicht gespeichert".
  final String? statusLabel;

  @override
  State<CheckCircle> createState() => _CheckCircleState();
}

class _CheckCircleState extends State<CheckCircle>
    with TickerProviderStateMixin {
  late final AnimationController _fill;
  late final AnimationController _badge;
  Timer? _badgeTimer;

  @override
  void initState() {
    super.initState();
    _fill = AnimationController(vsync: this, value: widget.checked ? 1 : 0);
    _badge = AnimationController(vsync: this);
  }

  CheckState _stateOf(CheckCircle w) =>
      w.state ?? (w.checked ? CheckState.done : CheckState.open);

  void _spring(AnimationController controller, double target) {
    if (context.reduceMotion) {
      controller.value = target;
      return;
    }
    controller.animateWith(
      SpringSimulation(
        AvoMotion.quick,
        controller.value,
        target,
        controller.velocity,
        snapToEnd: true,
      ),
    );
  }

  @override
  void didUpdateWidget(CheckCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.checked != widget.checked) {
      _spring(_fill, widget.checked ? 1 : 0);
    }
    final now = _stateOf(widget);
    final was = _stateOf(oldWidget);
    if (now == CheckState.doneByOther &&
        was != CheckState.doneByOther &&
        widget.byName != null) {
      _showBadge();
    } else if (now != CheckState.doneByOther && was == CheckState.doneByOther) {
      _hideBadge();
    }
  }

  void _showBadge() {
    _badgeTimer?.cancel();
    _spring(_badge, 1);
    _badgeTimer = Timer(_byOtherVisible, _hideBadge);
  }

  void _hideBadge() {
    _badgeTimer?.cancel();
    _badgeTimer = null;
    if (mounted) _spring(_badge, 0);
  }

  @override
  void dispose() {
    _badgeTimer?.cancel();
    _fill.dispose();
    _badge.dispose();
    super.dispose();
  }

  void _toggle() {
    final onChanged = widget.onChanged;
    if (onChanged == null) return;
    onChanged(!widget.checked);
    unawaited(AvoHaptics.light());
  }

  String _value(BuildContext context, CheckState state) {
    final status =
        widget.statusLabel ??
        (state == CheckState.failed ? context.tr('common_not_saved') : null);
    return [
      if (widget.checked && state != CheckState.failed)
        context.tr('common_checked_state'),
      ?status,
    ].join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final m = _metricsOf(widget.size);
    final state = _stateOf(widget);
    final enabled = widget.onChanged != null;
    final badgeCenter = m.hit / 2 + m.diameter / 2 * math.sqrt1_2;
    final byName = widget.byName?.trim() ?? '';

    Widget visual = SizedBox.square(
      dimension: m.hit,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(
            child: SizedBox.square(
              dimension: m.diameter,
              child: CustomPaint(
                painter: _CirclePainter(
                  progress: _fill,
                  metrics: m,
                  ringColor: colors.uncheckedRing,
                  fillColor: colors.tintFill,
                  markColor: colors.onTint,
                  errorColor: colors.red,
                  failed: state == CheckState.failed,
                ),
              ),
            ),
          ),
          if (state == CheckState.pending)
            Positioned(
              left: badgeCenter - _syncDisc / 2,
              top: badgeCenter - _syncDisc / 2,
              child: _SyncBadge(
                disc: colors.surface,
                glyph: colors.secondaryLabel,
              ),
            ),
          if (state == CheckState.doneByOther && byName.isNotEmpty)
            Positioned(
              left: badgeCenter - _avatarSize / 2,
              top: badgeCenter - _avatarSize / 2,
              child: AnimatedBuilder(
                animation: _badge,
                child: _Initial(initial: byName.characters.first.toUpperCase()),
                builder: (context, child) {
                  final v = _badge.value.clamp(0.0, 1.0);
                  if (v == 0) return const SizedBox.shrink();
                  return Opacity(
                    opacity: v,
                    child: context.reduceMotion
                        ? child
                        : Transform.scale(scale: 0.6 + 0.4 * v, child: child),
                  );
                },
              ),
            ),
        ],
      ),
    );
    if (!enabled) visual = Opacity(opacity: _disabledOpacity, child: visual);

    return Semantics(
      container: true,
      button: true,
      checked: widget.checked,
      enabled: enabled,
      label: context.tr(
        widget.checked ? 'common_uncheck' : 'common_check_off',
        params: {'name': widget.itemName},
      ),
      value: _value(context, state),
      onTap: enabled ? _toggle : null,
      child: ExcludeSemantics(
        child: _Pressable(onTap: enabled ? _toggle : null, child: visual),
      ),
    );
  }
}

class _CirclePainter extends CustomPainter {
  _CirclePainter({
    required this.progress,
    required this.metrics,
    required this.ringColor,
    required this.fillColor,
    required this.markColor,
    required this.errorColor,
    required this.failed,
  }) : super(repaint: progress);

  /// 0 = open ring, 1 = filled with the full check mark.
  final Animation<double> progress;
  final _Metrics metrics;
  final Color ringColor;
  final Color fillColor;
  final Color markColor;
  final Color errorColor;
  final bool failed;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final unit = metrics.markBox / 24;
    final t = failed ? 0.0 : progress.value.clamp(0.0, 1.0);

    if (t < 1) {
      canvas.drawCircle(
        c,
        r - metrics.ring / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = metrics.ring
          ..color = failed ? errorColor : ringColor,
      );
    }
    if (t > 0) canvas.drawCircle(c, r * t, Paint()..color = fillColor);

    final draw = ((t - _markStart) / (1 - _markStart)).clamp(0.0, 1.0);
    if (draw > 0) {
      final origin = c - Offset(metrics.markBox / 2, metrics.markBox / 2);
      final p = [for (final o in metrics.mark) origin + o * unit];
      final path = Path()
        ..moveTo(p[0].dx, p[0].dy)
        ..lineTo(p[1].dx, p[1].dy)
        ..lineTo(p[2].dx, p[2].dy);
      final metric = path.computeMetrics().first;
      canvas.drawPath(
        metric.extractPath(0, metric.length * draw),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _markStroke * unit
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = markColor,
      );
    }

    if (failed) {
      final stroke = _markStroke * unit;
      final paint = Paint()
        ..color = errorColor
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas
        ..drawLine(c + Offset(0, -r * 0.45), c + Offset(0, r * 0.1), paint)
        ..drawCircle(c + Offset(0, r * 0.42), stroke * 0.6, paint);
    }
  }

  @override
  bool shouldRepaint(_CirclePainter old) =>
      old.progress != progress ||
      old.metrics != metrics ||
      old.ringColor != ringColor ||
      old.fillColor != fillColor ||
      old.markColor != markColor ||
      old.errorColor != errorColor ||
      old.failed != failed;
}

class _SyncBadge extends StatelessWidget {
  const _SyncBadge({required this.disc, required this.glyph});

  final Color disc;
  final Color glyph;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(color: disc, shape: const CircleBorder()),
      child: SizedBox.square(
        dimension: _syncDisc,
        child: Center(
          child: Icon(
            CupertinoIcons.arrow_2_circlepath,
            size: _syncGlyph,
            color: glyph,
          ),
        ),
      ),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.tintSoft,
        shape: CircleBorder(
          side: BorderSide(
            color: colors.surface,
            width: _avatarRing,
            strokeAlign: BorderSide.strokeAlignOutside,
          ),
        ),
      ),
      child: SizedBox.square(
        dimension: _avatarSize,
        child: Padding(
          padding: const EdgeInsets.all(AvoSpacing.xxs),
          // A badge glyph: scaled to the circle instead of growing with
          // Dynamic Type (like iOS badges).
          child: FittedBox(
            child: Text(
              initial,
              style: context.text(
                AvoTextStyle.caption2,
                weight: FontWeight.w700,
                color: colors.tint,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Scales its child to [AvoMotion.pressedScale] and 90 % opacity while a
/// finger is down, on the quick spring (instant opacity only under Reduce
/// Motion).
class _Pressable extends StatefulWidget {
  const _Pressable({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback? onTap;

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
    if (widget.onTap == null && _press.value != 0) _set(false);
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _reduceMotion = context.reduceMotion;
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: widget.onTap,
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

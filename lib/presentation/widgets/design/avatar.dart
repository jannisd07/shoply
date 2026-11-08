import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';

// D2 avatars: "mit Lena" chip (20 pt, 11/20 bold), list header stack (24 pt,
// 11 pt semibold, 2 pt ring, 6 pt overlap), X-Einkaufsmodus presence dot.
const double _ringWidth = 2; // D2 `box-shadow: 0 0 0 2px`
const double _overlapFactor = 0.25; // D2: 6 pt overlap at 24 pt
const double _plusPadding = AvoSpacing.xs; // "+12" needs a little more room

/// The presence dot (D2 X-Einkaufsmodus: 9 pt, 2 pt ring, at -2 / -2 of the
/// avatar's bottom corner).
const double _dotSize = 9; // D2
const double _dotRing = 2; // D2
const double _dotOffset = -2; // D2 `right:-2px; bottom:-2px`

/// The one pulse when the dot appears: a halo grows to this multiple of the
/// dot and fades out from this opacity.
const double _haloGrowth = 1.6;
const double _haloAlpha = 0.45;

/// Size of an [Avatar].
enum AvatarSize {
  /// 20 pt: inline in chips and meta lines (D2 "mit Lena").
  small(20),

  /// 24 pt: stacks in list headers and rows (D2-Liste, D2-Home).
  medium(24),

  /// 32 pt: larger rows.
  large(32);

  const AvatarSize(this.dimension);

  /// Diameter in points.
  final double dimension;
}

/// Glyph style of the initial per size. The glyph keeps its size under
/// Dynamic Type, like iOS avatars and badges; the text next to it grows.
TextStyle _initialStyle(BuildContext context, AvatarSize size, Color color) =>
    switch (size) {
      AvatarSize.small => context.text(
        AvoTextStyle.caption2,
        weight: FontWeight.w700,
        color: color,
      ), // D2 11 pt bold
      AvatarSize.medium => context.text(
        AvoTextStyle.caption2,
        weight: FontWeight.w600,
        color: color,
      ), // D2 11 pt semibold
      AvatarSize.large => context.text(
        AvoTextStyle.subhead,
        weight: FontWeight.w600,
        color: color,
      ),
    };

/// First letter of [name], upper case ("lena" → "L"); empty for an empty
/// name.
String _initialOf(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '';
  return trimmed.characters.first.toUpperCase();
}

/// A person as an initial in a circle (Konzept 00 §12.29, optics D2): the
/// accent [AvoColors.tint] on [AvoColors.tintSoft], or neutral
/// [AvoColors.label] on an opaque grey for the current user.
///
/// VoiceOver reads [name] (or "Lena kauft gerade ein" with [presence]). The
/// label merges into the row or card around it; wrap the avatar in
/// `ExcludeSemantics` where the name is already spoken.
class Avatar extends StatelessWidget {
  /// Creates an avatar for [name].
  const Avatar({
    super.key,
    required this.name,
    this.size = AvatarSize.medium,
    this.neutral = false,
    this.presence = false,
    this.ringColor,
    this.semanticLabel,
  });

  /// The person's display name; the first letter is shown.
  final String name;

  /// 20, 24 or 32 pt.
  final AvatarSize size;

  /// Grey instead of green (D2-Liste: the current user "J").
  final bool neutral;

  /// Adds the green [PresenceDot] at the bottom corner: the person is
  /// shopping right now.
  final bool presence;

  /// Colour of a 2 pt ring around the circle, drawn outside its bounds
  /// (stacks: the surface behind). Null draws no ring.
  final Color? ringColor;

  /// VoiceOver text; defaults to [name], or "{name} kauft gerade ein"
  /// (`common_shopping_now`) with [presence].
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label =
        semanticLabel ??
        (presence
            ? context.tr('common_shopping_now', params: {'name': name.trim()})
            : name.trim());
    final Widget circle = _AvatarCircle(
      text: _initialOf(name),
      size: size,
      neutral: neutral,
      ringColor: ringColor,
    );
    final Widget visual = presence
        ? Stack(
            clipBehavior: Clip.none,
            children: [
              circle,
              PositionedDirectional(
                end: _dotOffset,
                bottom: _dotOffset,
                child: PresenceDot(ringColor: ringColor ?? colors.surface),
              ),
            ],
          )
        : circle;
    return Semantics(
      label: label.isEmpty ? null : label,
      child: ExcludeSemantics(child: visual),
    );
  }
}

/// The painted circle with its glyph, shared by [Avatar] and the "+n" of
/// [AvatarStack].
class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({
    required this.text,
    required this.size,
    required this.neutral,
    this.ringColor,
    this.capsule = false,
  });

  final String text;
  final AvatarSize size;
  final bool neutral;
  final Color? ringColor;

  /// Grows sideways for longer text ("+12").
  final bool capsule;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Opaque even in the neutral tone: stacked avatars must hide the one
    // below, and `fill` alone is translucent.
    final background = neutral
        ? Color.alphaBlend(colors.fill, colors.surface)
        : colors.tintSoft;
    final foreground = neutral ? colors.label : colors.tint;
    final ring = ringColor;
    final side = ring == null
        ? BorderSide.none
        : BorderSide(
            color: ring,
            width: _ringWidth,
            strokeAlign: BorderSide.strokeAlignOutside,
          );
    final d = size.dimension;
    final glyph = MediaQuery.withNoTextScaling(
      child: Builder(
        builder: (context) => Text(
          text,
          maxLines: 1,
          softWrap: false,
          textAlign: TextAlign.center,
          style: _initialStyle(context, size, foreground),
        ),
      ),
    );
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: background,
        shape: capsule ? StadiumBorder(side: side) : CircleBorder(side: side),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: d,
          maxWidth: capsule ? double.infinity : d,
          minHeight: d,
          maxHeight: d,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: capsule ? _plusPadding : 0),
          // Bold Text can make the glyph wider than the circle: shrink it
          // rather than clip it.
          child: Center(
            widthFactor: 1,
            child: FittedBox(fit: BoxFit.scaleDown, child: glyph),
          ),
        ),
      ),
    );
  }
}

/// Overlapping avatars of a shared list (D2-Liste, D2-Home): at most [max]
/// circles, then "+n" for the rest. Each has a 2 pt ring in [ringColor] so
/// the overlap reads; the first sits on top.
///
/// One VoiceOver label for the group ([semanticLabel], for example "Geteilt
/// mit Jannis, Lena und Mia"; defaults to the names), merged into the row or
/// card around it.
class AvatarStack extends StatelessWidget {
  /// Creates a stack of [names].
  const AvatarStack({
    super.key,
    required this.names,
    this.size = AvatarSize.medium,
    this.max = 3,
    this.ringColor,
    this.neutralFirst = false,
    this.semanticLabel,
  });

  /// Display names, in order.
  final List<String> names;

  /// Size of each circle.
  final AvatarSize size;

  /// Circles shown before "+n"; at least 1.
  final int max;

  /// Ring colour, the surface the stack sits on; defaults to
  /// [AvoColors.surface] (D2-Liste header on the grouped background:
  /// [AvoColors.background]).
  final Color? ringColor;

  /// Draws the first avatar grey (the current user, D2-Liste "J").
  final bool neutralFirst;

  /// VoiceOver text for the whole stack; defaults to the names.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    if (names.isEmpty) return const SizedBox.shrink();
    final ring = ringColor ?? context.colors.surface;
    final limit = max < 1 ? 1 : max;
    final shown = names.length > limit ? names.sublist(0, limit) : names;
    final rest = names.length - shown.length;
    final d = size.dimension;
    final step = d - d * _overlapFactor;

    final circles = <Widget>[
      for (var i = 0; i < shown.length; i++)
        _AvatarCircle(
          text: _initialOf(shown[i]),
          size: size,
          neutral: neutralFirst && i == 0,
          ringColor: ring,
        ),
      if (rest > 0)
        _AvatarCircle(
          text: '+$rest',
          size: size,
          neutral: true,
          ringColor: ring,
          capsule: true,
        ),
    ];

    // Each circle is shifted by `step`; painted last to first so the first
    // one lies on top.
    final row = Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: EdgeInsetsDirectional.only(
            start: step * (circles.length - 1),
          ),
          child: circles.last,
        ),
        for (var i = circles.length - 2; i >= 0; i--)
          PositionedDirectional(start: step * i, top: 0, child: circles[i]),
      ],
    );

    final label = semanticLabel ?? names.map((n) => n.trim()).join(', ');
    return Semantics(
      label: label,
      child: ExcludeSemantics(child: row),
    );
  }
}

/// The green "is shopping right now" dot ([AvoColors.presence]) with a ring
/// in the surface colour behind it (D2 X-Einkaufsmodus).
///
/// When it appears it pulses once, softly, on the [AvoMotion.move] spring:
/// a halo grows and fades. Never loops; static under Reduce Motion.
/// VoiceOver reads [semanticLabel] or "{name} kauft gerade ein"
/// (`common_shopping_now`); without either it is decoration.
class PresenceDot extends StatefulWidget {
  /// Creates a presence dot.
  const PresenceDot({
    super.key,
    this.name,
    this.semanticLabel,
    this.ringColor,
    this.pulse = true,
  });

  /// Diameter of the dot without its ring (D2: 9 pt).
  static const double size = _dotSize;

  /// Who is shopping, for the VoiceOver text.
  final String? name;

  /// VoiceOver text; overrides the one built from [name].
  final String? semanticLabel;

  /// Ring colour (the surface behind); defaults to [AvoColors.background].
  final Color? ringColor;

  /// Pulse once when the dot appears (never under Reduce Motion).
  final bool pulse;

  @override
  State<PresenceDot> createState() => _PresenceDotState();
}

class _PresenceDotState extends State<PresenceDot>
    with SingleTickerProviderStateMixin {
  /// 0 = before the pulse, 1 = pulse over (halo gone).
  late final AnimationController _halo;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _halo = AnimationController(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.pulse || context.reduceMotion) {
      _halo.value = 1;
      return;
    }
    _halo.animateWith(
      SpringSimulation(AvoMotion.move, 0, 1, 0, snapToEnd: true),
    );
  }

  @override
  void didUpdateWidget(PresenceDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.pulse && _halo.isAnimating) {
      _halo
        ..stop()
        ..value = 1;
    }
  }

  @override
  void dispose() {
    _halo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final name = widget.name?.trim();
    final label =
        widget.semanticLabel ??
        (name == null || name.isEmpty
            ? null
            : context.tr('common_shopping_now', params: {'name': name}));
    final dot = SizedBox.square(
      dimension: _dotSize,
      child: CustomPaint(
        painter: _DotPainter(
          halo: _halo,
          color: colors.presence,
          ring: widget.ringColor ?? colors.background,
        ),
      ),
    );
    if (label == null) return ExcludeSemantics(child: dot);
    return Semantics(
      label: label,
      child: ExcludeSemantics(child: dot),
    );
  }
}

class _DotPainter extends CustomPainter {
  _DotPainter({required this.halo, required this.color, required this.ring})
    : super(repaint: halo);

  final Animation<double> halo;
  final Color color;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final t = halo.value.clamp(0.0, 1.0);
    if (t > 0 && t < 1) {
      canvas.drawCircle(
        c,
        (r + _dotRing) * (1 + (_haloGrowth - 1) * t),
        Paint()..color = color.withValues(alpha: _haloAlpha * (1 - t)),
      );
    }
    canvas
      ..drawCircle(c, r + _dotRing, Paint()..color = ring)
      ..drawCircle(c, r, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_DotPainter old) =>
      old.halo != halo || old.color != color || old.ring != ring;
}

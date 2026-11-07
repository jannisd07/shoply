import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';

/// The four poses of the 3D mascot in `assets/avo/`.
enum AvoPose {
  /// Greets: onboarding, the Home card ("Avo winkt").
  waving,

  /// Pleased: hero chips ("4 von 6 Zutaten da", "Avo freut sich").
  excited,

  /// Considers something: tips, searching ("Avo überlegt").
  thinking,

  /// Celebrates: the success moment.
  celebrating,
}

/// Opacity of the shadow ellipse (D2 `.avo-sh`: rgba(31,90,40,.22)).
const double _kShadowAlpha = 0.22; // D2

/// The ellipse spans the middle 60 % of the figure (D2 `.avo-sh` left 20 %).
const double _kShadowWidthFactor = 0.6; // D2

/// Shadow height relative to the figure (D2: 10 pt under a 137 pt figure).
const double _kShadowHeightFactor = 0.075; // D2

/// Smallest shadow height, so small chips still get a visible ellipse.
const double _kShadowMinHeight = 4; // D2 (hero chip: 10 pt under 27 pt)

/// The ellipse sits slightly below the feet (D2 `bottom: -3px` at 137 pt).
const double _kShadowDropFactor = 0.3; // D2

/// Where the gradient fades out (D2 `rgba(..,0) 70%`).
const double _kShadowFadeStop = 0.7; // D2

/// Avo, the real 3D figure from `assets/avo/` with the soft green shadow
/// ellipse D2 puts under it.
///
/// Owner rule: at most one figure per screen height, and never next to
/// allergies, money problems, errors, offline notes or deletions. Empty
/// states drop the figure from AX1 on (`EmptyState` does that itself).
class AvoFigure extends StatelessWidget {
  /// Creates a figure in [pose], fitted into a [size] × [size] box.
  const AvoFigure({
    super.key,
    required this.pose,
    this.size = 120,
    this.decorative = true,
    this.semanticLabel,
  }) : assert(
         decorative || semanticLabel != null,
         'A figure that is not decorative needs a semanticLabel.',
       );

  /// Which pose to show.
  final AvoPose pose;

  /// Edge of the square box the artwork is fitted into (contain): the figure
  /// is [size] tall and about 0.8 × [size] wide.
  final double size;

  /// Hidden from VoiceOver (the default): the figure only decorates text that
  /// says the same thing.
  final bool decorative;

  /// What VoiceOver reads when [decorative] is false, e.g. "Avo freut sich".
  final String? semanticLabel;

  /// The asset path for [pose].
  static String assetFor(AvoPose pose) => 'assets/avo/avo_${pose.name}.png';

  @override
  Widget build(BuildContext context) {
    final shadowHeight = math.max(
      _kShadowMinHeight,
      size * _kShadowHeightFactor,
    );
    final cacheHeight = (size * MediaQuery.devicePixelRatioOf(context)).round();
    final figure = SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: size * (1 - _kShadowWidthFactor) / 2,
            width: size * _kShadowWidthFactor,
            bottom: -shadowHeight * _kShadowDropFactor,
            height: shadowHeight,
            child: CustomPaint(
              painter: _ShadowPainter(
                context.colors.tintFill.withValues(alpha: _kShadowAlpha),
              ),
            ),
          ),
          Positioned.fill(
            child: Image.asset(
              assetFor(pose),
              fit: BoxFit.contain,
              cacheHeight: cacheHeight > 0 ? cacheHeight : null,
              filterQuality: FilterQuality.medium,
              excludeFromSemantics: true,
              gaplessPlayback: true,
            ),
          ),
        ],
      ),
    );
    if (decorative) return ExcludeSemantics(child: figure);
    return Semantics(
      image: true,
      label: semanticLabel,
      child: ExcludeSemantics(child: figure),
    );
  }
}

/// A radial gradient squeezed into an ellipse (a plain [RadialGradient] is
/// always circular).
class _ShadowPainter extends CustomPainter {
  const _ShadowPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final radius = size.width / 2;
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..scale(1, size.height / size.width);
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        radius,
        [color, color.withValues(alpha: 0)],
        const [0, _kShadowFadeStop],
      );
    canvas
      ..drawCircle(Offset.zero, radius, paint)
      ..restore();
  }

  @override
  bool shouldRepaint(_ShadowPainter old) => old.color != color;
}

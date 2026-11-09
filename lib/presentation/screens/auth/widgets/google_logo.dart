import 'package:flutter/widgets.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';

// Google "G" in Google's own colours (Konzept 17 §9.9: partner brand data,
// not design tokens). Paths from Google's sign-in button kit, 48 view box.
const Color _kGoogleRed = Color(0xFFEA4335); // brand data
const Color _kGoogleBlue = Color(0xFF4285F4); // brand data
const Color _kGoogleYellow = Color(0xFFFBBC05); // brand data
const Color _kGoogleGreen = Color(0xFF34A853); // brand data
const double _kViewBox = 48;

const List<(AvoIconPath, Color)> _kParts = [
  (
    AvoIconPath(
      'M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0'
      ' 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z',
    ),
    _kGoogleRed,
  ),
  (
    AvoIconPath(
      'M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26'
      ' 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z',
    ),
    _kGoogleBlue,
  ),
  (
    AvoIconPath(
      'M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19'
      'C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z',
    ),
    _kGoogleYellow,
  ),
  (
    AvoIconPath(
      'M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16'
      ' 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24'
      ' 48z',
    ),
    _kGoogleGreen,
  ),
];

/// The Google "G", drawn from vectors in the app (no image from the
/// network, Konzept 17 §3.5, Bug 12). Decorative: the button carries the
/// label.
class GoogleMark extends StatelessWidget {
  const GoogleMark({super.key, this.size = 18});

  /// Side of the square in points.
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: const CustomPaint(painter: _GoogleMarkPainter()),
    ),
  );
}

class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / _kViewBox;
    canvas.save();
    canvas.scale(scale);
    for (final (shape, color) in _kParts) {
      canvas.drawPath(
        shape.toPath(),
        Paint()
          ..color = color
          ..isAntiAlias = true,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

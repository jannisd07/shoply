import 'package:flutter/material.dart';

/// Social Button - Full-width pill-shaped button with icon for social login
class SocialButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Widget? customIcon;
  final Color backgroundColor;
  final Color textColor;
  final Color iconColor;
  final VoidCallback onPressed;

  const SocialButton({
    super.key,
    required this.text,
    this.icon,
    this.customIcon,
    required this.backgroundColor,
    required this.textColor,
    required this.iconColor,
    required this.onPressed,
  }) : assert(icon != null || customIcon != null, 'Either icon or customIcon must be provided');

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (customIcon != null)
              customIcon!
            else
              Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            const SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Official Google "G" Logo - accurate reproduction
class GoogleLogo extends StatelessWidget {
  final double size;
  
  const GoogleLogo({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  // Official Google brand colors
  static const Color googleBlue = Color(0xFF4285F4);
  static const Color googleGreen = Color(0xFF34A853);
  static const Color googleYellow = Color(0xFFFBBC05);
  static const Color googleRed = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width;
    final double strokeWidth = s * 0.18;
    final double radius = (s - strokeWidth) / 2;
    final Offset center = Offset(s / 2, s / 2);
    
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Draw the colored arcs of the G
    // Red (top) - from 225° to 315° (45° on each side of top)
    paint.color = googleRed;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -2.356, // 225° in radians (-135°)
      1.571,  // 90° sweep
      false,
      paint,
    );

    // Yellow (left) - from 135° to 225°
    paint.color = googleYellow;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      2.356, // 135° in radians
      0.785, // 45° sweep
      false,
      paint,
    );

    // Green (bottom-left) - from 45° to 135°
    paint.color = googleGreen;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0.785, // 45° in radians
      1.571, // 90° sweep
      false,
      paint,
    );

    // Blue (right) - from -45° to 45°
    paint.color = googleBlue;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -0.785, // -45° in radians
      0.785,  // 45° sweep (to 0°)
      false,
      paint,
    );

    // Blue horizontal bar
    final barPaint = Paint()
      ..color = googleBlue
      ..style = PaintingStyle.fill;
    
    final barHeight = strokeWidth;
    final barTop = center.dy - barHeight / 2;
    canvas.drawRect(
      Rect.fromLTRB(center.dx, barTop, s * 0.95, barTop + barHeight),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

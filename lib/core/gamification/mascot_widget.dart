import 'package:flutter/material.dart';
import 'dart:math';

/// Shoply Mascot - A cute round sprout character
class ShoplySprout extends StatefulWidget {
  final double size;
  final MascotMood mood;
  final String? message;
  final bool animate;
  final VoidCallback? onTap;

  const ShoplySprout({
    super.key,
    this.size = 80,
    this.mood = MascotMood.happy,
    this.message,
    this.animate = true,
    this.onTap,
  });

  @override
  State<ShoplySprout> createState() => _ShoplySproutState();
}

class _ShoplySproutState extends State<ShoplySprout>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounceAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    _bounceAnimation = Tween<double>(begin: 0, end: 6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _rotateAnimation = Tween<double>(begin: -0.03, end: 0.03).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.animate) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.message != null) ...[
            _buildSpeechBubble(context),
            const SizedBox(height: 6),
          ],
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, widget.animate ? -_bounceAnimation.value : 0),
                child: Transform.rotate(
                  angle: widget.animate ? _rotateAnimation.value : 0,
                  child: child,
                ),
              );
            },
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: CustomPaint(
                painter: _SproutPainter(mood: widget.mood),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeechBubble(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      constraints: BoxConstraints(maxWidth: widget.size * 2.5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        widget.message!,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.white : const Color(0xFF1C1C1E),
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

enum MascotMood { happy, excited, thinking, sleepy, proud, waving, celebrate }

class _SproutPainter extends CustomPainter {
  final MascotMood mood;
  _SproutPainter({required this.mood});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.55;
    final bodyRadius = size.width * 0.38;

    // Shadow
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, size.height * 0.92), width: bodyRadius * 1.4, height: size.height * 0.08),
      Paint()..color = Colors.black.withValues(alpha: 0.1),
    );

    // Body gradient - cute round shape
    final bodyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        radius: 1.2,
        colors: [const Color(0xFF5ED685), const Color(0xFF34C759)],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: bodyRadius));
    canvas.drawCircle(Offset(cx, cy), bodyRadius, bodyPaint);

    // Highlight
    canvas.drawCircle(
      Offset(cx - bodyRadius * 0.35, cy - bodyRadius * 0.35),
      bodyRadius * 0.18,
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );

    // Leaf stem
    final stemPaint = Paint()
      ..color = const Color(0xFF2AAA4A)
      ..strokeWidth = size.width * 0.045
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx, cy - bodyRadius), Offset(cx, cy - bodyRadius - size.height * 0.08), stemPaint);

    // Leaves
    _drawLeaf(canvas, Offset(cx, cy - bodyRadius - size.height * 0.06), size, -0.4);
    _drawLeaf(canvas, Offset(cx, cy - bodyRadius - size.height * 0.06), size, 0.4);

    // Face
    _drawFace(canvas, size, cx, cy, bodyRadius);
  }

  void _drawLeaf(Canvas canvas, Offset base, Size size, double angle) {
    final leafSize = size.width * 0.18;
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.rotate(angle);
    
    final leafPath = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(-leafSize * 0.6, -leafSize * 0.4, 0, -leafSize)
      ..quadraticBezierTo(leafSize * 0.6, -leafSize * 0.4, 0, 0);
    
    canvas.drawPath(leafPath, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFF5ED685), const Color(0xFF34C759)],
      ).createShader(Rect.fromLTWH(-leafSize, -leafSize, leafSize * 2, leafSize)));
    
    // Leaf vein
    canvas.drawLine(Offset(0, -leafSize * 0.15), Offset(0, -leafSize * 0.7),
      Paint()..color = const Color(0xFF2AAA4A)..strokeWidth = 1.2..strokeCap = StrokeCap.round);
    canvas.restore();
  }

  void _drawFace(Canvas canvas, Size size, double cx, double cy, double r) {
    final eyeY = cy - r * 0.1;
    final eyeSpacing = r * 0.4;
    final eyeSize = r * 0.18;

    // Blush
    canvas.drawCircle(Offset(cx - r * 0.55, cy + r * 0.2), r * 0.12,
      Paint()..color = const Color(0xFFFFB3B3).withValues(alpha: 0.5));
    canvas.drawCircle(Offset(cx + r * 0.55, cy + r * 0.2), r * 0.12,
      Paint()..color = const Color(0xFFFFB3B3).withValues(alpha: 0.5));

    switch (mood) {
      case MascotMood.happy:
      case MascotMood.waving:
        _drawCuteEyes(canvas, cx, eyeY, eyeSpacing, eyeSize);
        _drawSmile(canvas, cx, cy + r * 0.35, r * 0.25);
        break;
      case MascotMood.excited:
      case MascotMood.celebrate:
        _drawSparkleEyes(canvas, cx, eyeY, eyeSpacing, eyeSize * 1.2);
        _drawOpenSmile(canvas, cx, cy + r * 0.35, r * 0.28);
        break;
      case MascotMood.thinking:
        _drawLookingEyes(canvas, cx, eyeY, eyeSpacing, eyeSize, 0, -1);
        _drawDot(canvas, cx + r * 0.15, cy + r * 0.38, r * 0.06);
        break;
      case MascotMood.sleepy:
        _drawClosedEyes(canvas, cx, eyeY, eyeSpacing, eyeSize);
        _drawLine(canvas, cx, cy + r * 0.38, r * 0.15);
        break;
      case MascotMood.proud:
        _drawLookingEyes(canvas, cx, eyeY, eyeSpacing, eyeSize, 0, 0);
        _drawSmile(canvas, cx, cy + r * 0.35, r * 0.22);
        break;
    }
  }

  void _drawCuteEyes(Canvas canvas, double cx, double y, double spacing, double s) {
    final paint = Paint()..color = const Color(0xFF2D2D2D)..strokeWidth = s * 0.5..strokeCap = StrokeCap.round;
    for (final dx in [-spacing, spacing]) {
      final path = Path()
        ..moveTo(cx + dx - s, y)
        ..quadraticBezierTo(cx + dx, y - s * 0.8, cx + dx + s, y);
      canvas.drawPath(path, paint..style = PaintingStyle.stroke);
    }
  }

  void _drawSparkleEyes(Canvas canvas, double cx, double y, double spacing, double s) {
    for (final dx in [-spacing, spacing]) {
      _drawStar(canvas, Offset(cx + dx, y), s, Paint()..color = const Color(0xFFFFD700));
    }
  }

  void _drawStar(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final a = (i * 144 - 90) * pi / 180;
      final p = Offset(c.dx + r * cos(a), c.dy + r * sin(a));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawLookingEyes(Canvas canvas, double cx, double y, double spacing, double s, double ox, double oy) {
    for (final dx in [-spacing, spacing]) {
      canvas.drawCircle(Offset(cx + dx, y), s, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(cx + dx + ox * s * 0.3, y + oy * s * 0.3), s * 0.5, Paint()..color = const Color(0xFF2D2D2D));
    }
  }

  void _drawClosedEyes(Canvas canvas, double cx, double y, double spacing, double s) {
    final paint = Paint()..color = const Color(0xFF2D2D2D)..strokeWidth = s * 0.4..strokeCap = StrokeCap.round;
    for (final dx in [-spacing, spacing]) {
      final path = Path()
        ..moveTo(cx + dx - s * 0.8, y)
        ..quadraticBezierTo(cx + dx, y + s * 0.5, cx + dx + s * 0.8, y);
      canvas.drawPath(path, paint..style = PaintingStyle.stroke);
    }
  }

  void _drawSmile(Canvas canvas, double cx, double y, double w) {
    final path = Path()
      ..moveTo(cx - w, y)
      ..quadraticBezierTo(cx, y + w * 0.7, cx + w, y);
    canvas.drawPath(path, Paint()..color = const Color(0xFF2D2D2D)..strokeWidth = w * 0.18..strokeCap = StrokeCap.round..style = PaintingStyle.stroke);
  }

  void _drawOpenSmile(Canvas canvas, double cx, double y, double w) {
    final path = Path()
      ..moveTo(cx - w, y - w * 0.1)
      ..quadraticBezierTo(cx, y + w * 0.9, cx + w, y - w * 0.1)
      ..quadraticBezierTo(cx, y + w * 0.3, cx - w, y - w * 0.1);
    canvas.drawPath(path, Paint()..color = const Color(0xFF2D2D2D));
  }

  void _drawDot(Canvas canvas, double x, double y, double r) {
    canvas.drawCircle(Offset(x, y), r, Paint()..color = const Color(0xFF2D2D2D));
  }

  void _drawLine(Canvas canvas, double cx, double y, double w) {
    canvas.drawLine(Offset(cx - w, y), Offset(cx + w, y), Paint()..color = const Color(0xFF2D2D2D)..strokeWidth = w * 0.15..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _SproutPainter oldDelegate) => oldDelegate.mood != mood;
}

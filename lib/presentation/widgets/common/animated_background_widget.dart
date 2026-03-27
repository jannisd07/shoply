import 'package:flutter/material.dart';
import 'dart:math' as math;

class AnimatedBackgroundWidget extends StatefulWidget {
  final Widget? child;
  
  const AnimatedBackgroundWidget({super.key, this.child});

  @override
  State<AnimatedBackgroundWidget> createState() => _AnimatedBackgroundWidgetState();
}

class _AnimatedBackgroundWidgetState extends State<AnimatedBackgroundWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<ShapeData> shapes;
  final math.Random random = math.Random();

  @override
  void initState() {
    super.initState();
    
    // Generiere zufällige Anfangspositionen für alle Formen
    shapes = List.generate(3, (index) => ShapeData.random(random));
    
    _controller = AnimationController(
      duration: const Duration(seconds: 25),
      vsync: this,
    );
    
    _controller.addStatusListener((status) {
      // Wenn Animation zu Ende, generiere neue zufällige Positionen und starte neu
      if (status == AnimationStatus.completed) {
        setState(() {
          shapes = List.generate(3, (index) => ShapeData.random(random));
        });
        _controller.forward(from: 0.0);
      }
    });
    
    // Starte die erste Animation
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Hintergrund Gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFE8D4F8), // Hell Lila
                Color(0xFFFFC4D6), // Rosa
                Color(0xFFFFE8E0), // Pfirsich
              ],
            ),
          ),
        ),
        
        // Animierte Formen
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: AnimatedShapesPainter(
                animation: _controller.value,
                shapes: shapes,
              ),
              size: Size.infinite,
            );
          },
        ),
        
        // Ihr Content
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class ShapeData {
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  final double controlX1;
  final double controlY1;
  final double controlX2;
  final double controlY2;
  final double width;
  final double height;
  final Color color;
  final double rotation;

  ShapeData({
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    required this.controlX1,
    required this.controlY1,
    required this.controlX2,
    required this.controlY2,
    required this.width,
    required this.height,
    required this.color,
    required this.rotation,
  });

  factory ShapeData.random(math.Random random) {
    final colors = [
      const Color(0xFF5DADE2).withValues(alpha: 0.6),
      const Color(0xFF1E3A8A).withValues(alpha: 0.7),
      const Color(0xFF3B82F6).withValues(alpha: 0.5),
    ];
    
    return ShapeData(
      startX: random.nextDouble() * 1.5 - 0.25,
      startY: random.nextDouble() * 1.5 - 0.25,
      endX: random.nextDouble() * 1.5 - 0.25,
      endY: random.nextDouble() * 1.5 - 0.25,
      controlX1: random.nextDouble() * 1.5 - 0.25,
      controlY1: random.nextDouble() * 1.5 - 0.25,
      controlX2: random.nextDouble() * 1.5 - 0.25,
      controlY2: random.nextDouble() * 1.5 - 0.25,
      width: random.nextDouble() * 0.6 + 0.4,
      height: random.nextDouble() * 0.6 + 0.4,
      color: colors[random.nextInt(colors.length)],
      rotation: random.nextDouble() * math.pi * 2,
    );
  }
}

class AnimatedShapesPainter extends CustomPainter {
  final double animation;
  final List<ShapeData> shapes;

  AnimatedShapesPainter({
    required this.animation,
    required this.shapes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var shape in shapes) {
      final paint = Paint()
        ..color = shape.color
        ..style = PaintingStyle.fill;

      // Interpoliere zwischen Start- und Endpositionen mit Easing
      final easedAnimation = Curves.easeInOutCubic.transform(animation);
      
      final currentX = shape.startX + (shape.endX - shape.startX) * easedAnimation;
      final currentY = shape.startY + (shape.endY - shape.startY) * easedAnimation;
      final currentRotation = shape.rotation * easedAnimation;

      canvas.save();
      canvas.translate(size.width * currentX, size.height * currentY);
      canvas.rotate(currentRotation);

      final path = Path();
      
      // Erstelle organische Form mit Bezier-Kurven
      final w = size.width * shape.width;
      final h = size.height * shape.height;
      
      path.moveTo(-w / 2, -h / 2);
      
      path.cubicTo(
        w * shape.controlX1 - w / 2,
        h * shape.controlY1 - h / 2,
        w * shape.controlX2 - w / 2,
        h * shape.controlY2 - h / 2,
        w / 2,
        h / 2,
      );
      
      path.cubicTo(
        w * (1 - shape.controlX1) - w / 2,
        h * (1 - shape.controlY1) - h / 2,
        w * (1 - shape.controlX2) - w / 2,
        h * (1 - shape.controlY2) - h / 2,
        -w / 2,
        -h / 2,
      );
      
      path.close();
      
      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(AnimatedShapesPainter oldDelegate) {
    return oldDelegate.animation != animation || oldDelegate.shapes != shapes;
  }
}

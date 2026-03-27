import 'package:flutter/material.dart';
import 'package:shoply/core/mascot/avo_mascot.dart';
import 'package:shoply/data/services/interactive_tutorial_service.dart';

/// Interactive tutorial overlay that highlights specific UI elements
/// and blocks all other interactions
class InteractiveTutorialOverlay extends StatefulWidget {
  final Widget child;

  const InteractiveTutorialOverlay({
    super.key,
    required this.child,
  });

  @override
  State<InteractiveTutorialOverlay> createState() =>
      _InteractiveTutorialOverlayState();
}

class _InteractiveTutorialOverlayState extends State<InteractiveTutorialOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.0, end: 8.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Initialize tutorial service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      InteractiveTutorialService.instance.initialize();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: InteractiveTutorialService.instance,
      builder: (context, _) {
        final tutorial = InteractiveTutorialService.instance;

        return Stack(
          children: [
            // Main app content
            widget.child,

            // Tutorial overlay (only shown when active)
            if (tutorial.isActive) ...[
              // Dark overlay with cutout for target
              _buildOverlay(context, tutorial),

              // Skip button
              _buildSkipButton(context, tutorial),

              // Avo with speech bubble
              _buildAvoSpeechBubble(context, tutorial),

              // Progress indicator
              _buildProgressIndicator(context, tutorial),
            ],
          ],
        );
      },
    );
  }

  Widget _buildOverlay(BuildContext context, InteractiveTutorialService tutorial) {
    final targetKey = tutorial.currentTargetKey;
    final targetRect = targetKey != null ? tutorial.getTargetRect(targetKey) : null;

    return GestureDetector(
      onTapDown: (details) {
        // Only allow taps on the target area
        if (tutorial.isTapOnTarget(details.globalPosition)) {
          // Let the tap through - it will be handled by the actual widget
          return;
        }
        // Block tap
      },
      behavior: HitTestBehavior.translucent,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return CustomPaint(
            size: MediaQuery.of(context).size,
            painter: _TutorialOverlayPainter(
              targetRect: targetRect,
              pulseValue: _pulseAnimation.value,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSkipButton(BuildContext context, InteractiveTutorialService tutorial) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      right: 16,
      child: GestureDetector(
        onTap: () => tutorial.skipTutorial(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.skip_next, color: Colors.white, size: 18),
              SizedBox(width: 4),
              Text(
                'Skip',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvoSpeechBubble(BuildContext context, InteractiveTutorialService tutorial) {
    final step = tutorial.currentStep;
    if (step == null) return const SizedBox.shrink();

    final targetKey = tutorial.currentTargetKey;
    final targetRect = targetKey != null ? tutorial.getTargetRect(targetKey) : null;

    // Calculate position based on target and avo position preference
    double top;
    double? bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    if (targetRect != null) {
      if (step.avoPosition == Alignment.topCenter) {
        // Avo above target (target is at bottom, like nav bar)
        bottom = screenHeight - targetRect.top + 20;
        top = 0; // Will be ignored
      } else {
        // Avo below target
        top = targetRect.bottom + 20;
      }
    } else {
      top = screenHeight * 0.3;
    }

    return Positioned(
      top: step.avoPosition == Alignment.topCenter ? null : top,
      bottom: step.avoPosition == Alignment.topCenter ? bottom : null,
      left: 0,
      right: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pointer up (if Avo is below target)
          if (step.avoPosition != Alignment.topCenter && targetRect != null)
            _buildPointer(isUp: true),

          // Speech bubble
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                // Avo mascot
                AvoMascot(
                  size: 70,
                  expression: AvoExpression.happy,
                  animate: true,
                ),
                const SizedBox(width: 16),
                // Message
                Expanded(
                  child: Text(
                    step.avoMessage,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF1A1A1A),
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Pointer down (if Avo is above target)
          if (step.avoPosition == Alignment.topCenter && targetRect != null)
            _buildPointer(isUp: false),
        ],
      ),
    );
  }

  Widget _buildPointer({required bool isUp}) {
    return CustomPaint(
      size: const Size(30, 15),
      painter: _PointerPainter(isUp: isUp),
    );
  }

  Widget _buildProgressIndicator(BuildContext context, InteractiveTutorialService tutorial) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      child: Row(
        children: List.generate(tutorial.totalSteps, (index) {
          final isCompleted = index < tutorial.currentStepIndex;
          final isCurrent = index == tutorial.currentStepIndex;

          return Container(
            width: isCurrent ? 24 : 8,
            height: 8,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: isCompleted || isCurrent
                  ? Colors.white
                  : Colors.white.withOpacity(0.3),
            ),
          );
        }),
      ),
    );
  }
}

/// Custom painter for the dark overlay with cutout
class _TutorialOverlayPainter extends CustomPainter {
  final Rect? targetRect;
  final double pulseValue;

  _TutorialOverlayPainter({
    this.targetRect,
    this.pulseValue = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.75);

    // Draw full overlay
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);

    if (targetRect != null) {
      // Create path with cutout for target
      final path = Path()
        ..addRect(fullRect)
        ..addRRect(
          RRect.fromRectAndRadius(
            targetRect!.inflate(8 + pulseValue),
            const Radius.circular(12),
          ),
        )
        ..fillType = PathFillType.evenOdd;

      canvas.drawPath(path, paint);

      // Draw glow effect around target
      final glowPaint = Paint()
        ..color = Colors.white.withOpacity(0.3 - (pulseValue / 40))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 + pulseValue / 2;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          targetRect!.inflate(8 + pulseValue),
          const Radius.circular(12),
        ),
        glowPaint,
      );
    } else {
      // No target, just draw overlay
      canvas.drawRect(fullRect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TutorialOverlayPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.pulseValue != pulseValue;
  }
}

/// Custom painter for speech bubble pointer
class _PointerPainter extends CustomPainter {
  final bool isUp;

  _PointerPainter({required this.isUp});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();
    if (isUp) {
      path.moveTo(0, size.height);
      path.lineTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width / 2, size.height);
      path.lineTo(size.width, 0);
    }
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Wrapper widget that makes a child tappable for tutorial steps
class TutorialTarget extends StatelessWidget {
  final GlobalKey tutorialKey;
  final Widget child;
  final VoidCallback? onTap;
  final TutorialStepType? stepType;

  const TutorialTarget({
    super.key,
    required this.tutorialKey,
    required this.child,
    this.onTap,
    this.stepType,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: InteractiveTutorialService.instance,
      builder: (context, _) {
        final tutorial = InteractiveTutorialService.instance;
        final isTargeted = tutorial.isActive &&
            tutorial.currentStep?.type == stepType;

        return GestureDetector(
          key: tutorialKey,
          onTap: () {
            // Execute original onTap
            onTap?.call();

            // If this is the current tutorial target, advance tutorial
            if (isTargeted) {
              tutorial.completeCurrentStep();
            }
          },
          child: child,
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shoply/core/mascot/avo_mascot.dart';
import 'package:shoply/data/services/dynamic_tutorial_service.dart';

class DynamicTutorialOverlay extends StatefulWidget {
  final Widget child;

  const DynamicTutorialOverlay({
    super.key,
    required this.child,
  });

  @override
  State<DynamicTutorialOverlay> createState() => _DynamicTutorialOverlayState();
}

class _DynamicTutorialOverlayState extends State<DynamicTutorialOverlay>
    with TickerProviderStateMixin {
  Rect? _cachedTargetRect;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DynamicTutorialService.instance.initialize();
    });
    _startTargetRectRefresh();
    
    DynamicTutorialService.instance.addListener(_onTutorialChange);
  }

  void _onTutorialChange() {
    if (DynamicTutorialService.instance.isActive) {
      _fadeController.forward();
    }
  }

  @override
  void dispose() {
    DynamicTutorialService.instance.removeListener(_onTutorialChange);
    _fadeController.dispose();
    super.dispose();
  }

  void _startTargetRectRefresh() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _updateTargetRect();
        _startTargetRectRefresh();
      }
    });
  }

  void _updateTargetRect() {
    final tutorial = DynamicTutorialService.instance;
    final targetKey = tutorial.currentTargetKey;
    if (targetKey != null) {
      final newRect = tutorial.getTargetRect(targetKey);
      if (newRect != _cachedTargetRect) {
        setState(() {
          _cachedTargetRect = newRect;
        });
      }
    } else {
      if (_cachedTargetRect != null) {
        setState(() {
          _cachedTargetRect = null;
        });
      }
    }
  }

  double _getHighlightPadding(TutorialStepId? stepId) {
    switch (stepId) {
      case TutorialStepId.navigateToRecipes:
        return 4.0; // Small padding for navbar icons (48x48 target)
      case TutorialStepId.openShoppingList:
        return 4.0; // Small padding for list cards
      case TutorialStepId.showListItems:
      case TutorialStepId.showInputField:
      case TutorialStepId.showRecipes:
      case TutorialStepId.showCreateRecipe:
        return 8.0; // Slightly larger padding for info steps
      default:
        return 4.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DynamicTutorialService.instance,
      builder: (context, _) {
        final tutorial = DynamicTutorialService.instance;

        if (!tutorial.isActive || tutorial.currentStep == null) {
          return widget.child;
        }

        final step = tutorial.currentStep!;
        final targetKey = tutorial.currentTargetKey;
        Rect? targetRect = targetKey != null ? tutorial.getTargetRect(targetKey) : null;
        
        final padding = _getHighlightPadding(step.id);
        if (targetRect != null && padding > 0) {
          targetRect = targetRect.inflate(padding);
        }

        return Stack(
          children: [
            widget.child,
            _buildOverlay(context, step, targetRect),
            _buildSkipButton(context, tutorial, targetRect),
            _buildAvoWithBubble(context, step, targetRect),
          ],
        );
      },
    );
  }

  Widget _buildOverlay(BuildContext context, TutorialStep step, Rect? targetRect) {
    final screenSize = MediaQuery.of(context).size;
    final isClickStep = step.type == TutorialStepType.click;
    final isInfoOrFinish = step.type == TutorialStepType.info || step.type == TutorialStepType.finish;

    return Stack(
      children: [
        if (isInfoOrFinish)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity < -200) {
                  DynamicTutorialService.instance.nextStep();
                }
              },
              child: const SizedBox.expand(),
            ),
          ),
        IgnorePointer(
          child: CustomPaint(
            size: screenSize,
            painter: _OverlayPainter(
              targetRect: targetRect,
              screenSize: screenSize,
            ),
          ),
        ),
        if (isClickStep && targetRect != null)
          _buildTapBlocker(context, targetRect.inflate(4)),
      ],
    );
  }

  Widget _buildTapBlocker(BuildContext context, Rect holeRect) {
    final screenSize = MediaQuery.of(context).size;
    
    final clampedHole = Rect.fromLTRB(
      holeRect.left.clamp(0, screenSize.width),
      holeRect.top.clamp(0, screenSize.height),
      holeRect.right.clamp(0, screenSize.width),
      holeRect.bottom.clamp(0, screenSize.height),
    );
    
    return Positioned.fill(
      child: Stack(
        children: [
          if (clampedHole.top > 0)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: clampedHole.top,
              child: GestureDetector(
                onTap: () {},
                behavior: HitTestBehavior.opaque,
                child: const SizedBox.expand(),
              ),
            ),
          if (clampedHole.bottom < screenSize.height)
            Positioned(
              top: clampedHole.bottom,
              left: 0,
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: () {},
                behavior: HitTestBehavior.opaque,
                child: const SizedBox.expand(),
              ),
            ),
          if (clampedHole.left > 0)
            Positioned(
              top: clampedHole.top,
              left: 0,
              width: clampedHole.left,
              height: clampedHole.height,
              child: GestureDetector(
                onTap: () {},
                behavior: HitTestBehavior.opaque,
                child: const SizedBox.expand(),
              ),
            ),
          if (clampedHole.right < screenSize.width)
            Positioned(
              top: clampedHole.top,
              left: clampedHole.right,
              right: 0,
              height: clampedHole.height,
              child: GestureDetector(
                onTap: () {},
                behavior: HitTestBehavior.opaque,
                child: const SizedBox.expand(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSkipButton(BuildContext context, DynamicTutorialService tutorial, Rect? targetRect) {
    final safeTop = MediaQuery.of(context).padding.top;
    final screenWidth = MediaQuery.of(context).size.width;
    
    final skipButtonArea = Rect.fromLTWH(screenWidth - 150, safeTop, 150, 60);
    final bool targetOverlapsSkip = targetRect != null && targetRect.overlaps(skipButtonArea);
    
    return Positioned(
      top: safeTop + 12,
      right: targetOverlapsSkip ? null : 16,
      left: targetOverlapsSkip ? 16 : null,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: GestureDetector(
          onTap: () => tutorial.skipTutorial(),
          child: Text(
            'Überspringen',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvoWithBubble(BuildContext context, TutorialStep step, Rect? targetRect) {
    final screenSize = MediaQuery.of(context).size;
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final isWelcome = step.id == TutorialStepId.welcome;
    final isFinish = step.type == TutorialStepType.finish;
    final showNextButton = step.type == TutorialStepType.info || step.type == TutorialStepType.finish;
    final isClickStep = step.type == TutorialStepType.click;

    final avoSize = 100.0;
    final minTop = safeTop + 80;
    final maxTop = screenSize.height - safeBottom - 200;

    double top;
    
    if (isWelcome || isFinish || targetRect == null) {
      top = screenSize.height * 0.35;
    } else {
      final spaceBelow = screenSize.height - targetRect.bottom - safeBottom - 20;
      final spaceAbove = targetRect.top - minTop;
      
      if (spaceBelow >= 200) {
        top = targetRect.bottom + 30;
      } else if (spaceAbove >= 200) {
        top = targetRect.top - 200;
      } else {
        top = screenSize.height * 0.4;
      }
      
      top = top.clamp(minTop, maxTop);
    }

    return Positioned(
      top: top,
      left: 20,
      right: 20,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SizedBox(
            height: 160,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: AvoMascot(
                    size: avoSize,
                    expression: isFinish 
                        ? AvoExpression.success 
                        : (isClickStep ? AvoExpression.excited : AvoExpression.happy),
                    animate: true,
                  ),
                ),
                Positioned(
                  left: avoSize * 0.5,
                  top: 0,
                  right: 0,
                  child: _buildSpeechBubble(step, showNextButton, isClickStep),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpeechBubble(TutorialStep step, bool showNextButton, bool isClickStep) {
    return CustomPaint(
      painter: _SpeechBubblePainter(),
      child: Container(
        margin: const EdgeInsets.only(left: 16, bottom: 16),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              step.message,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1A1A1A),
                height: 1.4,
                fontWeight: FontWeight.w400,
              ),
            ),
            if (showNextButton) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => DynamicTutorialService.instance.nextStep(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    step.buttonText ?? 'Weiter',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ] else if (isClickStep) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.touch_app_rounded,
                    size: 12,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Tippe auf das Element',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SpeechBubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final path = Path();
    const radius = 14.0;
    const pointerSize = 12.0;
    const margin = 16.0;
    
    final bubbleLeft = margin;
    const bubbleTop = 0.0;
    final bubbleRight = size.width;
    final bubbleBottom = size.height - margin;
    
    path.moveTo(bubbleLeft + radius, bubbleTop);
    path.lineTo(bubbleRight - radius, bubbleTop);
    path.quadraticBezierTo(bubbleRight, bubbleTop, bubbleRight, bubbleTop + radius);
    path.lineTo(bubbleRight, bubbleBottom - radius);
    path.quadraticBezierTo(bubbleRight, bubbleBottom, bubbleRight - radius, bubbleBottom);
    path.lineTo(bubbleLeft + radius, bubbleBottom);
    path.quadraticBezierTo(bubbleLeft, bubbleBottom, bubbleLeft, bubbleBottom - radius);
    path.lineTo(bubbleLeft, bubbleBottom - 20);
    path.lineTo(0, size.height);
    path.lineTo(bubbleLeft, bubbleBottom - 20 - pointerSize);
    path.lineTo(bubbleLeft, bubbleTop + radius);
    path.quadraticBezierTo(bubbleLeft, bubbleTop, bubbleLeft + radius, bubbleTop);
    path.close();

    canvas.drawPath(path.shift(const Offset(0, 2)), shadowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OverlayPainter extends CustomPainter {
  final Rect? targetRect;
  final Size screenSize;

  _OverlayPainter({
    this.targetRect,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xBB000000);
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);

    if (targetRect != null && targetRect!.width > 0 && targetRect!.height > 0) {
      final clampedRect = Rect.fromLTRB(
        targetRect!.left.clamp(0, screenSize.width),
        targetRect!.top.clamp(0, screenSize.height),
        targetRect!.right.clamp(0, screenSize.width),
        targetRect!.bottom.clamp(0, screenSize.height),
      );
      
      final borderRadius = clampedRect.height > 200 ? 28.0 : 14.0;
      
      if (clampedRect.width > 0 && clampedRect.height > 0) {
        final path = Path()
          ..addRect(fullRect)
          ..addRRect(RRect.fromRectAndRadius(
            clampedRect,
            Radius.circular(borderRadius),
          ))
          ..fillType = PathFillType.evenOdd;

        canvas.drawPath(path, paint);
      } else {
        canvas.drawRect(fullRect, paint);
      }
    } else {
      canvas.drawRect(fullRect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect;
  }
}

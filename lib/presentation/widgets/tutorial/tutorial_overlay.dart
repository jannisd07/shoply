import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shoply/core/mascot/avo_mascot.dart';
import 'package:shoply/data/services/dynamic_tutorial_service.dart';

/// A beautifully designed tutorial overlay that introduces users to the app.
/// Features Avo mascot, glassmorphism cards, and smooth animations.
class TutorialOverlay extends StatefulWidget {
  final Widget child;

  const TutorialOverlay({
    super.key,
    required this.child,
  });

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with TickerProviderStateMixin {
  Rect? _cachedTargetRect;
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await DynamicTutorialService.instance.initialize();
      // Check if tutorial became active after initialization
      if (DynamicTutorialService.instance.isActive && mounted) {
        _fadeController.forward();
      }
    });
    
    _startTargetRectRefresh();
    DynamicTutorialService.instance.addListener(_onTutorialChange);
  }

  void _onTutorialChange() {
    if (DynamicTutorialService.instance.isActive) {
      _fadeController.forward();
    } else {
      _fadeController.reverse();
    }
  }

  @override
  void dispose() {
    DynamicTutorialService.instance.removeListener(_onTutorialChange);
    _fadeController.dispose();
    _pulseController.dispose();
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
        setState(() => _cachedTargetRect = newRect);
      }
    } else if (_cachedTargetRect != null) {
      setState(() => _cachedTargetRect = null);
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
        
        // Add small padding around target for the highlight
        final Rect? highlightRect = targetRect != null ? targetRect.inflate(4) : null;

        final isFullScreenStep = step.id == TutorialStepId.welcome || 
                                  step.type == TutorialStepType.finish;
        
        // Check if this is a tab bar target
        final isTabBarTarget = step.id == TutorialStepId.navigateToRecipes;

        return Stack(
          children: [
            widget.child,
            // Dark overlay with hole for target
            _buildOverlay(context, step, highlightRect),
            // Pulsing ring around target (exactly around the highlight)
            if (highlightRect != null && step.type == TutorialStepType.click)
              _buildPulsingRing(highlightRect, isTabBarTarget: isTabBarTarget),
            // Tap blocker (allows tap only on target)
            if (step.type == TutorialStepType.click && targetRect != null)
              _buildTapBlocker(context, targetRect),
            // Main content (Avo + Message Card) - before skip button so skip is on top
            if (isFullScreenStep)
              _buildFullScreenContent(context, step)
            else
              _buildFloatingContent(context, step, highlightRect),
            // Skip button - always on top
            _buildSkipButton(context, tutorial),
            // Progress dots
            _buildProgressDots(context, step),
          ],
        );
      },
    );
  }

  Widget _buildOverlay(BuildContext context, TutorialStep step, Rect? targetRect) {
    final screenSize = MediaQuery.of(context).size;
    final isInfoOrFinish = step.type == TutorialStepType.info || step.type == TutorialStepType.finish;
    
    // Check if this is a tab bar target (navigateToRecipes step)
    final isTabBarTarget = step.id == TutorialStepId.navigateToRecipes;

    return Stack(
      children: [
        // Swipe gesture for info steps
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
        // Dark overlay with cutout
        IgnorePointer(
          child: CustomPaint(
            size: screenSize,
            painter: _OverlayPainter(
              targetRect: targetRect,
              screenSize: screenSize,
              overlayOpacity: step.id == TutorialStepId.welcome ? 0.85 : 0.7,
              isTabBarTarget: isTabBarTarget,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPulsingRing(Rect targetRect, {bool isTabBarTarget = false}) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final scale = 1.0 + (_pulseAnimation.value * 0.1);
        final opacity = 0.7 - (_pulseAnimation.value * 0.5);
        
        // Calculate the center of the target rect
        final centerX = targetRect.center.dx;
        final centerY = targetRect.center.dy;
        
        // Calculate border radius based on target type
        double borderRadius;
        if (isTabBarTarget || targetRect.width > targetRect.height * 2) {
          // Pill shape for tab bar or wide targets
          borderRadius = (targetRect.height * scale) / 2;
        } else if (targetRect.shortestSide > 80) {
          borderRadius = 20;
        } else {
          borderRadius = 12;
        }
        
        return Positioned(
          left: centerX - (targetRect.width / 2) * scale,
          top: centerY - (targetRect.height / 2) * scale,
          child: IgnorePointer(
            child: Container(
              width: targetRect.width * scale,
              height: targetRect.height * scale,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color: Color.fromRGBO(76, 175, 80, opacity),
                  width: 3,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTapBlocker(BuildContext context, Rect holeRect) {
    final screenSize = MediaQuery.of(context).size;
    
    return Positioned.fill(
      child: Stack(
        children: [
          // Top blocker
          if (holeRect.top > 0)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: holeRect.top,
              child: GestureDetector(
                onTap: () {},
                behavior: HitTestBehavior.opaque,
                child: const SizedBox.expand(),
              ),
            ),
          // Bottom blocker
          if (holeRect.bottom < screenSize.height)
            Positioned(
              top: holeRect.bottom,
              left: 0,
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: () {},
                behavior: HitTestBehavior.opaque,
                child: const SizedBox.expand(),
              ),
            ),
          // Left blocker
          if (holeRect.left > 0)
            Positioned(
              top: holeRect.top,
              left: 0,
              width: holeRect.left,
              height: holeRect.height,
              child: GestureDetector(
                onTap: () {},
                behavior: HitTestBehavior.opaque,
                child: const SizedBox.expand(),
              ),
            ),
          // Right blocker
          if (holeRect.right < screenSize.width)
            Positioned(
              top: holeRect.top,
              left: holeRect.right,
              right: 0,
              height: holeRect.height,
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

  Widget _buildSkipButton(BuildContext context, DynamicTutorialService tutorial) {
    final safeTop = MediaQuery.of(context).padding.top;
    
    // Position skip button on the left side for recipe-related steps
    final isRecipeStep = tutorial.currentStepId == TutorialStepId.navigateToRecipes ||
                         tutorial.currentStepId == TutorialStepId.showRecipes ||
                         tutorial.currentStepId == TutorialStepId.showCreateRecipe;
    
    return Positioned(
      top: safeTop + 12,
      left: isRecipeStep ? 16 : null,
      right: isRecipeStep ? null : 16,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: GestureDetector(
          onTap: () => tutorial.skipTutorial(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(0, 0, 0, 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color.fromRGBO(255, 255, 255, 0.15),
                width: 1,
              ),
            ),
            child: const Text(
              'Überspringen',
              style: TextStyle(
                color: Color.fromRGBO(255, 255, 255, 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullScreenContent(BuildContext context, TutorialStep step) {
    final isWelcome = step.id == TutorialStepId.welcome;
    
    return Positioned.fill(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                // Avo mascot - larger for welcome/finish
                AvoMascot(
                  size: isWelcome ? 140 : 120,
                  expression: isWelcome ? AvoExpression.waving : AvoExpression.celebrating,
                  animate: true,
                ),
                const SizedBox(height: 28),
                // Message card
                _buildMessageCard(
                  context: context,
                  title: isWelcome ? 'Willkommen! 👋' : 'Geschafft! 🎉',
                  message: step.message,
                  buttonText: step.buttonText ?? 'Weiter',
                  onTap: () => DynamicTutorialService.instance.nextStep(),
                ),
                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingContent(BuildContext context, TutorialStep step, Rect? targetRect) {
    final screenSize = MediaQuery.of(context).size;
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    
    // Calculate best position for the card - avoid overlapping with target and skip button
    final double skipButtonBottom = safeTop + 12 + 30; // skip button position + height
    
    double cardTop;
    
    if (targetRect == null) {
      cardTop = screenSize.height * 0.35;
    } else {
      final spaceBelow = screenSize.height - targetRect.bottom - safeBottom - 120;
      final spaceAbove = targetRect.top - skipButtonBottom - 40;
      
      final showBelow = spaceBelow >= 200 || spaceAbove < 180;
      
      if (showBelow) {
        cardTop = targetRect.bottom + 24;
      } else {
        // Position above target, but below skip button
        cardTop = targetRect.top - 180;
      }
    }
    
    // Clamp to safe area, ensuring we don't overlap skip button
    cardTop = cardTop.clamp(skipButtonBottom + 20, screenSize.height - safeBottom - 200);
    
    final isClickStep = step.type == TutorialStepType.click;
    
    return Positioned(
      top: cardTop,
      left: 16,
      right: 16,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avo mascot
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: AvoMascot(
                size: 70,
                expression: isClickStep ? AvoExpression.excited : AvoExpression.happy,
                animate: true,
              ),
            ),
            const SizedBox(width: 12),
            // Message card
            Expanded(
              child: _buildCompactMessageCard(
                context: context,
                message: step.message,
                buttonText: step.type == TutorialStepType.info ? (step.buttonText ?? 'Weiter') : null,
                isClickStep: isClickStep,
                onTap: step.type == TutorialStepType.info 
                    ? () => DynamicTutorialService.instance.nextStep()
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageCard({
    required BuildContext context,
    required String title,
    required String message,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(28, 28, 30, 0.85),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color.fromRGBO(255, 255, 255, 0.1),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color.fromRGBO(255, 255, 255, 0.85),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              _buildPrimaryButton(
                text: buttonText,
                onTap: onTap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactMessageCard({
    required BuildContext context,
    required String message,
    String? buttonText,
    bool isClickStep = false,
    VoidCallback? onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(28, 28, 30, 0.9),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color.fromRGBO(255, 255, 255, 0.08),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color.fromRGBO(255, 255, 255, 0.95),
                  height: 1.45,
                ),
              ),
              if (buttonText != null && onTap != null) ...[
                const SizedBox(height: 14),
                _buildPrimaryButton(
                  text: buttonText,
                  onTap: onTap,
                  compact: true,
                ),
              ] else if (isClickStep) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(76, 175, 80, 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.touch_app_rounded,
                        size: 14,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Tippe auf das markierte Element',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color.fromRGBO(255, 255, 255, 0.5),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String text,
    required VoidCallback onTap,
    bool compact = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: compact ? null : double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 20 : 24,
          vertical: compact ? 10 : 12,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(76, 175, 80, 0.35),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 13 : 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressDots(BuildContext context, TutorialStep step) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final allSteps = TutorialStepId.values;
    final currentIndex = allSteps.indexOf(step.id);
    
    // Use higher bottom padding to avoid iOS 26 navbar overlap
    // iOS 26 navbar is taller, so we add extra padding (70 instead of 30)
    final bottomPadding = safeBottom + 70;
    
    return Positioned(
      bottom: bottomPadding,
      left: 0,
      right: 0,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(allSteps.length, (index) {
            final isActive = index == currentIndex;
            final isPast = index < currentIndex;
            
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isActive ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF4CAF50)
                    : isPast
                        ? const Color.fromRGBO(255, 255, 255, 0.45)
                        : const Color.fromRGBO(255, 255, 255, 0.15),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final Rect? targetRect;
  final Size screenSize;
  final double overlayOpacity;
  final bool isTabBarTarget;

  _OverlayPainter({
    this.targetRect,
    required this.screenSize,
    this.overlayOpacity = 0.7,
    this.isTabBarTarget = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Color.fromRGBO(0, 0, 0, overlayOpacity);
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);

    if (targetRect != null && targetRect!.width > 0 && targetRect!.height > 0) {
      // Clamp to screen bounds
      final clampedRect = Rect.fromLTRB(
        targetRect!.left.clamp(0, screenSize.width),
        targetRect!.top.clamp(0, screenSize.height),
        targetRect!.right.clamp(0, screenSize.width),
        targetRect!.bottom.clamp(0, screenSize.height),
      );
      
      // For tab bar targets, use pill/stadium shape (fully rounded)
      // For other targets, use appropriate corner radius
      double borderRadius;
      if (isTabBarTarget || clampedRect.width > clampedRect.height * 2) {
        // Pill shape - radius is half the height
        borderRadius = clampedRect.height / 2;
      } else if (clampedRect.shortestSide > 80) {
        borderRadius = 20.0;
      } else {
        borderRadius = 12.0;
      }
      
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
    return oldDelegate.targetRect != targetRect ||
           oldDelegate.overlayOpacity != overlayOpacity;
  }
}

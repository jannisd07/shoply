import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shoply/core/mascot/avo_mascot.dart';
import 'package:shoply/data/services/dynamic_tutorial_service.dart';
import 'package:shoply/data/services/navigation_service.dart';
import 'package:shoply/data/services/supabase_service.dart';

class TutorialOverlay extends StatefulWidget {
  final Widget child;

  const TutorialOverlay({super.key, required this.child});

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with TickerProviderStateMixin {
  Rect? _cachedTargetRect;
  late final StreamSubscription _authSubscription;
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initializeTutorial());
    });

    _authSubscription = SupabaseService.instance.authStateChanges.listen((
      data,
    ) {
      if (data.session == null) {
        DynamicTutorialService.instance.resetForNewUser();
        return;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_initializeTutorial());
        }
      });
    });

    _startTargetRectRefresh();
    DynamicTutorialService.instance.addListener(_onTutorialChange);
  }

  Future<void> _initializeTutorial() async {
    await DynamicTutorialService.instance.initialize();
    if (DynamicTutorialService.instance.isActive && mounted) {
      _fadeController.forward();
    }
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
    _authSubscription.cancel();
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
        Rect? targetRect = targetKey != null
            ? tutorial.getTargetRect(targetKey)
            : null;

        final Rect? highlightRect = targetRect?.inflate(4);

        final isFullScreenStep =
            step.id == TutorialStepId.welcome ||
            step.type == TutorialStepType.finish;

        final isTabBarTarget = step.id == TutorialStepId.navigateToRecipes;

        return Stack(
          children: [
            widget.child,
            _buildOverlay(context, step, highlightRect),
            if (highlightRect != null && step.type == TutorialStepType.click)
              _buildPulsingRing(highlightRect, isTabBarTarget: isTabBarTarget),
            if (step.type == TutorialStepType.click && targetRect != null)
              _buildTapBlocker(context, targetRect),
            if (isFullScreenStep)
              _buildFullScreenContent(context, step)
            else
              _buildFloatingContent(context, step, highlightRect),
            _buildSkipButton(context, tutorial),
            _buildProgressDots(context, step),
          ],
        );
      },
    );
  }

  Widget _buildOverlay(
    BuildContext context,
    TutorialStep step,
    Rect? targetRect,
  ) {
    final screenSize = MediaQuery.of(context).size;
    final isTabBarTarget = step.id == TutorialStepId.navigateToRecipes;

    return IgnorePointer(
      child: CustomPaint(
        size: screenSize,
        painter: _OverlayPainter(
          targetRect: targetRect,
          screenSize: screenSize,
          overlayOpacity: step.id == TutorialStepId.welcome ? 0.85 : 0.65,
          isTabBarTarget: isTabBarTarget,
        ),
      ),
    );
  }

  Widget _buildPulsingRing(Rect targetRect, {bool isTabBarTarget = false}) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final scale = 1.0 + (_pulseAnimation.value * 0.08);
        final opacity = 0.5 - (_pulseAnimation.value * 0.35);

        final centerX = targetRect.center.dx;
        final centerY = targetRect.center.dy;

        double borderRadius;
        if (isTabBarTarget || targetRect.width > targetRect.height * 2) {
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
                  color: Color.fromRGBO(255, 255, 255, opacity),
                  width: 2,
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

  Widget _buildSkipButton(
    BuildContext context,
    DynamicTutorialService tutorial,
  ) {
    final safeTop = MediaQuery.of(context).padding.top;

    final isRecipeStep =
        tutorial.currentStepId == TutorialStepId.navigateToRecipes ||
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
              color: const Color.fromRGBO(0, 0, 0, 0.45),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color.fromRGBO(255, 255, 255, 0.12),
                width: 0.5,
              ),
            ),
            child: const Text(
              'Überspringen',
              style: TextStyle(
                color: Color.fromRGBO(255, 255, 255, 0.7),
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
    final isFinish = step.type == TutorialStepType.finish;

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
                AvoMascot(
                  size: isWelcome ? 140 : 120,
                  expression: isWelcome
                      ? AvoExpression.waving
                      : AvoExpression.celebrating,
                  animate: true,
                ),
                const SizedBox(height: 32),
                _buildMessageCard(
                  context: context,
                  title: isWelcome ? 'Willkommen' : 'Geschafft',
                  message: step.message,
                  buttonText: step.buttonText ?? 'Weiter',
                  onTap: () => DynamicTutorialService.instance.nextStep(),
                  secondaryButtonText: isFinish
                      ? 'Ernährungspräferenzen angeben'
                      : null,
                  onSecondaryTap: isFinish
                      ? () => _openDietPreferencesFromFinish(context)
                      : null,
                ),
                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openDietPreferencesFromFinish(BuildContext context) async {
    unawaited(DynamicTutorialService.instance.completeTutorial());
    NavigationService.instance.navigateToDietPreferences();
  }

  Widget _buildFloatingContent(
    BuildContext context,
    TutorialStep step,
    Rect? targetRect,
  ) {
    final screenSize = MediaQuery.of(context).size;
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    final double skipButtonBottom = safeTop + 12 + 30;

    double cardTop;

    if (targetRect == null) {
      cardTop = screenSize.height * 0.35;
    } else {
      final spaceBelow =
          screenSize.height - targetRect.bottom - safeBottom - 120;
      final spaceAbove = targetRect.top - skipButtonBottom - 40;

      final showBelow = spaceBelow >= 200 || spaceAbove < 180;

      if (showBelow) {
        cardTop = targetRect.bottom + 24;
      } else {
        cardTop = targetRect.top - 180;
      }
    }

    cardTop = cardTop.clamp(
      skipButtonBottom + 20,
      screenSize.height - safeBottom - 200,
    );

    final isClickStep = step.type == TutorialStepType.click;

    return Positioned(
      top: cardTop,
      left: 20,
      right: 20,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: AvoMascot(
                size: 64,
                expression: isClickStep
                    ? AvoExpression.excited
                    : AvoExpression.happy,
                animate: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCompactMessageCard(
                context: context,
                message: step.message,
                buttonText: step.type == TutorialStepType.info
                    ? (step.buttonText ?? 'Weiter')
                    : null,
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
    String? secondaryButtonText,
    VoidCallback? onSecondaryTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(28, 28, 30, 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color.fromRGBO(255, 255, 255, 0.08),
          width: 0.5,
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
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: Color.fromRGBO(255, 255, 255, 0.7),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                buttonText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (secondaryButtonText != null && onSecondaryTap != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onSecondaryTap,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(255, 255, 255, 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color.fromRGBO(255, 255, 255, 0.08),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.restaurant_menu_rounded,
                      color: Color.fromRGBO(255, 255, 255, 0.72),
                      size: 17,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      secondaryButtonText,
                      style: const TextStyle(
                        color: Color.fromRGBO(255, 255, 255, 0.78),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(28, 28, 30, 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color.fromRGBO(255, 255, 255, 0.08),
          width: 0.5,
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
              color: Color.fromRGBO(255, 255, 255, 0.9),
              height: 1.45,
            ),
          ),
          if (buttonText != null && onTap != null) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  buttonText,
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ] else if (isClickStep) ...[
            const SizedBox(height: 10),
            Text(
              'Tippe auf das markierte Element',
              style: TextStyle(
                fontSize: 11,
                color: const Color.fromRGBO(255, 255, 255, 0.4),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressDots(BuildContext context, TutorialStep step) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final allSteps = TutorialStepId.values;
    final currentIndex = allSteps.indexOf(step.id);

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
                    ? Colors.white
                    : isPast
                    ? const Color.fromRGBO(255, 255, 255, 0.4)
                    : const Color.fromRGBO(255, 255, 255, 0.12),
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
    this.overlayOpacity = 0.65,
    this.isTabBarTarget = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Color.fromRGBO(0, 0, 0, overlayOpacity);
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);

    if (targetRect != null && targetRect!.width > 0 && targetRect!.height > 0) {
      final clampedRect = Rect.fromLTRB(
        targetRect!.left.clamp(0, screenSize.width),
        targetRect!.top.clamp(0, screenSize.height),
        targetRect!.right.clamp(0, screenSize.width),
        targetRect!.bottom.clamp(0, screenSize.height),
      );

      double borderRadius;
      if (isTabBarTarget || clampedRect.width > clampedRect.height * 2) {
        borderRadius = clampedRect.height / 2;
      } else if (clampedRect.shortestSide > 80) {
        borderRadius = 20.0;
      } else {
        borderRadius = 12.0;
      }

      if (clampedRect.width > 0 && clampedRect.height > 0) {
        final path = Path()
          ..addRect(fullRect)
          ..addRRect(
            RRect.fromRectAndRadius(clampedRect, Radius.circular(borderRadius)),
          )
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

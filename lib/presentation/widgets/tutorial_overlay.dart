import 'package:flutter/material.dart';
import 'package:shoply/core/mascot/avo_mascot.dart';
import 'package:shoply/data/services/tutorial_service.dart';

/// Tutorial step configuration
class TutorialStep {
  final String title;
  final String message;
  final AvoExpression expression;
  final Alignment avoPosition;
  final Alignment? highlightPosition;
  final Size? highlightSize;
  final String? highlightKey;

  const TutorialStep({
    required this.title,
    required this.message,
    required this.expression,
    this.avoPosition = Alignment.center,
    this.highlightPosition,
    this.highlightSize,
    this.highlightKey,
  });
}

/// Interactive tutorial overlay with Avo mascot
class TutorialOverlay extends StatefulWidget {
  final VoidCallback onComplete;
  final VoidCallback onSkip;
  final Map<String, GlobalKey>? highlightKeys;

  const TutorialOverlay({
    super.key,
    required this.onComplete,
    required this.onSkip,
    this.highlightKeys,
  });

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<TutorialStep> _steps = [
    const TutorialStep(
      title: 'Welcome to Shoply! 🎉',
      message:
          'I\'m Avo, your shopping assistant! Let me show you around the app.',
      expression: AvoExpression.waving,
      avoPosition: Alignment.center,
    ),
    const TutorialStep(
      title: 'Your Shopping Lists 🛒',
      message:
          'Create and manage your shopping lists here. Tap the + button to add a new list!',
      expression: AvoExpression.happy,
      avoPosition: Alignment.bottomCenter,
      highlightKey: 'home_lists',
    ),
    const TutorialStep(
      title: 'Shared Lists 👨‍👩‍👧‍👦',
      message:
          'Share lists with family and friends! Everyone can add items and check them off in real-time.',
      expression: AvoExpression.excited,
      avoPosition: Alignment.bottomCenter,
      highlightKey: 'home_lists',
    ),
    const TutorialStep(
      title: 'Discover Recipes 🍳',
      message:
          'Explore thousands of delicious recipes! Tap the recipes tab to browse.',
      expression: AvoExpression.happy,
      avoPosition: Alignment.center,
      highlightKey: 'nav_recipes',
    ),
    const TutorialStep(
      title: 'You\'re All Set! 🚀',
      message:
          'That\'s it! Start by creating your first shopping list. Happy shopping!',
      expression: AvoExpression.success,
      avoPosition: Alignment.center,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      _animationController.reverse().then((_) {
        setState(() {
          _currentStep++;
        });
        _animationController.forward();
      });
    } else {
      _completeAndClose();
    }
  }

  void _completeAndClose() async {
    await TutorialService.instance.markTutorialCompleted();
    _animationController.reverse().then((_) {
      widget.onComplete();
    });
  }

  void _skipTutorial() async {
    await TutorialService.instance.markTutorialSkipped();
    _animationController.reverse().then((_) {
      widget.onSkip();
    });
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];
    final screenSize = MediaQuery.of(context).size;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Dark overlay
            GestureDetector(
              onTap: _nextStep,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.black.withOpacity(0.75),
              ),
            ),

            // Skip button (top right)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: TextButton(
                onPressed: _skipTutorial,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.15),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Skip Tutorial',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            // Progress indicator
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              child: Row(
                children: List.generate(_steps.length, (index) {
                  return Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index <= _currentStep
                          ? Colors.white
                          : Colors.white.withOpacity(0.3),
                    ),
                  );
                }),
              ),
            ),

            // Avo and speech bubble
            _buildAvoWithBubble(step, screenSize),

            // Next/Done button
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 40,
              left: 24,
              right: 24,
              child: ElevatedButton(
                onPressed: _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  elevation: 4,
                ),
                child: Text(
                  _currentStep == _steps.length - 1 ? 'Get Started!' : 'Next',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvoWithBubble(TutorialStep step, Size screenSize) {
    // Position Avo based on step configuration
    double top;

    switch (step.avoPosition) {
      case Alignment.topCenter:
        top = MediaQuery.of(context).padding.top + 80;
        break;
      case Alignment.bottomCenter:
        top = screenSize.height * 0.25;
        break;
      case Alignment.center:
      default:
        top = screenSize.height * 0.2;
        break;
    }

    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: Column(
        children: [
          // Avo mascot
          Center(
            child: AvoMascot(
              size: 120,
              expression: step.expression,
              animate: true,
            ),
          ),

          const SizedBox(height: 24),

          // Speech bubble
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  step.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  step.message,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF4A4A4A),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Pointer triangle
          CustomPaint(
            size: const Size(24, 12),
            painter: _BubblePointerPainter(),
          ),
        ],
      ),
    );
  }
}

class _BubblePointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Mixin to add tutorial functionality to screens
mixin TutorialMixin<T extends StatefulWidget> on State<T> {
  bool _showTutorial = false;

  bool get showTutorial => _showTutorial;

  Future<void> checkAndShowTutorial() async {
    final shouldShow = await TutorialService.instance.shouldShowTutorial();
    if (shouldShow && mounted) {
      setState(() {
        _showTutorial = true;
      });
    }
  }

  void hideTutorial() {
    if (mounted) {
      setState(() {
        _showTutorial = false;
      });
    }
  }

  Widget buildTutorialOverlay() {
    if (!_showTutorial) return const SizedBox.shrink();

    return TutorialOverlay(
      onComplete: hideTutorial,
      onSkip: hideTutorial,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/mascot/avo_mascot.dart';
import 'package:shoply/core/gamification/gamification_service.dart';
import 'package:shoply/core/localization/localization_helper.dart';

/// A playful greeting widget for the home screen featuring the mascot
class HomeGreetingWidget extends StatefulWidget {
  final String? userName;
  final VoidCallback? onMascotTap;

  const HomeGreetingWidget({
    super.key,
    this.userName,
    this.onMascotTap,
  });

  @override
  State<HomeGreetingWidget> createState() => _HomeGreetingWidgetState();
}

class _HomeGreetingWidgetState extends State<HomeGreetingWidget>
    with SingleTickerProviderStateMixin {
  final GamificationService _gamification = GamificationService();
  
  int _streak = 0;
  String _greeting = '';
  AvoExpression _mood = AvoExpression.happy;
  bool _showStreak = false;
  bool _isLoading = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _loadData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final streak = await _gamification.updateStreak();
    final (greeting, mood) = _gamification.getTimeBasedGreeting(widget.userName);
    
    if (mounted) {
      setState(() {
        _streak = streak;
        _greeting = greeting;
        _mood = mood;
        _showStreak = streak > 1;
        _isLoading = false;
      });
      _fadeController.forward();
    }
  }

  void _onMascotTapped() {
    HapticFeedback.lightImpact();
    // Just haptic feedback, don't change the message
    widget.onMascotTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(height: 120);
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mascot
            GestureDetector(
              onTap: _onMascotTapped,
              child: AvoMascot(
                size: 60,
                expression: _mood,
                animate: true,
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Greeting and streak
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting message
                  Text(
                    _greeting,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary(context),
                      height: 1.4,
                    ),
                  ),
                  
                  // Streak badge
                  if (_showStreak) ...[
                    const SizedBox(height: 10),
                    _buildStreakBadge(context),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakBadge(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF9500).withOpacity(0.2),
            const Color(0xFFFF6B00).withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF9500).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '🔥',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 6),
          Text(
            context.tr('day_streak', params: {'count': '$_streak'}),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFFFAA33) : const Color(0xFFE67E00),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact streak indicator for app bar or other locations
class StreakIndicator extends StatelessWidget {
  final int streak;
  
  const StreakIndicator({super.key, required this.streak});

  @override
  Widget build(BuildContext context) {
    if (streak <= 1) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9500).withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            '$streak',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFFFF9500),
            ),
          ),
        ],
      ),
    );
  }
}

/// Celebration overlay for achievements
class CelebrationOverlay extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;

  const CelebrationOverlay({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    
    _controller.forward();
    
    // Auto dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onDismiss,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            ),
          );
        },
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(40),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1C1C1E)
                  : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AvoMascot(
                  size: 80,
                  expression: AvoExpression.happy,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.message,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

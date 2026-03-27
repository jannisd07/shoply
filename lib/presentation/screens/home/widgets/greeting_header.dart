import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/app_dimensions.dart';
import 'package:shoply/core/constants/app_text_styles.dart';
import 'package:shoply/core/mascot/avo_mascot.dart';
import 'package:shoply/core/gamification/gamification_service.dart';

/// Collapsible sliver header with mascot, greeting message, and streak
/// Animates opacity, scale, and position on scroll
class GreetingHeader extends SliverPersistentHeaderDelegate {
  final String displayName;
  final String? avatarUrl;
  final VoidCallback onAvatarTap;

  GreetingHeader({
    required this.displayName,
    this.avatarUrl,
    required this.onAvatarTap,
  });

  @override
  double get minExtent => 60;

  @override
  double get maxExtent => 160;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final t = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final opacity = 1.0 - t;
    final scale = 1.0 - (t * 0.1);
    final translateY = t * -20.0;

    return Container(
      color: Colors.transparent,
      child: Opacity(
        opacity: opacity,
        child: Transform.translate(
          offset: Offset(0, translateY),
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(
                top: AppDimensions.spacingXLarge,
                left: AppDimensions.screenHorizontalPadding,
                right: AppDimensions.screenHorizontalPadding,
                bottom: AppDimensions.spacingSmall,
              ),
              child: _GreetingContent(
                displayName: displayName,
                avatarUrl: avatarUrl,
                onAvatarTap: onAvatarTap,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant GreetingHeader oldDelegate) {
    return oldDelegate.displayName != displayName || oldDelegate.avatarUrl != avatarUrl;
  }
}

class _GreetingContent extends StatefulWidget {
  final String displayName;
  final String? avatarUrl;
  final VoidCallback onAvatarTap;

  const _GreetingContent({
    required this.displayName,
    this.avatarUrl,
    required this.onAvatarTap,
  });

  @override
  State<_GreetingContent> createState() => _GreetingContentState();
}

class _GreetingContentState extends State<_GreetingContent> {
  final GamificationService _gamification = GamificationService();
  
  int _streak = 0;
  String _greeting = '';
  AvoExpression _mood = AvoExpression.happy;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final streak = await _gamification.updateStreak();
    final (greeting, mood) = _gamification.getTimeBasedGreeting(widget.displayName);
    
    if (mounted) {
      setState(() {
        _streak = streak;
        _greeting = greeting;
        _mood = mood;
        _initialized = true;
      });
    }
  }

  void _onMascotTap() {
    HapticFeedback.lightImpact();
    // Just haptic feedback, don't change the greeting
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Hey ${widget.displayName}! 👋',
                  style: AppTextStyles.h1.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _buildAvatar(),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mascot
        GestureDetector(
          onTap: _onMascotTap,
          child: AvoMascot(
            size: 55,
            expression: _mood,
            animate: true,
          ),
        ),
        
        const SizedBox(width: 14),
        
        // Greeting and streak
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Greeting message
              Text(
                _greeting,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary(context),
                  height: 1.35,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              // Streak badge
              if (_streak > 1) ...[
                const SizedBox(height: 8),
                _buildStreakBadge(),
              ],
            ],
          ),
        ),
        
        const SizedBox(width: 12),
        
        // Avatar
        _buildAvatar(),
      ],
    );
  }

  Widget _buildStreakBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF9500).withOpacity(0.15),
            const Color(0xFFFF6B00).withOpacity(0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            '$_streak day streak',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFFFF9500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return GestureDetector(
      onTap: widget.onAvatarTap,
      child: CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.accent,
        backgroundImage: widget.avatarUrl != null
            ? NetworkImage(widget.avatarUrl!)
            : null,
        child: widget.avatarUrl == null
            ? Text(
                (widget.displayName.isNotEmpty ? widget.displayName[0] : 'U').toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              )
            : null,
      ),
    );
  }
}

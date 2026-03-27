import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/providers/subscription_provider.dart';
import 'package:shoply/presentation/screens/subscription/subscription_screen.dart';

/// Widget that gates premium features behind a subscription
/// Shows an overlay with a premium badge when the user is not subscribed
class PremiumFeatureGate extends ConsumerWidget {
  final Widget child;
  final String? featureName;
  final bool showBadgeOnly;
  final VoidCallback? onTap;

  const PremiumFeatureGate({
    super.key,
    required this.child,
    this.featureName,
    this.showBadgeOnly = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSubscribed = ref.watch(isSubscribedProvider);

    if (isSubscribed) {
      return child;
    }

    return GestureDetector(
      onTap: onTap ?? () => _showSubscriptionSheet(context),
      child: Stack(
        children: [
          // Original content with reduced opacity
          Opacity(
            opacity: showBadgeOnly ? 1.0 : 0.5,
            child: IgnorePointer(
              ignoring: !showBadgeOnly,
              child: child,
            ),
          ),
          
          // Premium overlay
          if (!showBadgeOnly)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: _buildPremiumBadge(context),
                ),
              ),
            ),
          
          // Premium badge in corner
          if (showBadgeOnly)
            Positioned(
              top: 8,
              right: 8,
              child: _buildSmallBadge(context),
            ),
        ],
      ),
    );
  }

  Widget _buildPremiumBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.shade400,
            Colors.orange.shade600,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.workspace_premium_rounded,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('premium_feature'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                context.tr('unlock_with_pro'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.shade400,
            Colors.orange.shade600,
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            color: Colors.white,
            size: 14,
          ),
          SizedBox(width: 4),
          Text(
            'PRO',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  void _showSubscriptionSheet(BuildContext context) {
    showSubscriptionSheet(context);
  }
}

/// A button that shows the subscription screen when tapped
class GoProButton extends ConsumerWidget {
  final bool compact;
  
  const GoProButton({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSubscribed = ref.watch(isSubscribedProvider);

    if (isSubscribed) {
      return const SizedBox.shrink();
    }

    if (compact) {
      return GestureDetector(
        onTap: () => showSubscriptionSheet(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.amber.shade400,
                Colors.orange.shade600,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.workspace_premium_rounded,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                context.tr('go_pro'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: () => showSubscriptionSheet(context),
      icon: const Icon(Icons.workspace_premium_rounded),
      label: Text(context.tr('go_pro')),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange.shade500,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

/// Premium locked overlay for full-screen features
class PremiumLockedOverlay extends ConsumerWidget {
  final String featureName;
  final String? description;
  final IconData? icon;

  const PremiumLockedOverlay({
    super.key,
    required this.featureName,
    this.description,
    this.icon,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Premium icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.amber.shade400,
                        Colors.orange.shade600,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon ?? Icons.workspace_premium_rounded,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Feature name
                Text(
                  featureName,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 12),
                
                // Description
                Text(
                  description ?? context.tr('premium_feature_locked'),
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 32),
                
                // Unlock button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => showSubscriptionSheet(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade500,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      context.tr('unlock_with_pro'),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Back button
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    context.tr('back'),
                    style: TextStyle(
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

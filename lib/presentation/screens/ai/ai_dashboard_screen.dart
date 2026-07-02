import 'package:flutter/material.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/app_dimensions.dart';
import 'package:shoply/core/constants/app_text_styles.dart';

/// Redesigned AI Dashboard matching app's design system
class AIDashboardScreen extends StatelessWidget {
  const AIDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('AI Assistant', style: AppTextStyles.h2),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.screenHorizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Nutrition Score Card - Simplified
            _buildNutritionScoreCard(context, isDark, score: 78),
            const SizedBox(height: AppDimensions.screenHorizontalPadding),
            
            // AI Features Grid - Available to all users
            _buildFeatureCard(
              context,
              isDark,
              icon: Icons.calendar_today_rounded,
              title: 'AI Meal Planning',
              description: 'Get personalized weekly meal plans based on your preferences',
              onTap: () => _showComingSoon(context),
              featured: true,
            ),
            const SizedBox(height: AppDimensions.cardPadding),
            
            // Two column grid
            Row(
              children: [
                Expanded(
                  child: _buildFeatureCard(
                    context,
                    isDark,
                    icon: Icons.restaurant_rounded,
                    title: 'Recipe Suggestions',
                    description: 'Smart recommendations',
                    onTap: () => _showComingSoon(context),
                    compact: true,
                  ),
                ),
                const SizedBox(width: AppDimensions.cardPadding),
                Expanded(
                  child: _buildFeatureCard(
                    context,
                    isDark,
                    icon: Icons.shopping_cart_rounded,
                    title: 'Smart Shopping',
                    description: 'Predictive lists',
                    onTap: () => _showComingSoon(context),
                    compact: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.cardPadding),
            
            _buildFeatureCard(
              context,
              isDark,
              icon: Icons.insights_rounded,
              title: 'Nutrition Insights',
              description: 'Track your health trends and get personalized recommendations',
              onTap: () => _showComingSoon(context),
            ),
            const SizedBox(height: AppDimensions.cardPadding),
            
            // Settings Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isDark ? Colors.grey.shade800 : PaperColors.hairline,
                  width: 1,
                ),
              ),
              child: SwitchListTile(
                title: Text(
                  'Enable AI Recommendations',
                  style: AppTextStyles.h4,
                ),
                subtitle: Text(
                  'Show smart suggestions in shopping lists',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.grey.shade400 : PaperColors.muted,
                  ),
                ),
                value: true,
                onChanged: (value) {
                  // Placeholder
                },
                activeColor: AppColors.accentBlue,
              ),
            ),
            
            // Extra padding for bottom navigation
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionScoreCard(BuildContext context, bool isDark, {required int score}) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.grey.shade800 : PaperColors.hairline,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Nutrition Score', style: AppTextStyles.h3),
                Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.accentBlue,
                  size: 24,
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Simple circular progress indicator instead of custom gauge
            SizedBox(
              height: 120,
              width: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CupertinoActivityIndicator(
                    color: _getScoreColor(score),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$score',
                        style: theme.textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _getScoreColor(score),
                        ),
                      ),
                      Text(
                        _getScoreLabel(score),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.grey.shade400 : PaperColors.muted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Based on your recent shopping and meal choices',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.grey.shade400 : PaperColors.muted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context,
    bool isDark, {
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
    bool featured = false,
    bool compact = false,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.grey.shade800 : PaperColors.hairline,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(featured ? 20 : AppDimensions.cardPadding),
          child: compact
              ? _buildCompactContent(context, isDark, icon, title, description)
              : _buildFullContent(context, isDark, icon, title, description, featured),
        ),
      ),
    );
  }

  Widget _buildCompactContent(
    BuildContext context,
    bool isDark,
    IconData icon,
    String title,
    String description,
  ) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.accentBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 28,
            color: AppColors.accentBlue,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: AppTextStyles.h4.copyWith(fontSize: 15),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isDark ? Colors.grey.shade400 : PaperColors.muted,
            fontSize: 12,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildFullContent(
    BuildContext context,
    bool isDark,
    IconData icon,
    String title,
    String description,
    bool featured,
  ) {
    final theme = Theme.of(context);
    
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.accentBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 32,
            color: AppColors.accentBlue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: featured ? AppTextStyles.h3 : AppTextStyles.h4,
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.grey.shade400 : PaperColors.muted,
                ),
              ),
            ],
          ),
        ),
        if (featured) ...[
          const SizedBox(width: 12),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: isDark ? Colors.grey.shade400 : PaperColors.muted,
          ),
        ],
      ],
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return AppColors.accentBlue;
    if (score >= 60) return AppColors.accentBlue.withValues(alpha: 0.7);
    if (score >= 40) return Colors.orange;
    return Colors.grey.shade500;
  }

  String _getScoreLabel(int score) {
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Fair';
    return 'Needs Improvement';
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Coming soon!'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

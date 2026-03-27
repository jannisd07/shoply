import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/data/services/dynamic_tutorial_service.dart';
import 'package:shoply/presentation/screens/profile/settings/display_name_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/personal_info_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/diet_preferences_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/theme_customization_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/help_support_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/notifications_screen.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/providers/subscription_provider.dart';
import 'package:shoply/presentation/screens/subscription/subscription_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final backgroundColor = AppColors.background(context);
    final separatorColor = AppColors.divider(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: 120 + MediaQuery.of(context).padding.bottom,
          ),
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Text(
                context.tr('settings'),
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            
            // Go Pro Banner
            _buildProBanner(context),
            
            // SECTION: Account
            _buildSectionHeader('Account', textSecondary),
            _buildSettingsItem(
              icon: Icons.person_outline_rounded,
              title: context.tr('profile'),
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DisplayNameScreen()),
              ),
            ),
            _buildDivider(separatorColor),
            _buildSettingsItem(
              icon: Icons.badge_outlined,
              title: context.tr('personal_information'),
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PersonalInfoScreen()),
              ),
            ),
            _buildDivider(separatorColor),
            _buildSettingsItem(
              icon: Icons.restaurant_outlined,
              title: context.tr('diet_allergies'),
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DietPreferencesScreen()),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // SECTION: Preferences
            _buildSectionHeader('Preferences', textSecondary),
            _buildSettingsItem(
              icon: Icons.palette_outlined,
              title: context.tr('appearance'),
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ThemeCustomizationScreen()),
              ),
            ),
            _buildDivider(separatorColor),
            _buildSettingsItem(
              icon: Icons.notifications_outlined,
              title: context.tr('notifications'),
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              onTap: () => Navigator.push(
                context,
                CupertinoPageRoute(builder: (context) => const NotificationsScreen()),
              ),
            ),

            const SizedBox(height: 32),

            // SECTION: Support
            _buildSectionHeader('Support', textSecondary),
            _buildSettingsItem(
              icon: Icons.help_outline_rounded,
              title: context.tr('help_support'),
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HelpSupportScreen()),
              ),
            ),
            _buildDivider(separatorColor),
            _buildSettingsItem(
              icon: Icons.school_outlined,
              title: 'Restart Tutorial',
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              onTap: () async {
                HapticFeedback.mediumImpact();
                await DynamicTutorialService.instance.restartTutorial();
                if (context.mounted) {
                  context.go('/home');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tutorial neu gestartet! Folge Avos Anweisungen.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
            _buildDivider(separatorColor),
            _buildSettingsItem(
              icon: Icons.shield_outlined,
              title: context.tr('privacy'),
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              onTap: () => context.push('/privacy-policy'),
            ),
            _buildDivider(separatorColor),
            _buildSettingsItem(
              icon: Icons.description_outlined,
              title: context.tr('terms_of_service'),
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              onTap: () => context.push('/terms-of-service'),
            ),
            _buildDivider(separatorColor),
            _buildSettingsItem(
              icon: Icons.info_outline_rounded,
              title: context.tr('app_version'),
              trailing: '1.0.0',
              showChevron: false,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            
            const SizedBox(height: 48),
            
            // Sign Out Button
            GestureDetector(
              onTap: () async {
                HapticFeedback.mediumImpact();
                await SupabaseService.instance.signOut();
                if (context.mounted) {
                  context.go('/welcome');
                }
              },
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    context.tr('sign_out'),
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    String? trailing,
    bool showChevron = true,
    required Color textPrimary,
    required Color textSecondary,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap?.call();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              color: textPrimary,
              size: 22,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing,
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 16,
                ),
              ),
            if (showChevron) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: textSecondary,
                size: 20,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProBanner(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSubscribed = ref.watch(isSubscribedProvider);
    final fg = AppColors.textPrimary(context);
    final muted = AppColors.textSecondary(context);
    
    if (isSubscribed) {
      return Container(
        margin: const EdgeInsets.only(bottom: 32),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Text(
              'Pro',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: fg,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.tr('subscription_success'),
                style: TextStyle(
                  fontSize: 14,
                  color: muted,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            Icon(
              Icons.check_circle_rounded,
              color: fg,
              size: 22,
            ),
          ],
        ),
      );
    }
    
    return GestureDetector(
      onTap: () => showSubscriptionSheet(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 32),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: isDark ? Colors.white : Colors.black,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Text(
              'Pro',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.black : Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.tr('unlock_premium_features'),
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.7),
                  letterSpacing: -0.2,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_rounded,
              color: isDark ? Colors.black : Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 38),
      child: Container(
        height: 0.5,
        color: color,
      ),
    );
  }
}

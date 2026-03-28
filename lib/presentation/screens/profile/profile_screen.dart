import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/data/services/dynamic_tutorial_service.dart';
import 'package:shoply/presentation/screens/profile/settings/display_name_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/personal_info_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/diet_preferences_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/theme_customization_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/help_support_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/notifications_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/language_screen.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/providers/subscription_provider.dart';
import 'package:shoply/presentation/screens/subscription/subscription_screen.dart';
import 'package:shoply/presentation/state/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final backgroundColor = AppColors.background(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userAsync = ref.watch(currentUserProvider);

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
              padding: const EdgeInsets.only(bottom: 28),
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

            // Profile Card
            _buildProfileCard(context, userAsync, isDark, textPrimary, textSecondary),

            const SizedBox(height: 28),

            // Go Pro Banner
            _buildProBanner(context),

            // SECTION: Account
            _buildSectionHeader(context.tr('account'), textSecondary),
            _buildSettingsGroup(
              context,
              isDark: isDark,
              items: [
                _SettingsItemData(
                  icon: Icons.person_outline_rounded,
                  title: context.tr('profile'),
                  onTap: () => Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (context) => const DisplayNameScreen()),
                  ),
                ),
                _SettingsItemData(
                  icon: Icons.badge_outlined,
                  title: context.tr('personal_information'),
                  onTap: () => Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (context) => const PersonalInfoScreen()),
                  ),
                ),
                _SettingsItemData(
                  icon: Icons.restaurant_outlined,
                  title: context.tr('diet_allergies'),
                  onTap: () => Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (context) => const DietPreferencesScreen()),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // SECTION: Preferences
            _buildSectionHeader(context.tr('preferences'), textSecondary),
            _buildSettingsGroup(
              context,
              isDark: isDark,
              items: [
                _SettingsItemData(
                  icon: Icons.palette_outlined,
                  title: context.tr('appearance'),
                  onTap: () => Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (context) => const ThemeCustomizationScreen()),
                  ),
                ),
                _SettingsItemData(
                  icon: Icons.notifications_outlined,
                  title: context.tr('notifications'),
                  onTap: () => Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (context) => const NotificationsScreen()),
                  ),
                ),
                _SettingsItemData(
                  icon: Icons.language_rounded,
                  title: context.tr('language'),
                  onTap: () => Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (context) => const LanguageScreen()),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // SECTION: Support
            _buildSectionHeader(context.tr('support'), textSecondary),
            _buildSettingsGroup(
              context,
              isDark: isDark,
              items: [
                _SettingsItemData(
                  icon: Icons.help_outline_rounded,
                  title: context.tr('help_support'),
                  onTap: () => Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (context) => const HelpSupportScreen()),
                  ),
                ),
                _SettingsItemData(
                  icon: Icons.school_outlined,
                  title: context.tr('restart_tutorial'),
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    await DynamicTutorialService.instance.restartTutorial();
                    if (context.mounted) {
                      context.go('/home');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.tr('tutorial_restarted')),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
                _SettingsItemData(
                  icon: Icons.shield_outlined,
                  title: context.tr('privacy'),
                  onTap: () => context.push('/privacy-policy'),
                ),
                _SettingsItemData(
                  icon: Icons.description_outlined,
                  title: context.tr('terms_of_service'),
                  onTap: () => context.push('/terms-of-service'),
                ),
                _SettingsItemData(
                  icon: Icons.info_outline_rounded,
                  title: context.tr('app_version'),
                  trailing: '1.0.0',
                  showChevron: false,
                ),
              ],
            ),

            const SizedBox(height: 36),

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
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    context.tr('sign_out'),
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 16,
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

  Widget _buildProfileCard(
    BuildContext context,
    AsyncValue userAsync,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.push(
          context,
          CupertinoPageRoute(builder: (context) => const DisplayNameScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
        child: userAsync.when(
          data: (user) {
            final displayName = user?.displayName ?? 'User';
            final email = user?.email ?? '';
            final avatarUrl = user?.avatarUrl;
            final initials = displayName.isNotEmpty
                ? displayName[0].toUpperCase()
                : '?';

            return Row(
              children: [
                // Avatar
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                  child: avatarUrl != null && avatarUrl.isNotEmpty
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: avatarUrl,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Center(
                              child: Text(
                                initials,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Center(
                              child: Text(
                                initials,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            initials,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 16),
                // Name & Email
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          email,
                          style: TextStyle(
                            fontSize: 14,
                            color: textSecondary,
                            letterSpacing: -0.1,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: textSecondary,
                  size: 22,
                ),
              ],
            );
          },
          loading: () => Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 120,
                      height: 18,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 180,
                      height: 14,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          error: (_, __) => Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.06),
                ),
                child: Center(
                  child: Text(
                    '?',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'User',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(
    BuildContext context, {
    required bool isDark,
    required List<_SettingsItemData> items,
  }) {
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Column(
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isLast = index == items.length - 1;

          return Column(
            children: [
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  item.onTap?.call();
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          item.icon,
                          color: textPrimary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      if (item.trailing != null)
                        Text(
                          item.trailing!,
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 15,
                          ),
                        ),
                      if (item.showChevron) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: textSecondary,
                          size: 20,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.only(left: 62),
                  child: Container(
                    height: 0.5,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildProBanner(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSubscribed = ref.watch(isSubscribedProvider);
    final fg = AppColors.textPrimary(context);
    final muted = AppColors.textSecondary(context);

    if (isSubscribed) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white : Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'PRO',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.black : Colors.white,
                    letterSpacing: 0.5,
                  ),
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
                size: 20,
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: GestureDetector(
        onTap: () => showSubscriptionSheet(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white : Colors.black,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'PRO',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.white,
                    letterSpacing: 0.5,
                  ),
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
      ),
    );
  }
}

class _SettingsItemData {
  final IconData icon;
  final String title;
  final String? trailing;
  final bool showChevron;
  final VoidCallback? onTap;

  const _SettingsItemData({
    required this.icon,
    required this.title,
    this.trailing,
    this.showChevron = true,
    this.onTap,
  });
}

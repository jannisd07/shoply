import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/data/services/dynamic_tutorial_service.dart';
import 'package:shoply/presentation/screens/profile/settings/display_name_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/personal_info_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/diet_preferences_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/app_priorities_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/theme_customization_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/help_support_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/notifications_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/language_screen.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/providers/subscription_provider.dart';
import 'package:shoply/presentation/state/calorie_tracking_provider.dart';
import 'package:shoply/presentation/state/language_provider.dart';
import 'package:shoply/presentation/state/lists_provider.dart';
import 'package:shoply/presentation/state/saved_recipes_provider.dart';
import 'package:shoply/presentation/state/shopping_history_provider.dart';
import 'package:shoply/presentation/screens/subscription/subscription_screen.dart';
import 'package:shoply/presentation/state/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  /// Attribution for the third-party data the app displays.
  void _showDataSources(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppColors.background(ctx),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.divider(ctx),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              ctx.tr('data_sources'),
              style: PaperTextStyles.serif(
                20,
                color: AppColors.textPrimary(ctx),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              ctx.tr('data_sources_body'),
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.textSecondary(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openExternal(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

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
                style: PaperTextStyles.serif(30, color: textPrimary),
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
                  trailing: ref.watch(languageProvider) == 'de'
                      ? 'Deutsch'
                      : 'English',
                  onTap: () => Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (context) => const LanguageScreen()),
                  ),
                ),
                _SettingsItemData(
                  icon: Icons.tune_rounded,
                  title: context.tr('app_priorities'),
                  onTap: () => Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (context) => const AppPrioritiesScreen()),
                  ),
                ),
                _SettingsItemData(
                  icon: Icons.local_fire_department_outlined,
                  title: context.tr('calorie_tracking'),
                  showChevron: false,
                  trailingWidget: Switch.adaptive(
                    value: ref.watch(calorieTrackingEnabledProvider),
                    activeColor: AppColors.accentColor(context),
                    onChanged: (v) => ref
                        .read(calorieTrackingEnabledProvider.notifier)
                        .setEnabled(v),
                  ),
                  onTap: () => ref
                      .read(calorieTrackingEnabledProvider.notifier)
                      .setEnabled(!ref.read(calorieTrackingEnabledProvider)),
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
                  external: true,
                  onTap: () => _openExternal('https://joinavo.app/privacy'),
                ),
                _SettingsItemData(
                  icon: Icons.description_outlined,
                  title: context.tr('imprint'),
                  external: true,
                  onTap: () => _openExternal('https://joinavo.app/impressum'),
                ),
                // ODbL requires crediting Open Prices / Open Food Facts
                // wherever their price data is used, and OpenStreetMap
                // likewise for the store locations. Keeping this as a
                // permanent settings entry satisfies that regardless of
                // which screen happens to surface a price.
                _SettingsItemData(
                  icon: Icons.dataset_outlined,
                  title: context.tr('data_sources'),
                  onTap: () => _showDataSources(context),
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
                    color: PaperColors.danger.withValues(
                      alpha: isDark ? 0.45 : 0.28,
                    ),
                  ),
                ),
                child: Center(
                  child: Text(
                    context.tr('sign_out'),
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFFE0887A)
                          : PaperColors.danger,
                      fontSize: 15,
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
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: userAsync.when(
          data: (user) {
            final displayName = user?.displayName ?? 'User';
            final email = user?.email ?? '';
            final avatarUrl = user?.avatarUrl;
            final initials = displayName.isNotEmpty
                ? displayName[0].toUpperCase()
                : '?';

            final headerRow = Row(
              children: [
                // Avatar
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: PaperColors.cream,
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
                        style: PaperTextStyles.serif(19, color: textPrimary),
                      ),
                      const SizedBox(height: 3),
                      if (ref.watch(isSubscribedProvider))
                        Text(
                          'Premium',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.accentColor(context),
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      else if (email.isNotEmpty)
                        Text(
                          email,
                          style: TextStyle(
                            fontSize: 13,
                            color: textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
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

            final listsCount =
                ref.watch(listsNotifierProvider).valueOrNull?.length ?? 0;
            final tripsCount =
                ref.watch(shoppingHistoryProvider).valueOrNull?.length ?? 0;
            final savedCount =
                ref.watch(savedRecipesProvider).savedIds.length;

            return Column(
              children: [
                headerRow,
                const SizedBox(height: 14),
                Container(height: 1, color: AppColors.divider(context)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStat(
                      context,
                      '$tripsCount',
                      context.tr('purchases_label'),
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: AppColors.divider(context),
                    ),
                    _buildStat(
                      context,
                      '$listsCount',
                      context.tr('lists_label'),
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: AppColors.divider(context),
                    ),
                    _buildStat(
                      context,
                      '$savedCount',
                      context.tr('saved_label'),
                    ),
                  ],
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

  Widget _buildStat(BuildContext context, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: PaperTextStyles.serif(
              19,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9.5,
              letterSpacing: 1,
              color: AppColors.textSecondary(context),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
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
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 2,
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
      decoration: const BoxDecoration(),
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
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 13),
                  child: Row(
                    children: [
                      Icon(
                        item.icon,
                        color: textSecondary,
                        size: 17,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      if (item.trailing != null)
                        Text(
                          item.trailing!,
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      if (item.trailingWidget != null) item.trailingWidget!,
                      if (item.external) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.open_in_new_rounded,
                          color: textSecondary,
                          size: 15,
                        ),
                      ] else if (item.showChevron) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: textSecondary,
                          size: 18,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (!isLast)
                Padding(
                  padding: EdgeInsets.zero,
                  child: Container(
                    height: 1,
                    color: AppColors.divider(context),
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

    final card = BoxDecoration(
      color: isDark ? const Color(0xFF1C1C1E) : PaperColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: isDark ? const Color(0xFF2C2C2E) : PaperColors.hairline,
      ),
    );

    if (isSubscribed) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: card,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Avo Premium',
                      style: PaperTextStyles.serif(
                        15,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr('subscription_success'),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: PaperColors.sage,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: PaperColors.sageInk,
                ),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: card,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Avo Premium',
                      style: PaperTextStyles.serif(
                        15,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr('premium_trial_line'),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: PaperColors.terracotta,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  context.tr('try_free'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: PaperColors.paper,
                  ),
                ),
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
  final Widget? trailingWidget;
  final bool showChevron;
  final bool external;
  final VoidCallback? onTap;

  const _SettingsItemData({
    required this.icon,
    required this.title,
    this.trailing,
    this.trailingWidget,
    this.showChevron = true,
    this.external = false,
    this.onTap,
  });
}

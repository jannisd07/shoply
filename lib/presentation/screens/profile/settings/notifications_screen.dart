import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/services/mascot_notification_service.dart';
import 'package:shoply/data/services/notification_preferences_service.dart';
import 'package:shoply/presentation/widgets/common/paper_settings.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _prefs = NotificationPreferencesService.instance;

  bool _masterEnabled = true;
  final Map<NotificationCategory, bool> _categoryValues = {};

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final master = await _prefs.isMasterEnabled();
    final values = <NotificationCategory, bool>{};
    for (final category in NotificationCategory.values) {
      values[category] = await _prefs.isCategoryEnabled(category);
    }
    if (!mounted) return;
    setState(() {
      _masterEnabled = master;
      _categoryValues.addAll(values);
      _isLoading = false;
    });

    // The DB is authoritative for the master switch (settable from other
    // devices / Avo chat) — refresh from remote in the background.
    await _prefs.syncFromRemote();
    final synced = await _prefs.isMasterEnabled();
    if (mounted && synced != master) {
      setState(() => _masterEnabled = synced);
    }
  }

  void _toggleMaster() {
    HapticFeedback.selectionClick();
    final newValue = !_masterEnabled;
    setState(() => _masterEnabled = newValue);
    _prefs.setMasterEnabled(newValue).then((_) {
      // Clears or re-arms Avo's scheduled reminders to match the new gate.
      MascotNotificationService.instance.rearmRestockReminder(force: true);
      MascotNotificationService.instance.rearmDinnerIdeasReminder(force: true);
    });
  }

  void _toggleCategory(NotificationCategory category) {
    HapticFeedback.selectionClick();
    final newValue = !(_categoryValues[category] ?? category.defaultValue);
    setState(() => _categoryValues[category] = newValue);
    _prefs.setCategoryEnabled(category, newValue).then((_) {
      if (category == NotificationCategory.avoNudges) {
        MascotNotificationService.instance.rearmRestockReminder(force: true);
        MascotNotificationService.instance
            .rearmDinnerIdeasReminder(force: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = AppColors.background(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final separatorColor = AppColors.divider(context);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: PaperSettingsAppBar(title: context.tr('notifications')),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : ListView(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 8,
                bottom: 60 + MediaQuery.of(context).padding.bottom,
              ),
              children: [
                // Master switch (enforced account-wide, incl. push delivery)
                _buildToggleItem(
                  title: context.tr('all_notifications'),
                  value: _masterEnabled,
                  textPrimary: textPrimary,
                  onTap: _toggleMaster,
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    context.tr('all_notifications_desc'),
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                ),
                const SizedBox(height: 20),

                // Category toggles are inert while the master switch is off.
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOutCubic,
                  opacity: _masterEnabled ? 1.0 : 0.4,
                  child: IgnorePointer(
                    ignoring: !_masterEnabled,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // SECTION: Avo
                        PaperSectionHeader(context.tr('avo_section')),
                        _buildToggleItem(
                          title: context.tr('avo_restock_reminders'),
                          value: _categoryValue(NotificationCategory.avoNudges),
                          textPrimary: textPrimary,
                          onTap: () =>
                              _toggleCategory(NotificationCategory.avoNudges),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            context.tr('avo_restock_reminders_desc'),
                            style:
                                TextStyle(fontSize: 12, color: textSecondary),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // SECTION: Listen (Lists)
                        PaperSectionHeader(context.tr('lists_section')),
                        _buildToggleItem(
                          title: context.tr('when_items_added'),
                          value:
                              _categoryValue(NotificationCategory.listActivity),
                          textPrimary: textPrimary,
                          onTap: () => _toggleCategory(
                              NotificationCategory.listActivity),
                        ),
                        _buildDivider(separatorColor),
                        _buildToggleItem(
                          title: context.tr('when_shopping_completed'),
                          value: _categoryValue(
                              NotificationCategory.shoppingCompleted),
                          textPrimary: textPrimary,
                          onTap: () => _toggleCategory(
                              NotificationCategory.shoppingCompleted),
                        ),
                        _buildDivider(separatorColor),
                        _buildToggleItem(
                          title: context.tr('list_invitations'),
                          value: _categoryValue(
                              NotificationCategory.listInvitations),
                          textPrimary: textPrimary,
                          onTap: () => _toggleCategory(
                              NotificationCategory.listInvitations),
                        ),

                        const SizedBox(height: 28),

                        // SECTION: Rezepte (Recipes)
                        PaperSectionHeader(context.tr('recipes_section')),
                        _buildToggleItem(
                          title: context.tr('likes_on_recipes'),
                          value:
                              _categoryValue(NotificationCategory.recipeLikes),
                          textPrimary: textPrimary,
                          onTap: () =>
                              _toggleCategory(NotificationCategory.recipeLikes),
                        ),
                        _buildDivider(separatorColor),
                        _buildToggleItem(
                          title: context.tr('comments_notifications'),
                          value: _categoryValue(
                              NotificationCategory.recipeComments),
                          textPrimary: textPrimary,
                          onTap: () => _toggleCategory(
                              NotificationCategory.recipeComments),
                        ),
                        _buildDivider(separatorColor),
                        _buildToggleItem(
                          title: context.tr('new_recipes_from_followed'),
                          value:
                              _categoryValue(NotificationCategory.newRecipes),
                          textPrimary: textPrimary,
                          onTap: () =>
                              _toggleCategory(NotificationCategory.newRecipes),
                        ),

                        const SizedBox(height: 28),

                        // SECTION: Allgemein (General)
                        PaperSectionHeader(context.tr('general_section')),
                        _buildToggleItem(
                          title: context.tr('weekly_summary'),
                          value: _categoryValue(
                              NotificationCategory.weeklySummary),
                          textPrimary: textPrimary,
                          onTap: () => _toggleCategory(
                              NotificationCategory.weeklySummary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  bool _categoryValue(NotificationCategory category) {
    return _categoryValues[category] ?? category.defaultValue;
  }

  Widget _buildToggleItem({
    required String title,
    required bool value,
    required Color textPrimary,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: 12),
          CupertinoSwitch(
            value: value,
            onChanged: (_) => onTap(),
            activeTrackColor: AppColors.accentColor(context),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(Color color) {
    return Container(
      height: 0.5,
      color: color,
    );
  }
}

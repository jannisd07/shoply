import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // Preference keys
  static const _keyItemsAdded = 'notif_items_added';
  static const _keyShoppingCompleted = 'notif_shopping_completed';
  static const _keyListInvitations = 'notif_list_invitations';
  static const _keyRecipeLikes = 'notif_recipe_likes';
  static const _keyComments = 'notif_comments';
  static const _keyNewRecipes = 'notif_new_recipes';
  static const _keyWeeklySummary = 'notif_weekly_summary';

  bool _itemsAdded = true;
  bool _shoppingCompleted = true;
  bool _listInvitations = true;
  bool _recipeLikes = true;
  bool _comments = true;
  bool _newRecipes = false;
  bool _weeklySummary = true;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _itemsAdded = prefs.getBool(_keyItemsAdded) ?? true;
      _shoppingCompleted = prefs.getBool(_keyShoppingCompleted) ?? true;
      _listInvitations = prefs.getBool(_keyListInvitations) ?? true;
      _recipeLikes = prefs.getBool(_keyRecipeLikes) ?? true;
      _comments = prefs.getBool(_keyComments) ?? true;
      _newRecipes = prefs.getBool(_keyNewRecipes) ?? false;
      _weeklySummary = prefs.getBool(_keyWeeklySummary) ?? true;
      _isLoading = false;
    });
  }

  Future<void> _savePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  void _toggle(String key, bool currentValue, void Function(bool) setter) {
    HapticFeedback.selectionClick();
    final newValue = !currentValue;
    setter(newValue);
    _savePreference(key, newValue);
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = AppColors.background(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final separatorColor = AppColors.divider(context);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          context.tr('notifications'),
          style: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
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
                // SECTION: Listen (Lists)
                _buildSectionHeader(context.tr('lists_section'), textSecondary),
                _buildToggleItem(
                  title: context.tr('when_items_added'),
                  value: _itemsAdded,
                  textPrimary: textPrimary,
                  onTap: () => _toggle(_keyItemsAdded, _itemsAdded, (v) => setState(() => _itemsAdded = v)),
                ),
                _buildDivider(separatorColor),
                _buildToggleItem(
                  title: context.tr('when_shopping_completed'),
                  value: _shoppingCompleted,
                  textPrimary: textPrimary,
                  onTap: () => _toggle(_keyShoppingCompleted, _shoppingCompleted, (v) => setState(() => _shoppingCompleted = v)),
                ),
                _buildDivider(separatorColor),
                _buildToggleItem(
                  title: context.tr('list_invitations'),
                  value: _listInvitations,
                  textPrimary: textPrimary,
                  onTap: () => _toggle(_keyListInvitations, _listInvitations, (v) => setState(() => _listInvitations = v)),
                ),

                const SizedBox(height: 32),

                // SECTION: Rezepte (Recipes)
                _buildSectionHeader(context.tr('recipes_section'), textSecondary),
                _buildToggleItem(
                  title: context.tr('likes_on_recipes'),
                  value: _recipeLikes,
                  textPrimary: textPrimary,
                  onTap: () => _toggle(_keyRecipeLikes, _recipeLikes, (v) => setState(() => _recipeLikes = v)),
                ),
                _buildDivider(separatorColor),
                _buildToggleItem(
                  title: context.tr('comments_notifications'),
                  value: _comments,
                  textPrimary: textPrimary,
                  onTap: () => _toggle(_keyComments, _comments, (v) => setState(() => _comments = v)),
                ),
                _buildDivider(separatorColor),
                _buildToggleItem(
                  title: context.tr('new_recipes_from_followed'),
                  value: _newRecipes,
                  textPrimary: textPrimary,
                  onTap: () => _toggle(_keyNewRecipes, _newRecipes, (v) => setState(() => _newRecipes = v)),
                ),

                const SizedBox(height: 32),

                // SECTION: Allgemein (General)
                _buildSectionHeader(context.tr('general_section'), textSecondary),
                _buildToggleItem(
                  title: context.tr('weekly_summary'),
                  value: _weeklySummary,
                  textPrimary: textPrimary,
                  onTap: () => _toggle(_keyWeeklySummary, _weeklySummary, (v) => setState(() => _weeklySummary = v)),
                ),
              ],
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
                fontSize: 17,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: 12),
          CupertinoSwitch(
            value: value,
            onChanged: (_) => onTap(),
            activeTrackColor: AppColors.textPrimary(context),
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

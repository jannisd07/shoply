import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/presentation/state/auth_provider.dart';

class DietPreferencesScreen extends ConsumerStatefulWidget {
  const DietPreferencesScreen({super.key});

  @override
  ConsumerState<DietPreferencesScreen> createState() => _DietPreferencesScreenState();
}

class _DietPreferencesScreenState extends ConsumerState<DietPreferencesScreen> {
  Set<String> _selectedPreferences = {};
  bool _isLoading = false;

  final List<DietPreference> _preferences = [
    DietPreference(id: 'vegetarian', label: 'Vegetarian', description: 'No meat or fish'),
    DietPreference(id: 'vegan', label: 'Vegan', description: 'No animal products'),
    DietPreference(id: 'gluten_free', label: 'Gluten-Free', description: 'No gluten-containing foods'),
    DietPreference(id: 'dairy_free', label: 'Dairy-Free', description: 'No milk or dairy products'),
    DietPreference(id: 'keto', label: 'Keto', description: 'Low-carb, high-fat diet'),
    DietPreference(id: 'paleo', label: 'Paleo', description: 'Whole foods, no processed items'),
    DietPreference(id: 'low_carb', label: 'Low-Carb', description: 'Reduced carbohydrate intake'),
    DietPreference(id: 'halal', label: 'Halal', description: 'Islamic dietary laws'),
    DietPreference(id: 'kosher', label: 'Kosher', description: 'Jewish dietary laws'),
    DietPreference(id: 'pescatarian', label: 'Pescatarian', description: 'Vegetarian plus fish'),
    DietPreference(id: 'nut_free', label: 'Nut-Free', description: 'No nuts or nut products'),
    DietPreference(id: 'low_sodium', label: 'Low-Sodium', description: 'Reduced salt intake'),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
  }

  Future<void> _loadUserPreferences() async {
    final user = SupabaseService.instance.currentUser;
    if (user == null) return;

    try {
      final response = await SupabaseService.instance
          .from('users')
          .select('diet_preferences')
          .eq('id', user.id)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _selectedPreferences = Set.from(
            (response['diet_preferences'] as List?)?.cast<String>() ?? []
          );
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _savePreferences() async {
    final user = SupabaseService.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      await SupabaseService.instance.from('users').update({
        'diet_preferences': _selectedPreferences.toList(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      ref.invalidate(currentUserProvider);

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
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
          context.tr('diet_preferences'),
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
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _savePreferences,
            child: _isLoading
                ? CupertinoActivityIndicator(radius: 10, color: textPrimary)
                : Text(
                    context.tr('save'),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 8,
          bottom: 60 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          if (_selectedPreferences.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16, left: 4),
              child: Text(
                '${_selectedPreferences.length} ${context.tr('selected')}',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 14,
                ),
              ),
            ),

          // Preferences section
          _buildSectionHeader(context.tr('diet_preferences'), textSecondary),
          ...List.generate(_preferences.length, (index) {
            final pref = _preferences[index];
            return Column(
              children: [
                _buildPreferenceRow(
                  pref: pref,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
                if (index < _preferences.length - 1)
                  _buildDivider(separatorColor),
              ],
            );
          }),

          const SizedBox(height: 32),

          // No restrictions
          _buildSectionHeader(context.tr('other'), textSecondary),
          _buildNoRestrictionsRow(textPrimary, textSecondary),
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

  Widget _buildPreferenceRow({
    required DietPreference pref,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final isSelected = _selectedPreferences.contains(pref.id);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          if (isSelected) {
            _selectedPreferences.remove(pref.id);
          } else {
            _selectedPreferences.add(pref.id);
          }
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pref.label,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pref.description,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: isSelected ? textPrimary : textSecondary.withOpacity(0.4),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoRestrictionsRow(Color textPrimary, Color textSecondary) {
    final isSelected = _selectedPreferences.isEmpty;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedPreferences.clear();
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('no_restrictions'),
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.tr('i_eat_everything'),
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: isSelected ? textPrimary : textSecondary.withOpacity(0.4),
              size: 22,
            ),
          ],
        ),
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

class DietPreference {
  final String id;
  final String label;
  final String description;

  const DietPreference({
    required this.id,
    required this.label,
    required this.description,
  });
}

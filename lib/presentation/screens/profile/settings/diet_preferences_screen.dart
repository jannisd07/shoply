import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/presentation/widgets/common/paper_settings.dart';
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
      appBar: PaperSettingsAppBar(
        title: context.tr('diet_preferences'),
        actions: [
          PaperSaveButton(
            label: context.tr('save'),
            loading: _isLoading,
            onPressed: _savePreferences,
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
          PaperSectionHeader(context.tr('diet_preferences')),
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
          PaperSectionHeader(context.tr('other')),
          _buildNoRestrictionsRow(textPrimary, textSecondary),
        ],
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
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pref.description,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: isSelected
                  ? AppColors.accentColor(context)
                  : textSecondary.withValues(alpha: 0.4),
              size: 21,
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
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.tr('i_eat_everything'),
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: isSelected
                  ? AppColors.accentColor(context)
                  : textSecondary.withValues(alpha: 0.4),
              size: 21,
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

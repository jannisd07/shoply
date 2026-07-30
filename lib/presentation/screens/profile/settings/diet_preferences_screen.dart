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

  static const List<String> _preferenceIds = [
    'vegetarian',
    'vegan',
    'gluten_free',
    'dairy_free',
    'keto',
    'paleo',
    'low_carb',
    'halal',
    'kosher',
    'pescatarian',
    'nut_free',
    'low_sodium',
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
          ...List.generate(_preferenceIds.length, (index) {
            final id = _preferenceIds[index];
            return Column(
              children: [
                _buildPreferenceRow(
                  id: id,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
                if (index < _preferenceIds.length - 1)
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
    required String id,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final isSelected = _selectedPreferences.contains(id);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          if (isSelected) {
            _selectedPreferences.remove(id);
          } else {
            _selectedPreferences.add(id);
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
                    context.tr('diet_$id'),
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.tr('diet_${id}_desc'),
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

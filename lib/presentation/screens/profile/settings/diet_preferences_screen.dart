import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/app_dimensions.dart';
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
    DietPreference(
      id: 'vegetarian',
      label: 'Vegetarian',
      icon: Icons.eco_rounded,
      description: 'No meat or fish',
    ),
    DietPreference(
      id: 'vegan',
      label: 'Vegan',
      icon: Icons.spa_rounded,
      description: 'No animal products',
    ),
    DietPreference(
      id: 'gluten_free',
      label: 'Gluten-Free',
      icon: Icons.grain_rounded,
      description: 'No gluten-containing foods',
    ),
    DietPreference(
      id: 'dairy_free',
      label: 'Dairy-Free',
      icon: Icons.no_drinks_rounded,
      description: 'No milk or dairy products',
    ),
    DietPreference(
      id: 'keto',
      label: 'Keto',
      icon: Icons.fitness_center_rounded,
      description: 'Low-carb, high-fat diet',
    ),
    DietPreference(
      id: 'paleo',
      label: 'Paleo',
      icon: Icons.nature_people_rounded,
      description: 'Whole foods, no processed items',
    ),
    DietPreference(
      id: 'low_carb',
      label: 'Low-Carb',
      icon: Icons.trending_down_rounded,
      description: 'Reduced carbohydrate intake',
    ),
    DietPreference(
      id: 'halal',
      label: 'Halal',
      icon: Icons.mosque_rounded,
      description: 'Islamic dietary laws',
    ),
    DietPreference(
      id: 'kosher',
      label: 'Kosher',
      icon: Icons.star_rounded,
      description: 'Jewish dietary laws',
    ),
    DietPreference(
      id: 'pescatarian',
      label: 'Pescatarian',
      icon: Icons.set_meal_rounded,
      description: 'Vegetarian plus fish',
    ),
    DietPreference(
      id: 'nut_free',
      label: 'Nut-Free',
      icon: Icons.block_rounded,
      description: 'No nuts or nut products',
    ),
    DietPreference(
      id: 'low_sodium',
      label: 'Low-Sodium',
      icon: Icons.water_drop_rounded,
      description: 'Reduced salt intake',
    ),
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
      
      // Refresh user data
      ref.invalidate(currentUserProvider);

      if (mounted) {
        setState(() => _isLoading = false);
        
        // Show success dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green.shade600,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.tr('diet_preferences_saved'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr('preferences_will_be_used'),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext); // Close dialog
                    Navigator.pop(context); // Go back to settings
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(context.tr('ok')),
                ),
              ),
            ],
          ),
        );
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
                ? CupertinoActivityIndicator(radius: 10, color: AppColors.accent)
                : Text(
                    context.tr('save'),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.only(
          left: AppDimensions.screenHorizontalPadding,
          right: AppDimensions.screenHorizontalPadding,
          top: AppDimensions.screenHorizontalPadding,
          bottom: 100 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          // Selected count
          if (_selectedPreferences.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                '${_selectedPreferences.length} ${context.tr('selected')}',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 14,
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Preference cards
          ..._preferences.map((pref) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildPreferenceCard(context, pref),
              )),

          const SizedBox(height: 16),

          // No restrictions option
          _buildNoRestrictionsCard(context),
        ],
      ),
    );
  }


  Widget _buildPreferenceCard(BuildContext context, DietPreference preference) {
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final inputFill = AppColors.inputFill(context);
    final borderColor = AppColors.border(context);
    final isSelected = _selectedPreferences.contains(preference.id);

    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedPreferences.remove(preference.id);
          } else {
            _selectedPreferences.add(preference.id);
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withOpacity(0.1) : inputFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.accent : borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected 
                    ? AppColors.accent.withOpacity(0.2) 
                    : AppColors.surface(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                preference.icon,
                size: 28,
                color: isSelected ? AppColors.accent : textSecondary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preference.label,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 15,
                      color: isSelected ? AppColors.accent : textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    preference.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.accent : Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppColors.accent : borderColor,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoRestrictionsCard(BuildContext context) {
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final inputFill = AppColors.inputFill(context);
    final borderColor = AppColors.border(context);
    final isSelected = _selectedPreferences.isEmpty;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedPreferences.clear();
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.success.withOpacity(0.1) : inputFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.success : borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.success.withOpacity(0.2)
                    : AppColors.surface(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.check_circle_outline_rounded,
                size: 24,
                color: isSelected ? AppColors.success : textSecondary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('no_restrictions'),
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 15,
                      color: isSelected ? AppColors.success : textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr('i_eat_everything'),
                    style: TextStyle(
                      fontSize: 13,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DietPreference {
  final String id;
  final String label;
  final IconData icon;
  final String description;

  const DietPreference({
    required this.id,
    required this.label,
    required this.icon,
    required this.description,
  });
}

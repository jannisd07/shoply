import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/app_dimensions.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/presentation/state/auth_provider.dart';

class PersonalInfoScreen extends ConsumerStatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  ConsumerState<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends ConsumerState<PersonalInfoScreen> {
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  String _selectedHeightUnit = 'cm';
  String? _selectedGender;
  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = SupabaseService.instance.currentUser;
    if (user == null) return;

    try {
      final response = await SupabaseService.instance
          .from('users')
          .select('age, height, height_unit, gender')
          .eq('id', user.id)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          if (response['age'] != null) {
            _ageController.text = response['age'].toString();
          }
          if (response['height'] != null) {
            _heightController.text = response['height'].toString();
          }
          _selectedHeightUnit = response['height_unit'] as String? ?? 'cm';
          _selectedGender = response['gender'] as String?;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  Future<void> _saveChanges() async {
    final user = SupabaseService.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final age = _ageController.text.isNotEmpty ? int.parse(_ageController.text) : null;
      final height = _heightController.text.isNotEmpty ? double.parse(_heightController.text) : null;

      await SupabaseService.instance.from('users').update({
        'age': age,
        'height': height,
        'height_unit': _selectedHeightUnit,
        'gender': _selectedGender,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      if (mounted) {
        setState(() => _hasChanges = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Personal information updated')),
        );
        // Refresh user data
        ref.invalidate(currentUserProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = AppColors.background(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final inputFill = AppColors.inputFill(context);
    final borderColor = AppColors.border(context);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          context.tr('personal_information'),
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
          if (_hasChanges)
            TextButton(
              onPressed: _isLoading ? null : _saveChanges,
              child: _isLoading
                  ? CupertinoActivityIndicator(radius: 10, color: AppColors.accent)
                  : Text(
                      context.tr('save'),
                      style: TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
        ],
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.only(
          left: AppDimensions.screenHorizontalPadding,
          right: AppDimensions.screenHorizontalPadding,
          top: AppDimensions.screenHorizontalPadding,
          bottom: 100 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          // Age section
          Text(
            context.tr('age'),
            style: TextStyle(
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: inputFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: TextField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: textPrimary),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              decoration: InputDecoration(
                hintText: context.tr('enter_your_age'),
                hintStyle: TextStyle(color: textSecondary),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
                suffixText: context.tr('years'),
                suffixStyle: TextStyle(color: textSecondary),
              ),
              onChanged: (_) => setState(() => _hasChanges = true),
            ),
          ),

          const SizedBox(height: 24),

          // Height section
          Text(
            context.tr('height'),
            style: TextStyle(
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          // Unit selector
          Row(
            children: [
              Expanded(
                child: _buildUnitButton(context, 'cm', 'Centimeters'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildUnitButton(context, 'ft', 'Feet'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: inputFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: TextField(
              controller: _heightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: textPrimary),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              decoration: InputDecoration(
                hintText: _selectedHeightUnit == 'cm' ? '170' : '5.7',
                hintStyle: TextStyle(color: textSecondary),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
                suffixText: _selectedHeightUnit,
                suffixStyle: TextStyle(color: textSecondary),
              ),
              onChanged: (_) => setState(() => _hasChanges = true),
            ),
          ),

          const SizedBox(height: 24),

          // Gender section
          Text(
            context.tr('gender'),
            style: TextStyle(
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          _buildGenderCard(
            context,
            gender: 'male',
            icon: Icons.male_rounded,
            label: context.tr('male'),
          ),
          const SizedBox(height: 12),
          _buildGenderCard(
            context,
            gender: 'female',
            icon: Icons.female_rounded,
            label: context.tr('female'),
          ),
          const SizedBox(height: 12),
          _buildGenderCard(
            context,
            gender: 'other',
            icon: Icons.transgender_rounded,
            label: context.tr('other'),
          ),
          const SizedBox(height: 12),
          _buildGenderCard(
            context,
            gender: 'prefer_not_to_say',
            icon: Icons.help_outline_rounded,
            label: context.tr('prefer_not_to_say'),
          ),

          const SizedBox(height: 32),

          // Info text
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accent.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.accent,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.tr('personal_info_hint'),
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitButton(BuildContext context, String unit, String label) {
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final inputFill = AppColors.inputFill(context);
    final borderColor = AppColors.border(context);
    final isSelected = _selectedHeightUnit == unit;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedHeightUnit = unit;
          _heightController.clear();
          _hasChanges = true;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withOpacity(0.1) : inputFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.accent : borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              unit.toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isSelected ? AppColors.accent : textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderCard(
    BuildContext context, {
    required String gender,
    required IconData icon,
    required String label,
  }) {
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final inputFill = AppColors.inputFill(context);
    final borderColor = AppColors.border(context);
    final isSelected = _selectedGender == gender;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedGender = gender;
          _hasChanges = true;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected 
                    ? AppColors.accent.withOpacity(0.2) 
                    : AppColors.surface(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 24,
                color: isSelected ? AppColors.accent : textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 15,
                  color: isSelected ? AppColors.accent : textPrimary,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: AppColors.accent,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}

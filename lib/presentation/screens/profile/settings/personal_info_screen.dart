import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/data/services/user_location_service.dart';
import 'package:shoply/presentation/providers/price_comparison_provider.dart';
import 'package:shoply/presentation/widgets/common/paper_settings.dart';
import 'package:shoply/presentation/state/auth_provider.dart';

class PersonalInfoScreen extends ConsumerStatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  ConsumerState<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends ConsumerState<PersonalInfoScreen> {
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _zipController = TextEditingController();
  String _selectedHeightUnit = 'cm';
  String? _selectedGender;
  String _initialZip = '';
  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadZipCode();
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

  Future<void> _loadZipCode() async {
    final zip = await UserLocationService.instance.getManualZipCode() ?? '';
    if (mounted) {
      setState(() {
        _zipController.text = zip;
        _initialZip = zip;
      });
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

      final zip = _zipController.text.trim();
      if (zip != _initialZip) {
        await UserLocationService.instance.setManualZipCode(zip);
        _initialZip = zip;
        ref.invalidate(userZipCodeProvider);
      }

      if (mounted) {
        setState(() => _hasChanges = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Personal information updated')),
        );
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
    _zipController.dispose();
    super.dispose();
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
        title: context.tr('personal_information'),
        actions: [
          if (_hasChanges)
            PaperSaveButton(
              label: context.tr('save'),
              loading: _isLoading,
              onPressed: _saveChanges,
            ),
        ],
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 8,
          bottom: 100 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          // Age section
          PaperSectionHeader(context.tr('age')),
          Container(
            decoration: paperFieldDecoration(context),
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

          const SizedBox(height: 32),

          // Height section
          PaperSectionHeader(context.tr('height')),

          // Unit toggle
          Row(
            children: [
              _buildUnitOption(context, 'cm', textPrimary, textSecondary, separatorColor),
              const SizedBox(width: 24),
              _buildUnitOption(context, 'ft', textPrimary, textSecondary, separatorColor),
            ],
          ),
          const SizedBox(height: 12),

          Container(
            decoration: paperFieldDecoration(context),
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

          const SizedBox(height: 32),

          // Gender section
          PaperSectionHeader(context.tr('gender')),
          _buildGenderRow(context, 'male', context.tr('male'), textPrimary, textSecondary),
          Container(height: 0.5, color: separatorColor),
          _buildGenderRow(context, 'female', context.tr('female'), textPrimary, textSecondary),
          Container(height: 0.5, color: separatorColor),
          _buildGenderRow(context, 'other', context.tr('other'), textPrimary, textSecondary),
          Container(height: 0.5, color: separatorColor),
          _buildGenderRow(context, 'prefer_not_to_say', context.tr('prefer_not_to_say'), textPrimary, textSecondary),

          const SizedBox(height: 32),

          // Zip code section (used for local offer/price lookups)
          PaperSectionHeader(context.tr('location_for_offers')),
          Container(
            decoration: paperFieldDecoration(context),
            child: TextField(
              controller: _zipController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: textPrimary),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(5),
              ],
              decoration: InputDecoration(
                hintText: context.tr('zip_code_hint'),
                hintStyle: TextStyle(color: textSecondary),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
              onChanged: (_) => setState(() => _hasChanges = true),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              context.tr('zip_code_field_hint'),
              style: TextStyle(color: textSecondary, fontSize: 12),
            ),
          ),

          const SizedBox(height: 32),

          // Info text
          Padding(
            padding: const EdgeInsets.only(left: 4),
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
    );
  }

  Widget _buildUnitOption(BuildContext context, String unit, Color textPrimary, Color textSecondary, Color separatorColor) {
    final isSelected = _selectedHeightUnit == unit;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedHeightUnit = unit;
          _heightController.clear();
          _hasChanges = true;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Icon(
            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: isSelected
                ? AppColors.accentColor(context)
                : textSecondary.withValues(alpha: 0.4),
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            unit.toUpperCase(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? textPrimary : textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderRow(BuildContext context, String gender, String label, Color textPrimary, Color textSecondary) {
    final isSelected = _selectedGender == gender;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedGender = gender;
          _hasChanges = true;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: textPrimary,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_rounded,
                color: AppColors.accentColor(context),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';

/// Provider for unit system preference
final unitSystemProvider = StateNotifierProvider<UnitSystemNotifier, UnitSystem>((ref) {
  return UnitSystemNotifier();
});

enum UnitSystem { metric, imperial }

class UnitSystemNotifier extends StateNotifier<UnitSystem> {
  UnitSystemNotifier() : super(UnitSystem.metric) {
    _loadPreference();
  }

  static const String _key = 'unit_system';

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    if (value == 'imperial') {
      state = UnitSystem.imperial;
    }
  }

  Future<void> setUnitSystem(UnitSystem system) async {
    state = system;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, system == UnitSystem.imperial ? 'imperial' : 'metric');
  }

  void toggle() {
    setUnitSystem(state == UnitSystem.metric ? UnitSystem.imperial : UnitSystem.metric);
  }

  bool get isMetric => state == UnitSystem.metric;
  bool get isImperial => state == UnitSystem.imperial;
}

/// Toggle widget for switching between metric and imperial units
class UnitConversionToggle extends ConsumerWidget {
  final bool showLabel;

  const UnitConversionToggle({super.key, this.showLabel = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitSystem = ref.watch(unitSystemProvider);
    final isMetric = unitSystem == UnitSystem.metric;
    final textSecondary = AppColors.textSecondary(context);
    final borderColor = AppColors.recipeBorderColor(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabel) ...[
          Text(
            context.tr('units'),
            style: TextStyle(
              color: textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Container(
          decoration: BoxDecoration(
            color: AppColors.recipeInput(context),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildOption(
                context,
                label: 'Metric',
                isSelected: isMetric,
                onTap: () => ref.read(unitSystemProvider.notifier).setUnitSystem(UnitSystem.metric),
              ),
              _buildOption(
                context,
                label: 'Imperial',
                isSelected: !isMetric,
                onTap: () => ref.read(unitSystemProvider.notifier).setUnitSystem(UnitSystem.imperial),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.recipeAccentColor(context) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary(context),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// Settings tile for unit conversion in settings screen
class UnitConversionSettingsTile extends ConsumerWidget {
  const UnitConversionSettingsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitSystem = ref.watch(unitSystemProvider);
    final isMetric = unitSystem == UnitSystem.metric;
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final inputFill = AppColors.recipeInput(context);
    final borderColor = AppColors.recipeBorderColor(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: inputFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.straighten_rounded, color: textSecondary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('unit_system'),
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isMetric 
                          ? context.tr('metric_description')
                          : context.tr('imperial_description'),
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildOptionTile(
                  context,
                  ref,
                  label: context.tr('metric'),
                  subtitle: 'g, ml, °C',
                  isSelected: isMetric,
                  onTap: () => ref.read(unitSystemProvider.notifier).setUnitSystem(UnitSystem.metric),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOptionTile(
                  context,
                  ref,
                  label: context.tr('imperial'),
                  subtitle: 'oz, cups, °F',
                  isSelected: !isMetric,
                  onTap: () => ref.read(unitSystemProvider.notifier).setUnitSystem(UnitSystem.imperial),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final borderColor = AppColors.recipeBorderColor(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.recipeAccentColor(context).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.recipeAccentColor(context) : borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.recipeAccentColor(context) : AppColors.textPrimary(context),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

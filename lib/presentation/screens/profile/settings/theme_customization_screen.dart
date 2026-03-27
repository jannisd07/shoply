import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/presentation/state/theme_provider.dart';

/// Simple Theme Customization Screen - Light/Dark/Auto mode only
class ThemeCustomizationScreen extends ConsumerWidget {
  const ThemeCustomizationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentThemeMode = ref.watch(themeModeProvider);
    final isDark = currentThemeMode == ThemeMode.dark ||
        (currentThemeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    final backgroundColor = AppColors.background(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final surfaceColor = AppColors.surface(context);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Appearance',
          style: TextStyle(
            color: textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mode Toggle Section
            _buildModeToggle(context, ref, currentThemeMode, isDark, surfaceColor, textPrimary, textSecondary),

            const SizedBox(height: 24),

            // Current mode description
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    currentThemeMode == ThemeMode.light
                        ? Icons.light_mode_rounded
                        : currentThemeMode == ThemeMode.dark
                            ? Icons.dark_mode_rounded
                            : Icons.brightness_auto_rounded,
                    color: AppColors.accent,
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentThemeMode == ThemeMode.light
                              ? 'Light Mode'
                              : currentThemeMode == ThemeMode.dark
                                  ? 'Dark Mode'
                                  : 'System',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currentThemeMode == ThemeMode.system
                              ? 'Follows your device settings'
                              : 'Manually selected',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
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

  Widget _buildModeToggle(
    BuildContext context,
    WidgetRef ref,
    ThemeMode currentMode,
    bool isDark,
    Color surfaceColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          _buildModeButton(
            context: context,
            ref: ref,
            icon: Icons.light_mode_rounded,
            label: 'Light',
            mode: ThemeMode.light,
            isSelected: currentMode == ThemeMode.light,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            isDark: isDark,
          ),
          _buildModeButton(
            context: context,
            ref: ref,
            icon: Icons.dark_mode_rounded,
            label: 'Dark',
            mode: ThemeMode.dark,
            isSelected: currentMode == ThemeMode.dark,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            isDark: isDark,
          ),
          _buildModeButton(
            context: context,
            ref: ref,
            icon: Icons.brightness_auto_rounded,
            label: 'Auto',
            mode: ThemeMode.system,
            isSelected: currentMode == ThemeMode.system,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required BuildContext context,
    required WidgetRef ref,
    required IconData icon,
    required String label,
    required ThemeMode mode,
    required bool isSelected,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          ref.read(themeModeProvider.notifier).setThemeMode(mode);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF3A3A3C) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? textPrimary : textSecondary,
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? textPrimary : textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

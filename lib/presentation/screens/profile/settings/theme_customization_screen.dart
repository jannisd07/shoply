import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/presentation/state/theme_provider.dart';

class ThemeCustomizationScreen extends ConsumerWidget {
  const ThemeCustomizationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentThemeMode = ref.watch(themeModeProvider);

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
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Appearance',
          style: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 4),
              child: Text(
                'THEME',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            // Theme options as simple rows
            _buildThemeRow(
              context: context,
              ref: ref,
              label: 'Light',
              subtitle: 'Always use light mode',
              mode: ThemeMode.light,
              currentMode: currentThemeMode,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            Container(height: 0.5, color: separatorColor),
            _buildThemeRow(
              context: context,
              ref: ref,
              label: 'Dark',
              subtitle: 'Always use dark mode',
              mode: ThemeMode.dark,
              currentMode: currentThemeMode,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            Container(height: 0.5, color: separatorColor),
            _buildThemeRow(
              context: context,
              ref: ref,
              label: 'System',
              subtitle: 'Follows your device settings',
              mode: ThemeMode.system,
              currentMode: currentThemeMode,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeRow({
    required BuildContext context,
    required WidgetRef ref,
    required String label,
    required String subtitle,
    required ThemeMode mode,
    required ThemeMode currentMode,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final isSelected = currentMode == mode;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        ref.read(themeModeProvider.notifier).setThemeMode(mode);
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
                    label,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w400,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_rounded,
                color: textPrimary,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}

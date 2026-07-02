import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/common/paper_settings.dart';
import 'package:shoply/presentation/state/theme_provider.dart';

class ThemeCustomizationScreen extends ConsumerWidget {
  const ThemeCustomizationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentThemeMode = ref.watch(themeModeProvider);
    final separatorColor = AppColors.divider(context);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: PaperSettingsAppBar(title: context.tr('appearance')),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PaperSectionHeader(context.tr('theme')),
            _buildThemeRow(
              context: context,
              ref: ref,
              label: context.tr('light_mode'),
              subtitle: context.tr('theme_light_desc'),
              mode: ThemeMode.light,
              currentMode: currentThemeMode,
            ),
            Container(height: 0.5, color: separatorColor),
            _buildThemeRow(
              context: context,
              ref: ref,
              label: context.tr('dark_mode'),
              subtitle: context.tr('theme_dark_desc'),
              mode: ThemeMode.dark,
              currentMode: currentThemeMode,
            ),
            Container(height: 0.5, color: separatorColor),
            _buildThemeRow(
              context: context,
              ref: ref,
              label: context.tr('system_label'),
              subtitle: context.tr('theme_system_desc'),
              mode: ThemeMode.system,
              currentMode: currentThemeMode,
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
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ],
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

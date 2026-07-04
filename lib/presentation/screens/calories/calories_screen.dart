import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/app_dimensions.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/state/calorie_tracking_provider.dart';

/// Kalorien tab — v0. The full tracking area (dashboard, food log, goals)
/// is Feature 6 and not built yet; this screen says so honestly instead of
/// faking data, and lets the user hide the tab again from right here.
class CaloriesScreen extends ConsumerWidget {
  const CaloriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final accent = AppColors.accentColor(context);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.screenHorizontalPadding,
            18,
            AppDimensions.screenHorizontalPadding,
            140, // clears the floating navbar
          ),
          children: [
            Text(
              context.tr('calories').toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.tr('calories_v0_title'),
              style: PaperTextStyles.serif(28, color: textPrimary),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.local_fire_department_outlined,
                      size: 26, color: accent),
                  const SizedBox(height: 12),
                  Text(
                    context.tr('calories_v0_card_title'),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr('calories_v0_card_sub'),
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  ref
                      .read(calorieTrackingEnabledProvider.notifier)
                      .setEnabled(false);
                },
                child: Text(
                  context.tr('hide_calories_tab'),
                  style: TextStyle(fontSize: 13, color: textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';

/// Seven small bars showing the last week's logged calories against the
/// daily target — a lightweight progress view without a chart dependency.
class WeeklyCaloriesStrip extends ConsumerWidget {
  final int target;
  final VoidCallback? onTap;

  const WeeklyCaloriesStrip({super.key, required this.target, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalsAsync = ref.watch(weeklyNutritionTotalsProvider);
    final textSecondary = AppColors.textSecondary(context);
    final accent = AppColors.accentColor(context);
    final locale = Localizations.localeOf(context).toString();

    return totalsAsync.when(
      loading: () => const SizedBox(height: 56),
      error: (_, __) => const SizedBox.shrink(),
      data: (totals) {
        final today = DateTime.now();
        final days = List.generate(
            7, (i) => DateTime(today.year, today.month, today.day).subtract(Duration(days: 6 - i)));
        return GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            height: 56,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: days.map((day) {
                final calories = totals[day]?.calories ?? 0;
                final ratio = target <= 0 ? 0.0 : (calories / target).clamp(0.0, 1.2);
                final isToday =
                    day.year == today.year && day.month == today.month && day.day == today.day;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: 32 * (ratio == 0 ? 0.05 : ratio.clamp(0.08, 1.0)),
                          decoration: BoxDecoration(
                            color: ratio > 1.0
                                ? const Color(0xFFE0764A)
                                : (isToday ? accent : accent.withValues(alpha: 0.35)),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(DateFormat('E', locale).format(day).substring(0, 1),
                            style: TextStyle(
                                fontSize: 10,
                                color: isToday ? accent : textSecondary,
                                fontWeight: isToday ? FontWeight.w700 : FontWeight.w400)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

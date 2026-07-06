import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/widgets/design_system.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';

class WaterTrackerCard extends ConsumerWidget {
  final int targetMl;

  const WaterTrackerCard({super.key, required this.targetMl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalAsync = ref.watch(dailyWaterTotalProvider);
    final total = totalAsync.valueOrNull ?? 0;
    final progress = targetMl <= 0 ? 0.0 : (total / targetMl).clamp(0.0, 1.0);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final blue = const Color(0xFF5B9BD5);

    Future<void> add(int ml) async {
      HapticFeedback.selectionClick();
      await ref.read(waterLogServiceProvider).addEntry(ml);
      invalidateNutritionLog(ref);
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.water_drop_outlined, size: 20, color: blue),
              const SizedBox(width: 8),
              Text(context.tr('water'),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary)),
              const Spacer(),
              Text('${(total / 1000).toStringAsFixed(2)} / ${(targetMl / 1000).toStringAsFixed(1)} l',
                  style: TextStyle(fontSize: 12.5, color: textSecondary)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.border(context),
              valueColor: AlwaysStoppedAnimation(blue),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _quickAddChip(context, '+250 ml', () => add(250)),
              const SizedBox(width: 8),
              _quickAddChip(context, '+500 ml', () => add(500)),
              const SizedBox(width: 8),
              _quickAddChip(context, '+750 ml', () => add(750)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickAddChip(BuildContext context, String label, VoidCallback onTap) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 10),
          side: BorderSide(color: AppColors.border(context)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

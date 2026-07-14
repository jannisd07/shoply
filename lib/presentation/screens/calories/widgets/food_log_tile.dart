import 'package:flutter/material.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/data/models/food_log_entry.dart';

class FoodLogTile extends StatelessWidget {
  final FoodLogEntry entry;
  final VoidCallback onDelete;

  const FoodLogTile({super.key, required this.entry, required this.onDelete});

  IconData get _sourceIcon => switch (entry.source) {
        FoodLogSource.recipe => Icons.restaurant_menu,
        FoodLogSource.barcode => Icons.qr_code_scanner,
        FoodLogSource.photo => Icons.camera_alt_outlined,
        FoodLogSource.manual => Icons.edit_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    final macroParts = <String>[];
    if (entry.proteinG != null) macroParts.add('${entry.proteinG!.round()}g P');
    if (entry.carbsG != null) macroParts.add('${entry.carbsG!.round()}g C');
    if (entry.fatG != null) macroParts.add('${entry.fatG!.round()}g F');

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.error),
      ),
      onDismissed: (_) => onDelete(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            if (entry.photoUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  entry.photoUrl!,
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(_sourceIcon, size: 18, color: textSecondary),
                ),
              )
            else
              Icon(_sourceIcon, size: 18, color: textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.foodName,
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: textPrimary)),
                  if (macroParts.isNotEmpty)
                    Text(macroParts.join(' · '),
                        style: TextStyle(fontSize: 12, color: textSecondary)),
                ],
              ),
            ),
            Text('${entry.calories} kcal',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: textPrimary)),
          ],
        ),
      ),
    );
  }
}

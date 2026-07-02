import 'package:flutter/material.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/data/models/recommendation_item.dart';

class RecommendationCard extends StatelessWidget {
  final RecommendationItem recommendation;
  final VoidCallback onAdd;
  final VoidCallback? onDismiss;

  const RecommendationCard({
    super.key,
    required this.recommendation,
    required this.onAdd,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onAdd,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2C2C2E)
                        : PaperColors.cream,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getCategoryIcon(recommendation.category),
                    color: isDark
                        ? AppColors.textSecondary(context)
                        : PaperColors.creamInk,
                    size: 17,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _capitalizeItemName(recommendation.itemName),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        recommendation.reason,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.accentColor(context),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: PaperColors.paper,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _capitalizeItemName(String name) {
    if (name.isEmpty) return name;
    return name.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  IconData _getCategoryIcon(String? category) {
    if (category == null) return Icons.shopping_basket_outlined;

    final cat = category.toLowerCase();
    if (cat.contains('fruit') || cat.contains('vegetable')) {
      return Icons.eco_outlined;
    } else if (cat.contains('dairy') || cat.contains('milk')) {
      return Icons.water_drop_outlined;
    } else if (cat.contains('meat') || cat.contains('protein')) {
      return Icons.set_meal_outlined;
    } else if (cat.contains('bread') || cat.contains('bakery')) {
      return Icons.bakery_dining_outlined;
    } else if (cat.contains('beverage') || cat.contains('drink')) {
      return Icons.local_cafe_outlined;
    } else if (cat.contains('snack')) {
      return Icons.cookie_outlined;
    } else if (cat.contains('frozen')) {
      return Icons.ac_unit_rounded;
    } else if (cat.contains('household')) {
      return Icons.home_outlined;
    }
    return Icons.shopping_basket_outlined;
  }
}

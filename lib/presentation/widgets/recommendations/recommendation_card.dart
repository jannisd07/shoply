import 'package:flutter/material.dart';
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
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDarkMode 
            ? Colors.grey.shade800.withValues(alpha: 0.3) 
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode 
              ? Colors.grey.shade700 
              : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onAdd,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Icon based on category
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getCategoryColor(recommendation.category, isDarkMode),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getCategoryIcon(recommendation.category),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                
                // Item info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _capitalizeItemName(recommendation.itemName),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        recommendation.reason,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Add button
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDarkMode 
                        ? AppColors.accentDark 
                        : AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: onAdd,
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
    if (category == null) return Icons.shopping_basket_rounded;
    
    final cat = category.toLowerCase();
    if (cat.contains('fruit') || cat.contains('vegetable')) {
      return Icons.apple_rounded;
    } else if (cat.contains('dairy') || cat.contains('milk')) {
      return Icons.water_drop_rounded;
    } else if (cat.contains('meat') || cat.contains('protein')) {
      return Icons.set_meal_rounded;
    } else if (cat.contains('bread') || cat.contains('bakery')) {
      return Icons.bakery_dining_rounded;
    } else if (cat.contains('beverage') || cat.contains('drink')) {
      return Icons.local_cafe_rounded;
    } else if (cat.contains('snack')) {
      return Icons.cookie_rounded;
    } else if (cat.contains('frozen')) {
      return Icons.ac_unit_rounded;
    } else if (cat.contains('household')) {
      return Icons.home_rounded;
    }
    return Icons.shopping_basket_rounded;
  }

  Color _getCategoryColor(String? category, bool isDarkMode) {
    if (category == null) {
      return isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400;
    }
    
    final cat = category.toLowerCase();
    if (cat.contains('fruit') || cat.contains('vegetable')) {
      return Colors.green.shade600;
    } else if (cat.contains('dairy') || cat.contains('milk')) {
      return Colors.blue.shade600;
    } else if (cat.contains('meat') || cat.contains('protein')) {
      return Colors.red.shade600;
    } else if (cat.contains('bread') || cat.contains('bakery')) {
      return Colors.orange.shade600;
    } else if (cat.contains('beverage') || cat.contains('drink')) {
      return Colors.brown.shade600;
    } else if (cat.contains('snack')) {
      return Colors.amber.shade600;
    } else if (cat.contains('frozen')) {
      return Colors.cyan.shade600;
    } else if (cat.contains('household')) {
      return Colors.purple.shade600;
    }
    return isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400;
  }
}

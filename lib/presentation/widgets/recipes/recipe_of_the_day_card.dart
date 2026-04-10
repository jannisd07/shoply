import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/services/recipe_features_service.dart';

/// Featured recipe of the week card
class RecipeOfTheWeekCard extends StatefulWidget {
  const RecipeOfTheWeekCard({super.key});

  @override
  State<RecipeOfTheWeekCard> createState() => _RecipeOfTheWeekCardState();
}

// Keep old name as alias for backwards compat
typedef RecipeOfTheDayCard = RecipeOfTheWeekCard;

class _RecipeOfTheWeekCardState extends State<RecipeOfTheWeekCard> {
  final _service = RecipeFeaturesService.instance;
  Recipe? _recipe;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecipeOfTheWeek();
  }

  Future<void> _loadRecipeOfTheWeek() async {
    final recipe = await _service.getRecipeOfTheWeek();
    if (mounted) {
      setState(() {
        _recipe = recipe;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(height: 200);
    }

    if (_recipe == null) {
      return const SizedBox.shrink();
    }

    final textPrimary = AppColors.textPrimary(context);

    return GestureDetector(
      onTap: () => context.push('/recipes/${_recipe!.id}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image
            CachedNetworkImage(
              imageUrl: _recipe!.imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: AppColors.recipeInput(context),
                child: const Center(child: CupertinoActivityIndicator()),
              ),
              errorWidget: (_, __, ___) => Container(
                color: AppColors.recipeInput(context),
                child: const Icon(Icons.restaurant_rounded, size: 48),
              ),
            ),
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha:0.7),
                  ],
                  stops: const [0.3, 1.0],
                ),
              ),
            ),
            // Badge
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.recipeAccentColor(context),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      context.tr('recipe_of_the_week'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Content
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _recipe!.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 14, color: Colors.white.withValues(alpha:0.9)),
                      const SizedBox(width: 4),
                      Text(
                        '${_recipe!.totalTimeMinutes} min',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha:0.9),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (_recipe!.averageRating > 0) ...[
                        Icon(Icons.star_rounded, size: 14, color: AppColors.recipeStarColor(context)),
                        const SizedBox(width: 4),
                        Text(
                          _recipe!.averageRating.toStringAsFixed(1),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha:0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              context.tr('cook_now'),
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_forward_rounded, size: 14, color: textPrimary),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

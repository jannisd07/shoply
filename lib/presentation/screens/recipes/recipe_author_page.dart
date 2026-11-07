import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/services/recipe_service.dart';
import 'package:shoply/presentation/screens/recipes/widgets/author_avatar.dart';
import 'package:shoply/presentation/widgets/recipes/star_rating_widget.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Recipe Author Profile Page
/// Shows author info and all their recipes
class RecipeAuthorPage extends ConsumerStatefulWidget {
  final String authorId;
  final String? authorName;

  const RecipeAuthorPage({
    super.key,
    required this.authorId,
    this.authorName,
  });

  @override
  ConsumerState<RecipeAuthorPage> createState() => _RecipeAuthorPageState();
}

class _RecipeAuthorPageState extends ConsumerState<RecipeAuthorPage> {
  List<Recipe> _recipes = [];
  bool _isLoading = true;
  String? _authorName;
  String? _authorAvatarUrl;
  double _authorAverageRating = 0.0;

  @override
  void initState() {
    super.initState();
    _loadAuthorData();
  }

  /// Loads only this author's recipes (one query; the service also resolves
  /// the author's display name and avatar from `users`).
  Future<void> _loadAuthorData() async {
    setState(() => _isLoading = true);
    try {
      final authorRecipes =
          await RecipeService.instance.getRecipesByAuthor(widget.authorId);
      if (!mounted) return;

      final rated = authorRecipes.where((r) => r.ratingCount > 0).toList();
      final avgRating = rated.isEmpty
          ? 0.0
          : rated.map((r) => r.averageRating).reduce((a, b) => a + b) / rated.length;

      setState(() {
        _recipes = authorRecipes;
        if (authorRecipes.isNotEmpty) {
          _authorName = authorRecipes.first.authorName;
          _authorAvatarUrl = authorRecipes.first.authorAvatarUrl;
        }
        _authorAverageRating = avgRating;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ [AUTHOR_PAGE] Failed to load author ${widget.authorId}: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('author_load_failed'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = AppColors.recipeBg(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final cardColor = AppColors.recipeSurface(context);
    final borderColor = AppColors.recipeBorderColor(context);
    final displayName = (_authorName?.isNotEmpty ?? false)
        ? _authorName!
        : (widget.authorName?.isNotEmpty ?? false)
            ? widget.authorName!
            : null;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          displayName ?? context.tr('author_label'),
          style: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : _recipes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.restaurant_menu,
                        size: 64,
                        color: textSecondary.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.tr('no_recipes_found'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    CupertinoSliverRefreshControl(
                      onRefresh: _loadAuthorData,
                    ),
                    // Author Header
                    SliverToBoxAdapter(
                      child: Container(
                          padding: const EdgeInsets.all(24),
                          margin: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              // Profile Picture
                              AuthorAvatar(
                                name: displayName ?? '',
                                avatarUrl: _authorAvatarUrl,
                                size: 100,
                                backgroundColor: AppColors.recipeInput(context),
                                border: Border.all(color: borderColor, width: 2),
                                initialStyle: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: textSecondary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Author Name
                              Text(
                                displayName ?? context.tr('unknown_author'),
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              
                              // Stats Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Recipe count
                                  _StatChip(
                                    icon: Icons.restaurant_rounded,
                                    label: _recipes.length == 1 
                                      ? '1 ${context.tr('recipe_singular')}'
                                      : '${_recipes.length} ${context.tr('recipes_plural')}',
                                  ),
                                  const SizedBox(width: 12),
                                  
                                  // Average rating
                                  if (_recipes.any((r) => r.ratingCount > 0))
                                    _StatChip(
                                      icon: Icons.star_rounded,
                                      label: context.tr('author_avg_rating', params: {
                                        'rating': _authorAverageRating.toStringAsFixed(1),
                                      }),
                                      isRating: true,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Section Title
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          child: Text(
                            '${context.tr('recipes_by')} ${displayName ?? context.tr('this_author')}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                        ),
                      ),
                      
                      // Recipe Grid
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.75,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final recipe = _recipes[index];
                              return _RecipeCard(recipe: recipe);
                            },
                            childCount: _recipes.length,
                          ),
                        ),
                      ),
                      
                      // Bottom padding
                      SliverPadding(
                        padding: EdgeInsets.only(
                          bottom: 100 + MediaQuery.paddingOf(context).bottom,
                        ),
                      ),
                    ],
                  ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isRating;

  const _StatChip({
    required this.icon,
    required this.label,
    this.isRating = false,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimary(context);
    final borderColor = AppColors.recipeBorderColor(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon, 
            size: 18, 
            color: isRating ? AppColors.recipeStarColor(context) : textPrimary.withOpacity(0.7),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final Recipe recipe;

  const _RecipeCard({required this.recipe});

  @override
  Widget build(BuildContext context) {
    final cardColor = AppColors.recipeSurface(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    return GestureDetector(
      onTap: () {
        // Use /recipe/ route (outside ShellRoute) to avoid navigation conflicts
        context.push('/recipe/${recipe.id}', extra: recipe);
      },
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recipe Image
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: recipe.imageUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: (MediaQuery.sizeOf(context).width /
                            2 *
                            MediaQuery.devicePixelRatioOf(context))
                        .round(),
                    placeholder: (context, url) => Container(
                      color: AppColors.recipeInput(context),
                      child: Center(
                        child: CupertinoActivityIndicator(color: textSecondary, radius: 10),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: AppColors.recipeInput(context),
                      child: Icon(Icons.restaurant, size: 48, color: textSecondary),
                    ),
                  ),
                  // Time badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${recipe.totalTimeMinutes} min',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Recipe Info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  CompactStarRating(
                    averageRating: recipe.averageRating,
                    ratingCount: recipe.ratingCount,
                    starSize: 12,
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

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/presentation/state/saved_recipes_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Screen displaying user's saved/bookmarked recipes
class SavedRecipesScreen extends ConsumerStatefulWidget {
  const SavedRecipesScreen({super.key});

  @override
  ConsumerState<SavedRecipesScreen> createState() => _SavedRecipesScreenState();
}

class _SavedRecipesScreenState extends ConsumerState<SavedRecipesScreen> {
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();
    // Force reload saved recipes when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    if (!_hasLoaded) {
      _hasLoaded = true;
      await ref.read(savedRecipesProvider.notifier).loadSavedRecipes();
    }
  }

  @override
  Widget build(BuildContext context) {
    final savedState = ref.watch(savedRecipesProvider);
    
    // Debug logging
    print('🔍 [SAVED_RECIPES_SCREEN] isLoading: ${savedState.isLoading}, count: ${savedState.savedRecipes.length}');
    final backgroundColor = AppColors.recipeBg(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    
    return Scaffold(
      backgroundColor: backgroundColor,
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            backgroundColor: backgroundColor,
            elevation: 0,
            scrolledUnderElevation: 0,
            floating: true,
            pinned: true,
            expandedHeight: 100,
            collapsedHeight: 60,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_rounded, color: textPrimary),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: EdgeInsets.zero,
              expandedTitleScale: 1,
              title: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 56),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('saved_recipes'),
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (savedState.savedRecipes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '${savedState.savedRecipes.length} ${context.tr('recipes')}',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Content
          if (savedState.isLoading)
            const SliverFillRemaining(
              child: Center(child: CupertinoActivityIndicator()),
            )
          else if (savedState.savedRecipes.isEmpty)
            SliverFillRemaining(
              child: _buildEmptyState(context),
            )
          else
            SliverPadding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: 100 + MediaQuery.of(context).padding.bottom,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final recipe = savedState.savedRecipes[index];
                    return _SavedRecipeCard(
                      recipe: recipe,
                      onTap: () => context.push('/recipes/${recipe.id}'),
                      onRemove: () {
                        ref.read(savedRecipesProvider.notifier).toggleSave(recipe.id);
                      },
                    );
                  },
                  childCount: savedState.savedRecipes.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final cardColor = AppColors.recipeSurface(context);
    final borderColor = AppColors.recipeBorderColor(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border_rounded,
              size: 64,
              color: textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              context.tr('no_saved_recipes'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('save_recipes_hint'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () => context.pop(),
              icon: Icon(Icons.search_rounded, color: textPrimary, size: 20),
              label: Text(
                context.tr('browse_recipes'),
                style: TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: textSecondary.withOpacity(0.2)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedRecipeCard extends ConsumerWidget {
  final Recipe recipe;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _SavedRecipeCard({
    required this.recipe,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardColor = AppColors.recipeSurface(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final borderColor = AppColors.recipeBorderColor(context);
    final inputFill = AppColors.recipeInput(context);

    return Dismissible(
      key: Key(recipe.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image with bookmark button
              Stack(
                children: [
                  if (recipe.imageUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: recipe.imageUrl,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        height: 160,
                        color: inputFill,
                        child: Center(
                          child: Icon(Icons.restaurant_rounded, size: 40, color: textSecondary),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        height: 160,
                        color: inputFill,
                        child: Icon(Icons.restaurant_rounded, size: 40, color: textSecondary),
                      ),
                    ),
                  // Remove/Bookmark button
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: onRemove,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.bookmark_rounded,
                          size: 20,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.name,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      recipe.description,
                      style: TextStyle(color: textSecondary, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    // Author & Stats Row
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.push(
                            '/author/${recipe.authorId}',
                            extra: {'authorName': recipe.authorName},
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: inputFill,
                                backgroundImage: recipe.authorAvatarUrl != null
                                    ? NetworkImage(recipe.authorAvatarUrl!)
                                    : null,
                                child: recipe.authorAvatarUrl == null
                                    ? Text(
                                        recipe.authorName[0].toUpperCase(),
                                        style: TextStyle(fontSize: 10, color: textSecondary),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                recipe.authorName,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.schedule_rounded, size: 14, color: textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '${recipe.totalTimeMinutes} min',
                          style: TextStyle(color: textSecondary, fontSize: 13),
                        ),
                        if (recipe.averageRating > 0) ...[
                          const SizedBox(width: 10),
                          Icon(Icons.star_rounded, size: 14, color: AppColors.recipeStarColor(context)),
                          const SizedBox(width: 3),
                          Text(
                            recipe.averageRating.toStringAsFixed(1),
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

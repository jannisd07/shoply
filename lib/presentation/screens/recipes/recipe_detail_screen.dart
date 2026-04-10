import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/app_dimensions.dart';
import 'package:shoply/core/constants/app_text_styles.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/dietary_preference.dart';
import 'package:shoply/data/services/recipe_service.dart';
import 'package:shoply/data/services/ingredient_substitution_service.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/saved_recipes_provider.dart';
import 'package:shoply/presentation/state/recipes_provider.dart';
import 'package:shoply/presentation/widgets/recipes/star_rating_widget.dart';
import 'package:shoply/presentation/screens/recipes/widgets/select_list_bottom_sheet.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/screens/recipes/cooking_mode_screen.dart';
import 'package:shoply/presentation/providers/subscription_provider.dart';
import 'package:shoply/presentation/screens/subscription/subscription_screen.dart';

class RecipeDetailScreen extends ConsumerStatefulWidget {
  final String recipeId;

  const RecipeDetailScreen({
    super.key,
    required this.recipeId,
  });

  @override
  ConsumerState<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  final RecipeService _recipeService = RecipeService();
  Recipe? _recipe;
  bool _isLoading = true;
  int _servings = 1;
  bool _showAdaptedIngredients = true; // Toggle für angepasste Zutaten
  
  @override
  void initState() {
    super.initState();
    _loadRecipe();
  }

  Future<void> _loadRecipe() async {
    setState(() => _isLoading = true);
    try {
      print('🔍 [RECIPE_DETAIL] Loading recipe with ID: ${widget.recipeId}');
      print('📏 [RECIPE_DETAIL] ID type: ${widget.recipeId.runtimeType}');
      print('📐 [RECIPE_DETAIL] ID length: ${widget.recipeId.length}');
      
      final recipe = await _recipeService.getRecipeById(widget.recipeId);
      
      print('✅ [RECIPE_DETAIL] Recipe loaded successfully: ${recipe.name}');
      print('👤 [RECIPE_DETAIL] Author: ${recipe.authorName} (${recipe.authorId})');
      print('🖼️ [RECIPE_DETAIL] Image URL: ${recipe.imageUrl}');
      
      if (mounted) {
        setState(() {
          _recipe = recipe;
          _servings = recipe.defaultServings;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      print('❌ [RECIPE_DETAIL] Error loading recipe: $e');
      print('📋 [RECIPE_DETAIL] Recipe ID was: ${widget.recipeId}');
      print('📚 [RECIPE_DETAIL] Stack trace: $stackTrace');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _recipe = null; // Explicitly set to null to show error
        });
        
        // Show more detailed error
        final errorMessage = e.toString().contains('Recipe not found') 
            ? 'Recipe not found. It may have been deleted or the link is invalid.'
            : 'Error loading recipe: $e';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$errorMessage\nID: ${widget.recipeId}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadRecipe,
            ),
          ),
        );
      }
    }
  }

  List<Ingredient> get _adjustedIngredients {
    if (_recipe == null) return [];
    
    final baseIngredients = _recipe!.ingredients
        .map((ing) => ing.adjustForServings(_recipe!.defaultServings, _servings))
        .toList();
    
    // Wenn Toggle aktiviert ist, versuche Anpassung basierend auf User-Präferenzen
    if (_showAdaptedIngredients) {
      final user = ref.watch(currentUserProvider).value;
      if (user != null && (user.allergies.isNotEmpty || user.dietPreferences.isNotEmpty)) {
        // Konvertiere User-Präferenzen zu Enums
        final allergies = user.allergies
            .map((a) => AllergyType.values.firstWhere(
                  (type) => type.name == a,
                  orElse: () => AllergyType.gluten,
                ))
            .toList();
        
        final diets = user.dietPreferences
            .map((d) => DietType.values.firstWhere(
                  (type) => type.name == d,
                  orElse: () => DietType.none,
                ))
            .toList();
        
        // Hole angepasste Zutaten mit Substitutionen
        final withSubstitutions = IngredientSubstitutionService.getIngredientsWithSubstitutions(
          ingredients: baseIngredients,
          allergies: allergies,
          diets: diets,
        );
        
        // Nutze angepasste Zutat falls Substitution vorhanden
        return withSubstitutions.map((ws) => ws.adaptedIngredient).toList();
      }
    }
    
    return baseIngredients;
  }
  
  List<IngredientWithSubstitution> get _ingredientsWithInfo {
    if (_recipe == null) return [];
    
    final baseIngredients = _recipe!.ingredients
        .map((ing) => ing.adjustForServings(_recipe!.defaultServings, _servings))
        .toList();
    
    final user = ref.watch(currentUserProvider).value;
    
    // Get user preferences (empty lists if user is null)
    final allergies = user?.allergies
        .map((a) => AllergyType.values.firstWhere(
              (type) => type.name == a,
              orElse: () => AllergyType.gluten,
            ))
        .toList() ?? [];
    
    final diets = user?.dietPreferences
        .map((d) => DietType.values.firstWhere(
              (type) => type.name == d,
              orElse: () => DietType.none,
            ))
        .toList() ?? [];
    
    print('🔍 [RECIPE_DETAIL] Analyzing ingredients for user');
    print('   - User allergies: $allergies');
    print('   - User diets: $diets');
    
    // Always call substitution service to get diet flags
    return IngredientSubstitutionService.getIngredientsWithSubstitutions(
      ingredients: baseIngredients,
      allergies: allergies,
      diets: diets,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CupertinoActivityIndicator()),
      );
    }

    if (_recipe == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(context.tr('recipe_not_found'))),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF262626) : const Color(0xFFFBFBFB);
    final cardColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final textSecondary = isDark ? const Color(0xFF6B6B6B) : const Color(0xFF9CA3AF);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);
    
    return Scaffold(
      backgroundColor: scaffoldBg,
      body: CustomScrollView(
        slivers: [
          // App Bar with Hero Image
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            stretch: true,
            backgroundColor: scaffoldBg,
            automaticallyImplyLeading: false,
            leading: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                      onPressed: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          context.go('/home');
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: _recipe!.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: AppColors.recipeInput(context),
                      child: const Center(child: CupertinoActivityIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: AppColors.recipeInput(context),
                      child: const Icon(Icons.restaurant, size: 80),
                    ),
                  ),
                  // Gradient overlay for better readability
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                        stops: const [0.5, 1.0],
                      ),
                    ),
                  ),
                  // Title overlay at bottom
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
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (!_recipe!.isImported)
                          GestureDetector(
                            onTap: () {
                              context.push('/author/${_recipe!.authorId}', extra: {'authorName': _recipe!.authorName});
                            },
                            child: Row(
                              children: [
                                // Author avatar
                                if (_recipe!.authorAvatarUrl != null && _recipe!.authorAvatarUrl!.isNotEmpty)
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white54, width: 1),
                                      image: DecorationImage(
                                        image: NetworkImage(_recipe!.authorAvatarUrl!),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white24,
                                      border: Border.all(color: Colors.white54, width: 1),
                                    ),
                                    child: Center(
                                      child: Text(
                                        _recipe!.authorName.isNotEmpty ? _recipe!.authorName[0].toUpperCase() : '?',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 6),
                                Text(
                                  _recipe!.authorName,
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right_rounded, size: 14, color: Colors.white54),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              // Delete button (only for own recipes)
              Consumer(
                builder: (context, ref, _) {
                  final currentUser = ref.watch(currentUserProvider).value;
                  final isOwnRecipe = currentUser != null && _recipe?.authorId == currentUser.id;
                  
                  if (!isOwnRecipe) return const SizedBox.shrink();
                  
                  return Container(
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.8),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
                      onPressed: () => _showDeleteConfirmation(),
                    ),
                  );
                },
              ),
              // Edit button (only for own recipes) or Bookmark button (for others)
              Consumer(
                builder: (context, ref, _) {
                  final currentUser = ref.watch(currentUserProvider).value;
                  final isOwnRecipe = currentUser != null && _recipe?.authorId == currentUser.id;
                  
                  if (isOwnRecipe) {
                    // Edit button for own recipes
                    return Container(
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: AppColors.recipeAccentColor(context).withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 22),
                        onPressed: () {
                          context.push('/recipes/add', extra: {'recipeId': widget.recipeId});
                        },
                      ),
                    );
                  }
                  
                  // Bookmark button for other users' recipes
                  final isSaved = ref.watch(isRecipeSavedProvider(widget.recipeId));
                  return Container(
                    margin: const EdgeInsets.only(right: 4),
                    child: ClipOval(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSaved ? Colors.white : Colors.black.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                          ),
                          child: IconButton(
                            icon: Icon(
                              isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                              color: isSaved ? Colors.black : Colors.white,
                              size: 22,
                            ),
                            onPressed: () {
                              ref.read(savedRecipesProvider.notifier).toggleSave(widget.recipeId);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isSaved ? 'Recipe unsaved' : 'Recipe saved'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              Container(
                margin: const EdgeInsets.only(right: 8),
                child: ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.ios_share, color: Colors.white, size: 22),
                        onPressed: _shareRecipe,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Quick Info Bar
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isDark ? null : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _QuickInfoItem(
                    icon: Icons.schedule_rounded,
                    value: '${_recipe!.totalTimeMinutes}',
                    label: 'min total',
                    color: textSecondary, // Changed from recipeStepColor
                  ),
                  Container(width: 1, height: 40, color: borderColor),
                  _QuickInfoItem(
                    icon: Icons.restaurant_rounded,
                    value: '$_servings',
                    label: 'servings',
                    color: textSecondary, // Changed from recipeAccentColor
                    onTap: () => _showServingsDialog(),
                  ),
                  Container(width: 1, height: 40, color: borderColor),
                  _QuickInfoItem(
                    icon: Icons.star_rounded,
                    value: _recipe!.averageRating.toStringAsFixed(1),
                    label: '(${_recipe!.ratingCount})',
                    color: const Color(0xFFFFB300), // Matching the star color
                  ),
                  Container(width: 1, height: 40, color: borderColor),
                  _QuickInfoItem(
                    icon: Icons.visibility_rounded,
                    value: _formatViewCount(_recipe!.viewCount),
                    label: context.tr('views'),
                    color: textSecondary,
                  ),
                ],
              ),
            ),
          ),
          
          // Start Cooking Button - Premium Feature
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _buildCookingModeButton(context),
            ),
          ),

          // Description Section
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isDark ? null : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: textSecondary),
                      const SizedBox(width: 8),
                      Text(context.tr('about'), style: AppTextStyles.h3.copyWith(color: textColor)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _recipe!.description,
                    style: AppTextStyles.bodyMedium.copyWith(color: textColor.withOpacity(0.8)),
                  ),
                  const SizedBox(height: 16),
                  // Rate this recipe
                  LargeStarRating(
                    averageRating: _recipe!.averageRating,
                    ratingCount: _recipe!.ratingCount,
                    userRating: _recipe!.userRating,
                    onRate: (rating) async {
                      if (_recipe == null) return;
                      final previousRating = _recipe!.userRating;
                      final newRating = rating.toInt();
                      setState(() {
                        final newAverageRating = previousRating == null
                            ? ((_recipe!.averageRating * _recipe!.ratingCount) + newRating) / (_recipe!.ratingCount + 1)
                            : ((_recipe!.averageRating * _recipe!.ratingCount) - previousRating + newRating) / _recipe!.ratingCount;
                        final newRatingCount = previousRating == null ? _recipe!.ratingCount + 1 : _recipe!.ratingCount;
                        _recipe = _recipe!.copyWith(averageRating: newAverageRating, ratingCount: newRatingCount, userRating: newRating);
                      });
                      await _recipeService.rateRecipe(_recipe!.id, newRating);
                      
                      // Refresh recipe data across the app so main page shows updated rating
                      refreshRecipeData(ref);
                      
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(previousRating == null ? '✅ ${context.tr('rating_submitted')}' : '✅ ${context.tr('rating_updated')}'), duration: const Duration(seconds: 2)),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // Ingredients Section
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isDark ? null : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.restaurant_menu, size: 18, color: textSecondary),
                      const SizedBox(width: 8),
                      Text(context.tr('ingredients'), style: AppTextStyles.h3.copyWith(color: textColor)),
                      const Spacer(),
                      // Toggle for adapted ingredients
                      if (ref.watch(currentUserProvider).value != null &&
                          (ref.watch(currentUserProvider).value!.allergies.isNotEmpty ||
                           ref.watch(currentUserProvider).value!.dietPreferences.isNotEmpty))
                        Row(
                          children: [
                            Text(
                              _showAdaptedIngredients
                                  ? '${context.tr('adapted')} ${context.tr('ingredients').toLowerCase()}'
                                  : '${context.tr('original')} ${context.tr('ingredients').toLowerCase()}',
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            AdaptiveSwitch(
                              value: _showAdaptedIngredients,
                              activeColor: Colors.green,
                              onChanged: (value) {
                                setState(() {
                                  _showAdaptedIngredients = value;
                                });
                              },
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Zutaten mit Substitutions-Info
                  ..._ingredientsWithInfo.map((ingredientInfo) {
                    final isSubstituted = ingredientInfo.needsSubstitution && 
                                         ingredientInfo.bestSubstitute != null &&
                                         _showAdaptedIngredients;
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isSubstituted ? Icons.swap_horiz : Icons.circle,
                                size: isSubstituted ? 16 : 6,
                                color: isSubstituted ? textSecondary : borderColor,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Haupttext
                                    RichText(
                                      text: TextSpan(
                                        style: AppTextStyles.bodyMedium.copyWith(
                                          color: textColor,
                                        ),
                                        children: [
                                          if (isSubstituted) ...[
                                            TextSpan(
                                              text: '${ingredientInfo.adaptedIngredient.displayText}',
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            TextSpan(
                                              text: ' (statt ${ingredientInfo.original.name})',
                                              style: TextStyle(
                                                color: textSecondary,
                                                fontSize: 12,
                                                decoration: TextDecoration.lineThrough,
                                              ),
                                            ),
                                          ] else
                                            TextSpan(text: ingredientInfo.original.displayText),
                                        ],
                                      ),
                                    ),
                                    // Gründe für Substitution
                                    if (isSubstituted && ingredientInfo.reasons.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Wrap(
                                          spacing: 4,
                                          children: ingredientInfo.reasons.map((reason) => 
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.recipeAccentColor(context).withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(AppDimensions.borderRadiusSmall),
                                              ),
                                              child: Text(
                                                reason,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: AppColors.recipeAccentColor(context),
                                                ),
                                              ),
                                            )
                                          ).toList(),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  // Add to Shopping List Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _addToShoppingList,
                      icon: const Icon(Icons.add_shopping_cart),
                      label: Text(context.tr('add_to_shopping_list')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.recipeAccentColor(context),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // Instructions Section
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isDark ? null : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.format_list_numbered, size: 18, color: textSecondary),
                      const SizedBox(width: 8),
                      Text(context.tr('instructions'), style: AppTextStyles.h3.copyWith(color: textColor)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(_recipe!.instructions.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: textSecondary, // Changed from recipeStepColor (red/orange)
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _recipe!.instructions[index],
                              style: AppTextStyles.bodyMedium.copyWith(color: textColor),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          
          // Source attribution (only for imported recipes)
          if (_recipe!.isImported)
            SliverToBoxAdapter(
              child: _buildSourceFooter(context),
            ),

          // Bottom padding
          SliverToBoxAdapter(
            child: SizedBox(height: 100 + MediaQuery.of(context).padding.bottom),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceFooter(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final url = _recipe!.sourceUrl!;
    final sourceLabel = _recipe!.sourceName == 'wikibooks'
        ? 'Wikibooks Cookbook'
        : 'external source';
    final licenseLabel =
        _recipe!.sourceName == 'wikibooks' ? 'CC BY-SA 4.0' : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(
            height: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () async {
              final uri = Uri.tryParse(url);
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.link_rounded,
                    size: 14,
                    color: AppColors.textTertiary(context),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary(context),
                        ),
                        children: [
                          const TextSpan(text: 'Source: '),
                          TextSpan(
                            text: sourceLabel,
                            style: TextStyle(
                              color: AppColors.textSecondary(context),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          if (licenseLabel != null) TextSpan(text: '  ·  $licenseLabel'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Format view count for display (e.g., 1.2k, 15k)
  String _formatViewCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }

  void _showServingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('adjust_servings')),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 32),
              onPressed: _servings > 1 ? () {
                setState(() => _servings--);
                Navigator.pop(context);
              } : null,
            ),
            const SizedBox(width: 16),
            Text('$_servings', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 32),
              onPressed: () {
                setState(() => _servings++);
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('done'))),
        ],
      ),
    );
  }

  // Like functionality temporarily disabled - will be replaced with favorites system
  // Future<void> _toggleLike() async {
  //   try {
  //     await _recipeService.toggleLike(_recipe!.id, false);
  //     _loadRecipe();
  //   } catch (e) {
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('Error: $e')),
  //       );
  //     }
  //   }
  // }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rezept löschen'),
        content: const Text('Möchtest du dieses Rezept wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _deleteRecipe();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRecipe() async {
    setState(() => _isLoading = true);
    
    try {
      await _recipeService.deleteRecipe(widget.recipeId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rezept wurde gelöscht')),
        );
        // Navigate to recipes page
        context.go('/recipes');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Löschen: $e')),
        );
      }
    }
  }

  void _shareRecipe() async {
    final shareText = _recipeService.getShareText(_recipe!);
    final box = context.findRenderObject() as RenderBox?;
    await Share.share(
      shareText,
      subject: '🍳 ${_recipe!.name}',
      sharePositionOrigin: box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : const Rect.fromLTWH(0, 0, 100, 100),
    );
  }

  void _addToShoppingList() {
    // Get ingredients with substitution info for the current servings
    final ingredientsWithInfo = _ingredientsWithInfo;
    
    // Show dialog centered on screen
    showDialog(
      context: context,
      builder: (context) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.88,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1C1C1E)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            clipBehavior: Clip.antiAlias,
            child: SelectListBottomSheet(
              ingredientsWithInfo: ingredientsWithInfo,
              defaultServings: _servings,
              recipeDefaultServings: _recipe!.defaultServings,
              useAdaptedIngredients: _showAdaptedIngredients,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCookingModeButton(BuildContext context) {
    final isSubscribed = ref.watch(isSubscribedProvider);
    
    if (isSubscribed) {
      // Subscribed users get the normal button
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CookingModeScreen(
                  recipe: _recipe!,
                  servings: _servings,
                ),
              ),
            );
          },
          icon: const Icon(Icons.restaurant_menu_rounded, size: 22),
          label: Text(
            context.tr('start_cooking'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.recipeAccentColor(context),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
        ),
      );
    }
    
    // Non-subscribed users get a clean premium button
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => showSubscriptionSheet(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.recipeAccentColor(context),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.restaurant_menu_rounded, size: 22),
            const SizedBox(width: 8),
            Text(
              context.tr('start_cooking'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'PRO',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick info item widget for the info bar
class _QuickInfoItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _QuickInfoItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.recipeTextPrimary(context);
    
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: textColor.withOpacity(0.6),
            ),
          ),
          if (onTap != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'tap to adjust',
                style: TextStyle(fontSize: 9, color: color),
              ),
            ),
        ],
      ),
    );
  }
}

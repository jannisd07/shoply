import 'dart:async';
import 'dart:math';

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
import 'package:shoply/data/models/recipe_offer_highlight.dart';
import 'package:shoply/data/models/user_model.dart';
import 'package:shoply/presentation/screens/recipes/recipe_user_diet.dart';
import 'package:shoply/presentation/screens/recipes/widgets/author_avatar.dart';
import 'package:shoply/presentation/screens/recipes/widgets/servings_stepper.dart';
import 'package:shoply/data/services/recipe_service.dart';
import 'package:shoply/data/services/ingredient_substitution_service.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/saved_recipes_provider.dart';
import 'package:shoply/presentation/widgets/common/liquid_glass_container.dart';
import 'package:shoply/presentation/state/recipes_provider.dart';
import 'package:shoply/presentation/widgets/recipes/star_rating_widget.dart';
import 'package:shoply/presentation/screens/recipes/widgets/select_list_bottom_sheet.dart';
import 'package:shoply/core/widgets/design_system.dart';
import 'package:shoply/presentation/screens/calories/widgets/log_recipe_sheet.dart';
import 'package:shoply/presentation/state/calorie_tracking_provider.dart';
import 'package:shoply/presentation/widgets/recipes/nutrition_info_widget.dart';
import 'package:shoply/presentation/providers/recipe_offers_provider.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_offers_card.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/screens/recipes/cooking_mode_screen.dart';
import 'package:shoply/presentation/providers/subscription_provider.dart';
import 'package:shoply/presentation/screens/subscription/subscription_screen.dart';

class RecipeDetailScreen extends ConsumerStatefulWidget {
  final String recipeId;

  /// The recipe as already loaded by the list the user tapped, if any. It is
  /// shown immediately and refreshed in the background; deep links pass none.
  final Recipe? initialRecipe;

  const RecipeDetailScreen({
    super.key,
    required this.recipeId,
    this.initialRecipe,
  });

  @override
  ConsumerState<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  final RecipeService _recipeService = RecipeService();
  Recipe? _recipe;
  bool _isLoading = true;
  int _servings = 1;
  bool _showAdaptedIngredients = true;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialRecipe;
    if (initial != null && initial.id == widget.recipeId) {
      _recipe = initial;
      _servings = initial.defaultServings;
      _isLoading = false;
      _loadRecipe(silent: true);
    } else {
      _loadRecipe();
    }
    // Count the view once per opening (not on reloads after rating).
    unawaited(_recipeService.trackRecipeView(widget.recipeId));
  }

  /// Fetches the full recipe. With [silent] the current content stays on
  /// screen while loading (background refresh), and servings are kept.
  Future<void> _loadRecipe({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final recipe = await _recipeService.getRecipeById(widget.recipeId);
      if (!mounted) return;
      setState(() {
        if (!silent || _recipe == null) _servings = recipe.defaultServings;
        _recipe = recipe;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ [RECIPE_DETAIL] Error loading recipe ${widget.recipeId}: $e');
      if (!mounted) return;
      // A failed background refresh keeps the recipe we already show.
      if (silent && _recipe != null) return;
      setState(() {
        _isLoading = false;
        _recipe = null;
      });
      final notFound = e.toString().contains('Recipe not found');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr(
              notFound ? 'recipe_not_found_detail' : 'recipe_load_failed')),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: context.tr('retry'),
            textColor: Colors.white,
            onPressed: _loadRecipe,
          ),
        ),
      );
    }
  }

  /// The recipe's ingredients scaled to the current servings, each with the
  /// substitution info for [user]'s diet/allergies (empty profile if null).
  List<IngredientWithSubstitution> _ingredientsWithInfo(UserModel? user) {
    if (_recipe == null) return [];

    final baseIngredients = _recipe!.ingredients
        .map((ing) => ing.adjustForServings(_recipe!.defaultServings, _servings))
        .toList();

    // Always call the substitution service to get diet flags.
    return IngredientSubstitutionService.getIngredientsWithSubstitutions(
      ingredients: baseIngredients,
      allergies: user?.allergyTypes ?? const [],
      diets: user?.dietTypes ?? const [],
    );
  }

  /// Offers lookup key for the loaded recipe — shared by the offers card
  /// and the add-to-list flow so both read the same provider instance.
  RecipeOffersRequest get _offersRequest => RecipeOffersRequest(
        recipeId: widget.recipeId,
        ingredientNames:
            _recipe?.ingredients.map((i) => i.name).toList() ?? const [],
      );

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
    final cardColor = AppColors.surface(context);
    final textColor = AppColors.textPrimary(context);
    final textSecondary = isDark ? const Color(0xFF6B6B6B) : const Color(0xFF9CA3AF);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);
    final user = ref.watch(currentUserProvider).value;
    final isOwnRecipe = user != null && _recipe!.authorId == user.id;
    final ingredientsWithInfo = _ingredientsWithInfo(user);

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
              // Real UIGlassEffect over the hero image, instead of a
              // hand-rolled blur circle.
              child: AdaptiveGlass(
                isCircle: true,
                opaqueColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 20),
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
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: _recipe!.imageUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: (MediaQuery.sizeOf(context).width *
                            MediaQuery.devicePixelRatioOf(context))
                        .round(),
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
                                AuthorAvatar(
                                  name: _recipe!.authorName,
                                  avatarUrl: _recipe!.authorAvatarUrl,
                                  size: 22,
                                  backgroundColor: Colors.white24,
                                  border: Border.all(color: Colors.white54, width: 1),
                                  initialStyle: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
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
              if (isOwnRecipe) ...[
                // Delete + edit for own recipes
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
                    onPressed: _showDeleteConfirmation,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: AppColors.recipeAccentColor(context).withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 22),
                    onPressed: _editRecipe,
                  ),
                ),
              ] else
                // Bookmark for other users' recipes
                Consumer(
                  builder: (context, ref, _) {
                    final isSaved = ref.watch(isRecipeSavedProvider(widget.recipeId));
                    return Container(
                      margin: const EdgeInsets.only(right: 4),
                      // Glass while unsaved; once saved it becomes a solid
                      // white pill so the active state is unmistakable —
                      // translucency reads as "off" at a glance.
                      child: AdaptiveGlass(
                        isCircle: true,
                        opaqueColor: isSaved ? Colors.white : Colors.black54,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: isSaved ? Colors.white : Colors.transparent,
                            shape: BoxShape.circle,
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
                                  content: Text(context.tr(
                                      isSaved ? 'recipe_unsaved_toast' : 'recipe_saved_toast')),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              Container(
                margin: const EdgeInsets.only(right: 8),
                child: AdaptiveGlass(
                  isCircle: true,
                  opaqueColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.ios_share, color: Colors.white, size: 22),
                    onPressed: _shareRecipe,
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
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _QuickInfoItem(
                    icon: Icons.schedule_rounded,
                    value: '${_recipe!.totalTimeMinutes}',
                    label: context.tr('recipe_min_total'),
                    color: textSecondary,
                  ),
                  Container(width: 1, height: 40, color: borderColor),
                  _QuickInfoItem(
                    icon: Icons.restaurant_rounded,
                    value: '$_servings',
                    label: context.tr('portions'),
                    color: textSecondary,
                    onTap: _showServingsDialog,
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

          // Nutrition + "log to diary" (calorie tracking integration)
          if (_recipe!.nutrition != null && _recipe!.nutrition!.hasData)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    NutritionInfoWidget(nutrition: _recipe!.nutrition!, expanded: true),
                    if (ref.watch(calorieTrackingEnabledProvider)) ...[
                      const SizedBox(height: 8),
                      AppOutlineButton(
                        text: context.tr('log_recipe_cta'),
                        icon: Icons.add_chart_outlined,
                        onPressed: () => showLogRecipeSheet(
                          context,
                          recipeId: _recipe!.id,
                          recipeName: _recipe!.name,
                          nutritionPerServing: _recipe!.nutrition!,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // Description Section
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border(context)),
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
                    onRate: _rate,
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
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border(context)),
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
                      if (user != null && user.hasDietProfile)
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
                  ...ingredientsWithInfo.map((ingredientInfo) {
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
                                              text: ingredientInfo.adaptedIngredient.displayText,
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            TextSpan(
                                              text: ' (${context.tr('ingredient_instead_of', params: {'name': ingredientInfo.original.name})})',
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
                      onPressed: () => _addToShoppingList(ingredientsWithInfo),
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

          // Current supermarket offers for the recipe's ingredients
          // (renders nothing when no ingredient is on offer / no real zip).
          SliverToBoxAdapter(
            child: RecipeOffersCard(request: _offersRequest),
          ),

          // Instructions Section
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border(context)),
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
            child: SizedBox(height: 100 + MediaQuery.paddingOf(context).bottom),
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
        : context.tr('recipe_source_external');
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
                          TextSpan(text: context.tr('recipe_source_label')),
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

  /// Servings stepper dialog; stays open while adjusting.
  void _showServingsDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(dialogContext.tr('adjust_servings')),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ServingsStepper(
                value: _servings,
                valueFontSize: 32,
                onChanged: (value) {
                  setState(() => _servings = value);
                  setDialogState(() {});
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(dialogContext.tr('done')),
            ),
          ],
        ),
      ),
    );
  }

  /// Optimistically shows the new rating, then saves it; reverts and tells
  /// the user when saving fails.
  Future<void> _rate(double rating) async {
    final before = _recipe;
    if (before == null) return;
    final previousRating = before.userRating;
    final newRating = rating.toInt();
    final count = before.ratingCount;
    final total = before.averageRating * count;
    setState(() {
      _recipe = before.copyWith(
        averageRating: previousRating == null
            ? (total + newRating) / (count + 1)
            : (total - previousRating + newRating) / max(1, count),
        ratingCount: previousRating == null ? count + 1 : count,
        userRating: newRating,
      );
    });

    try {
      await _recipeService.rateRecipe(before.id, newRating);
      if (!mounted) return;
      // Refresh recipe data across the app so lists show the new rating.
      refreshRecipeData(ref);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '✅ ${context.tr(previousRating == null ? 'rating_submitted' : 'rating_updated')}'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('❌ [RECIPE_DETAIL] Failed to save rating: $e');
      if (!mounted) return;
      setState(() => _recipe = before);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('rating_save_failed'))),
      );
    }
  }

  /// Opens the editor; reloads this page when the recipe was saved.
  Future<void> _editRecipe() async {
    final saved = await context.push<bool>(
      '/recipes/add',
      extra: {'recipeId': widget.recipeId},
    );
    if (saved == true && mounted) _loadRecipe(silent: true);
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr('delete_recipe_title')),
        content: Text(dialogContext.tr('delete_recipe_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(dialogContext.tr('cancel')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _deleteRecipe();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(dialogContext.tr('delete')),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRecipe() async {
    setState(() => _isLoading = true);

    try {
      await _recipeService.deleteRecipe(widget.recipeId);
      if (!mounted) return;
      refreshRecipeData(ref);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('recipe_deleted'))),
      );
      context.go('/recipes');
    } catch (e) {
      debugPrint('❌ [RECIPE_DETAIL] Failed to delete recipe: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('recipe_delete_failed'))),
      );
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

  /// [ingredientsWithInfo] are already scaled to the current servings.
  Future<void> _addToShoppingList(
      List<IngredientWithSubstitution> ingredientsWithInfo) async {
    // Current offers already fetched for this recipe (if any) — added
    // ingredients carry their offer price into the list's total (Feature 1).
    final offersResult =
        ref.read(recipeOffersProvider(_offersRequest)).valueOrNull;
    final ingredientOffers = <String, RecipeIngredientOffer>{
      for (final match in offersResult?.matches ?? const <RecipeIngredientOffer>[])
        if (match.isStillValid)
          match.ingredientName.trim().toLowerCase(): match,
    };

    // Show dialog centered on screen
    final result = await showDialog<AddIngredientsResult>(
      context: context,
      builder: (context) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: MediaQuery.sizeOf(context).width * 0.88,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.75,
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
              // The ingredients are already scaled to _servings, so the
              // sheet must scale relative to that, not to the recipe's
              // default (that scaled the amounts twice).
              recipeDefaultServings: _servings,
              useAdaptedIngredients: _showAdaptedIngredients,
              ingredientOffers: ingredientOffers,
            ),
          ),
        ),
      ),
    );
    if (result != null && mounted) showAddIngredientsResult(context, result);
  }

  Widget _buildCookingModeButton(BuildContext context) {
    final isSubscribed = ref.watch(isSubscribedProvider);
    
    if (isSubscribed) {
      // Subscribed users get the normal button
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                fullscreenDialog: true,
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
                context.tr('tap_to_adjust'),
                style: TextStyle(fontSize: 9, color: color),
              ),
            ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/constants/recipe_categories.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/services/contextual_prompt_service.dart';
import 'package:shoply/data/services/dynamic_tutorial_service.dart';
import 'package:shoply/data/services/offline_cache_service.dart';
import 'package:shoply/data/services/recipe_features_service.dart';
import 'package:shoply/data/services/recipe_service.dart';
import 'package:shoply/presentation/screens/recipes/recipes_home_data.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_home_widgets.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_search_results.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/recipes_provider.dart';
import 'package:shoply/presentation/state/saved_recipes_provider.dart';
import 'package:shoply/presentation/widgets/common/liquid_glass_container.dart';

class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key, this.initialQuery});

  /// Pre-fills and triggers the search, e.g. from a Siri "search recipes"
  /// deep link (`shoply://recipes/search?q=...`).
  final String? initialQuery;

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends ConsumerState<RecipesScreen> {
  static const _searchDebounce = Duration(milliseconds: 250);

  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _searchTimer;

  List<Recipe> _allRecipes = [];
  List<Recipe> _popularRecipes = [];
  List<Recipe> _recentRecipes = [];
  Recipe? _recipeOfTheWeek;
  List<Recipe> _forYouRecipes = [];
  List<RecipeAuthorSummary> _allAuthors = [];
  Map<String, int> _categoryCounts = {};
  bool _isLoading = true;
  bool _isSearching = false;
  String _searchQuery = '';
  List<Recipe> _searchResults = [];

  List<RecipeAuthorSummary> get _topAuthors => _allAuthors.take(8).toList();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);
    _seedFromCache();
    _loadAllData();
    _maybeShowDietPrompt();

    final initialQuery = widget.initialQuery;
    if (initialQuery != null && initialQuery.isNotEmpty) {
      // Deferred: setting .text fires _onSearchTextChanged synchronously,
      // which calls setState — not allowed during initState itself.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchController.text = initialQuery;
      });
    }
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// Show diet preferences prompt once on first visit
  Future<void> _maybeShowDietPrompt() async {
    // Delay to let the screen render first
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    final shouldShow = await ContextualPromptService.instance.shouldShowDietPrompt();
    if (shouldShow && mounted) {
      ContextualPromptService.instance.showDietPrompt(context);
    }
  }

  /// Paint the tab from the warmed offline cache before any network call, so
  /// the first frame already shows recipes; the network result replaces them.
  /// Runs synchronously in initState — no await, no empty frame.
  void _seedFromCache() {
    final cached = OfflineCacheService.instance.getCachedRecipesSync();
    if (cached == null || cached.isEmpty) return;
    _allRecipes = cached;
    _popularRecipes = ([...cached]
          ..sort((a, b) => b.averageRating.compareTo(a.averageRating)))
        .take(8)
        .toList();
    _recentRecipes = recentRecipesFrom(cached);
    _allAuthors = topAuthorsFrom(cached);
    _categoryCounts = categoryCountsFrom(cached);
    _isLoading = false;
  }

  /// Loads the recipe list once (through [recipesProvider], which also
  /// caches it offline) and derives every section from it in memory.
  /// Only "popular this week" and "recipe of the week" need their own query.
  Future<void> _loadAllData({bool forceRefresh = false}) async {
    // Only block the UI when there is nothing cached to show yet; otherwise
    // refresh silently underneath the already-rendered content.
    if (_allRecipes.isEmpty) setState(() => _isLoading = true);
    try {
      final allRecipesFuture = forceRefresh
          ? ref.refresh(recipesProvider.future)
          : ref.read(recipesProvider.future);
      final results = await Future.wait([
        allRecipesFuture,
        // Request 9 so we still have 8 after excluding recipe of the week
        RecipeService.instance.getPopularRecipes(limit: 9, thisWeekOnly: true),
        RecipeFeaturesService.instance.getRecipeOfTheWeek(),
      ]);
      if (!mounted) return;

      final allRecipes = results[0] as List<Recipe>;
      final weekRecipe = results[2] as Recipe?;
      final weekId = weekRecipe?.id;

      // Exclude recipe of the week from "Popular This Week"
      final popular = (results[1] as List<Recipe>)
          .where((r) => r.id != weekId)
          .take(8)
          .toList();

      // Personalized "For You" (diet, allergies, priorities); excludes
      // anything already shown in recipe of the week or popular.
      final forYou = forYouRecipesFrom(
        allRecipes,
        user: ref.read(currentUserProvider).value,
        excludeIds: {if (weekId != null) weekId, ...popular.map((r) => r.id)},
      );

      setState(() {
        _allRecipes = allRecipes;
        _popularRecipes = popular;
        _recentRecipes = recentRecipesFrom(allRecipes);
        _allAuthors = topAuthorsFrom(allRecipes);
        _recipeOfTheWeek = weekRecipe;
        _forYouRecipes = forYou;
        _categoryCounts = categoryCountsFrom(allRecipes);
        _isLoading = false;
        if (_isSearching) {
          _searchResults = searchRecipesLocally(allRecipes, _searchQuery);
        }
      });
      DynamicTutorialService.instance.updateRecipesData(
        hasRecipes: popular.isNotEmpty || _recentRecipes.isNotEmpty,
      );
    } catch (e) {
      debugPrint('❌ [RECIPES] Failed to load recipes tab: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('error_loading_recipes'))),
      );
    }
  }

  void _onSearchTextChanged() {
    final value = _searchController.text;
    if (value == _searchQuery) return;
    _searchQuery = value;
    _searchTimer?.cancel();

    if (value.trim().isEmpty) {
      if (_isSearching) {
        setState(() {
          _isSearching = false;
          _searchResults = [];
        });
      }
      return;
    }

    if (!_isSearching) setState(() => _isSearching = true);
    // Search is a local filter over the already-loaded recipes; the debounce
    // only avoids re-filtering on every keystroke while typing fast.
    _searchTimer = Timer(_searchDebounce, () {
      if (!mounted) return;
      setState(() => _searchResults = searchRecipesLocally(_allRecipes, _searchQuery));
    });
  }

  void _clearSearch() {
    _searchTimer?.cancel();
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _searchResults = [];
    });
  }

  void _openRecipe(Recipe recipe) => context.push('/recipes/${recipe.id}', extra: recipe);

  @override
  Widget build(BuildContext context) {
    // Only the count is shown here; watching the whole saved-recipes state
    // rebuilt the tab three times per bookmark toggle anywhere in the app.
    final savedCount = ref.watch(savedRecipesProvider.select((s) => s.savedIds.length));

    // Reload when ratings change. Deferred a microtask so the invalidation
    // that follows the trigger bump in refreshRecipeData has happened.
    ref.listen(recipeRefreshTriggerProvider, (previous, next) {
      if (previous != next) Future.microtask(() => mounted ? _loadAllData() : null);
    });

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: _isLoading
          ? _buildLoadingState(context)
          : Column(
              children: [
                _buildSearchHeader(context),
                Expanded(
                  child: _isSearching
                      ? RecipesSearchResults(
                          query: _searchQuery,
                          results: _searchResults,
                          authors: _allAuthors,
                          onRecipeTap: _openRecipe,
                        )
                      : _buildMainContent(context, savedCount),
                ),
              ],
            ),
    );
  }

  Widget _buildSearchHeader(BuildContext context) {
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  context.tr('recipes'),
                  style: PaperTextStyles.serif(27, color: textPrimary),
                ),
                const Spacer(),
                // Glass circle, matching the composer's "+" — 34pt visual
                // inside a 44pt touch target.
                GestureDetector(
                  key: DynamicTutorialService.instance.addRecipeButtonKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/recipes/add');
                  },
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: SizedBox(
                        width: 34,
                        height: 34,
                        child: AdaptiveGlass(
                          isCircle: true,
                          child: Center(
                            child: Icon(Icons.add_rounded, color: textPrimary, size: 20),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // The same TextField in both modes, so focus survives the switch.
            SizedBox(
              height: 42,
              child: AdaptiveGlass(
                isCircle: true,
                opaqueColor: AppColors.surface(context),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    hintText: context.tr('search_recipes_users'),
                    hintStyle: TextStyle(color: textSecondary, fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded, color: textSecondary, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.close_rounded, color: textSecondary, size: 18),
                            onPressed: _clearSearch,
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  style: TextStyle(color: textPrimary, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, int savedCount) {
    return CustomScrollView(
      key: DynamicTutorialService.instance.recipesAreaKey,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: () => _loadAllData(forceRefresh: true),
        ),

        // Community stats banner
        if (_allRecipes.isNotEmpty)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  RecipeStatItem(
                    value: '${_allRecipes.length}',
                    label: context.tr('recipes'),
                  ),
                  RecipeStatItem(
                    value: '${_allAuthors.length}',
                    label: context.tr('creators'),
                  ),
                  RecipeStatItem(
                    value: '$savedCount',
                    label: context.tr('saved_recipes'),
                  ),
                ],
              ),
            ),
          ),

        if (_recipeOfTheWeek != null) ...[
          SliverToBoxAdapter(
            child: RecipeSectionHeader(title: context.tr('recipe_of_the_week')),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FeaturedRecipeCard(
                recipe: _recipeOfTheWeek!,
                onTap: () => _openRecipe(_recipeOfTheWeek!),
              ),
            ),
          ),
        ],

        // Shortcuts: My Recipes, Saved, Drafts, Creators
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: RecipeActionCard(
                        icon: Icons.restaurant_rounded,
                        label: context.tr('my_recipes'),
                        onTap: () => context.push('/recipes/my'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: RecipeActionCard(
                        icon: Icons.bookmark_rounded,
                        label: context.tr('saved_recipes'),
                        badge: savedCount > 0 ? '$savedCount' : null,
                        onTap: () => context.push('/recipes/saved'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: RecipeActionCard(
                        icon: Icons.edit_note_rounded,
                        label: context.tr('my_drafts'),
                        onTap: () => context.push('/recipes/drafts'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: RecipeActionCard(
                        icon: Icons.people_rounded,
                        label: context.tr('creators'),
                        onTap: () => context.push('/recipes/creators'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        if (_forYouRecipes.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: RecipeSectionHeader(title: context.tr('recommended_for_you')),
          ),
          SliverToBoxAdapter(
            child: RecipeCarousel(recipes: _forYouRecipes, onTap: _openRecipe),
          ),
        ],

        if (_popularRecipes.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: RecipeSectionHeader(
              title: context.tr('popular_this_week'),
              onSeeAll: () => context.push('/recipes/popular'),
            ),
          ),
          SliverToBoxAdapter(
            child: RecipeCarousel(recipes: _popularRecipes, onTap: _openRecipe),
          ),
        ],

        SliverToBoxAdapter(
          child: RecipeSectionHeader(title: context.tr('browse_by_category')),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 0.75,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final category = recipeCategories[index];
                return RecipeCategoryCard(
                  category: category,
                  count: _categoryCounts[category.id] ?? 0,
                  onTap: () => context.push('/recipes/category/${category.id}'),
                );
              },
              childCount: recipeCategories.length,
            ),
          ),
        ),

        if (_allAuthors.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: RecipeSectionHeader(
              title: context.tr('top_creators'),
              onSeeAll: () => context.push('/recipes/creators'),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 110,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final author in _topAuthors)
                    CreatorAvatarCard(
                      name: author.name,
                      avatarUrl: author.avatarUrl,
                      recipeCount: author.recipeCount,
                      onTap: () => context.push(
                        '/author/${author.id}',
                        extra: {'authorName': author.name},
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],

        if (_recentRecipes.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: RecipeSectionHeader(
              title: context.tr('recently_added'),
              onSeeAll: () => context.push('/recipes/all'),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            // Two-column photo tiles, matching the reference design.
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.82,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => DietAwareRecipeCard(
                  recipe: _recentRecipes[index],
                  onTap: () => _openRecipe(_recentRecipes[index]),
                ),
                childCount: _recentRecipes.length > 6 ? 6 : _recentRecipes.length,
              ),
            ),
          ),
        ],

        SliverPadding(
          padding: EdgeInsets.only(bottom: 120 + MediaQuery.paddingOf(context).bottom),
        ),
      ],
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CupertinoActivityIndicator(),
          const SizedBox(height: 16),
          Text(context.tr('loading_recipes')),
        ],
      ),
    );
  }
}

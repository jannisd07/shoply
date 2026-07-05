import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/constants/recipe_categories.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/dietary_preference.dart';
import 'package:shoply/data/services/recipe_service.dart';
import 'package:shoply/data/services/recipe_features_service.dart';
import 'package:shoply/data/services/ingredient_substitution_service.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/saved_recipes_provider.dart';
import 'package:shoply/presentation/state/recipes_provider.dart';
import 'package:shoply/data/services/dynamic_tutorial_service.dart';
import 'package:shoply/data/services/contextual_prompt_service.dart';
// QuickFiltersRow removed - now using inline search
import 'package:cached_network_image/cached_network_image.dart';

class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key, this.initialQuery});

  /// Pre-fills and triggers the search, e.g. from a Siri "search recipes"
  /// deep link (`shoply://recipes/search?q=...`).
  final String? initialQuery;

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends ConsumerState<RecipesScreen> {
  final _recipeService = RecipeService();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  
  // ignore: unused_field - used for search/filter functionality
  List<Recipe> _allRecipes = [];
  List<Recipe> _popularRecipes = [];
  List<Recipe> _recentRecipes = [];
  Recipe? _recipeOfTheWeek;
  List<Recipe> _forYouRecipes = []; // Personalized recommendations
  List<Map<String, dynamic>> _topAuthors = [];
  Map<String, int> _categoryCounts = {};
  int _totalRecipes = 0;
  int _totalCreators = 0;
  bool _isLoading = true;
  bool _isSearching = false;
  String _searchQuery = '';
  List<Recipe> _searchResults = [];
  int _lastRefreshTrigger = 0;

  @override
  void dispose() {
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);
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

  /// Check if data needs to be refreshed (e.g., after rating change)
  void _checkForRefresh() {
    final currentTrigger = ref.read(recipeRefreshTriggerProvider);
    if (currentTrigger != _lastRefreshTrigger) {
      _lastRefreshTrigger = currentTrigger;
      _loadAllData();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reset search when navigating back to this screen via tab
    final location = GoRouterState.of(context).matchedLocation;
    if (location == '/recipes' && _isSearching) {
      // Clear search when tab is clicked
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isSearching) {
          _clearSearch();
        }
      });
    }
  }

  void _onSearchTextChanged() {
    final value = _searchController.text;
    if (value != _searchQuery) {
      _searchQuery = value;
      if (value.length >= 1) {
        _performSearch(value);
      } else if (value.isEmpty && _isSearching) {
        setState(() {
          _isSearching = false;
          _searchResults = [];
        });
      }
    }
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _recipeService.getRecipes(),
        // Request 9 so we still have 8 after excluding recipe of the week
        _recipeService.getPopularRecipes(limit: 9, thisWeekOnly: true),
        _recipeService.getRecentRecipes(limit: 10),
        _recipeService.getTopAuthors(limit: 8),
        RecipeFeaturesService.instance.getRecipeOfTheWeek(),
      ]);

      final allRecipes = results[0] as List<Recipe>;
      final popularRaw = results[1] as List<Recipe>;
      final authors = results[3] as List<Map<String, dynamic>>;
      final weekRecipe = results[4] as Recipe?;

      // Exclude recipe of the week from "Popular This Week"
      final weekId = weekRecipe?.id;
      final popular = popularRaw
          .where((r) => r.id != weekId)
          .take(8)
          .toList();

      // IDs already shown (recipe of week + popular) → exclude from "For You"
      final shownIds = <String>{
        if (weekId != null) weekId,
        ...popular.map((r) => r.id),
      };

      // Calculate category counts
      final counts = <String, int>{};
      for (final category in recipeCategories) {
        counts[category.id] = allRecipes.where((r) =>
          r.labels.any((l) => l.toLowerCase().contains(category.id.toLowerCase()))
        ).length;
      }

      // Get personalized "For You" recipes based on user diet preferences
      // Excludes anything already shown in recipe of week or popular sections
      final candidateRecipes =
          allRecipes.where((r) => !shownIds.contains(r.id)).toList();
      final user = ref.read(currentUserProvider).value;
      List<Recipe> forYou = [];
      if (user != null && (user.dietPreferences.isNotEmpty || user.allergies.isNotEmpty)) {
        // Score recipes based on preference matches, rating, and engagement
        final scoredRecipes = <Recipe, double>{};
        for (final recipe in candidateRecipes) {
          double score = 0;

          // Add points for matching diet preferences
          for (final pref in user.dietPreferences) {
            if (recipe.labels.any((l) => l.toLowerCase().contains(pref.toLowerCase()))) {
              score += 2.0;
            }
          }

          // Subtract points for allergens
          for (final allergy in user.allergies) {
            if (recipe.ingredients.any((ing) =>
                ing.name.toLowerCase().contains(allergy.toLowerCase()))) {
              score -= 5.0; // Heavy penalty for allergens
            }
          }

          // Boost by rating (0-5 stars → 0-2.5 points)
          score += recipe.averageRating * 0.5;

          // Boost by view count (logarithmic to not over-weight viral recipes)
          if (recipe.viewCount > 0) {
            score += (recipe.viewCount.toDouble()).clamp(0, 100) * 0.01;
          }

          // Boost by rating count (social proof)
          score += (recipe.ratingCount * 0.2).clamp(0, 2);

          // Freshness boost (recipes from last 7 days get bonus)
          final age = DateTime.now().difference(recipe.createdAt).inDays;
          if (age <= 7) {
            score += 1.0;
          } else if (age <= 30) {
            score += 0.5;
          }

          if (score > 0) {
            scoredRecipes[recipe] = score;
          }
        }

        // Sort by score and take appropriate amount based on total recipes
        final sorted = scoredRecipes.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final forYouLimit = candidateRecipes.length <= 6
            ? (candidateRecipes.length / 2).ceil().clamp(1, 3)
            : 6;
        forYou = sorted.take(forYouLimit).map((e) => e.key).toList();
      }
      // If no personalized matches, show top rated from candidates
      if (forYou.isEmpty) {
        forYou = List<Recipe>.from(candidateRecipes)
          ..sort((a, b) {
            final scoreA = a.averageRating * 2 + (a.ratingCount * 0.1) + (a.viewCount * 0.01);
            final scoreB = b.averageRating * 2 + (b.ratingCount * 0.1) + (b.viewCount * 0.01);
            return scoreB.compareTo(scoreA);
          });
        final forYouLimit = candidateRecipes.length <= 6
            ? (candidateRecipes.length / 2).ceil().clamp(1, 3)
            : 6;
        forYou = forYou.take(forYouLimit).toList();
      }

      setState(() {
        _allRecipes = allRecipes;
        _popularRecipes = popular;
        _recentRecipes = results[2] as List<Recipe>;
        _topAuthors = authors;
        _recipeOfTheWeek = weekRecipe;
        _forYouRecipes = forYou;
        _categoryCounts = counts;
        _totalRecipes = allRecipes.length;
        _totalCreators = authors.length;
        _isLoading = false;
      });
      
      // Load saved recipes
      ref.read(savedRecipesProvider.notifier).loadSavedRecipes();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('error_loading_recipes_detail', params: {'error': e.toString()}))),
        );
      }
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchQuery = '';
        _searchResults = [];
      });
      return;
    }

    // Only update query, don't trigger full rebuild yet
    _searchQuery = query;
    
    // Set searching to true only once and keep focus
    final wasSearching = _isSearching;
    if (!_isSearching) {
      setState(() {
        _isSearching = true;
      });
      // Request focus after view switch
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _searchFocusNode.requestFocus();
        }
      });
    }

    try {
      final recipes = await _recipeService.searchRecipes(query);
      if (mounted && _searchQuery == query) {
        // Only update if query hasn't changed
        setState(() {
          _searchResults = recipes;
        });
        // Keep focus on search field
        if (!wasSearching) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_searchFocusNode.hasFocus) {
              _searchFocusNode.requestFocus();
            }
          });
        }
      }
    } catch (e) {
      // Handle error silently
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _searchResults = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final savedState = ref.watch(savedRecipesProvider);

    // Watch refresh trigger to reload data when ratings change
    ref.listen(recipeRefreshTriggerProvider, (previous, next) {
      if (previous != next) {
        _loadAllData();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: _isLoading
          ? _buildLoadingState(context)
          : Column(
              children: [
                // Fixed Search Header
                _buildSearchHeader(context, textPrimary, textSecondary),
                // Content area
                Expanded(
                  child: _isSearching
                      ? _buildSearchResultsList(context)
                      : _buildMainContent(context, savedState),
                ),
              ],
            ),
    );
  }

  Widget _buildSearchHeader(BuildContext context, Color textPrimary, Color textSecondary) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                IconButton(
                  key: DynamicTutorialService.instance.addRecipeButtonKey,
                  icon: Icon(Icons.add_rounded, color: textPrimary),
                  onPressed: () => context.push('/recipes/add'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Search Bar - ALWAYS the same TextField widget
            Container(
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.border(context)),
              ),
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
                // onChanged handled by controller listener
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, dynamic savedState) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Update tutorial with recipes data
    DynamicTutorialService.instance.updateRecipesData(hasRecipes: _popularRecipes.isNotEmpty || _recentRecipes.isNotEmpty);
    
    return NotificationListener<ScrollNotification>(
      key: DynamicTutorialService.instance.recipesAreaKey,
      onNotification: (notification) {
        // Dismiss keyboard when user starts scrolling
        if (notification is ScrollStartNotification) {
          FocusScope.of(context).unfocus();
        }
        return false;
      },
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
        // Native iOS Pull-to-Refresh
        CupertinoSliverRefreshControl(
          onRefresh: _loadAllData,
        ),
        // Community Stats Banner - clean minimal look
        if (_totalRecipes > 0)
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
                  _StatItem(
                    icon: Icons.restaurant_menu_rounded,
                    value: _totalRecipes.toString(),
                    label: context.tr('recipes'),
                  ),
                  _StatItem(
                    icon: Icons.people_rounded,
                    value: _totalCreators.toString(),
                    label: context.tr('creators'),
                  ),
                  _StatItem(
                    icon: Icons.bookmark_rounded,
                    value: savedState.savedIds.length.toString(),
                    label: context.tr('saved_recipes'),
                  ),
                ],
              ),
            ),
          ),
        
        // Featured Recipe of the Week
        if (_recipeOfTheWeek != null) ...[
          _buildSectionHeader(
            context,
            context.tr('recipe_of_the_week'),
            Icons.auto_awesome_rounded,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _FeaturedRecipeCard(
                recipe: _recipeOfTheWeek!,
                onTap: () => context.push('/recipes/${_recipeOfTheWeek!.id}'),
              ),
            ),
          ),
        ],
        
        // User Actions Row (My Recipes, Saved, Drafts, Browse Users)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.restaurant_rounded,
                        label: context.tr('my_recipes'),
                        color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                        onTap: () => context.push('/recipes/my'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.bookmark_rounded,
                        label: context.tr('saved_recipes'),
                        color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                        badge: savedState.savedIds.isNotEmpty 
                            ? savedState.savedIds.length.toString() 
                            : null,
                        onTap: () => context.push('/recipes/saved'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.edit_note_rounded,
                        label: context.tr('my_drafts'),
                        color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                        onTap: () => context.push('/recipes/drafts'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.people_rounded,
                        label: context.tr('creators'),
                        color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                        onTap: () => context.push('/recipes/creators'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        // For You - Personalized Recommendations
        if (_forYouRecipes.isNotEmpty) ...[
          _buildSectionHeader(
            context, 
            context.tr('recommended_for_you'), 
            Icons.favorite_rounded,
            iconColor: isDark ? Colors.white70 : const Color(0xFF6B7280),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 210,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _forYouRecipes.length,
                itemBuilder: (context, index) {
                  return _HorizontalRecipeCard(
                    recipe: _forYouRecipes[index],
                    onTap: () => context.push('/recipes/${_forYouRecipes[index].id}'),
                  );
                },
              ),
            ),
          ),
        ],
        
        // Popular This Week Section
        if (_popularRecipes.isNotEmpty) ...[
          _buildSectionHeader(
            context, 
            context.tr('popular_this_week'), 
            Icons.trending_up_rounded,
            onSeeAll: () => context.push('/recipes/popular'),
            iconColor: isDark ? Colors.white70 : const Color(0xFF6B7280),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 210,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _popularRecipes.length,
                itemBuilder: (context, index) {
                  return _HorizontalRecipeCard(
                    recipe: _popularRecipes[index],
                    onTap: () => context.push('/recipes/${_popularRecipes[index].id}'),
                  );
                },
              ),
            ),
          ),
        ],
        
        // Categories Section
        _buildSectionHeader(context, context.tr('browse_by_category'), Icons.category_rounded, iconColor: isDark ? Colors.white70 : const Color(0xFF6B7280)),
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
                return _CategoryCard(
                  category: category,
                  count: _categoryCounts[category.id] ?? 0,
                  onTap: () => context.push('/recipes/category/${category.id}'),
                );
              },
              childCount: recipeCategories.length,
            ),
          ),
        ),
        
        // Top Creators Section
        if (_topAuthors.isNotEmpty) ...[
          _buildSectionHeader(
            context, 
            context.tr('top_creators'), 
            Icons.star_rounded,
            onSeeAll: () => context.push('/recipes/creators'),
            iconColor: isDark ? Colors.white70 : const Color(0xFF6B7280),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _topAuthors.length,
                itemBuilder: (context, index) {
                  final author = _topAuthors[index];
                  return _CreatorCard(
                    name: author['authorName'] as String,
                    avatarUrl: author['authorAvatarUrl'] as String?,
                    recipeCount: author['recipeCount'] as int,
                    onTap: () => context.push(
                      '/author/${author['authorId']}',
                      extra: {'authorName': author['authorName']},
                    ),
                  );
                },
              ),
            ),
          ),
        ],
        
        // Recent Recipes Section
        if (_recentRecipes.isNotEmpty) ...[
          _buildSectionHeader(
            context, 
            context.tr('recently_added'), 
            Icons.schedule_rounded,
            onSeeAll: () => context.push('/recipes/all'),
            iconColor: isDark ? Colors.white70 : const Color(0xFF6B7280),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return _RecipeCard(
                    recipe: _recentRecipes[index],
                    onTap: () => context.push('/recipes/${_recentRecipes[index].id}'),
                  );
                },
                childCount: _recentRecipes.length > 5 ? 5 : _recentRecipes.length,
              ),
            ),
          ),
        ],
        
        // Bottom Padding
        SliverPadding(
          padding: EdgeInsets.only(
            bottom: 120 + MediaQuery.of(context).padding.bottom,
          ),
        ),
      ],
      ),
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

  Widget _buildSearchResultsList(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final queryLower = _searchQuery.toLowerCase();
    
    // Dismiss keyboard on scroll
    return NotificationListener<ScrollStartNotification>(
      onNotification: (notification) {
        // Dismiss keyboard when user starts scrolling
        FocusScope.of(context).unfocus();
        return false;
      },
      child: _buildSearchResultsContent(context, textPrimary, textSecondary, queryLower),
    );
  }
  
  Widget _buildSearchResultsContent(BuildContext context, Color textPrimary, Color textSecondary, String queryLower) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Find matching categories
    final matchingCategories = recipeCategories.where((cat) =>
      cat.nameKey.toLowerCase().contains(queryLower) ||
      cat.id.toLowerCase().contains(queryLower)
    ).toList();
    
    // Find matching authors from top authors
    final matchingAuthors = _topAuthors.where((author) =>
      (author['author_name'] as String?)?.toLowerCase().contains(queryLower) == true
    ).toList();
    
    // Preference keywords that users might search for
    final preferenceKeywords = {
      'vegan': ['vegan', 'plant-based', 'pflanzlich'],
      'vegetarian': ['vegetarian', 'vegetarisch', 'veggie'],
      'quick': ['quick', 'schnell', 'fast', 'easy'],
      'healthy': ['healthy', 'gesund', 'light', 'leicht'],
      'gluten-free': ['gluten-free', 'glutenfrei', 'gluten free'],
      'low-carb': ['low-carb', 'keto', 'low carb'],
      'dairy-free': ['dairy-free', 'laktosefrei', 'dairy free'],
    };
    
    final matchingPreferences = <String>[];
    for (final entry in preferenceKeywords.entries) {
      if (entry.value.any((keyword) => keyword.contains(queryLower) || queryLower.contains(keyword))) {
        matchingPreferences.add(entry.key);
      }
    }
    
    return CustomScrollView(
      slivers: [
        // Categories Section
        if (matchingCategories.isNotEmpty && _searchQuery.length >= 1)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Categories',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: matchingCategories.map((cat) => GestureDetector(
                      onTap: () => context.push('/recipes/category/${cat.id}'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: cat.color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(cat.icon, style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 6),
                            Text(
                              context.tr(cat.nameKey),
                              style: TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    )).toList(),
                  ),
                ],
              ),
            ),
          ),
        
        // Preferences Section
        if (matchingPreferences.isNotEmpty && _searchQuery.length >= 1)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dietary Preferences',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: matchingPreferences.map((pref) => GestureDetector(
                      onTap: () => context.push('/recipes/category/$pref'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline, size: 16, color: isDark ? Colors.white70 : const Color(0xFF6B7280)),
                            const SizedBox(width: 6),
                            Text(
                              pref.replaceAll('-', ' ').split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' '),
                              style: TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    )).toList(),
                  ),
                ],
              ),
            ),
          ),
        
        // Creators Section  
        if (matchingAuthors.isNotEmpty && _searchQuery.length >= 1)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Creators',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...matchingAuthors.take(3).map((author) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : PaperColors.cream,
                      child: Text(
                        (author['author_name'] as String? ?? 'U')[0].toUpperCase(),
                        style: TextStyle(color: textPrimary),
                      ),
                    ),
                    title: Text(
                      author['author_name'] as String? ?? 'Unknown',
                      style: TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      '${author['recipe_count'] ?? 0} recipes',
                      style: TextStyle(color: textSecondary, fontSize: 13),
                    ),
                    onTap: () => context.push(
                      '/author/${author['author_id']}',
                      extra: {'authorName': author['author_name']},
                    ),
                  )),
                ],
              ),
            ),
          ),
        
        // Recipes Section Header
        if (_searchResults.isNotEmpty && _searchQuery.length >= 1)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'Recipes (${_searchResults.length})',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        
        // Recipe Results
        if (_searchResults.isEmpty && matchingCategories.isEmpty && matchingAuthors.isEmpty && matchingPreferences.isEmpty && _searchQuery.length >= 1)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off_rounded, size: 64, color: textSecondary.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('no_results'),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr('try_different_search'),
                    style: TextStyle(color: textSecondary),
                  ),
                ],
              ),
            ),
          )
        else if (_searchResults.isNotEmpty)
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
                  return _RecipeCard(
                    recipe: _searchResults[index],
                    onTap: () => context.push('/recipes/${_searchResults[index].id}'),
                  );
                },
                childCount: _searchResults.length,
              ),
            ),
          ),
      ],
    );
  }

  SliverToBoxAdapter _buildSectionHeader(
    BuildContext context, 
    String title,
    IconData icon, {
    VoidCallback? onSeeAll,
    Color? iconColor,
  }) {
    // Paper kicker style section header
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 26, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ),
            if (onSeeAll != null)
              GestureDetector(
                onTap: onSeeAll,
                child: Text(
                  context.tr('see_all'),
                  style: TextStyle(
                    color: AppColors.accentColor(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

}

// Stat Item Widget (for community stats banner)
class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color? iconColor;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: PaperTextStyles.serif(
            19,
            color: AppColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// Featured Recipe Card Widget (Recipe of the Day)
class _FeaturedRecipeCard extends ConsumerWidget {
  final Recipe recipe;
  final VoidCallback onTap;

  const _FeaturedRecipeCard({
    required this.recipe,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSaved = ref.watch(isRecipeSavedProvider(recipe.id));
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final accent = AppColors.accentColor(context);

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image block with kicker + bookmark
            SizedBox(
              height: 150,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: recipe.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: const Color(0xFFB7C4A9),
                      child: const Center(child: CupertinoActivityIndicator()),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: const Color(0xFFB7C4A9),
                      child: const Icon(
                        Icons.restaurant_rounded,
                        size: 40,
                        color: Color(0xFF42513A),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: PaperColors.paper.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        context.tr('recipe_of_the_week').toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w600,
                          color: PaperColors.creamInk,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: () {
                        ref
                            .read(savedRecipesProvider.notifier)
                            .toggleSave(recipe.id);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: PaperColors.paper.withValues(alpha: 0.92),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          size: 18,
                          color: isSaved ? accent : PaperColors.creamInk,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Paper content panel below the image
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                border: Border(
                  left: BorderSide(color: AppColors.border(context)),
                  right: BorderSide(color: AppColors.border(context)),
                  bottom: BorderSide(color: AppColors.border(context)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PaperTextStyles.serif(19, color: textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${recipe.totalTimeMinutes} min · ${recipe.authorName}'
                    '${recipe.averageRating > 0 ? ' · ★ ${recipe.averageRating.toStringAsFixed(1)}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: 13,
                        color: accent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        context.tr('add_to_list'),
                        style: TextStyle(fontSize: 12, color: accent),
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

// Action Card Widget (My Recipes, Saved, Creators) - with gradient background
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    this.badge,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: AppColors.textSecondary(context),
                ),
                if (badge != null)
                  Positioned(
                    top: -6,
                    right: -14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentColor(context),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// Category Card Widget - clean, minimal design
class _CategoryCard extends StatelessWidget {
  final RecipeCategory category;
  final int count;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.category,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final surface = AppColors.surface(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(category.icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                context.tr(category.nameKey),
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 2),
            Opacity(
              opacity: count > 0 ? 1.0 : 0.0,
              child: Text(
                count > 0 ? '$count' : '0',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Creator Card Widget
class _CreatorCard extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final int recipeCount;
  final VoidCallback onTap;

  const _CreatorCard({
    required this.name,
    this.avatarUrl,
    required this.recipeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final cardColor = AppColors.surface(context);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cardColor,
                border: Border.all(color: borderColor),
              ),
              child: avatarUrl != null
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: avatarUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Center(
                          child: Text(
                            name[0].toUpperCase(),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: textSecondary,
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Center(
                          child: Text(
                            name[0].toUpperCase(),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: textSecondary,
                            ),
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        name[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textSecondary,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              style: TextStyle(
                color: textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            Text(
              '$recipeCount recipes',
              style: TextStyle(
                color: textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Horizontal Recipe Card (for Popular section)
class _HorizontalRecipeCard extends ConsumerWidget {
  final Recipe recipe;
  final VoidCallback onTap;

  const _HorizontalRecipeCard({
    required this.recipe,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = AppColors.surface(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);
    final isSaved = ref.watch(isRecipeSavedProvider(recipe.id));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        height: 200, // Fixed height to prevent overflow
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with bookmark
            Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: recipe.imageUrl,
                  height: 110,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    height: 110,
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                    child: const Center(child: Icon(Icons.restaurant_rounded)),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    height: 110,
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                    child: const Center(child: Icon(Icons.restaurant_rounded)),
                  ),
                ),
                // Bookmark button
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () {
                      ref.read(savedRecipesProvider.notifier).toggleSave(recipe.id);
                    },
                    child: ClipOval(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isSaved ? Colors.white : Colors.black.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                          ),
                          child: Icon(
                            isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                            size: 16,
                            color: isSaved ? Colors.black : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Content - Expanded to fill remaining space
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.name,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 12, color: textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '${recipe.totalTimeMinutes} min',
                          style: TextStyle(color: textSecondary, fontSize: 11),
                        ),
                        if (recipe.averageRating > 0) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.star_rounded, size: 12, color: const Color(0xFFFFB300)),
                          const SizedBox(width: 2),
                          Text(
                            recipe.averageRating.toStringAsFixed(1),
                            style: TextStyle(color: textPrimary, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Recipe Card Widget (Vertical list card with bookmark)
class _RecipeCard extends ConsumerWidget {
  final Recipe recipe;
  final VoidCallback onTap;

  const _RecipeCard({
    required this.recipe,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Check diet compatibility
    final user = ref.watch(currentUserProvider).value;
    RecipeCompatibility? compatibility;
    
    if (user != null && (user.allergies.isNotEmpty || user.dietPreferences.isNotEmpty)) {
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
      
      compatibility = IngredientSubstitutionService.checkRecipeCompatibility(
        recipe: recipe,
        allergies: allergies,
        diets: diets,
      );
    }
    
    final cardColor = AppColors.surface(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final borderColor = AppColors.border(context);
    final inputFill = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : PaperColors.cream;
    final isSaved = ref.watch(isRecipeSavedProvider(recipe.id));

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image with badges
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  child: SizedBox(
                    height: 160,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (recipe.imageUrl.isNotEmpty)
                          CachedNetworkImage(
                            imageUrl: recipe.imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: inputFill,
                              child: Center(
                                child: Icon(Icons.restaurant_rounded, size: 40, color: textSecondary),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: inputFill,
                              child: Icon(Icons.restaurant_rounded, size: 40, color: textSecondary),
                            ),
                          )
                        else
                          Container(
                            color: inputFill,
                            child: Icon(Icons.restaurant_rounded, size: 40, color: textSecondary),
                          ),
                        // Bookmark button
                        Positioned(
                          top: 10,
                          right: 10,
                          child: GestureDetector(
                            onTap: () {
                              ref.read(savedRecipesProvider.notifier).toggleSave(recipe.id);
                            },
                            child: ClipOval(
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isSaved ? Colors.white : Colors.black.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                                  ),
                                  child: Icon(
                                    isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                    size: 20,
                                    color: isSaved ? Colors.black : Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Compatibility Badge
                        if (compatibility != null)
                          Positioned(
                            top: 10,
                            left: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: compatibility.isCompatible
                                    ? (compatibility.needsModifications
                                        ? const Color(0xFFFF9500)
                                        : const Color(0xFF34C759))
                                    : const Color(0xFFFF3B30),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                compatibility.badgeText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.name,
                        style: PaperTextStyles.serif(18, color: textPrimary),
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
                          Expanded(
                            child: GestureDetector(
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
                                  Flexible(
                                    child: Text(
                                      recipe.authorName,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.schedule_rounded, size: 14, color: textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            '${recipe.totalTimeMinutes} min',
                            style: TextStyle(color: textSecondary, fontSize: 13),
                          ),
                          if (recipe.averageRating > 0) ...[
                            const SizedBox(width: 10),
                            Icon(Icons.star_rounded, size: 14, color: const Color(0xFFFFB300)),
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
      ),
    );
  }
}

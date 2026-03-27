import 'package:shoply/data/services/recipe_service.dart';
import 'package:shoply/core/constants/recipe_categories.dart';

/// Comprehensive search result types
enum SearchResultType {
  recipe,
  category,
  dietaryPreference,
  author,
  ingredient,
  tag,
}

/// A single search result item
class SearchResult {
  final SearchResultType type;
  final String id;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final double relevanceScore;
  final Map<String, dynamic>? metadata;

  const SearchResult({
    required this.type,
    required this.id,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.relevanceScore = 0.0,
    this.metadata,
  });
}

/// Grouped search results for display
class SearchResults {
  final List<SearchResult> categories;
  final List<SearchResult> dietaryPreferences;
  final List<SearchResult> authors;
  final List<SearchResult> recipes;
  final List<SearchResult> ingredients;
  final List<SearchResult> tags;
  
  const SearchResults({
    this.categories = const [],
    this.dietaryPreferences = const [],
    this.authors = const [],
    this.recipes = const [],
    this.ingredients = const [],
    this.tags = const [],
  });
  
  bool get isEmpty => 
    categories.isEmpty && 
    dietaryPreferences.isEmpty && 
    authors.isEmpty && 
    recipes.isEmpty &&
    ingredients.isEmpty &&
    tags.isEmpty;
    
  int get totalCount => 
    categories.length + 
    dietaryPreferences.length + 
    authors.length + 
    recipes.length +
    ingredients.length +
    tags.length;
}

/// Unified search service for comprehensive app-wide search
class UnifiedSearchService {
  final RecipeService _recipeService = RecipeService();
  
  /// All searchable dietary preferences with bilingual keywords
  static const Map<String, List<String>> _dietaryKeywords = {
    'vegan': ['vegan', 'plant-based', 'pflanzlich', 'plant based', 'no animal'],
    'vegetarian': ['vegetarian', 'vegetarisch', 'veggie', 'meatless', 'fleischlos'],
    'gluten-free': ['gluten-free', 'glutenfrei', 'gluten free', 'coeliac', 'celiac', 'zöliakie'],
    'dairy-free': ['dairy-free', 'laktosefrei', 'dairy free', 'lactose-free', 'milchfrei', 'no milk'],
    'low-carb': ['low-carb', 'low carb', 'keto', 'ketogenic', 'ketogen', 'kohlenhydratarm'],
    'high-protein': ['high-protein', 'high protein', 'proteinreich', 'protein-rich', 'eiweißreich'],
    'paleo': ['paleo', 'paleolithic', 'steinzeit', 'caveman'],
    'whole30': ['whole30', 'whole 30'],
    'low-fat': ['low-fat', 'low fat', 'fettarm', 'light', 'leicht'],
    'sugar-free': ['sugar-free', 'sugar free', 'zuckerfrei', 'no sugar', 'ohne zucker'],
    'nut-free': ['nut-free', 'nut free', 'nussfrei', 'no nuts', 'ohne nüsse'],
    'halal': ['halal'],
    'kosher': ['kosher', 'koschér'],
  };
  
  /// Time-based recipe keywords
  static const Map<String, List<String>> _timeKeywords = {
    'quick': ['quick', 'schnell', 'fast', 'easy', 'einfach', '15 min', '20 min', '30 min', 'unter 30'],
    'meal-prep': ['meal-prep', 'meal prep', 'vorkochen', 'batch cooking', 'make ahead'],
    'weeknight': ['weeknight', 'wochentag', 'after work', 'feierabend', 'abendessen'],
    'weekend': ['weekend', 'wochenende', 'sunday', 'sonntag', 'brunch'],
  };
  
  /// Meal type keywords
  static const Map<String, List<String>> _mealTypeKeywords = {
    'breakfast': ['breakfast', 'frühstück', 'morning', 'morgen', 'brunch'],
    'lunch': ['lunch', 'mittagessen', 'mittag'],
    'dinner': ['dinner', 'abendessen', 'supper', 'hauptgericht'],
    'snack': ['snack', 'zwischenmahlzeit', 'appetizer', 'vorspeise'],
    'dessert': ['dessert', 'nachtisch', 'süß', 'sweet', 'kuchen', 'cake'],
    'drinks': ['drink', 'getränk', 'smoothie', 'shake', 'cocktail', 'juice', 'saft'],
  };
  
  /// Cuisine keywords (in addition to categories)
  static const Map<String, List<String>> _cuisineKeywords = {
    'italian': ['italian', 'italienisch', 'italia', 'pasta', 'pizza', 'risotto'],
    'asian': ['asian', 'asiatisch', 'chinese', 'chinesisch', 'japanese', 'japanisch', 'thai', 'vietnamese', 'korean'],
    'mexican': ['mexican', 'mexikanisch', 'taco', 'burrito', 'enchilada', 'tex-mex'],
    'indian': ['indian', 'indisch', 'curry', 'masala', 'tikka', 'naan'],
    'mediterranean': ['mediterranean', 'mediterran', 'greek', 'griechisch', 'middle eastern', 'nahöstlich'],
    'american': ['american', 'amerikanisch', 'burger', 'bbq', 'barbecue', 'comfort food'],
    'french': ['french', 'französisch', 'france', 'baguette', 'croissant'],
    'german': ['german', 'deutsch', 'bavaria', 'bayerisch', 'schnitzel', 'bratwurst'],
  };

  /// Perform comprehensive search across all entities
  Future<SearchResults> search(String query) async {
    final queryLower = query.toLowerCase().trim();
    if (queryLower.isEmpty || queryLower.length < 2) {
      return const SearchResults();
    }
    
    // Run all searches in parallel
    final results = await Future.wait([
      _searchCategories(queryLower),
      _searchDietaryPreferences(queryLower),
      _searchTimeAndMealTypes(queryLower),
      _searchAuthors(queryLower),
      _searchRecipes(queryLower),
      _searchTags(queryLower),
    ]);
    
    return SearchResults(
      categories: results[0],
      dietaryPreferences: [...results[1], ...results[2]], // Combine dietary + time/meal
      authors: results[3],
      recipes: results[4],
      tags: results[5],
    );
  }
  
  /// Search recipe categories
  Future<List<SearchResult>> _searchCategories(String query) async {
    final matches = <SearchResult>[];
    
    for (final category in recipeCategories) {
      final score = _calculateRelevance(query, [
        category.id,
        category.nameKey,
        ...category.keywords,
      ]);
      
      if (score > 0) {
        matches.add(SearchResult(
          type: SearchResultType.category,
          id: category.id,
          title: category.nameKey, // Will be translated in UI
          subtitle: '${category.icon} Category',
          relevanceScore: score,
          metadata: {
            'icon': category.icon,
            'color': category.color.value,
            'keywords': category.keywords,
          },
        ));
      }
    }
    
    matches.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
    return matches.take(5).toList();
  }
  
  /// Search dietary preferences
  Future<List<SearchResult>> _searchDietaryPreferences(String query) async {
    final matches = <SearchResult>[];
    
    for (final entry in _dietaryKeywords.entries) {
      final score = _calculateRelevance(query, entry.value);
      
      if (score > 0) {
        matches.add(SearchResult(
          type: SearchResultType.dietaryPreference,
          id: entry.key,
          title: _formatPreferenceName(entry.key),
          subtitle: 'Dietary Preference',
          relevanceScore: score,
          metadata: {'keywords': entry.value},
        ));
      }
    }
    
    matches.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
    return matches.take(5).toList();
  }
  
  /// Search time-based and meal type preferences
  Future<List<SearchResult>> _searchTimeAndMealTypes(String query) async {
    final matches = <SearchResult>[];
    
    // Time keywords
    for (final entry in _timeKeywords.entries) {
      final score = _calculateRelevance(query, entry.value);
      if (score > 0) {
        matches.add(SearchResult(
          type: SearchResultType.dietaryPreference,
          id: 'time_${entry.key}',
          title: _formatPreferenceName(entry.key),
          subtitle: 'Time Filter',
          relevanceScore: score,
          metadata: {'filterType': 'time', 'keywords': entry.value},
        ));
      }
    }
    
    // Meal types
    for (final entry in _mealTypeKeywords.entries) {
      final score = _calculateRelevance(query, entry.value);
      if (score > 0) {
        matches.add(SearchResult(
          type: SearchResultType.dietaryPreference,
          id: 'meal_${entry.key}',
          title: _formatPreferenceName(entry.key),
          subtitle: 'Meal Type',
          relevanceScore: score,
          metadata: {'filterType': 'meal', 'keywords': entry.value},
        ));
      }
    }
    
    matches.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
    return matches.take(5).toList();
  }
  
  /// Search authors/creators
  Future<List<SearchResult>> _searchAuthors(String query) async {
    final matches = <SearchResult>[];
    
    try {
      final authors = await _recipeService.searchAuthors(query);
      
      for (final author in authors) {
        final authorName = author['authorName'] as String? ?? '';
        final score = _calculateRelevance(query, [authorName]);
        
        if (score > 0) {
          matches.add(SearchResult(
            type: SearchResultType.author,
            id: author['authorId'] as String? ?? '',
            title: authorName,
            subtitle: '${author['recipeCount'] ?? 0} recipes',
            imageUrl: author['authorAvatarUrl'] as String?,
            relevanceScore: score,
            metadata: author,
          ));
        }
      }
    } catch (e) {
      print('❌ [SEARCH] Error searching authors: $e');
    }
    
    matches.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
    return matches.take(5).toList();
  }
  
  /// Search recipes with comprehensive matching
  Future<List<SearchResult>> _searchRecipes(String query) async {
    final matches = <SearchResult>[];
    
    try {
      final recipes = await _recipeService.searchRecipes(query);
      
      for (final recipe in recipes) {
        // Calculate relevance based on multiple factors
        final searchableTexts = [
          recipe.name,
          recipe.description,
          recipe.authorName,
          ...recipe.labels,
          ...recipe.ingredients.map((i) => i.name),
        ];
        
        final score = _calculateRelevance(query, searchableTexts);
        
        // Boost score for exact name match
        final nameScore = recipe.name.toLowerCase().contains(query) ? 2.0 : 0.0;
        
        matches.add(SearchResult(
          type: SearchResultType.recipe,
          id: recipe.id,
          title: recipe.name,
          subtitle: '${recipe.totalTimeMinutes} min • ${recipe.authorName}',
          imageUrl: recipe.imageUrl,
          relevanceScore: score + nameScore + (recipe.averageRating / 5.0),
          metadata: {
            'recipe': recipe,
            'rating': recipe.averageRating,
            'time': recipe.totalTimeMinutes,
          },
        ));
      }
    } catch (e) {
      print('❌ [SEARCH] Error searching recipes: $e');
    }
    
    matches.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
    return matches.take(20).toList();
  }
  
  /// Search unique tags from all recipes
  Future<List<SearchResult>> _searchTags(String query) async {
    final matches = <SearchResult>[];
    final uniqueTags = <String>{};
    
    try {
      final allRecipes = await _recipeService.getRecipes();
      
      // Collect unique tags
      for (final recipe in allRecipes) {
        uniqueTags.addAll(recipe.labels);
      }
      
      // Search tags
      for (final tag in uniqueTags) {
        final score = _calculateRelevance(query, [tag]);
        
        if (score > 0) {
          // Count recipes with this tag
          final recipeCount = allRecipes.where((r) => r.labels.contains(tag)).length;
          
          matches.add(SearchResult(
            type: SearchResultType.tag,
            id: tag,
            title: '#$tag',
            subtitle: '$recipeCount recipes',
            relevanceScore: score,
            metadata: {'recipeCount': recipeCount},
          ));
        }
      }
      
      // Also check cuisine keywords
      for (final entry in _cuisineKeywords.entries) {
        final score = _calculateRelevance(query, entry.value);
        if (score > 0 && !matches.any((m) => m.id == entry.key)) {
          matches.add(SearchResult(
            type: SearchResultType.tag,
            id: entry.key,
            title: '#${entry.key}',
            subtitle: 'Cuisine',
            relevanceScore: score,
            metadata: {'keywords': entry.value},
          ));
        }
      }
    } catch (e) {
      print('❌ [SEARCH] Error searching tags: $e');
    }
    
    matches.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
    return matches.take(10).toList();
  }
  
  /// Calculate relevance score for a query against searchable texts
  double _calculateRelevance(String query, List<String> searchableTexts) {
    double maxScore = 0.0;
    final queryLower = query.toLowerCase();
    
    for (final text in searchableTexts) {
      final textLower = text.toLowerCase();
      
      // Exact match = highest score
      if (textLower == queryLower) {
        return 3.0;
      }
      
      // Starts with query = high score
      if (textLower.startsWith(queryLower)) {
        maxScore = maxScore < 2.5 ? 2.5 : maxScore;
        continue;
      }
      
      // Word boundary match = good score
      if (textLower.contains(' $queryLower') || textLower.contains('$queryLower ')) {
        maxScore = maxScore < 2.0 ? 2.0 : maxScore;
        continue;
      }
      
      // Contains query = moderate score
      if (textLower.contains(queryLower)) {
        maxScore = maxScore < 1.5 ? 1.5 : maxScore;
        continue;
      }
      
      // Query contains text (for short keywords)
      if (queryLower.contains(textLower) && textLower.length >= 3) {
        maxScore = maxScore < 1.0 ? 1.0 : maxScore;
      }
    }
    
    return maxScore;
  }
  
  /// Format preference name for display
  String _formatPreferenceName(String key) {
    return key
        .replaceAll('-', ' ')
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty 
            ? '${word[0].toUpperCase()}${word.substring(1)}' 
            : '')
        .join(' ');
  }
  
  /// Get popular/suggested searches for empty state
  List<String> getSuggestedSearches() {
    return [
      'Quick recipes',
      'Vegetarian',
      'Italian',
      'Breakfast',
      'Healthy',
      'Dessert',
      'Asian',
      'Under 30 min',
    ];
  }
}

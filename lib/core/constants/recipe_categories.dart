import 'package:flutter/material.dart';

/// Recipe category model for browsing and filtering
class RecipeCategory {
  final String id;
  final String nameKey; // Localization key for name
  final String icon;
  final Color color;
  final List<String> keywords; // Additional keywords for search

  const RecipeCategory({
    required this.id,
    required this.nameKey,
    required this.icon,
    required this.color,
    this.keywords = const [],
  });
}

/// Predefined categories for browsing - iOS color palette with variety
/// **IMPORTANT**: IDs must match QuickFilters in recipe_filter.dart and
/// auto-categorization labels in recipe_service.dart
const List<RecipeCategory> recipeCategories = [
  RecipeCategory(
    id: 'italian',
    nameKey: 'category_italian',
    icon: '🍝',
    color: Color(0xFFFF6B6B),
    keywords: ['italian', 'italien', 'pasta', 'pizza', 'risotto', 'italienisch'],
  ),
  RecipeCategory(
    id: 'asian',
    nameKey: 'category_asian',
    icon: '🍜',
    color: Color(0xFFFF9500),
    keywords: ['asian', 'asien', 'chinese', 'japanese', 'thai', 'vietnamese', 'korean', 'asiatisch', 'sushi', 'wok'],
  ),
  RecipeCategory(
    id: 'vegetarian',
    nameKey: 'category_vegetarian',
    icon: '🥗',
    color: Color(0xFF34C759),
    keywords: ['vegetarian', 'vegetarisch', 'veggie', 'meatless', 'fleischlos', 'gemüse', 'vegetables'],
  ),
  RecipeCategory(
    id: 'snack',
    nameKey: 'category_desserts',
    icon: '🍰',
    color: Color(0xFFAF52DE),
    keywords: ['dessert', 'nachtisch', 'süß', 'sweet', 'cake', 'kuchen', 'torte', 'gebäck', 'pastry', 'snack'],
  ),
  RecipeCategory(
    id: 'breakfast',
    nameKey: 'category_breakfast',
    icon: '🍳',
    color: Color(0xFFFFCC00),
    keywords: ['breakfast', 'frühstück', 'morning', 'brunch', 'eggs', 'pancakes', 'omelette'],
  ),
  RecipeCategory(
    id: 'quick',
    nameKey: 'category_quick',
    icon: '⚡',
    color: Color(0xFF5AC8FA),
    keywords: ['quick', 'schnell', 'fast', 'easy', 'einfach', '15 min', '20 min', '30 min', 'unter 30'],
  ),
  RecipeCategory(
    id: 'healthy',
    nameKey: 'category_healthy',
    icon: '💚',
    color: Color(0xFF30D158),
    keywords: ['healthy', 'gesund', 'light', 'leicht', 'fit', 'low-cal', 'salad', 'salat'],
  ),
  RecipeCategory(
    id: 'comfort-food',
    nameKey: 'category_comfort',
    icon: '🍲',
    color: Color(0xFFFF9F0A),
    keywords: ['comfort', 'comfort-food', 'herzhaft', 'wärmt', 'soul food', 'eintopf', 'stew'],
  ),
  RecipeCategory(
    id: 'mexican',
    nameKey: 'category_mexican',
    icon: '🌮',
    color: Color(0xFFE74C3C),
    keywords: ['mexican', 'mexikanisch', 'taco', 'burrito', 'enchilada', 'tex-mex', 'salsa'],
  ),
  RecipeCategory(
    id: 'mediterranean',
    nameKey: 'category_mediterranean',
    icon: '🫒',
    color: Color(0xFF2ECC71),
    keywords: ['mediterranean', 'mediterran', 'greek', 'griechisch', 'middle eastern', 'nahöstlich', 'hummus', 'falafel'],
  ),
  RecipeCategory(
    id: 'seafood',
    nameKey: 'category_seafood',
    icon: '🐟',
    color: Color(0xFF3498DB),
    keywords: ['seafood', 'meeresfrüchte', 'fish', 'fisch', 'shrimp', 'salmon', 'lachs'],
  ),
  RecipeCategory(
    id: 'soup',
    nameKey: 'category_soup',
    icon: '🥣',
    color: Color(0xFFF39C12),
    keywords: ['soup', 'suppe', 'broth', 'brühe', 'stew', 'eintopf'],
  ),
];

/// Get a category by ID
RecipeCategory? getCategoryById(String id) {
  try {
    return recipeCategories.firstWhere((cat) => cat.id == id);
  } catch (_) {
    return null;
  }
}

/// Get categories matching a search query
List<RecipeCategory> searchCategories(String query) {
  final queryLower = query.toLowerCase();
  return recipeCategories.where((cat) {
    return cat.id.toLowerCase().contains(queryLower) ||
           cat.nameKey.toLowerCase().contains(queryLower) ||
           cat.keywords.any((k) => k.toLowerCase().contains(queryLower));
  }).toList();
}

import 'package:flutter/material.dart';

class QuickFilter {
  final String id;
  final String label;
  final IconData icon;
  final FilterCategory category;

  const QuickFilter({
    required this.id,
    required this.label,
    required this.icon,
    required this.category,
  });
}

enum FilterCategory {
  popular,
  time,
  diet,
  mealType,
  difficulty,
  cuisine,
}

class AdvancedFilterOptions {
  final int? minTimeMinutes;
  final int? maxTimeMinutes;
  final Set<String> dietRestrictions;
  final Set<String> mealTypes;
  final String? difficulty;
  final Set<String> cuisineTypes;
  final int? minCalories;
  final int? maxCalories;
  final int? minServings;
  final int? maxServings;
  final List<String> includeIngredients;
  final List<String> excludeIngredients;
  final bool highProtein;
  final bool lowCalorie;
  final bool highFiber;

  const AdvancedFilterOptions({
    this.minTimeMinutes,
    this.maxTimeMinutes,
    this.dietRestrictions = const {},
    this.mealTypes = const {},
    this.difficulty,
    this.cuisineTypes = const {},
    this.minCalories,
    this.maxCalories,
    this.minServings,
    this.maxServings,
    this.includeIngredients = const [],
    this.excludeIngredients = const [],
    this.highProtein = false,
    this.lowCalorie = false,
    this.highFiber = false,
  });

  AdvancedFilterOptions copyWith({
    int? minTimeMinutes,
    int? maxTimeMinutes,
    Set<String>? dietRestrictions,
    Set<String>? mealTypes,
    String? difficulty,
    Set<String>? cuisineTypes,
    int? minCalories,
    int? maxCalories,
    int? minServings,
    int? maxServings,
    List<String>? includeIngredients,
    List<String>? excludeIngredients,
    bool? highProtein,
    bool? lowCalorie,
    bool? highFiber,
  }) {
    return AdvancedFilterOptions(
      minTimeMinutes: minTimeMinutes ?? this.minTimeMinutes,
      maxTimeMinutes: maxTimeMinutes ?? this.maxTimeMinutes,
      dietRestrictions: dietRestrictions ?? this.dietRestrictions,
      mealTypes: mealTypes ?? this.mealTypes,
      difficulty: difficulty ?? this.difficulty,
      cuisineTypes: cuisineTypes ?? this.cuisineTypes,
      minCalories: minCalories ?? this.minCalories,
      maxCalories: maxCalories ?? this.maxCalories,
      minServings: minServings ?? this.minServings,
      maxServings: maxServings ?? this.maxServings,
      includeIngredients: includeIngredients ?? this.includeIngredients,
      excludeIngredients: excludeIngredients ?? this.excludeIngredients,
      highProtein: highProtein ?? this.highProtein,
      lowCalorie: lowCalorie ?? this.lowCalorie,
      highFiber: highFiber ?? this.highFiber,
    );
  }

  bool get hasActiveFilters {
    return minTimeMinutes != null ||
        maxTimeMinutes != null ||
        dietRestrictions.isNotEmpty ||
        mealTypes.isNotEmpty ||
        difficulty != null ||
        cuisineTypes.isNotEmpty ||
        minCalories != null ||
        maxCalories != null ||
        minServings != null ||
        maxServings != null ||
        includeIngredients.isNotEmpty ||
        excludeIngredients.isNotEmpty ||
        highProtein ||
        lowCalorie ||
        highFiber;
  }
}

// Predefined quick filters
class QuickFilters {
  static const List<QuickFilter> all = [
    // Popular
    QuickFilter(
      id: 'top-rated',
      label: 'Top Rated',
      icon: Icons.star_rounded,
      category: FilterCategory.popular,
    ),
    
    // Time
    QuickFilter(
      id: 'quick',
      label: 'Quick (<15min)',
      icon: Icons.bolt_rounded,
      category: FilterCategory.time,
    ),
    QuickFilter(
      id: '30min',
      label: '30 Minutes',
      icon: Icons.schedule_rounded,
      category: FilterCategory.time,
    ),
    QuickFilter(
      id: 'under-hour',
      label: 'Under 1 Hour',
      icon: Icons.access_time_rounded,
      category: FilterCategory.time,
    ),
    
    // Diet
    QuickFilter(
      id: 'my-diet',
      label: 'My Diet',
      icon: Icons.person_rounded,
      category: FilterCategory.diet,
    ),
    QuickFilter(
      id: 'vegetarian',
      label: 'Vegetarian',
      icon: Icons.eco_rounded,
      category: FilterCategory.diet,
    ),
    QuickFilter(
      id: 'vegan',
      label: 'Vegan',
      icon: Icons.spa_rounded,
      category: FilterCategory.diet,
    ),
    QuickFilter(
      id: 'gluten-free',
      label: 'Gluten-Free',
      icon: Icons.grain_rounded,
      category: FilterCategory.diet,
    ),
    QuickFilter(
      id: 'keto',
      label: 'Keto',
      icon: Icons.fitness_center_rounded,
      category: FilterCategory.diet,
    ),
    QuickFilter(
      id: 'low-carb',
      label: 'Low-Carb',
      icon: Icons.trending_down_rounded,
      category: FilterCategory.diet,
    ),
    
    // Meal Type
    QuickFilter(
      id: 'breakfast',
      label: 'Breakfast',
      icon: Icons.free_breakfast_rounded,
      category: FilterCategory.mealType,
    ),
    QuickFilter(
      id: 'lunch',
      label: 'Lunch',
      icon: Icons.lunch_dining_rounded,
      category: FilterCategory.mealType,
    ),
    QuickFilter(
      id: 'dinner',
      label: 'Dinner',
      icon: Icons.dinner_dining_rounded,
      category: FilterCategory.mealType,
    ),
    QuickFilter(
      id: 'snack',
      label: 'Snack',
      icon: Icons.cookie_rounded,
      category: FilterCategory.mealType,
    ),
    
    // Difficulty
    QuickFilter(
      id: 'easy',
      label: 'Easy',
      icon: Icons.sentiment_satisfied_rounded,
      category: FilterCategory.difficulty,
    ),
    QuickFilter(
      id: 'medium',
      label: 'Medium',
      icon: Icons.sentiment_neutral_rounded,
      category: FilterCategory.difficulty,
    ),
    QuickFilter(
      id: 'advanced',
      label: 'Advanced',
      icon: Icons.psychology_rounded,
      category: FilterCategory.difficulty,
    ),
    
    // Cuisine
    QuickFilter(
      id: 'italian',
      label: 'Italian',
      icon: Icons.local_pizza_rounded,
      category: FilterCategory.cuisine,
    ),
    QuickFilter(
      id: 'asian',
      label: 'Asian',
      icon: Icons.ramen_dining_rounded,
      category: FilterCategory.cuisine,
    ),
    QuickFilter(
      id: 'mexican',
      label: 'Mexican',
      icon: Icons.lunch_dining_rounded,
      category: FilterCategory.cuisine,
    ),
    QuickFilter(
      id: 'mediterranean',
      label: 'Mediterranean',
      icon: Icons.set_meal_rounded,
      category: FilterCategory.cuisine,
    ),
  ];
}

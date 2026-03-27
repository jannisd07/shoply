import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Achievement badge definition
class AchievementDefinition extends Equatable {
  final String id;
  final String name;
  final String description;
  final String icon;
  final Color color;
  final String category;
  final String requirementType;
  final int requirementValue;
  final int points;
  final int sortOrder;

  const AchievementDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    this.color = const Color(0xFFFFD700),
    this.category = 'general',
    required this.requirementType,
    required this.requirementValue,
    this.points = 10,
    this.sortOrder = 0,
  });

  factory AchievementDefinition.fromJson(Map<String, dynamic> json) {
    return AchievementDefinition(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      icon: json['icon'] as String,
      color: json['color'] != null 
          ? Color(int.parse((json['color'] as String).replaceFirst('#', '0xFF')))
          : const Color(0xFFFFD700),
      category: json['category'] as String? ?? 'general',
      requirementType: json['requirement_type'] as String,
      requirementValue: json['requirement_value'] as int,
      points: json['points'] as int? ?? 10,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [id, name, requirementType, requirementValue];
}

/// User's unlocked achievement
class UserAchievement extends Equatable {
  final String id;
  final String oderId;
  final String achievementId;
  final DateTime unlockedAt;
  final AchievementDefinition? definition;

  const UserAchievement({
    required this.id,
    required this.oderId,
    required this.achievementId,
    required this.unlockedAt,
    this.definition,
  });

  factory UserAchievement.fromJson(Map<String, dynamic> json, {AchievementDefinition? definition}) {
    return UserAchievement(
      id: json['id'] as String,
      oderId: json['user_id'] as String,
      achievementId: json['achievement_id'] as String,
      unlockedAt: DateTime.parse(json['unlocked_at'] as String),
      definition: definition,
    );
  }

  @override
  List<Object?> get props => [id, achievementId];
}

/// User statistics for achievements
class UserStats extends Equatable {
  final String userId;
  final int recipesCooked;
  final int recipesSaved;
  final int recipesCreated;
  final int recipesRated;
  final int followersCount;
  final int followingCount;
  final int totalPoints;
  final int streakDays;
  final DateTime? lastActivityDate;

  const UserStats({
    required this.userId,
    this.recipesCooked = 0,
    this.recipesSaved = 0,
    this.recipesCreated = 0,
    this.recipesRated = 0,
    this.followersCount = 0,
    this.followingCount = 0,
    this.totalPoints = 0,
    this.streakDays = 0,
    this.lastActivityDate,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      userId: json['user_id'] as String,
      recipesCooked: json['recipes_cooked'] as int? ?? 0,
      recipesSaved: json['recipes_saved'] as int? ?? 0,
      recipesCreated: json['recipes_created'] as int? ?? 0,
      recipesRated: json['recipes_rated'] as int? ?? 0,
      followersCount: json['followers_count'] as int? ?? 0,
      followingCount: json['following_count'] as int? ?? 0,
      totalPoints: json['total_points'] as int? ?? 0,
      streakDays: json['streak_days'] as int? ?? 0,
      lastActivityDate: json['last_activity_date'] != null 
          ? DateTime.parse(json['last_activity_date'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'recipes_cooked': recipesCooked,
      'recipes_saved': recipesSaved,
      'recipes_created': recipesCreated,
      'recipes_rated': recipesRated,
      'followers_count': followersCount,
      'following_count': followingCount,
      'total_points': totalPoints,
      'streak_days': streakDays,
      'last_activity_date': lastActivityDate?.toIso8601String(),
    };
  }

  /// Get the value for a specific requirement type
  int getValueForType(String type) {
    switch (type) {
      case 'recipes_cooked': return recipesCooked;
      case 'recipes_saved': return recipesSaved;
      case 'recipes_created': return recipesCreated;
      case 'recipes_rated': return recipesRated;
      case 'followers_count': return followersCount;
      case 'following_count': return followingCount;
      default: return 0;
    }
  }

  @override
  List<Object?> get props => [userId, recipesCooked, recipesSaved, recipesCreated];
}

/// Nutrition information for a recipe
class NutritionInfo extends Equatable {
  final int calories;
  final int protein;  // grams
  final int carbs;    // grams
  final int fat;      // grams
  final int? fiber;   // grams
  final int? sugar;   // grams
  final int? sodium;  // mg

  const NutritionInfo({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fiber,
    this.sugar,
    this.sodium,
  });

  factory NutritionInfo.fromJson(Map<String, dynamic> json) {
    return NutritionInfo(
      calories: json['calories'] as int? ?? 0,
      protein: json['protein'] as int? ?? 0,
      carbs: json['carbs'] as int? ?? 0,
      fat: json['fat'] as int? ?? 0,
      fiber: json['fiber'] as int?,
      sugar: json['sugar'] as int?,
      sodium: json['sodium'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      if (fiber != null) 'fiber': fiber,
      if (sugar != null) 'sugar': sugar,
      if (sodium != null) 'sodium': sodium,
    };
  }

  @override
  List<Object?> get props => [calories, protein, carbs, fat];
}

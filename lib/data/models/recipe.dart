import 'package:equatable/equatable.dart';
import 'package:shoply/data/models/nutrition_info.dart';

class Recipe extends Equatable {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final int prepTimeMinutes;
  final int cookTimeMinutes;
  final int defaultServings;
  final List<Ingredient> ingredients;
  final List<String> instructions;
  final String authorId;
  final String authorName;
  final String? authorAvatarUrl;
  final DateTime createdAt;
  final double averageRating; // 0.0 to 5.0
  final int ratingCount;
  final int? userRating; // User's own rating (1-5), null if not rated
  final int viewCount; // Number of times recipe was viewed
  final List<String> labels; // ML-generated labels for filtering (diet, meal type, cuisine, etc.)
  final String language; // 'en' or 'de' - auto-detected from recipe content
  final NutritionInfo? nutrition; // Nutrition info per serving

  const Recipe({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.prepTimeMinutes,
    required this.cookTimeMinutes,
    required this.defaultServings,
    required this.ingredients,
    required this.instructions,
    required this.authorId,
    required this.authorName,
    this.authorAvatarUrl,
    required this.createdAt,
    this.averageRating = 0.0,
    this.ratingCount = 0,
    this.userRating,
    this.viewCount = 0,
    this.labels = const [],
    this.language = 'de', // Default to German for backward compatibility
    this.nutrition,
  });

  int get totalTimeMinutes => prepTimeMinutes + cookTimeMinutes;

  Recipe copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    int? prepTimeMinutes,
    int? cookTimeMinutes,
    int? defaultServings,
    List<Ingredient>? ingredients,
    List<String>? instructions,
    String? authorId,
    String? authorName,
    String? authorAvatarUrl,
    DateTime? createdAt,
    double? averageRating,
    int? ratingCount,
    int? userRating,
    int? viewCount,
    List<String>? labels,
    String? language,
    NutritionInfo? nutrition,
  }) {
    return Recipe(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      prepTimeMinutes: prepTimeMinutes ?? this.prepTimeMinutes,
      cookTimeMinutes: cookTimeMinutes ?? this.cookTimeMinutes,
      defaultServings: defaultServings ?? this.defaultServings,
      ingredients: ingredients ?? this.ingredients,
      instructions: instructions ?? this.instructions,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      createdAt: createdAt ?? this.createdAt,
      averageRating: averageRating ?? this.averageRating,
      ratingCount: ratingCount ?? this.ratingCount,
      userRating: userRating ?? this.userRating,
      viewCount: viewCount ?? this.viewCount,
      labels: labels ?? this.labels,
      language: language ?? this.language,
      nutrition: nutrition ?? this.nutrition,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'prep_time_minutes': prepTimeMinutes,
      'cook_time_minutes': cookTimeMinutes,
      'default_servings': defaultServings,
      'ingredients': ingredients.map((i) => i.toJson()).toList(),
      'instructions': instructions,
      'author_id': authorId,
      'author_name': authorName,
      'author_avatar_url': authorAvatarUrl,
      'created_at': createdAt.toIso8601String(),
      'average_rating': averageRating,
      'rating_count': ratingCount,
      'view_count': viewCount,
      'labels': labels,
      'language': language,
      'nutrition': nutrition?.toJson(),
    };
  }

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      imageUrl: json['image_url'] as String,
      prepTimeMinutes: json['prep_time_minutes'] as int,
      cookTimeMinutes: json['cook_time_minutes'] as int,
      defaultServings: json['default_servings'] as int,
      ingredients: (json['ingredients'] as List)
          .map((i) => Ingredient.fromJson(i as Map<String, dynamic>))
          .toList(),
      instructions: List<String>.from(json['instructions'] as List),
      authorId: json['author_id'] as String,
      authorName: json['author_name'] as String,
      authorAvatarUrl: json['author_avatar_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: json['rating_count'] as int? ?? 0,
      userRating: json['user_rating'] as int?,
      viewCount: json['view_count'] as int? ?? 0,
      labels: json['labels'] != null ? List<String>.from(json['labels'] as List) : [],
      language: json['language'] as String? ?? 'de', // Default to German for backward compatibility
      nutrition: json['nutrition'] != null 
          ? NutritionInfo.fromJson(json['nutrition'] as Map<String, dynamic>)
          : null,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        imageUrl,
        prepTimeMinutes,
        cookTimeMinutes,
        defaultServings,
        ingredients,
        instructions,
        authorId,
        authorName,
        authorAvatarUrl,
        createdAt,
        averageRating,
        ratingCount,
        userRating,
        viewCount,
        labels,
        language,
        nutrition,
      ];
}

class Ingredient extends Equatable {
  final String name;
  final double amount;
  final String unit;

  const Ingredient({
    required this.name,
    required this.amount,
    required this.unit,
  });

  Ingredient adjustForServings(int originalServings, int newServings) {
    final multiplier = newServings / originalServings;
    return Ingredient(
      name: name,
      amount: amount * multiplier,
      unit: unit,
    );
  }

  String get displayText {
    // Format amount nicely
    String formattedAmount;
    if (amount == amount.toInt()) {
      formattedAmount = amount.toInt().toString();
    } else {
      formattedAmount = amount.toStringAsFixed(1);
    }
    
    return '$formattedAmount $unit $name';
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'amount': amount,
      'unit': unit,
    };
  }

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      name: json['name'] as String,
      amount: (json['amount'] as num).toDouble(),
      unit: json['unit'] as String,
    );
  }

  @override
  List<Object?> get props => [name, amount, unit];
}

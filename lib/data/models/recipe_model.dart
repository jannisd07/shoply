import 'package:equatable/equatable.dart';

class RecipeModel extends Equatable {
  final String id;
  final String title;
  final String? description;
  final String? imageUrl;
  final int? prepTime;
  final int? cookTime;
  final int servings;
  final String? difficulty;
  final List<String> dietTags;
  final List<RecipeIngredient> ingredients;
  final List<RecipeInstruction> instructions;
  final RecipeNutrition? nutrition;
  final String? sourceType;
  final String? sourceUrl;
  final String? createdBy;
  final bool isPublic;
  final DateTime createdAt;
  final bool isFavorite;

  const RecipeModel({
    required this.id,
    required this.title,
    this.description,
    this.imageUrl,
    this.prepTime,
    this.cookTime,
    this.servings = 4,
    this.difficulty,
    this.dietTags = const [],
    required this.ingredients,
    required this.instructions,
    this.nutrition,
    this.sourceType,
    this.sourceUrl,
    this.createdBy,
    this.isPublic = true,
    required this.createdAt,
    this.isFavorite = false,
  });

  factory RecipeModel.fromJson(Map<String, dynamic> json) {
    return RecipeModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      prepTime: json['prep_time'] as int?,
      cookTime: json['cook_time'] as int?,
      servings: json['servings'] as int? ?? 4,
      difficulty: json['difficulty'] as String?,
      dietTags: json['diet_tags'] != null
          ? List<String>.from(json['diet_tags'] as List)
          : [],
      ingredients: (json['ingredients'] as List)
          .map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
          .toList(),
      instructions: (json['instructions'] as List)
          .map((e) => RecipeInstruction.fromJson(e as Map<String, dynamic>))
          .toList(),
      nutrition: json['nutrition'] != null
          ? RecipeNutrition.fromJson(json['nutrition'] as Map<String, dynamic>)
          : null,
      sourceType: json['source_type'] as String?,
      sourceUrl: json['source_url'] as String?,
      createdBy: json['created_by'] as String?,
      isPublic: json['is_public'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      isFavorite: json['is_favorite'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'prep_time': prepTime,
      'cook_time': cookTime,
      'servings': servings,
      'difficulty': difficulty,
      'diet_tags': dietTags,
      'ingredients': ingredients.map((e) => e.toJson()).toList(),
      'instructions': instructions.map((e) => e.toJson()).toList(),
      'nutrition': nutrition?.toJson(),
      'source_type': sourceType,
      'source_url': sourceUrl,
      'created_by': createdBy,
      'is_public': isPublic,
      'created_at': createdAt.toIso8601String(),
    };
  }

  int get totalTime => (prepTime ?? 0) + (cookTime ?? 0);

  RecipeModel copyWith({
    String? id,
    String? title,
    String? description,
    String? imageUrl,
    int? prepTime,
    int? cookTime,
    int? servings,
    String? difficulty,
    List<String>? dietTags,
    List<RecipeIngredient>? ingredients,
    List<RecipeInstruction>? instructions,
    RecipeNutrition? nutrition,
    String? sourceType,
    String? sourceUrl,
    String? createdBy,
    bool? isPublic,
    DateTime? createdAt,
    bool? isFavorite,
  }) {
    return RecipeModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      prepTime: prepTime ?? this.prepTime,
      cookTime: cookTime ?? this.cookTime,
      servings: servings ?? this.servings,
      difficulty: difficulty ?? this.difficulty,
      dietTags: dietTags ?? this.dietTags,
      ingredients: ingredients ?? this.ingredients,
      instructions: instructions ?? this.instructions,
      nutrition: nutrition ?? this.nutrition,
      sourceType: sourceType ?? this.sourceType,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      createdBy: createdBy ?? this.createdBy,
      isPublic: isPublic ?? this.isPublic,
      createdAt: createdAt ?? this.createdAt,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        imageUrl,
        prepTime,
        cookTime,
        servings,
        difficulty,
        dietTags,
        ingredients,
        instructions,
        nutrition,
        sourceType,
        sourceUrl,
        createdBy,
        isPublic,
        createdAt,
        isFavorite,
      ];
}

class RecipeIngredient extends Equatable {
  final String name;
  final double quantity;
  final String unit;

  const RecipeIngredient({
    required this.name,
    required this.quantity,
    required this.unit,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      name: json['name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
    };
  }

  RecipeIngredient scale(double factor) {
    return RecipeIngredient(
      name: name,
      quantity: quantity * factor,
      unit: unit,
    );
  }

  @override
  List<Object?> get props => [name, quantity, unit];
}

class RecipeInstruction extends Equatable {
  final int step;
  final String text;

  const RecipeInstruction({
    required this.step,
    required this.text,
  });

  factory RecipeInstruction.fromJson(Map<String, dynamic> json) {
    return RecipeInstruction(
      step: json['step'] as int,
      text: json['text'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'step': step,
      'text': text,
    };
  }

  @override
  List<Object?> get props => [step, text];
}

class RecipeNutrition extends Equatable {
  final int? calories;
  final int? protein;
  final int? carbs;
  final int? fat;

  const RecipeNutrition({
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
  });

  factory RecipeNutrition.fromJson(Map<String, dynamic> json) {
    return RecipeNutrition(
      calories: json['calories'] as int?,
      protein: json['protein'] as int?,
      carbs: json['carbs'] as int?,
      fat: json['fat'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
    };
  }

  @override
  List<Object?> get props => [calories, protein, carbs, fat];
}

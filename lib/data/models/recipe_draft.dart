import 'dart:convert';

/// Model for a recipe draft that can be saved locally before publishing
class RecipeDraft {
  final String id;
  final String name;
  final String description;
  final String? localImagePath;
  final int? prepTimeMinutes;
  final int? cookTimeMinutes;
  final int? defaultServings;
  final List<DraftIngredient> ingredients;
  final List<String> instructions;
  final DateTime createdAt;
  final DateTime updatedAt;

  RecipeDraft({
    required this.id,
    required this.name,
    required this.description,
    this.localImagePath,
    this.prepTimeMinutes,
    this.cookTimeMinutes,
    this.defaultServings,
    required this.ingredients,
    required this.instructions,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Check if draft has minimum data for saving
  bool get hasMinimumData {
    return name.trim().isNotEmpty || 
           description.trim().isNotEmpty || 
           ingredients.any((i) => i.name.isNotEmpty) ||
           instructions.any((i) => i.isNotEmpty);
  }

  /// Check if draft is complete and ready for publishing
  bool get isComplete {
    return name.trim().isNotEmpty &&
           description.trim().isNotEmpty &&
           localImagePath != null &&
           prepTimeMinutes != null &&
           cookTimeMinutes != null &&
           defaultServings != null &&
           ingredients.isNotEmpty &&
           ingredients.every((i) => i.name.isNotEmpty && i.amount.isNotEmpty && i.unit.isNotEmpty) &&
           instructions.isNotEmpty &&
           instructions.any((i) => i.isNotEmpty);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'localImagePath': localImagePath,
      'prepTimeMinutes': prepTimeMinutes,
      'cookTimeMinutes': cookTimeMinutes,
      'defaultServings': defaultServings,
      'ingredients': ingredients.map((i) => i.toJson()).toList(),
      'instructions': instructions,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory RecipeDraft.fromJson(Map<String, dynamic> json) {
    return RecipeDraft(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      localImagePath: json['localImagePath'] as String?,
      prepTimeMinutes: json['prepTimeMinutes'] as int?,
      cookTimeMinutes: json['cookTimeMinutes'] as int?,
      defaultServings: json['defaultServings'] as int?,
      ingredients: (json['ingredients'] as List<dynamic>?)
          ?.map((i) => DraftIngredient.fromJson(i as Map<String, dynamic>))
          .toList() ?? [],
      instructions: (json['instructions'] as List<dynamic>?)
          ?.map((i) => i as String)
          .toList() ?? [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  RecipeDraft copyWith({
    String? id,
    String? name,
    String? description,
    String? localImagePath,
    int? prepTimeMinutes,
    int? cookTimeMinutes,
    int? defaultServings,
    List<DraftIngredient>? ingredients,
    List<String>? instructions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RecipeDraft(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      localImagePath: localImagePath ?? this.localImagePath,
      prepTimeMinutes: prepTimeMinutes ?? this.prepTimeMinutes,
      cookTimeMinutes: cookTimeMinutes ?? this.cookTimeMinutes,
      defaultServings: defaultServings ?? this.defaultServings,
      ingredients: ingredients ?? this.ingredients,
      instructions: instructions ?? this.instructions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class DraftIngredient {
  final String name;
  final String amount;
  final String unit;

  DraftIngredient({
    required this.name,
    required this.amount,
    required this.unit,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'amount': amount,
      'unit': unit,
    };
  }

  factory DraftIngredient.fromJson(Map<String, dynamic> json) {
    return DraftIngredient(
      name: json['name'] as String? ?? '',
      amount: json['amount'] as String? ?? '',
      unit: json['unit'] as String? ?? '',
    );
  }
}

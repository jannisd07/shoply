import 'package:equatable/equatable.dart';
import 'package:shoply/data/models/recipe.dart';

/// A user-submitted modification to a recipe
class RecipeVariation extends Equatable {
  final String id;
  final String originalRecipeId;
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final String title;
  final String? description;
  final List<VariationChange> changes;
  final List<Ingredient>? modifiedIngredients;
  final List<String>? modifiedInstructions;
  final int upvotes;
  final bool? userVoted;  // true = upvoted, false = downvoted, null = not voted
  final DateTime createdAt;

  const RecipeVariation({
    required this.id,
    required this.originalRecipeId,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    required this.title,
    this.description,
    this.changes = const [],
    this.modifiedIngredients,
    this.modifiedInstructions,
    this.upvotes = 0,
    this.userVoted,
    required this.createdAt,
  });

  factory RecipeVariation.fromJson(Map<String, dynamic> json) {
    return RecipeVariation(
      id: json['id'] as String,
      originalRecipeId: json['original_recipe_id'] as String,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String? ?? 'Anonymous',
      userAvatarUrl: json['user_avatar_url'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      changes: json['changes'] != null
          ? (json['changes'] as List).map((c) => VariationChange.fromJson(c)).toList()
          : [],
      modifiedIngredients: json['modified_ingredients'] != null
          ? (json['modified_ingredients'] as List).map((i) => Ingredient.fromJson(i)).toList()
          : null,
      modifiedInstructions: json['modified_instructions'] != null
          ? List<String>.from(json['modified_instructions'] as List)
          : null,
      upvotes: json['upvotes'] as int? ?? 0,
      userVoted: json['user_voted'] as bool?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'original_recipe_id': originalRecipeId,
      'user_id': userId,
      'title': title,
      'description': description,
      'changes': changes.map((c) => c.toJson()).toList(),
      'modified_ingredients': modifiedIngredients?.map((i) => i.toJson()).toList(),
      'modified_instructions': modifiedInstructions,
    };
  }

  @override
  List<Object?> get props => [id, originalRecipeId, title];
}

/// A single change in a recipe variation
class VariationChange extends Equatable {
  final String field;      // 'ingredient', 'instruction', 'time', etc.
  final String? original;
  final String? modified;
  final String? note;

  const VariationChange({
    required this.field,
    this.original,
    this.modified,
    this.note,
  });

  factory VariationChange.fromJson(Map<String, dynamic> json) {
    return VariationChange(
      field: json['field'] as String,
      original: json['original'] as String?,
      modified: json['modified'] as String?,
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'field': field,
      'original': original,
      'modified': modified,
      'note': note,
    };
  }

  @override
  List<Object?> get props => [field, original, modified];
}

/// Recipe comment data model
///
/// **AI: Required Imports**:
/// - No special imports needed - standalone model
///
/// **AI: Database Table**: recipe_comments
/// - id: UUID (primary key)
/// - recipe_id: UUID (foreign key to recipes)
/// - user_id: UUID (foreign key to auth.users)
/// - comment: TEXT (max 500 chars)
/// - created_at: TIMESTAMP
/// - updated_at: TIMESTAMP
///
/// **AI: Usage**:
/// ```dart
/// final comment = RecipeComment(
///   id: '123',
///   recipeId: '456',
///   userId: '789',
///   comment: 'Delicious recipe!',
///   createdAt: DateTime.now(),
/// );
/// ```

class RecipeComment {
  final String id;
  final String recipeId;
  final String userId;
  final String comment;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  // Optional fields from joined data
  final String? userName;
  final String? userProfilePicture;

  const RecipeComment({
    required this.id,
    required this.recipeId,
    required this.userId,
    required this.comment,
    required this.createdAt,
    this.updatedAt,
    this.userName,
    this.userProfilePicture,
  });

  /// Create from Supabase JSON
  factory RecipeComment.fromJson(Map<String, dynamic> json) {
    return RecipeComment(
      id: json['id'] as String,
      recipeId: json['recipe_id'] as String,
      userId: json['user_id'] as String,
      comment: json['comment'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : null,
      userName: json['users']?['display_name'] as String?,
      userProfilePicture: json['users']?['profile_picture_url'] as String?,
    );
  }

  /// Convert to Supabase JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'recipe_id': recipeId,
      'user_id': userId,
      'comment': comment,
      'created_at': createdAt.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  /// Create a copy with modified fields
  RecipeComment copyWith({
    String? id,
    String? recipeId,
    String? userId,
    String? comment,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userName,
    String? userProfilePicture,
  }) {
    return RecipeComment(
      id: id ?? this.id,
      recipeId: recipeId ?? this.recipeId,
      userId: userId ?? this.userId,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userName: userName ?? this.userName,
      userProfilePicture: userProfilePicture ?? this.userProfilePicture,
    );
  }
}

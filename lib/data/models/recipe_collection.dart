import 'package:equatable/equatable.dart';

/// A curated collection of recipes
class RecipeCollection extends Equatable {
  final String id;
  final String name;
  final String? nameDE;
  final String? description;
  final String? descriptionDE;
  final String? imageUrl;
  final String icon;
  final bool isFeatured;
  final int displayOrder;
  final List<String> recipeIds;
  final DateTime createdAt;

  const RecipeCollection({
    required this.id,
    required this.name,
    this.nameDE,
    this.description,
    this.descriptionDE,
    this.imageUrl,
    this.icon = '📚',
    this.isFeatured = false,
    this.displayOrder = 0,
    this.recipeIds = const [],
    required this.createdAt,
  });

  /// Get localized name based on language code
  String getLocalizedName(String languageCode) {
    if (languageCode == 'de' && nameDE != null) {
      return nameDE!;
    }
    return name;
  }

  /// Get localized description based on language code
  String? getLocalizedDescription(String languageCode) {
    if (languageCode == 'de' && descriptionDE != null) {
      return descriptionDE!;
    }
    return description;
  }

  factory RecipeCollection.fromJson(Map<String, dynamic> json) {
    return RecipeCollection(
      id: json['id'] as String,
      name: json['name'] as String,
      nameDE: json['name_de'] as String?,
      description: json['description'] as String?,
      descriptionDE: json['description_de'] as String?,
      imageUrl: json['image_url'] as String?,
      icon: json['icon'] as String? ?? '📚',
      isFeatured: json['is_featured'] as bool? ?? false,
      displayOrder: json['display_order'] as int? ?? 0,
      recipeIds: json['recipe_ids'] != null
          ? List<String>.from(json['recipe_ids'] as List)
          : [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'name_de': nameDE,
      'description': description,
      'description_de': descriptionDE,
      'image_url': imageUrl,
      'icon': icon,
      'is_featured': isFeatured,
      'display_order': displayOrder,
      'recipe_ids': recipeIds,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, name, nameDE, description, descriptionDE, imageUrl, icon, isFeatured, displayOrder, recipeIds];
}

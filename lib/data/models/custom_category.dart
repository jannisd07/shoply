import 'package:flutter/material.dart';

/// A custom category created by the user for a specific list.
///
/// Custom categories are stored on this device only (see
/// [CategoryOrderService]); their ids always start with `custom_`.
class CustomCategory {
  final String id;
  final String name;
  final Color color;

  const CustomCategory({
    required this.id,
    required this.name,
    required this.color,
  });

  static bool isCustomId(String categoryId) => categoryId.startsWith('custom_');

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color.toARGB32(),
      };

  factory CustomCategory.fromJson(Map<String, dynamic> json) => CustomCategory(
        id: json['id'] as String,
        name: json['name'] as String,
        color: Color(json['color'] as int),
      );
}

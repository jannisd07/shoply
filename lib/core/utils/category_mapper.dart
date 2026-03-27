import 'package:flutter/material.dart';
import 'package:shoply/data/models/product_category.dart';

/// Maps between ProductCategory enum and string category names
class CategoryMapper {
  /// Convert ProductCategory enum to display string
  static String toDisplayString(ProductCategory category) {
    return category.displayName;
  }

  /// Convert display string to ProductCategory enum
  static ProductCategory fromDisplayString(String displayName) {
    for (final category in ProductCategory.values) {
      if (category.displayName == displayName) {
        return category;
      }
    }
    return ProductCategory.fruitsVegetables; // Default fallback
  }

  /// Get category icon
  static IconData getIcon(ProductCategory category) {
    switch (category) {
      case ProductCategory.fruitsVegetables:
        return Icons.apple_rounded;
      case ProductCategory.meatFish:
        return Icons.set_meal_rounded;
      case ProductCategory.bakery:
        return Icons.bakery_dining_rounded;
      case ProductCategory.flowersPlants:
        return Icons.local_florist_rounded;
      case ProductCategory.dairy:
        return Icons.water_drop_rounded;
      case ProductCategory.frozen:
        return Icons.ac_unit_rounded;
      case ProductCategory.staples:
        return Icons.grain_rounded;
      case ProductCategory.canned:
        return Icons.inventory_2_rounded;
      case ProductCategory.spices:
        return Icons.grain_rounded;
      case ProductCategory.condiments:
        return Icons.inventory_2_rounded;
      case ProductCategory.breakfast:
        return Icons.cookie_rounded;
      case ProductCategory.sweets:
        return Icons.cookie_rounded;
      case ProductCategory.snacks:
        return Icons.cookie_rounded;
      case ProductCategory.beverages:
        return Icons.local_cafe_rounded;
      case ProductCategory.household:
        return Icons.home_rounded;
      case ProductCategory.cleaning:
        return Icons.cleaning_services_rounded;
      case ProductCategory.paper:
        return Icons.note_rounded;
      case ProductCategory.drugstore:
        return Icons.medical_services_rounded;
      case ProductCategory.bodycare:
        return Icons.spa_rounded;
      case ProductCategory.cosmetics:
        return Icons.face_rounded;
      case ProductCategory.hygiene:
        return Icons.clean_hands_rounded;
      case ProductCategory.baby:
        return Icons.child_care_rounded;
      case ProductCategory.petSupplies:
        return Icons.pets_rounded;
      case ProductCategory.nonFood:
        return Icons.inventory_rounded;
      case ProductCategory.appliances:
        return Icons.electrical_services_rounded;
      case ProductCategory.stationery:
        return Icons.edit_rounded;
      case ProductCategory.textiles:
        return Icons.checkroom_rounded;
      case ProductCategory.toys:
        return Icons.toys_rounded;
      case ProductCategory.seasonal:
        return Icons.celebration_rounded;
      case ProductCategory.checkout:
        return Icons.shopping_cart_rounded;
      case ProductCategory.householdDrugstore:
        return Icons.cleaning_services_rounded;
    }
  }

  /// Get all category names as strings
  static List<String> getAllCategoryNames() {
    return ProductCategory.values
        .map((category) => category.displayName)
        .toList();
  }
}

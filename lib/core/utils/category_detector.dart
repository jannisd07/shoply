import 'package:shoply/data/services/smart_categorization_service.dart';

class CategoryDetector {
  /// Detects the category of an item based on its name via
  /// [SmartCategorizationService] (learned user preferences, product
  /// knowledge base, keyword fallback).
  static Future<String> detectCategory(String itemName) async {
    if (itemName.isEmpty) return 'Grundnahrungsmittel';

    final result = await SmartCategorizationService.instance.classify(itemName);

    // Return the display name of the detected category
    return result.category.displayName;
  }

  /// Record when user manually changes a category
  /// This helps the system learn user preferences
  static Future<void> recordUserCategoryChange(
    String itemName,
    String category,
  ) async {
    await SmartCategorizationService.instance
        .recordUserCategoryChange(itemName, category);
  }
}

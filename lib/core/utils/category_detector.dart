import 'package:shoply/data/services/smart_categorization_service.dart';

class CategoryDetector {
  /// Learns that the user moved [itemName] into [category] (a category id or
  /// the shown name of a built-in category), so the next "add" of the same
  /// product lands there right away.
  static Future<void> recordUserCategoryChange(
    String itemName,
    String category,
  ) =>
      SmartCategorizationService.instance
          .recordUserCategoryChange(itemName, category);
}

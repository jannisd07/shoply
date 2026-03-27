import 'package:shoply/core/constants/categories.dart';

class DietChecker {
  /// Checks if an item conflicts with the user's diet preferences
  static bool checkDietWarning(String itemName, List<String> dietPreferences) {
    if (dietPreferences.isEmpty || 
        dietPreferences.contains('None / No restrictions')) {
      return false;
    }
    
    final normalizedName = itemName.toLowerCase().trim();
    
    for (final diet in dietPreferences) {
      final restrictions = Categories.dietRestrictions[diet];
      if (restrictions != null) {
        for (final restriction in restrictions) {
          if (normalizedName.contains(restriction.toLowerCase())) {
            return true;
          }
        }
      }
    }
    
    return false;
  }
  
  /// Gets a warning message for diet conflicts
  static String getDietWarningMessage(String itemName, List<String> dietPreferences) {
    final conflicts = <String>[];
    final normalizedName = itemName.toLowerCase().trim();
    
    for (final diet in dietPreferences) {
      final restrictions = Categories.dietRestrictions[diet];
      if (restrictions != null) {
        for (final restriction in restrictions) {
          if (normalizedName.contains(restriction.toLowerCase())) {
            conflicts.add(diet);
            break;
          }
        }
      }
    }
    
    if (conflicts.isEmpty) return '';
    
    return 'This item may not match your ${conflicts.join(', ')} diet preferences.';
  }
}

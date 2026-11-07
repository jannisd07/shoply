import 'package:shoply/core/constants/categories.dart';

class DietChecker {
  static final RegExp _nonLetters = RegExp(r'[^a-zäöüß]+');

  /// Checks if an item conflicts with the user's diet preferences.
  ///
  /// [dietPreferences] are the stored diet ids ('vegan', 'gluten_free', ...).
  /// Matching is per word: a word matches a restricted term when it equals
  /// it or, for terms of 4+ letters, starts with it ('Eier' matches 'eier',
  /// but 'Reis' or 'Eisbergsalat' do not match 'eis').
  static bool checkDietWarning(String itemName, List<String> dietPreferences) {
    if (dietPreferences.isEmpty) return false;

    final words = itemName
        .toLowerCase()
        .split(_nonLetters)
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return false;

    for (final diet in dietPreferences) {
      final restrictions = Categories.dietRestrictions[diet];
      if (restrictions == null) continue;
      for (final term in restrictions) {
        for (final word in words) {
          if (word == term || (term.length >= 4 && word.startsWith(term))) {
            return true;
          }
        }
      }
    }
    return false;
  }
}

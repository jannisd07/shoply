import 'package:shoply/data/models/dietary_preference.dart';
import 'package:shoply/data/models/user_model.dart';

/// Typed view of a user's stored diet/allergy strings.
///
/// Unknown values are skipped instead of being mapped to a default — an
/// unrecognised allergy string used to silently turn into "gluten".
extension UserDietX on UserModel {
  bool get hasDietProfile => allergies.isNotEmpty || dietPreferences.isNotEmpty;

  List<AllergyType> get allergyTypes {
    final byName = AllergyType.values.asNameMap();
    return allergies.map((a) => byName[a]).whereType<AllergyType>().toList();
  }

  List<DietType> get dietTypes {
    final byName = DietType.values.asNameMap();
    return dietPreferences.map((d) => byName[d]).whereType<DietType>().toList();
  }
}

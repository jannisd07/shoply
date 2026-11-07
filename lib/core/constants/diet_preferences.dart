/// Diet preference ids stored in `users.diet_preferences`. Shared by
/// onboarding and Profile → Diet preferences so both offer the same
/// taxonomy. Labels come from the `diet_<id>` / `diet_<id>_desc`
/// translation keys. An empty selection means "no restrictions".
const List<String> kDietPreferenceIds = [
  'vegetarian',
  'vegan',
  'gluten_free',
  'dairy_free',
  'pescatarian',
  'keto',
  'paleo',
  'low_carb',
  'halal',
  'kosher',
  'nut_free',
  'low_sodium',
];

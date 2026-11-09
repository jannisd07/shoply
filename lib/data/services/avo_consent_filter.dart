/// What a tool result may tell the model without the person's consents
/// (server contract `supabase/functions/_shared/avo_tools.ts`, W1b review
/// I3): without `consent_body` no totals, goals, earlier or target weights
/// and no age, gender, height or weight; without `consent_health` no
/// allergies or diet. The cards in the app still show everything; only the
/// tool result for the model is cut.
library;

/// Profile fields that are body data.
const Set<String> _bodyProfileFields = {
  'age',
  'gender',
  'height',
  'weight',
  'nutrition_goal',
};

/// Profile fields that are health data (diet and allergies).
const Set<String> _healthProfileFields = {'allergies', 'diet_preferences'};

/// Setting keys whose values are body or health data.
const Set<String> _bodySettings = {'age', 'gender', 'height_cm', 'height'};
const Set<String> _healthSettings = {
  'allergies_add',
  'allergies_remove',
  'diet_add',
  'diet_remove',
};

/// [result] of [tool] as the model may see it with the consents [health]
/// ("Ernährung und Allergien") and [body] ("Kalorien, Gewicht und Ziele").
Map<String, Object?> avoConsentFilter(
  String tool,
  Map<String, Object?> result, {
  required bool health,
  required bool body,
}) {
  if (health && body && !(tool == 'update_setting' && result['key'] == 'zip_code')) {
    return result;
  }
  final out = Map<String, Object?>.of(result);
  void drop(Iterable<String> keys) => keys.forEach(out.remove);
  switch (tool) {
    case 'log_water' when !body:
      drop(const ['total_today_ml', 'target_ml']);
    case 'log_weight' when !body:
      drop(const [
        'previous_weight_kg',
        'previous_logged_date',
        'target_weight_kg',
      ]);
    case 'log_food' when !body:
      drop(const ['consumed_today_calories', 'remaining_calories']);
    case 'get_user_profile':
      if (!body) drop(_bodyProfileFields);
      if (!health) drop(_healthProfileFields);
      out['not_shared'] = [
        if (!body) 'calories_weight_goals',
        if (!health) 'diet_and_allergies',
      ];
    case 'search_recipes' when !health:
      drop(const ['left_out_for_allergies']);
    case 'update_setting' when result['key'] == 'zip_code':
      // The postcode never goes to the model, only whether one is set
      // (contract, like get_user_profile).
      final value = result['new_value'];
      drop(const ['old_value', 'new_value']);
      out['postcode_set'] =
          value is String && value.isNotEmpty && value != 'none';
    case 'update_setting':
      final key = result['key'];
      final hidden =
          (!body && _bodySettings.contains(key)) ||
          (!health && _healthSettings.contains(key));
      if (hidden) drop(const ['old_value', 'new_value']);
  }
  return out;
}

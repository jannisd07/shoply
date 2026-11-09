// Tool results without the consents (server contract avo_tools.ts:53-58,
// W1b review I3): no body data without consent_body, no allergy or diet
// data without consent_health. One test per tool that carries such data.
import 'package:flutter_test/flutter_test.dart';

import 'package:shoply/data/services/avo_consent_filter.dart';

Map<String, Object?> _f(
  String tool,
  Map<String, Object?> r, {
  bool health = false,
  bool body = false,
}) => avoConsentFilter(tool, r, health: health, body: body);

void main() {
  test('log_water: no total or target without consent_body', () {
    final r = {
      'success': true,
      'added_ml': 250,
      'total_today_ml': 1250,
      'target_ml': 2000,
    };
    expect(_f('log_water', r), {'success': true, 'added_ml': 250});
    expect(_f('log_water', r, body: true), r);
  });

  test('log_weight: no earlier or target weight without consent_body', () {
    final r = {
      'success': true,
      'weight_kg': 78.4,
      'previous_weight_kg': 79.0,
      'previous_logged_date': '2026-11-01',
      'target_weight_kg': 75.0,
    };
    expect(_f('log_weight', r), {'success': true, 'weight_kg': 78.4});
    expect(_f('log_weight', r, body: true), r);
  });

  test('log_food: no day totals without consent_body', () {
    final r = {
      'saved': false,
      'calories': 650,
      'consumed_today_calories': 1800,
      'remaining_calories': 200,
    };
    expect(_f('log_food', r), {'saved': false, 'calories': 650});
  });

  test('get_user_profile: body and health fields only with their consent', () {
    final r = {
      'display_name': 'Jannis',
      'age': 31,
      'gender': 'male',
      'height': '180 cm',
      'nutrition_goal': {'daily_calorie_target': 2000},
      'allergies': ['Erdnüsse'],
      'diet_preferences': ['vegetarisch'],
      'postcode_set': true,
    };
    final none = _f('get_user_profile', r);
    expect(
      none.keys,
      containsAll(['display_name', 'postcode_set', 'not_shared']),
    );
    for (final k in [
      'age',
      'gender',
      'height',
      'nutrition_goal',
      'allergies',
      'diet_preferences',
    ]) {
      expect(none.containsKey(k), isFalse, reason: k);
    }
    final health = _f('get_user_profile', r, health: true);
    expect(health['allergies'], ['Erdnüsse']);
    expect(health.containsKey('age'), isFalse);
    final body = _f('get_user_profile', r, body: true);
    expect(body['age'], 31);
    expect(body.containsKey('allergies'), isFalse);
    expect(_f('get_user_profile', r, health: true, body: true), r);
  });

  test('search_recipes: whether allergens were left out only with '
      'consent_health', () {
    final r = {'found': 2, 'left_out_for_allergies': true};
    expect(_f('search_recipes', r), {'found': 2});
    expect(_f('search_recipes', r, health: true), r);
  });

  test('update_setting: allergy and diet values only with consent_health, '
      'age/height/gender only with consent_body', () {
    final allergy = {
      'success': true,
      'key': 'allergies_add',
      'old_value': 'Erdnüsse',
      'new_value': 'Erdnüsse, Milch',
    };
    expect(_f('update_setting', allergy), {
      'success': true,
      'key': 'allergies_add',
    });
    expect(_f('update_setting', allergy, health: true), allergy);
    final age = {
      'success': true,
      'key': 'age',
      'old_value': '30',
      'new_value': '31',
    };
    expect(_f('update_setting', age, health: true), {
      'success': true,
      'key': 'age',
    });
    final theme = {
      'success': true,
      'key': 'theme_mode',
      'old_value': 'Light',
      'new_value': 'Dark',
    };
    expect(_f('update_setting', theme), theme);
  });

  test('update_setting zip_code: never the postcode, only whether one is set '
      '(N6), also with every consent', () {
    final r = {
      'success': true,
      'key': 'zip_code',
      'display_name': 'Zip code',
      'old_value': '80331',
      'new_value': '10115',
    };
    for (final (h, b) in [(false, false), (true, true)]) {
      final out = _f('update_setting', r, health: h, body: b);
      expect(out.containsKey('old_value'), isFalse);
      expect(out.containsKey('new_value'), isFalse);
      expect(out['postcode_set'], isTrue);
    }
    expect(
      _f(
        'update_setting',
        {...r, 'new_value': 'none'},
        health: true,
        body: true,
      )['postcode_set'],
      isFalse,
    );
  });

  test('update_setting zip_code refused: postcode_set is what is stored, '
      'never the attempted value (M-e)', () {
    final refused = {
      'success': false,
      'key': 'zip_code',
      'display_name': 'Zip code',
      'new_value': '12',
      'error': 'Zip code must be 4-5 digits (or empty to clear it)',
    };
    for (final stored in [true, false]) {
      final out = _f(
        'update_setting',
        {...refused, 'postcode_set': stored},
        health: true,
        body: true,
      );
      expect(out['postcode_set'], stored);
      expect(out.containsKey('new_value'), isFalse);
    }
    // Without the tool's reading only a change that went through counts.
    expect(_f('update_setting', refused)['postcode_set'], isFalse);
  });

  test('other tools pass unchanged', () {
    final r = {'found': 3, 'lists': []};
    expect(_f('get_lists', r), r);
  });
}

// Card-less writes count as done, so "Erneut versuchen" never runs them
// twice (W1 re-review, round 2 point 4).
import 'package:flutter_test/flutter_test.dart';

import 'package:shoply/data/services/avo_assistant_models.dart';
import 'package:shoply/data/services/avo_tool_writes.dart';

void main() {
  test('recipe to list leaves a write marker with its list', () {
    final marker = avoWriteMarker(
      'add_recipe_to_list',
      {'added': 9},
      hadDoneCard: false,
      listName: 'Wocheneinkauf',
    )!;
    expect(marker.kind, AvoPayloadKind.wrote);
    expect(marker.wroteTool, 'add_recipe_to_list');
    expect(marker.wroteListName, 'Wocheneinkauf');
    expect(marker.isDoneChange, isTrue);
  });

  test('reads, failures, switched-off modules and carded writes: none', () {
    expect(avoWriteMarker('get_lists', const {}, hadDoneCard: false), isNull);
    expect(
      avoWriteMarker('add_recipe_to_list', {'error': 'x'}, hadDoneCard: false),
      isNull,
    );
    expect(
      avoWriteMarker('log_water', {
        'tracking_enabled': false,
      }, hadDoneCard: false),
      isNull,
    );
    expect(
      avoWriteMarker('add_item_to_list', const {}, hadDoneCard: true),
      isNull,
    );
  });

  test('every other writing tool counts', () {
    for (final tool in [
      'add_history_items_to_list',
      'plan_to_list',
      'add_to_plan',
      'move_in_plan',
      'log_food',
      'log_water',
      'log_weight',
      'log_workout',
      'set_module',
      'setup_nutrition_goal',
      'split_trip_cost',
    ]) {
      expect(
        avoWriteMarker(tool, const {}, hadDoneCard: false)?.isDoneChange,
        isTrue,
        reason: tool,
      );
    }
  });
}

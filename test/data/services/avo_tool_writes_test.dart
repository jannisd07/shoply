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

  test('nothing written: no marker; partly written: marker (round 3, N1)', () {
    // add_recipe_to_list when every ingredient failed.
    expect(
      avoWriteMarker('add_recipe_to_list', {
        'added': 0,
        'failed_items': ['Mehl'],
      }, hadDoneCard: false),
      isNull,
    );
    // add_history_items_to_list when nothing matched.
    expect(
      avoWriteMarker('add_history_items_to_list', {
        'added': 0,
      }, hadDoneCard: false),
      isNull,
    );
    // plan_to_list that failed.
    expect(
      avoWriteMarker('plan_to_list', {
        'success': false,
        'added': 0,
        'failed': ['x'],
      }, hadDoneCard: false),
      isNull,
    );
    // Partly written: a retry would double the written part.
    expect(
      avoWriteMarker('add_recipe_to_list', {
        'added': 3,
        'failed_items': ['Mehl'],
      }, hadDoneCard: false)?.isDoneChange,
      isTrue,
    );
  });

  group('avoNoteWrite (the wiring in _runToolCall)', () {
    Future<List<AvoWidgetPayload>> run(
      String tool,
      Map<String, Object?> result, {
      List<AvoWidgetPayload> fromTool = const [],
      Map<String, Object?> input = const {'list_id': 'w'},
    }) async {
      final payloads = <AvoWidgetPayload>[AvoWidgetPayload.lists(const [])];
      final before = payloads.length;
      payloads.addAll(fromTool);
      await avoNoteWrite(
        payloads,
        before: before,
        tool: tool,
        input: input,
        result: result,
        listName: (id) async => id == 'w' ? 'Wocheneinkauf' : '',
      );
      return payloads.skip(before).toList();
    }

    test('a card-less write gets a marker with its list', () async {
      final added = await run('add_recipe_to_list', {'added': 9});
      expect(added.single.wroteTool, 'add_recipe_to_list');
      expect(added.single.wroteListName, 'Wocheneinkauf');
    });

    test('a write that left a done card of its own gets none', () async {
      final card = AvoWidgetPayload.listChange(
        const AvoListChange(
          kind: AvoListChangeKind.added,
          listId: 'w',
          listName: 'Wocheneinkauf',
        ),
      );
      final added = await run(
        'add_item_to_list',
        {'success': true},
        fromTool: [card],
      );
      expect(added, [card]);
    });

    test('earlier cards of the answer do not count', () async {
      // The lists card was there before this tool ran.
      final added = await run('log_water', {'logged_ml': 250});
      expect(added.single.wroteTool, 'log_water');
    });

    test('reads and failed writes get none', () async {
      expect(await run('get_lists', const {}), isEmpty);
      expect(
        await run('plan_to_list', {'success': false, 'added': 0}),
        isEmpty,
      );
      expect(
        await run('add_history_items_to_list', {
          'error': 'History entry not found',
        }),
        isEmpty,
      );
    });
  });
}

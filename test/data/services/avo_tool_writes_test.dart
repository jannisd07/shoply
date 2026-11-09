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

  test('a partial plan_to_list keeps its marker (W1 re-review 3, Minor 1)', () {
    // plan_to_list reports success: false as soon as one line failed, with
    // the lines it did write in `added`.
    final marker = avoWriteMarker(
      'plan_to_list',
      {
        'success': false,
        'added': 5,
        'failed': ['Dill'],
      },
      hadDoneCard: false,
      listName: 'Wocheneinkauf',
    );
    expect(marker?.isDoneChange, isTrue);
    expect(marker?.wroteListName, 'Wocheneinkauf');
    // An error with some lines written is partial too.
    expect(
      avoWriteMarker('add_history_items_to_list', {
        'error': 'network',
        'added': 2,
      }, hadDoneCard: false)?.isDoneChange,
      isTrue,
    );
    // An error without anything written stays without one.
    expect(
      avoWriteMarker('plan_to_list', {
        'error': 'network',
      }, hadDoneCard: false),
      isNull,
    );
  });

  test('a card that asks first is no write yet (W1b): estimate, goal '
      'preview, planned day, missing goal fields', () {
    for (final (tool, result) in [
      ('log_food', <String, Object?>{'saved': false, 'shown_estimate': true}),
      ('setup_nutrition_goal', <String, Object?>{'requires_confirmation': true}),
      ('setup_nutrition_goal', <String, Object?>{'incomplete': true}),
      ('add_to_plan', <String, Object?>{'asked': true}),
      ('update_setting', <String, Object?>{
        'success': false,
        'requires_confirmation': true,
      }),
    ]) {
      expect(
        avoWriteMarker(tool, result, hadDoneCard: false),
        isNull,
        reason: '$tool $result',
      );
    }
  });

  test('a record is a done card: no extra marker', () async {
    final payloads = <AvoWidgetPayload>[];
    payloads.add(
      AvoWidgetPayload.record(
        const AvoWaterRecord(
          tool: 'log_water',
          amountMl: 250,
          totalMl: 500,
          targetMl: 2000,
        ),
      ),
    );
    await avoNoteWrite(
      payloads,
      before: 0,
      tool: 'log_water',
      input: const {},
      result: const {'success': true},
      listName: (_) async => '',
    );
    expect(payloads, hasLength(1));
    expect(payloads.single.isDoneChange, isTrue);
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

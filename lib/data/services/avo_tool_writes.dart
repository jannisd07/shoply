import 'package:shoply/data/services/avo_assistant_models.dart';

/// Tools that change the person's data. A retry of an answer that ran one of
/// them must not run it again (W1 review): the list tools leave a change
/// card, `update_setting` a setting card, the others an
/// [AvoPayloadKind.wrote] marker from [avoWriteMarker].
const Set<String> avoWritingTools = {
  'add_item_to_list',
  'check_items',
  'complete_list',
  'update_item',
  'move_items',
  'create_list',
  'rename_list',
  'add_recipe_to_list',
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
  'update_setting',
  'split_trip_cost',
};

/// The marker for a writing [tool] that succeeded without leaving a done
/// card ([hadDoneCard]); null for reads, failures and switched-off modules.
///
/// A tool that reports nothing written (`success: false`, `added: 0`, as
/// `add_recipe_to_list`, `add_history_items_to_list` and `plan_to_list` do
/// when every item failed) gets none: the retry must do it. A partial result
/// (`added > 0` with failures) keeps it, or a retry would double quantities.
AvoWidgetPayload? avoWriteMarker(
  String tool,
  Map<String, Object?> result, {
  required bool hadDoneCard,
  String? listName,
}) {
  if (!avoWritingTools.contains(tool) || hadDoneCard) return null;
  if (result['error'] != null ||
      result['not_available'] == true ||
      result['tracking_enabled'] == false ||
      result['success'] == false) {
    return null;
  }
  final added = result['added'];
  if (added is num && added <= 0) return null;
  return AvoWidgetPayload.wrote(
    tool,
    listName: listName == null || listName.isEmpty ? null : listName,
  );
}

/// After a tool ran: adds the [avoWriteMarker] for it to [payloads] when it
/// wrote without a done card of its own. [before] is the payload count before
/// the tool ran; [listName] resolves the `list_id`/`to_list_id` of [input].
Future<void> avoNoteWrite(
  List<AvoWidgetPayload> payloads, {
  required int before,
  required String tool,
  required Map<String, Object?> input,
  required Map<String, Object?> result,
  required Future<String> Function(String listId) listName,
}) async {
  if (!avoWritingTools.contains(tool)) return;
  final hadDoneCard = payloads.skip(before).any((p) => p.isDoneChange);
  if (hadDoneCard) return;
  final listId = input['list_id'] ?? input['to_list_id'];
  final marker = avoWriteMarker(
    tool,
    result,
    hadDoneCard: false,
    listName: listId is String ? await listName(listId) : null,
  );
  if (marker != null) payloads.add(marker);
}

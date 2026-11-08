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
AvoWidgetPayload? avoWriteMarker(
  String tool,
  Map<String, Object?> result, {
  required bool hadDoneCard,
  String? listName,
}) {
  if (!avoWritingTools.contains(tool) || hadDoneCard) return null;
  if (result['error'] != null ||
      result['not_available'] == true ||
      result['tracking_enabled'] == false) {
    return null;
  }
  return AvoWidgetPayload.wrote(
    tool,
    listName: listName == null || listName.isEmpty ? null : listName,
  );
}

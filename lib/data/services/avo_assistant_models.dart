import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/services/avo_settings_bridge.dart';
import 'package:shoply/data/services/avo_conversation.dart';
import 'package:shoply/data/services/avo_consents.dart';

// ════════════════════════════════════════════════════════════════════
// RESPONSE / PAYLOAD MODELS
// ════════════════════════════════════════════════════════════════════

class AvoResponse {
  final String message;
  final List<AvoWidgetPayload> payloads;
  final AvoExpressionType expression;

  /// Why the answer failed (server code such as `quota_exceeded`,
  /// `rate_limited`, `network_error`, `timeout`, `refused`, `unauthorized`,
  /// `ai_disabled`, or `generic`); null for an answer. The tab picks its
  /// error state from it, [message] is only the fallback text.
  final String? errorCode;

  /// Seconds until "Erneut versuchen" makes sense again (`rate_limited`).
  final int? retryAfterS;

  const AvoResponse({
    required this.message,
    this.payloads = const [],
    this.expression = AvoExpressionType.happy,
    this.errorCode,
    this.retryAfterS,
  });
}

/// What a change Avo made on a list was (Kap. 5.1 answer cards).
enum AvoListChangeKind {
  /// `add_item_to_list`: "1 hinzugefügt".
  added,

  /// `check_items` and `complete_list`: "2 abgehakt".
  checked,

  /// `check_items` with `checked: false`: opened again.
  unchecked,

  /// `update_item`: "Milch: Menge 3, vorher 2".
  updated,

  /// `move_items`: "2 verschoben aus Wocheneinkauf" (card on the target).
  moved,

  /// `create_list`: "Neue Liste".
  created,

  /// `rename_list`: "Umbenannt, vorher Party".
  renamed,
}

/// How taking back one of Avo's changes went.
enum AvoUndoResult {
  /// The change is taken back.
  undone,

  /// The data changed since (by the person or someone else): nothing was
  /// touched, "Widerrufen" goes away.
  changedSince,

  /// It could not be taken back (network, rights).
  failed,
}

/// A change Avo made on a list, with the way back.
class AvoListChange {
  const AvoListChange({
    required this.kind,
    required this.listId,
    required this.listName,
    this.items = const [],
    this.count = 0,
    this.fromListName,
    this.previousName,
    this.itemName,
    this.previousQuantity,
    this.newQuantity,
    this.undo,
    this.pendingOffline = false,
    this.failedCount = 0,
    this.retryFailed,
  });

  final AvoListChangeKind kind;

  /// The list the card is about (the target list of a move).
  final String listId;
  final String listName;

  /// The items as they are after the change (rows of the card).
  final List<ShoppingItemModel> items;

  /// How many items changed.
  final int count;

  /// [AvoListChangeKind.moved]: where the items came from.
  final String? fromListName;

  /// [AvoListChangeKind.renamed]: the old name.
  final String? previousName;

  /// [AvoListChangeKind.updated]: the item and its quantity before / after
  /// (null when the quantity did not change).
  final String? itemName;
  final double? previousQuantity;
  final double? newQuantity;

  /// Takes the change back if the data is unchanged since; null when it
  /// cannot be taken back.
  final Future<AvoUndoResult> Function()? undo;

  /// The change waits in the offline queue ("Wird gesendet, sobald du online
  /// bist"); it has no undo yet.
  final bool pendingOffline;

  /// Items that could not be changed ("2 Artikel nicht verschoben").
  final int failedCount;

  /// Tries the [failedCount] items again and returns the whole change after
  /// it (null when nothing could be done).
  final Future<AvoListChange?> Function()? retryFailed;
}

enum AvoExpressionType {
  happy,
  excited,
  thinking,
  confused,
  celebrating,
  waving,
}

/// Rich content the assistant wants rendered in the chat bubble.
/// The chat screen inspects [kind] and reads the matching fields.
enum AvoPayloadKind {
  recipes,
  listItems,
  lists,
  history,
  pickList,
  nutrition,
  settingChange,
  appInfo,
  confirmDelete,
  consentRequest,

  /// A change Avo made on a list ([AvoListChange]).
  listChange,

  /// A tool needed a module that is switched off ([AvoWidgetPayload.module]).
  moduleOff,
}

class AvoWidgetPayload {
  final AvoPayloadKind kind;
  final List<Recipe>? recipes;
  final List<ShoppingItemModel>? items;
  final String? listId;
  final String? listName;
  final List<ShoppingListModel>? lists;
  final List<ShoppingHistory>? history;
  final AvoPickListData? pickListData;
  final AvoNutritionData? nutrition;
  final SettingChangeResult? settingChange;
  final AvoAppInfoData? appInfo;
  final AvoPendingDelete? pendingDelete;
  final AvoConsentKind? consentKind;
  final AvoListChange? listChange;
  final AppModule? module;

  const AvoWidgetPayload._({
    required this.kind,
    this.recipes,
    this.items,
    this.listId,
    this.listName,
    this.lists,
    this.history,
    this.pickListData,
    this.nutrition,
    this.settingChange,
    this.appInfo,
    this.pendingDelete,
    this.consentKind,
    this.listChange,
    this.module,
  });

  /// A change on a list, shown as a result card with "Widerrufen".
  factory AvoWidgetPayload.listChange(AvoListChange change) =>
      AvoWidgetPayload._(kind: AvoPayloadKind.listChange, listChange: change);

  /// [module] is switched off; the card offers to switch it on.
  factory AvoWidgetPayload.moduleOff(AppModule module) =>
      AvoWidgetPayload._(kind: AvoPayloadKind.moduleOff, module: module);

  factory AvoWidgetPayload.recipes(List<Recipe> recipes) =>
      AvoWidgetPayload._(kind: AvoPayloadKind.recipes, recipes: recipes);

  factory AvoWidgetPayload.listItems({
    required String listId,
    required String listName,
    required List<ShoppingItemModel> items,
  }) => AvoWidgetPayload._(
    kind: AvoPayloadKind.listItems,
    listId: listId,
    listName: listName,
    items: items,
  );

  factory AvoWidgetPayload.lists(List<ShoppingListModel> lists) =>
      AvoWidgetPayload._(kind: AvoPayloadKind.lists, lists: lists);

  factory AvoWidgetPayload.history(List<ShoppingHistory> history) =>
      AvoWidgetPayload._(kind: AvoPayloadKind.history, history: history);

  factory AvoWidgetPayload.pickList({
    required String itemName,
    required double quantity,
    String? unit,
  }) => AvoWidgetPayload._(
    kind: AvoPayloadKind.pickList,
    pickListData: AvoPickListData(
      itemName: itemName,
      quantity: quantity,
      unit: unit,
    ),
  );

  factory AvoWidgetPayload.nutrition({
    required String recipeName,
    required int servings,
    int? calories,
    double? proteinG,
    double? carbsG,
    double? fatG,
    bool estimated = false,
  }) => AvoWidgetPayload._(
    kind: AvoPayloadKind.nutrition,
    nutrition: AvoNutritionData(
      recipeName: recipeName,
      servings: servings,
      calories: calories,
      proteinG: proteinG,
      carbsG: carbsG,
      fatG: fatG,
      estimated: estimated,
    ),
  );

  factory AvoWidgetPayload.settingChange(SettingChangeResult result) =>
      AvoWidgetPayload._(
        kind: AvoPayloadKind.settingChange,
        settingChange: result,
      );

  /// A deletion Avo proposed; only a tap on this card deletes.
  factory AvoWidgetPayload.confirmDelete(AvoPendingDelete pending) =>
      AvoWidgetPayload._(kind: AvoPayloadKind.confirmDelete, pendingDelete: pending);

  /// Asks to share data with Avo before a tool can use it.
  factory AvoWidgetPayload.consentRequest(AvoConsentKind kind) =>
      AvoWidgetPayload._(kind: AvoPayloadKind.consentRequest, consentKind: kind);

  factory AvoWidgetPayload.appInfo({
    required String topic,
    required String answer,
  }) => AvoWidgetPayload._(
    kind: AvoPayloadKind.appInfo,
    appInfo: AvoAppInfoData(topic: topic, answer: answer),
  );
}

class AvoPickListData {
  final String itemName;
  final double quantity;
  final String? unit;
  const AvoPickListData({required this.itemName, this.quantity = 1, this.unit});
}

class AvoNutritionData {
  final String recipeName;
  final int servings;
  final int? calories;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final bool estimated;
  const AvoNutritionData({
    required this.recipeName,
    required this.servings,
    this.calories,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.estimated = false,
  });
}

class AvoAppInfoData {
  final String topic;
  final String answer;
  const AvoAppInfoData({required this.topic, required this.answer});
}

class AvoContext {
  final List<ShoppingListModel>? lists;
  final List<ShoppingItemModel>? currentListItems;
  final String? currentListId;
  final List<Recipe>? recentRecipes;
  final List<String>? recentHistoryItems;
  final Map<String, List<ShoppingItemModel>>? allListItems;
  final List<String>? dietPreferences;
  final List<String>? allergies;
  final String? userName;
  final List<String>? appPriorities;

  AvoContext({
    this.lists,
    this.currentListItems,
    this.currentListId,
    this.recentRecipes,
    this.recentHistoryItems,
    this.allListItems,
    this.dietPreferences,
    this.allergies,
    this.userName,
    this.appPriorities,
  });
}

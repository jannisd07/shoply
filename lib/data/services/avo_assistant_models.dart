import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/services/avo_card_data.dart';
import 'package:shoply/data/services/avo_conversation.dart';
import 'package:shoply/data/services/avo_consents.dart';

export 'package:shoply/data/services/avo_card_data.dart';

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
  listItems,
  lists,
  pickList,
  confirmDelete,
  consentRequest,

  /// A write outside a list's own changes, with its undo ([AvoRecord]).
  record,

  /// A read result or a question card ([AvoCardData]).
  card,

  /// A change Avo made on a list ([AvoListChange]).
  listChange,

  /// A tool needed a module that is switched off ([AvoWidgetPayload.module]).
  moduleOff,

  /// A tool wrote something that has no card of its own (recipe to list,
  /// food log, a module switched): shows nothing, but tells a retry that it
  /// is done ([AvoWidgetPayload.wroteTool]).
  wrote,
}

class AvoWidgetPayload {
  final AvoPayloadKind kind;
  final List<ShoppingItemModel>? items;
  final String? listId;
  final String? listName;
  final List<ShoppingListModel>? lists;
  final AvoPickListData? pickListData;
  final AvoRecord? record;
  final AvoCardData? card;
  final AvoPendingDelete? pendingDelete;
  final AvoConsentKind? consentKind;
  final AvoListChange? listChange;
  final AppModule? module;

  /// [AvoPayloadKind.wrote]: the tool and the list it wrote to, if any.
  final String? wroteTool;
  final String? wroteListName;

  const AvoWidgetPayload._({
    required this.kind,
    this.items,
    this.listId,
    this.listName,
    this.lists,
    this.pickListData,
    this.record,
    this.card,
    this.pendingDelete,
    this.consentKind,
    this.listChange,
    this.module,
    this.wroteTool,
    this.wroteListName,
  });

  /// [tool] wrote something without a card of its own.
  factory AvoWidgetPayload.wrote(String tool, {String? listName}) =>
      AvoWidgetPayload._(
        kind: AvoPayloadKind.wrote,
        wroteTool: tool,
        wroteListName: listName,
      );

  /// Something this payload stands for is already done (a retry must not
  /// do it again): a list change, a record (setting, log, plan, items), a
  /// card-less write.
  bool get isDoneChange => switch (kind) {
    AvoPayloadKind.listChange ||
    AvoPayloadKind.record ||
    AvoPayloadKind.wrote => true,
    _ => false,
  };

  /// A write with its card and undo (Kap. 5.2–5.7).
  factory AvoWidgetPayload.record(AvoRecord record) =>
      AvoWidgetPayload._(kind: AvoPayloadKind.record, record: record);

  /// A read result or a question card (Kap. 5.2–5.7, 7).
  factory AvoWidgetPayload.card(AvoCardData card) =>
      AvoWidgetPayload._(kind: AvoPayloadKind.card, card: card);

  /// A change on a list, shown as a result card with "Widerrufen".
  factory AvoWidgetPayload.listChange(AvoListChange change) =>
      AvoWidgetPayload._(kind: AvoPayloadKind.listChange, listChange: change);

  /// [module] is switched off; the card offers to switch it on.
  factory AvoWidgetPayload.moduleOff(AppModule module) =>
      AvoWidgetPayload._(kind: AvoPayloadKind.moduleOff, module: module);

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

  /// A deletion Avo proposed; only a tap on this card deletes.
  factory AvoWidgetPayload.confirmDelete(AvoPendingDelete pending) =>
      AvoWidgetPayload._(
        kind: AvoPayloadKind.confirmDelete,
        pendingDelete: pending,
      );

  /// Asks to share data with Avo before a tool can use it.
  factory AvoWidgetPayload.consentRequest(AvoConsentKind kind) =>
      AvoWidgetPayload._(
        kind: AvoPayloadKind.consentRequest,
        consentKind: kind,
      );
}

class AvoPickListData {
  final String itemName;
  final double quantity;
  final String? unit;
  const AvoPickListData({required this.itemName, this.quantity = 1, this.unit});
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

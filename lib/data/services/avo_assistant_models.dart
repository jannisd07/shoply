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

  const AvoResponse({
    required this.message,
    this.payloads = const [],
    this.expression = AvoExpressionType.happy,
  });
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
  });

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

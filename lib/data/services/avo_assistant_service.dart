import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shoply/core/config/env.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/services/recipe_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Avo's personality and capabilities for the AI chatbot
/// Uses Gemini 2.0 Flash Lite for conversational AI
class AvoAssistantService {
  static final AvoAssistantService instance = AvoAssistantService._internal();
  factory AvoAssistantService() => instance;
  AvoAssistantService._internal();

  GenerativeModel? _model;
  ChatSession? _chatSession;
  final _supabase = Supabase.instance.client;

  static const String _systemPrompt = '''
You are Avo, a friendly avocado mascot for the Shoply shopping list app.

Personality: warm, concise, helpful. Occasionally use a food pun. Keep replies to 1-3 sentences unless asked for detail.

You have FULL access to the user's data. When the user asks to SEE or DO something, you MUST use the right action code so the app renders rich UI.

═══ ACTION CODES ═══
Embed these in your response text. The app strips them out and renders interactive widgets.

DISPLAY actions (show rich inline content):
• [ACTION:SHOW_LIST_ITEMS:listId]  → renders the list's items with check/uncheck toggles
• [ACTION:SHOW_LIST_OVERVIEW]      → renders all user's lists as tappable cards
• [ACTION:SHOW_RECIPES:query]      → searches recipes and renders result cards inline
• [ACTION:SHOW_SAVED_RECIPES]      → renders user's saved/bookmarked recipes
• [ACTION:SHOW_HISTORY]            → renders recent shopping history

MUTATION actions (change data):
• [ACTION:ADD_ITEM:listId:itemName:quantity:unit]  → add item to list
• [ACTION:PICK_LIST:itemName:quantity:unit]         → ask user to pick a list first
• [ACTION:CHECK_ITEM:itemId:listId]                → toggle item checked
• [ACTION:DELETE_ITEM:itemId:listId]               → delete item from list

NAVIGATION actions:
• [ACTION:NAVIGATE:route]          → go to screen (/home, /recipes, /profile, /recipes/saved, /recipes/my)
• [ACTION:SHOW_RECIPE:recipeId]    → navigate to recipe detail

═══ RULES ═══
1. When user asks "show my lists" / "what lists do I have" → use SHOW_LIST_OVERVIEW
2. When user asks "what's on my X list" / "show items in X" → find the list ID from context and use SHOW_LIST_ITEMS
3. When user asks to find/search recipes → use SHOW_RECIPES with a good search query
4. When user asks "show my saved recipes" → use SHOW_SAVED_RECIPES
5. When user asks about shopping history / "what did I buy" → use SHOW_HISTORY
6. When user says "add X to my list" with MULTIPLE lists → use PICK_LIST
7. When user says "add X to my list" with ONE list → use ADD_ITEM with that list's ID
8. When user says "check off X" / "mark X as done" → find the item ID from context and use CHECK_ITEM
9. When user says "remove X" / "delete X from list" → use DELETE_ITEM
10. Keep text responses SHORT when attaching rich content — the UI speaks for itself

Current context about the user's data will be provided with each message.
''';

  Future<void> initialize() async {
    try {
      final apiKey = Env.geminiApiKey;
      if (apiKey.isEmpty) {
        print('❌ [AVO] Gemini API key is empty!');
        return;
      }
      _model = GenerativeModel(
        model: 'gemini-2.0-flash-lite',
        apiKey: apiKey,
        systemInstruction: Content.text(_systemPrompt),
      );
      _chatSession = _model!.startChat();
      print('✅ [AVO] Assistant initialized');
    } catch (e) {
      print('❌ [AVO] Error initializing: $e');
    }
  }

  bool get isInitialized => _model != null && _chatSession != null;

  Future<AvoResponse> chat(String userMessage, {AvoContext? context}) async {
    if (!isInitialized) {
      return AvoResponse(
        message: "I'm not ready yet — give me a moment!",
        expression: AvoExpressionType.confused,
      );
    }
    try {
      final contextStr = _buildContextString(context);
      final fullMessage = contextStr.isNotEmpty
          ? 'Context:\n$contextStr\n\nUser: $userMessage'
          : userMessage;

      final response = await _chatSession!.sendMessage(Content.text(fullMessage));
      final responseText = response.text ?? "Hmm, I couldn't think of a response. Try again?";
      final parsed = _parseResponse(responseText);
      print('🥑 [AVO] ${parsed.message}');
      return parsed;
    } catch (e) {
      print('❌ [AVO] Chat error: $e');
      final err = e.toString().toLowerCase();
      if (err.contains('429') || err.contains('quota') || err.contains('resource_exhausted')) {
        return AvoResponse(
          message: "I've hit my thinking limit for now. Try again in a bit!",
          expression: AvoExpressionType.confused,
        );
      }
      return AvoResponse(
        message: "Something went wrong — could you try again?",
        expression: AvoExpressionType.confused,
      );
    }
  }

  String _buildContextString(AvoContext? context) {
    if (context == null) return '';
    final parts = <String>[];

    if (context.lists != null && context.lists!.isNotEmpty) {
      final info = context.lists!.map((l) =>
        '- "${l.name}" (ID:${l.id}, ${l.itemCount ?? 0} items)').join('\n');
      parts.add('Lists:\n$info');
    }

    if (context.allListItems != null) {
      for (final entry in context.allListItems!.entries) {
        if (entry.value.isEmpty) continue;
        String listName = 'Unknown';
        if (context.lists != null) {
          for (final l in context.lists!) {
            if (l.id == entry.key) { listName = l.name; break; }
          }
        }
        final items = entry.value.take(25).map((i) {
          final ck = i.isChecked ? ' ✓' : '';
          return '  - ${i.name} (qty:${i.quantity}, id:${i.id})$ck';
        }).join('\n');
        parts.add('"$listName" items:\n$items');
      }
    }

    if (context.recentRecipes != null && context.recentRecipes!.isNotEmpty) {
      final info = context.recentRecipes!.take(8).map((r) =>
        '- "${r.name}" (ID:${r.id}, ${r.totalTimeMinutes}min)').join('\n');
      parts.add('Recipes:\n$info');
    }

    if (context.recentHistoryItems != null && context.recentHistoryItems!.isNotEmpty) {
      parts.add('Recent purchases: ${context.recentHistoryItems!.take(10).join(', ')}');
    }

    return parts.join('\n\n');
  }

  AvoResponse _parseResponse(String responseText) {
    final actions = <AvoAction>[];
    var cleanMessage = responseText;
    final actionRegex = RegExp(r'\[ACTION:([^\]]+)\]');

    for (final match in actionRegex.allMatches(responseText)) {
      final actionStr = match.group(1)!;
      final parts = actionStr.split(':');
      if (parts.isNotEmpty) {
        actions.add(AvoAction(
          type: _parseActionType(parts[0]),
          params: parts.length > 1 ? parts.sublist(1) : [],
        ));
      }
      cleanMessage = cleanMessage.replaceAll(match.group(0)!, '').trim();
    }

    // Clean up extra whitespace / empty lines
    cleanMessage = cleanMessage.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();

    return AvoResponse(
      message: cleanMessage,
      actions: actions,
      expression: _determineExpression(cleanMessage, actions),
    );
  }

  AvoActionType _parseActionType(String type) {
    switch (type.toUpperCase()) {
      case 'ADD_ITEM': return AvoActionType.addItem;
      case 'SEARCH_RECIPES': return AvoActionType.searchRecipes;
      case 'SHOW_RECIPES': return AvoActionType.showRecipes;
      case 'SHOW_RECIPE': return AvoActionType.showRecipe;
      case 'NAVIGATE': return AvoActionType.navigate;
      case 'ANALYZE_LIST': return AvoActionType.analyzeList;
      case 'SUGGEST_ITEMS': return AvoActionType.suggestItems;
      case 'LIST_ITEMS': return AvoActionType.listItems;
      case 'SHOW_LIST_ITEMS': return AvoActionType.showListItems;
      case 'SHOW_LIST_OVERVIEW': return AvoActionType.showListOverview;
      case 'SHOW_SAVED_RECIPES': return AvoActionType.showSavedRecipes;
      case 'SHOW_HISTORY': return AvoActionType.showHistory;
      case 'PICK_LIST': return AvoActionType.pickList;
      case 'CHECK_ITEM': return AvoActionType.checkItem;
      case 'DELETE_ITEM': return AvoActionType.deleteItem;
      default: return AvoActionType.unknown;
    }
  }

  AvoExpressionType _determineExpression(String message, List<AvoAction> actions) {
    final m = message.toLowerCase();
    if (m.contains('done') || m.contains('added') || m.contains('great') || m.contains('perfect')) {
      return AvoExpressionType.celebrating;
    }
    if (m.contains('!') && (m.contains('delicious') || m.contains('amazing') || m.contains('love'))) {
      return AvoExpressionType.excited;
    }
    if (m.contains('here') || m.contains('found') || m.contains('showing') || actions.isNotEmpty) {
      return AvoExpressionType.happy;
    }
    if (m.contains('think') || m.contains('suggest') || m.contains('recommend')) {
      return AvoExpressionType.thinking;
    }
    if (m.contains('?') || m.contains('sorry') || m.contains('not sure')) {
      return AvoExpressionType.confused;
    }
    return AvoExpressionType.happy;
  }

  Future<List<Recipe>> getRecipeSuggestions(String query) async {
    try { return await RecipeService.instance.searchRecipes(query); }
    catch (e) { print('❌ [AVO] Recipe error: $e'); return []; }
  }

  Future<List<ShoppingListModel>> getUserLists() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];
      final response = await _supabase.from('shopping_lists').select('*')
          .eq('user_id', userId).order('updated_at', ascending: false);
      return (response as List).map((j) => ShoppingListModel.fromJson(j)).toList();
    } catch (e) { print('❌ [AVO] Lists error: $e'); return []; }
  }

  Future<List<ShoppingItemModel>> getListItems(String listId) async {
    try {
      final response = await _supabase.from('shopping_items').select('*')
          .eq('list_id', listId).order('created_at', ascending: false);
      return (response as List).map((j) => ShoppingItemModel.fromJson(j)).toList();
    } catch (e) { print('❌ [AVO] Items error: $e'); return []; }
  }

  Future<bool> addItemToList({required String listId, required String itemName, double quantity = 1, String? unit}) async {
    try {
      await _supabase.from('shopping_items').insert({
        'list_id': listId, 'name': itemName, 'quantity': quantity,
        'unit': unit, 'category': 'other', 'is_checked': false,
      });
      return true;
    } catch (e) { print('❌ [AVO] Add error: $e'); return false; }
  }

  void resetChat() {
    if (_model != null) { _chatSession = _model!.startChat(); }
  }

  void dispose() { _chatSession = null; _model = null; }
}

class AvoResponse {
  final String message;
  final List<AvoAction> actions;
  final AvoExpressionType expression;
  final List<Recipe>? recipes;
  final List<String>? suggestions;

  AvoResponse({
    required this.message,
    this.actions = const [],
    this.expression = AvoExpressionType.happy,
    this.recipes,
    this.suggestions,
  });
}

class AvoAction {
  final AvoActionType type;
  final List<String> params;

  AvoAction({required this.type, this.params = const []});

  @override
  String toString() => 'AvoAction($type, $params)';
}

enum AvoActionType {
  addItem,
  searchRecipes,
  showRecipes,
  showRecipe,
  navigate,
  analyzeList,
  suggestItems,
  listItems,
  showListItems,
  showListOverview,
  showSavedRecipes,
  showHistory,
  pickList,
  checkItem,
  deleteItem,
  unknown,
}

enum AvoExpressionType { happy, excited, thinking, confused, celebrating, waving }

class AvoContext {
  final List<ShoppingListModel>? lists;
  final List<ShoppingItemModel>? currentListItems;
  final String? currentListId;
  final List<Recipe>? recentRecipes;
  final List<String>? recentHistoryItems;
  final Map<String, List<ShoppingItemModel>>? allListItems;

  AvoContext({
    this.lists, this.currentListItems, this.currentListId,
    this.recentRecipes, this.recentHistoryItems, this.allListItems,
  });
}

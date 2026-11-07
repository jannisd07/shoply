import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shoply/core/config/env.dart';
import 'package:shoply/data/models/diet_challenge.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/nutrition_goal.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/recipe_offer_highlight.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/data/models/weekly_nutrition_summary.dart';
import 'package:shoply/data/repositories/item_repository.dart';
import 'package:shoply/data/repositories/list_repository.dart';
import 'package:shoply/data/services/avo_app_knowledge.dart';
import 'package:shoply/data/services/avo_assistant_models.dart';
import 'package:shoply/data/services/avo_nudge_service.dart';
import 'package:shoply/data/services/avo_settings_bridge.dart';
import 'package:shoply/data/services/avo_system_prompt.dart';
import 'package:shoply/data/services/avo_tool_declarations.dart';
import 'package:shoply/data/services/expense_split_service.dart';
import 'package:shoply/data/services/food_log_service.dart';
import 'package:shoply/data/services/mascot_notification_service.dart';
import 'package:shoply/data/services/nutrition_goal_service.dart';
import 'package:shoply/data/services/offer_price_service.dart';
import 'package:shoply/data/services/recipe_offer_service.dart';
import 'package:shoply/data/services/recipe_service.dart';
import 'package:shoply/data/services/shopping_history_service.dart';
import 'package:shoply/data/services/unread_service.dart';
import 'package:shoply/data/services/user_location_service.dart';
import 'package:shoply/data/services/user_service.dart';
import 'package:shoply/data/services/water_log_service.dart';
import 'package:shoply/data/services/weight_log_service.dart';
import 'package:shoply/presentation/providers/price_comparison_provider.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/calorie_tracking_provider.dart';
import 'package:shoply/presentation/state/diet_challenge_provider.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/state/language_provider.dart';
import 'package:shoply/presentation/state/lists_provider.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';
import 'package:shoply/presentation/state/theme_provider.dart';
import 'package:shoply/presentation/state/user_profile_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide FunctionResponse;

export 'package:shoply/data/services/avo_assistant_models.dart';

// ════════════════════════════════════════════════════════════════════
// Avo Assistant — Gemini with function calling
// ════════════════════════════════════════════════════════════════════
//
// The service declares a set of tools Gemini can call. For each user
// message we run a function-calling loop: send the message, if Gemini
// returns function calls we execute them (hitting RecipeService, the
// settings bridge, Supabase, etc.), send the responses back, and repeat
// until Gemini produces a plain text answer.
//
// The final AvoResponse carries both the text and a list of
// "widget payloads" the chat screen renders as rich cards.
// ════════════════════════════════════════════════════════════════════

class AvoAssistantService {
  static final AvoAssistantService instance = AvoAssistantService._();
  AvoAssistantService._();

  GenerativeModel? _model;
  ChatSession? _chatSession;
  final _supabase = Supabase.instance.client;

  /// Number of user messages kept in the chat history. The SDK resends the
  /// whole history every turn, so it is trimmed to bound latency and cost.
  static const _maxHistoryUserTurns = 10;

  /// Context string sent with the last message. Context is only resent when
  /// it changed (or after the history was reset/trimmed).
  String? _lastContextStr;

  /// User the current chat session belongs to; a different user (sign-out,
  /// account switch) gets a fresh session so no list names, items or
  /// allergies leak between accounts.
  String? _sessionUserId;
  StreamSubscription<AuthState>? _authSubscription;

  bool get isInitialized => _model != null && _chatSession != null;

  // ── Lifecycle ────────────────────────────────────────────────────

  Future<void> initialize() async {
    final apiKey = Env.geminiApiKey;
    if (apiKey.isEmpty) {
      debugPrint('❌ [AVO] Gemini API key is empty');
      return;
    }
    _model = GenerativeModel(
      model: 'gemini-2.0-flash-lite',
      apiKey: apiKey,
      systemInstruction: Content.text(avoSystemPrompt),
      tools: buildAvoTools(),
    );
    _chatSession = _model!.startChat();
    _sessionUserId = _supabase.auth.currentUser?.id;
    _authSubscription ??= _supabase.auth.onAuthStateChange.listen((data) {
      final userId = data.session?.user.id;
      if (userId != _sessionUserId) {
        _sessionUserId = userId;
        resetChat();
      }
    });
    debugPrint('✅ [AVO] Assistant initialized with function calling');
  }

  void resetChat() {
    if (_model != null) _chatSession = _model!.startChat();
    _lastContextStr = null;
  }

  void dispose() {
    _authSubscription?.cancel();
    _authSubscription = null;
    _chatSession = null;
    _model = null;
  }

  /// Restarts the session with only the last [_maxHistoryUserTurns] user
  /// messages (and everything after them). Cuts only at a plain user text
  /// turn so function call/response pairs stay together.
  void _trimHistory() {
    final session = _chatSession;
    final model = _model;
    if (session == null || model == null) return;
    final history = session.history.toList();
    final userTurnStarts = <int>[
      for (var i = 0; i < history.length; i++)
        if (history[i].role == 'user' &&
            history[i].parts.any((p) => p is TextPart))
          i,
    ];
    if (userTurnStarts.length <= _maxHistoryUserTurns) return;
    final cut = userTurnStarts[userTurnStarts.length - _maxHistoryUserTurns];
    _chatSession = model.startChat(history: history.sublist(cut));
    // The trimmed history may have lost the context; resend it next turn.
    _lastContextStr = null;
  }

  // ── Chat entry point ─────────────────────────────────────────────

  /// Send a message to Avo. The chat screen passes its [ref] so the
  /// service can call Riverpod notifiers (settings bridge, item provider,
  /// etc.) while executing function calls.
  Future<AvoResponse> chat(
    String userMessage, {
    required WidgetRef ref,
    AvoContext? context,
  }) async {
    if (!isInitialized) {
      return const AvoResponse(
        message: "I'm not ready yet — give me a moment!",
        expression: AvoExpressionType.confused,
      );
    }

    try {
      // The context (lists, items, profile) is only sent when it changed:
      // the chat history already carries the previous one.
      final contextStr = _buildContextString(context);
      final sendContext = contextStr.isNotEmpty && contextStr != _lastContextStr;
      final fullMessage = sendContext
          ? 'Context:\n$contextStr\n\nUser: $userMessage'
          : userMessage;
      if (sendContext) _lastContextStr = contextStr;

      final payloads = <AvoWidgetPayload>[];
      var response = await _chatSession!.sendMessage(Content.text(fullMessage));

      // Function-calling loop. Bounded to avoid runaway chains.
      for (var turn = 0; turn < 4; turn++) {
        final calls = response.functionCalls.toList();
        if (calls.isEmpty) break;

        final responses = <FunctionResponse>[];
        for (final call in calls) {
          final result = await _runTool(call, ref, context, payloads);
          responses.add(FunctionResponse(call.name, result));
        }
        response =
            await _chatSession!.sendMessage(Content.functionResponses(responses));
      }

      _trimHistory();

      final text = (response.text ?? '').trim();
      return AvoResponse(
        message: text,
        payloads: payloads,
        expression: _inferExpression(text, payloads),
      );
    } catch (e) {
      debugPrint('❌ [AVO] Chat error: $e');
      // A turn that failed mid function-call leaves an unanswered call in the
      // history, which would break every later message; start over then.
      // Either way the next message carries the context again.
      final lastTurn = _chatSession?.history.lastOrNull;
      if (lastTurn != null && lastTurn.parts.any((p) => p is FunctionCall)) {
        resetChat();
      }
      _lastContextStr = null;
      final err = e.toString().toLowerCase();
      if (err.contains('429') || err.contains('quota') || err.contains('resource_exhausted')) {
        return const AvoResponse(
          message: "I've hit my thinking limit for now. Try again in a bit!",
          expression: AvoExpressionType.confused,
        );
      }
      return const AvoResponse(
        message: "Something went wrong — could you try again?",
        expression: AvoExpressionType.confused,
      );
    }
  }

  // ── Tool dispatcher ──────────────────────────────────────────────

  Future<Map<String, Object?>> _runTool(
    FunctionCall call,
    WidgetRef ref,
    AvoContext? context,
    List<AvoWidgetPayload> payloads,
  ) async {
    final args = call.args;
    try {
      switch (call.name) {
        case 'search_recipes':
          return await _toolSearchRecipes(args, payloads);
        case 'get_saved_recipes':
          return await _toolSavedRecipes(payloads);
        case 'get_recipe_nutrition':
          return await _toolRecipeNutrition(args, payloads);
        case 'add_recipe_to_list':
          return await _toolAddRecipeToList(args, ref);
        case 'get_shopping_history':
          return await _toolShoppingHistory(args, payloads);
        case 'get_lists':
          return await _toolGetLists(ref, payloads);
        case 'get_list_contents':
          return await _toolGetListContents(args, context, payloads);
        case 'add_item_to_list':
          return await _toolAddItem(args, ref);
        case 'ask_pick_list':
          return await _toolPickList(args, payloads);
        case 'check_items':
          return await _toolCheckItems(args, ref);
        case 'complete_list':
          return await _toolCompleteList(args, ref);
        case 'add_history_items_to_list':
          return await _toolAddHistoryItems(args, ref);
        case 'update_setting':
          return await _toolUpdateSetting(args, ref, payloads);
        case 'get_app_info':
          return _toolAppInfo(args, payloads);
        case 'search_offers':
          return await _toolSearchOffers(args);
        case 'get_restock_suggestions':
          return await _toolRestockSuggestions(args);
        case 'compare_list_prices':
          return await _toolCompareListPrices(args, ref, context);
        case 'get_personalized_deals':
          return await _toolGetPersonalizedDeals(args, ref);
        case 'split_trip_cost':
          return await _toolSplitTripCost(args);
        case 'delete_item':
          return await _toolDeleteItem(args, ref);
        case 'delete_list':
          return await _toolDeleteList(args, ref);
        case 'update_item':
          return await _toolUpdateItem(args, ref);
        case 'move_items':
          return await _toolMoveItems(args, ref);
        case 'create_list':
          return await _toolCreateList(args, ref);
        case 'rename_list':
          return await _toolRenameList(args, ref);
        case 'get_user_profile':
          return await _toolGetUserProfile(ref);
        case 'setup_nutrition_goal':
          return await _toolSetupNutritionGoal(args, ref);
        case 'get_nutrition_status':
          return await _toolNutritionStatus(ref);
        case 'log_food':
          return await _toolLogFood(args, ref);
        case 'log_water':
          return await _toolLogWater(args, ref);
        case 'log_weight':
          return await _toolLogWeight(args, ref);
        case 'delete_food_log':
          return await _toolDeleteFoodLog(args, ref);
        case 'get_weekly_nutrition_summary':
          return await _toolWeeklyNutritionSummary(ref);
        case 'get_challenge_status':
          return await _toolChallengeStatus(ref);
        case 'get_savings_summary':
          return await _toolSavingsSummary();
        default:
          return {'error': 'Unknown tool ${call.name}'};
      }
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // ── Tool implementations ─────────────────────────────────────────

  Future<Map<String, Object?>> _toolSearchRecipes(
    Map<String, Object?> args,
    List<AvoWidgetPayload> payloads,
  ) async {
    final query = (args['query'] as String?) ?? '';
    final filters = _stringList(args['dietary_filters']);
    final exclude = _stringList(args['exclude_allergens']).map((s) => s.toLowerCase()).toList();
    final max = (args['max_results'] as int?) ?? 5;

    var recipes = await RecipeService.instance.searchRecipes(query);

    // Apply dietary filters (recipes must have all specified labels).
    if (filters.isNotEmpty) {
      recipes = recipes
          .where((r) =>
              filters.every((f) => r.labels.any((l) => l.toLowerCase() == f.toLowerCase())))
          .toList();
    }

    // Exclude recipes whose ingredients contain any allergen keyword.
    if (exclude.isNotEmpty) {
      recipes = recipes.where((r) {
        final ingredientText = r.ingredients.map((i) => i.name.toLowerCase()).join(' ');
        return !exclude.any((a) => ingredientText.contains(a));
      }).toList();
    }

    final top = recipes.take(max).toList();
    if (top.isNotEmpty) {
      payloads.add(AvoWidgetPayload.recipes(top));
    }
    return {
      'found': top.length,
      'recipes': top
          .map((r) => {
                'id': r.id,
                'name': r.name,
                'time_minutes': r.totalTimeMinutes,
                'rating': r.averageRating,
                'labels': r.labels,
                if (r.nutrition?.calories != null)
                  'calories_per_serving': r.nutrition!.calories,
              })
          .toList(),
    };
  }

  Future<Map<String, Object?>> _toolSavedRecipes(
    List<AvoWidgetPayload> payloads,
  ) async {
    final saved = await RecipeService.instance.getSavedRecipes();
    final top = saved.take(10).toList();
    if (top.isNotEmpty) {
      payloads.add(AvoWidgetPayload.recipes(top));
    }
    return {
      'found': top.length,
      'recipes': top.map((r) => {'id': r.id, 'name': r.name}).toList(),
    };
  }

  /// Resolves a recipe by id (exact match against the full library) or,
  /// failing that, by a free-text name (first search result) — the shared
  /// lookup every recipe-scoped tool (nutrition, add-to-list) needs.
  Future<Recipe?> _resolveRecipe(String? id, String? name) async {
    if (id != null && id.isNotEmpty) {
      try {
        return await RecipeService.instance.getRecipeById(id);
      } catch (_) {
        // Not found (or a hallucinated id) — fall back to the name search.
      }
    }
    if (name != null && name.isNotEmpty) {
      final results = await RecipeService.instance.searchRecipes(name);
      if (results.isNotEmpty) return results.first;
    }
    return null;
  }

  Future<Map<String, Object?>> _toolRecipeNutrition(
    Map<String, Object?> args,
    List<AvoWidgetPayload> payloads,
  ) async {
    final recipe = await _resolveRecipe(
      args['recipe_id'] as String?,
      args['recipe_name'] as String?,
    );

    if (recipe == null) {
      return {'error': 'Recipe not found'};
    }

    // Use existing nutrition if available; otherwise estimate from ingredients.
    final existing = recipe.nutrition;
    if (existing != null && existing.hasData) {
      payloads.add(AvoWidgetPayload.nutrition(
        recipeName: recipe.name,
        servings: recipe.defaultServings,
        calories: existing.calories,
        proteinG: existing.proteinG,
        carbsG: existing.carbsG,
        fatG: existing.fatG,
        estimated: false,
      ));
      return {
        'recipe': recipe.name,
        'servings': recipe.defaultServings,
        'calories': existing.calories,
        'source': 'stored',
      };
    }

    // Ask Gemini to ESTIMATE for us via a one-shot prompt that bypasses the tools.
    final estimate = await _estimateNutrition(recipe);
    payloads.add(AvoWidgetPayload.nutrition(
      recipeName: recipe.name,
      servings: recipe.defaultServings,
      calories: estimate['calories'] as int?,
      proteinG: (estimate['protein_g'] as num?)?.toDouble(),
      carbsG: (estimate['carbs_g'] as num?)?.toDouble(),
      fatG: (estimate['fat_g'] as num?)?.toDouble(),
      estimated: true,
    ));
    return {
      'recipe': recipe.name,
      'servings': recipe.defaultServings,
      'source': 'estimated',
      ...estimate,
    };
  }

  Future<Map<String, Object?>> _estimateNutrition(Recipe recipe) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-2.0-flash-lite',
        apiKey: Env.geminiApiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          responseSchema: Schema.object(properties: {
            'calories': Schema.integer(),
            'protein_g': Schema.number(),
            'carbs_g': Schema.number(),
            'fat_g': Schema.number(),
          }),
        ),
      );
      final ingredientList = recipe.ingredients
          .map((i) => '- ${i.amount} ${i.unit} ${i.name}'.trim())
          .join('\n');
      final prompt =
          'Estimate the nutrition PER SERVING for this recipe (${recipe.defaultServings} servings total). '
          'Return a JSON object with calories (int), protein_g, carbs_g, fat_g.\n\n'
          'Recipe: ${recipe.name}\nIngredients:\n$ingredientList';
      final resp = await model.generateContent([Content.text(prompt)]);
      final text = resp.text ?? '{}';
      // The response is JSON thanks to responseMimeType.
      final decoded = _parseJson(text);
      return {
        'calories': decoded['calories'] as int?,
        'protein_g': (decoded['protein_g'] as num?)?.toDouble(),
        'carbs_g': (decoded['carbs_g'] as num?)?.toDouble(),
        'fat_g': (decoded['fat_g'] as num?)?.toDouble(),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Adds every ingredient of a recipe to a list — "add ingredients for
  /// carbonara to Friday's list." Reuses [ItemsNotifier.addItem] (same write
  /// path as add_item_to_list/add_history_items_to_list), so items get the
  /// same auto-categorization as any manually-added item. Also attaches
  /// current offer prices where they exist, the same way the in-app
  /// recipe→list bottom sheet (`SelectListBottomSheet`) does, so a recipe
  /// added via chat counts into the list's price total identically to one
  /// added by tapping through the UI (closes the asymmetry flagged in the
  /// idea log after this tool's first version).
  Future<Map<String, Object?>> _toolAddRecipeToList(
    Map<String, Object?> args,
    WidgetRef ref,
  ) async {
    final listId = args['list_id'] as String?;
    if (listId == null || listId.isEmpty) {
      return {'error': 'list_id is required — call get_lists first to resolve it'};
    }
    final recipe = await _resolveRecipe(
      args['recipe_id'] as String?,
      args['recipe_name'] as String?,
    );
    if (recipe == null) return {'error': 'Recipe not found'};
    if (recipe.ingredients.isEmpty) {
      return {'error': '"${recipe.name}" has no stored ingredients to add'};
    }

    final requestedServings = (args['servings'] as num?)?.toInt();
    final scale = requestedServings != null &&
        requestedServings > 0 &&
        requestedServings != recipe.defaultServings;
    final ingredients = scale
        ? recipe.ingredients
            .map((i) => i.adjustForServings(recipe.defaultServings, requestedServings))
            .toList()
        : recipe.ingredients;

    // Best-effort offer lookup — a failed/slow price check must never block
    // the add itself, so any error just leaves ingredientOffers empty.
    var ingredientOffers = const <String, RecipeIngredientOffer>{};
    try {
      final zip = await UserLocationService.instance.getZipCode();
      if (zip != null && zip.isNotEmpty) {
        final offersResult = await RecipeOfferService.instance.getOffers(
          recipeId: recipe.id,
          ingredientNames: ingredients.map((i) => i.name).toList(),
          zipCode: zip,
        );
        ingredientOffers = {
          for (final match in offersResult.matches)
            if (match.isStillValid)
              match.ingredientName.trim().toLowerCase(): match,
        };
      }
    } catch (e) {
      debugPrint('⚠️ [AVO] add_recipe_to_list offer lookup failed: $e');
    }

    // Write through the repository instead of ItemsNotifier.addItem, which
    // reloads the whole list, marks it read and pushes to every member per
    // item. Reload, mark-read and the push happen once at the end instead.
    final repository = ref.read(itemRepositoryProvider);
    var added = 0;
    var addedWithOffer = 0;
    final failed = <String>[];
    for (final ingredient in ingredients) {
      final offer = ingredientOffers[ingredient.name.trim().toLowerCase()];
      try {
        await repository.addItem(
          listId: listId,
          name: ingredient.name,
          quantity: ingredient.amount,
          unit: ingredient.unit.isEmpty ? null : ingredient.unit,
          price: offer?.price,
          priceCurrency: offer != null ? 'EUR' : null,
          priceRetailer: offer?.retailerName,
          priceUnit: offer?.unitSizeLabel,
          priceOldValue: offer?.regularPrice,
        );
        added++;
        if (offer != null) addedWithOffer++;
      } catch (e) {
        failed.add(ingredient.name);
      }
    }
    ref.invalidate(itemsNotifierProvider(listId));
    ref.invalidate(listsNotifierProvider);
    await _afterBulkListChange(ref, listId, addedItemName: added > 0 ? recipe.name : null);

    return {
      'recipe': recipe.name,
      'servings': requestedServings ?? recipe.defaultServings,
      'list_id': listId,
      'added': added,
      'total_ingredients': ingredients.length,
      if (addedWithOffer > 0) 'added_with_offer_price': addedWithOffer,
      if (failed.isNotEmpty) 'failed_items': failed,
    };
  }

  Future<Map<String, Object?>> _toolShoppingHistory(
    Map<String, Object?> args,
    List<AvoWidgetPayload> payloads,
  ) async {
    final limit = (args['limit'] as int?) ?? 5;
    final history = await ShoppingHistoryService().getRecentHistory(limit: limit);
    if (history.isNotEmpty) {
      payloads.add(AvoWidgetPayload.history(history));
    }
    return {
      'found': history.length,
      'history': history
          .map((h) => {
                'id': h.id,
                'list_name': h.listName,
                'completed_at': h.completedAt.toIso8601String(),
                'item_count': h.items.length,
                'items': h.items.map((i) => i.name).toList(),
              })
          .toList(),
    };
  }

  Future<Map<String, Object?>> _toolGetLists(
    WidgetRef ref,
    List<AvoWidgetPayload> payloads,
  ) async {
    final lists = await _fetchLists(ref);
    if (lists.isNotEmpty) {
      payloads.add(AvoWidgetPayload.lists(lists));
    }
    return {
      'found': lists.length,
      'lists': lists
          .map((l) => {'id': l.id, 'name': l.name, 'item_count': l.itemCount ?? 0})
          .toList(),
    };
  }

  Future<Map<String, Object?>> _toolGetListContents(
    Map<String, Object?> args,
    AvoContext? context,
    List<AvoWidgetPayload> payloads,
  ) async {
    var listId = args['list_id'] as String?;
    if (listId == null || listId.isEmpty) {
      final firstList = context?.lists?.isNotEmpty == true ? context!.lists!.first : null;
      if (firstList == null) return {'error': 'No lists available'};
      listId = firstList.id;
    }
    final items = await ItemRepository.instance.getListItems(listId);
    String name = 'Shopping list';
    if (context?.lists != null) {
      for (final l in context!.lists!) {
        if (l.id == listId) {
          name = l.name;
          break;
        }
      }
    }
    payloads.add(AvoWidgetPayload.listItems(
      listId: listId,
      listName: name,
      items: items,
    ));
    return {
      'list_id': listId,
      'list_name': name,
      'item_count': items.length,
      'unchecked_count': items.where((i) => !i.isChecked).length,
      'items': items
          .map((i) => {
                'id': i.id,
                'name': i.name,
                'quantity': i.quantity,
                'unit': i.unit,
                'checked': i.isChecked,
              })
          .toList(),
    };
  }

  Future<Map<String, Object?>> _toolAddItem(
    Map<String, Object?> args,
    WidgetRef ref,
  ) async {
    final listId = args['list_id'] as String?;
    final name = args['name'] as String?;
    if (listId == null || name == null) {
      return {'error': 'list_id and name are required'};
    }
    final quantity = (args['quantity'] as num?)?.toDouble() ?? 1.0;
    final unit = args['unit'] as String?;
    await ref
        .read(itemsNotifierProvider(listId).notifier)
        .addItem(name: name, quantity: quantity, unit: unit);
    return {'success': true, 'list_id': listId, 'name': name};
  }

  Future<Map<String, Object?>> _toolPickList(
    Map<String, Object?> args,
    List<AvoWidgetPayload> payloads,
  ) async {
    final name = args['name'] as String?;
    if (name == null) return {'error': 'name is required'};
    final quantity = (args['quantity'] as num?)?.toDouble() ?? 1.0;
    final unit = args['unit'] as String?;
    payloads.add(AvoWidgetPayload.pickList(
      itemName: name,
      quantity: quantity,
      unit: unit,
    ));
    return {'prompted': true};
  }

  Future<Map<String, Object?>> _toolCheckItems(
    Map<String, Object?> args,
    WidgetRef ref,
  ) async {
    final listId = args['list_id'] as String?;
    final itemIds = _stringList(args['item_ids']);
    final checked = args['checked'] as bool? ?? true;
    if (listId == null || itemIds.isEmpty) {
      return {'error': 'list_id and item_ids are required'};
    }
    final repository = ref.read(itemRepositoryProvider);
    await Future.wait(
        itemIds.map((id) => repository.toggleItemChecked(id, checked)));
    ref.invalidate(itemsNotifierProvider(listId));
    await _afterBulkListChange(ref, listId);
    return {'updated': itemIds.length, 'checked': checked};
  }

  Future<Map<String, Object?>> _toolCompleteList(
    Map<String, Object?> args,
    WidgetRef ref,
  ) async {
    final listId = args['list_id'] as String?;
    if (listId == null) return {'error': 'list_id is required'};
    final repository = ref.read(itemRepositoryProvider);
    final unchecked =
        (await repository.getListItems(listId)).where((i) => !i.isChecked).toList();
    await Future.wait(
        unchecked.map((item) => repository.toggleItemChecked(item.id, true)));
    ref.invalidate(itemsNotifierProvider(listId));
    await _afterBulkListChange(ref, listId);
    return {'checked_count': unchecked.length};
  }

  Future<Map<String, Object?>> _toolAddHistoryItems(
    Map<String, Object?> args,
    WidgetRef ref,
  ) async {
    final historyId = args['history_id'] as String?;
    final listId = args['list_id'] as String?;
    if (historyId == null || listId == null) {
      return {'error': 'history_id and list_id are required'};
    }
    final filter = _stringList(args['item_names']).map((s) => s.toLowerCase()).toSet();

    // Find the history entry.
    final history = await ShoppingHistoryService().getRecentHistory(limit: 30);
    ShoppingHistory? entry;
    for (final h in history) {
      if (h.id == historyId) {
        entry = h;
        break;
      }
    }
    if (entry == null) return {'error': 'History entry not found'};

    final itemsToAdd = filter.isEmpty
        ? entry.items
        : entry.items.where((i) => filter.contains(i.name.toLowerCase())).toList();

    final notifier = ref.read(itemsNotifierProvider(listId).notifier);
    for (final item in itemsToAdd) {
      await notifier.addItem(
        name: item.name,
        quantity: item.quantity,
        unit: item.unit,
        category: item.category,
      );
    }
    // Refresh lists so the UI shows the new counts.
    ref.invalidate(listsNotifierProvider);
    return {'added': itemsToAdd.length};
  }

  Future<Map<String, Object?>> _toolUpdateSetting(
    Map<String, Object?> args,
    WidgetRef ref,
    List<AvoWidgetPayload> payloads,
  ) async {
    final key = args['key'] as String?;
    final value = args['value'];
    if (key == null) return {'error': 'key is required'};

    final bridge = AvoSettingsBridge(ref);
    final result = await bridge.update(key, value);
    payloads.add(AvoWidgetPayload.settingChange(result));
    return result.toJson();
  }

  Map<String, Object?> _toolAppInfo(
    Map<String, Object?> args,
    List<AvoWidgetPayload> payloads,
  ) {
    final topic = (args['topic'] as String?) ?? '';
    final answer = AvoAppKnowledge.lookup(topic);
    if (answer == null) {
      return {
        'error': 'No info for topic "$topic"',
        'available_topics': AvoAppKnowledge.topics.keys.toList(),
      };
    }
    payloads.add(AvoWidgetPayload.appInfo(topic: topic, answer: answer));
    return {'topic': topic, 'answer': answer};
  }

  Future<Map<String, Object?>> _toolSearchOffers(Map<String, Object?> args) async {
    final query = (args['query'] as String?)?.trim() ?? '';
    if (query.isEmpty) return {'error': 'query is required'};

    final zip = await UserLocationService.instance.getZipCode();
    if (zip == null || zip.isEmpty) {
      return {
        'found': 0,
        'note': 'No location available — ask the user for their zip code '
            '(PLZ), set it via update_setting key "zip_code", then search '
            'again.',
      };
    }

    final offers = await OfferPriceService.instance.searchOffers(query, zipCode: zip);
    if (offers.isEmpty) {
      return {'found': 0, 'note': 'No current offers found for "$query" near $zip.'};
    }

    final top = offers.take(5).toList();
    return {
      'found': top.length,
      'cheapest_store': top.first.retailerName,
      'cheapest_price': top.first.price,
      'offers': top
          .map((o) => {
                'product': o.productName,
                'price': o.price,
                'old_price': o.oldPrice,
                'unit': o.unitShortName,
                'store': o.retailerName,
              })
          .toList(),
    };
  }

  /// Whole-list version of [_toolSearchOffers] — reuses [basketComparisonProvider]
  /// (the same infra `list_detail_screen.dart`'s price-comparison sheet and the
  /// home screen's `PriceComparisonNudgeCard` already use) instead of duplicating
  /// the store-ranking logic.
  Future<Map<String, Object?>> _toolCompareListPrices(
    Map<String, Object?> args,
    WidgetRef ref,
    AvoContext? context,
  ) async {
    var listId = args['list_id'] as String?;
    var listName = 'your list';
    if (listId == null || listId.isEmpty) {
      final firstList = context?.lists?.isNotEmpty == true ? context!.lists!.first : null;
      if (firstList == null) return {'error': 'No lists available'};
      listId = firstList.id;
      listName = firstList.name;
    } else if (context?.lists != null) {
      for (final l in context!.lists!) {
        if (l.id == listId) {
          listName = l.name;
          break;
        }
      }
    }

    final zip = await UserLocationService.instance.getZipCode();
    if (zip == null || zip.isEmpty) {
      return {
        'found': false,
        'note': 'No location available — ask the user for their zip code '
            '(PLZ), set it via update_setting key "zip_code", then compare '
            'again.',
      };
    }

    final comparison = await ref.read(basketComparisonProvider(listId).future);
    if (comparison == null || comparison.comparableItemCount == 0) {
      return {
        'found': false,
        'list_name': listName,
        'note': 'No current offers match any item on "$listName" near $zip. '
            'This only compares items that are on a live promotional offer '
            'right now, not full regular-shelf prices.',
      };
    }

    return summarizeBasketComparison(comparison, listName);
  }

  /// Shapes a [BasketComparison] into the JSON summary handed back to
  /// Gemini: top 3 stores that actually have a matched item (cheapest
  /// first), the savings of the cheapest vs. the next-cheapest, and a
  /// confidence note when some matches are only broad/generic-term ones.
  /// Pure and unit-tested independently of the network/Riverpod plumbing
  /// that builds the [BasketComparison] in the first place.
  @visibleForTesting
  static Map<String, Object?> summarizeBasketComparison(
    BasketComparison comparison,
    String listName,
  ) {
    final ranked = comparison.ranked.where((s) => s.matchedCount > 0).take(3).toList();
    final best = comparison.bestStore;
    final secondCheapest = ranked.length > 1 ? ranked[1] : null;
    final savings = (best != null && secondCheapest != null)
        ? secondCheapest.comparableTotal - best.comparableTotal
        : null;

    return {
      'found': true,
      'list_name': listName,
      'comparable_item_count': comparison.comparableItemCount,
      'best_store': best?.retailerName,
      'stores': ranked
          .map((s) => {
                'store': s.retailerName,
                'total': double.parse(s.comparableTotal.toStringAsFixed(2)),
                'matched_items': s.matchedCount,
              })
          .toList(),
      if (savings != null && savings > 0.01)
        'savings_vs_next_cheapest': double.parse(savings.toStringAsFixed(2)),
      if (comparison.broadMatchOnlyCount > 0)
        'note': '${comparison.broadMatchOnlyCount} matched item(s) are only a '
            'similar-product match, not an exact one — mention this is an '
            'estimate, not an exact total.',
    };
  }

  /// Chat-facing version of the home screen's "Angebote" strip
  /// (`PersonalizedDealsService`/`personalizedDealsProvider`, Feature 8's
  /// eleventh session) — reuses the exact same provider the home screen
  /// strip and `WeeklyDealsScreen` already read from, rather than re-pooling
  /// list items itself, so a chat answer and the home screen never disagree.
  Future<Map<String, Object?>> _toolGetPersonalizedDeals(
    Map<String, Object?> args,
    WidgetRef ref,
  ) async {
    final zip = await UserLocationService.instance.getZipCode();
    if (zip == null || zip.isEmpty) {
      return {
        'found': 0,
        'note': 'No location available — ask the user for their zip code '
            '(PLZ), set it via update_setting key "zip_code", then check '
            'again.',
      };
    }

    final limit = ((args['limit'] as num?)?.toInt() ?? 5).clamp(1, 10);
    final matches = await ref.read(personalizedDealsProvider.future);
    return summarizePersonalizedDeals(matches, limit: limit);
  }

  /// Pure, unit-tested shaping of [PersonalizedDealsService.getMatches]'s
  /// result into the JSON summary handed back to Gemini.
  @visibleForTesting
  static Map<String, Object?> summarizePersonalizedDeals(
    List<RecipeIngredientOffer> matches, {
    int limit = 5,
  }) {
    if (matches.isEmpty) {
      return {
        'found': 0,
        'note': 'No current offers match anything on the user\'s shopping '
            'lists right now.',
      };
    }
    final top = matches.take(limit).toList();
    return {
      'found': top.length,
      'deals': top
          .map((m) => {
                'item': m.ingredientName,
                'product': m.productName,
                'price': m.price,
                if (m.regularPrice != null) 'regular_price': m.regularPrice,
                if (m.discountPercent != null)
                  'discount_percent': m.discountPercent,
                'store': m.retailerName,
                if (m.isBroadMatch) 'similar_product': true,
              })
          .toList(),
    };
  }

  Future<Map<String, Object?>> _toolRestockSuggestions(
      Map<String, Object?> args) async {
    final limit = (args['limit'] as num?)?.toInt() ?? 5;
    final suggestions = await AvoNudgeService.instance
        .getRestockSuggestions(limit: limit.clamp(1, 10));
    if (suggestions.isEmpty) {
      return {
        'found': 0,
        'note': 'Nothing seems due right now — either everything was bought '
            'recently, or there is not enough purchase history yet (an item '
            'needs 3+ tracked purchases).',
      };
    }
    const weekdayNames = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    return {
      'found': suggestions.length,
      'suggestions': suggestions
          .map((s) => {
                'item': s.displayName,
                'buys_about_every_days': s.averageDays,
                'last_bought_days_ago': s.daysSince,
                if (s.usualWeekday != null)
                  'usually_bought_on': weekdayNames[s.usualWeekday! - 1],
              })
          .toList(),
    };
  }

  Future<Map<String, Object?>> _toolSplitTripCost(Map<String, Object?> args) async {
    final historyId = args['history_id'] as String?;
    if (historyId == null || historyId.isEmpty) {
      return {'error': 'history_id is required — call get_shopping_history first'};
    }
    final names = _stringList(args['participant_names']);
    if (names.isEmpty) {
      return {'error': 'participant_names must include at least one other person'};
    }

    final history = await ShoppingHistoryService().getRecentHistory(limit: 30);
    ShoppingHistory? trip;
    for (final h in history) {
      if (h.id == historyId) {
        trip = h;
        break;
      }
    }
    if (trip == null) return {'error': 'Shopping history entry not found'};

    final total = (args['total_cost'] as num?)?.toDouble() ?? trip.totalCost;
    if (total == null || total <= 0) {
      return {
        'error':
            'This trip has no known total cost yet — ask the user for the total in EUR '
                'and call split_trip_cost again with total_cost set.',
      };
    }

    final userId = _supabase.auth.currentUser?.id;
    String currentUserName = 'You';
    if (userId != null) {
      try {
        final profile = await _supabase
            .from('users')
            .select('display_name')
            .eq('id', userId)
            .maybeSingle();
        currentUserName = (profile?['display_name'] as String?) ?? currentUserName;
      } catch (_) {}
    }

    final participantCount = names.length + 1;
    final share = double.parse((total / participantCount).toStringAsFixed(2));
    // The payer's share absorbs the cent remainder so shares sum to the total.
    final payerShare =
        double.parse((total - share * names.length).toStringAsFixed(2));

    final shares = [
      SplitShare(
          userId: userId, participantName: currentUserName, amount: payerShare),
      ...names.map((n) => SplitShare(participantName: n, amount: share)),
    ];

    await ExpenseSplitService.instance.createSplits(
      historyId: historyId,
      totalCost: total,
      shares: shares,
      paidByUserId: userId,
      paidByName: currentUserName,
    );

    return {
      'success': true,
      'trip': trip.listName,
      'total_cost': total,
      'each_share': share,
      'participants': [currentUserName, ...names],
    };
  }

  Future<Map<String, Object?>> _toolDeleteItem(
    Map<String, Object?> args,
    WidgetRef ref,
  ) async {
    final listId = args['list_id'] as String?;
    final itemId = args['item_id'] as String?;
    final itemName = (args['item_name'] as String?) ?? 'this item';
    final confirm = args['confirm'] as bool? ?? false;
    if (listId == null || itemId == null) {
      return {'error': 'list_id and item_id are required'};
    }
    if (!confirm) {
      return {
        'requires_confirmation': true,
        'question': 'Remove "$itemName" from the list? This can\'t be undone.',
      };
    }
    await ref.read(itemsNotifierProvider(listId).notifier).deleteItem(itemId);
    return {'success': true, 'deleted': itemName};
  }

  Future<Map<String, Object?>> _toolDeleteList(
    Map<String, Object?> args,
    WidgetRef ref,
  ) async {
    final listId = args['list_id'] as String?;
    final listName = (args['list_name'] as String?) ?? 'this list';
    final confirm = args['confirm'] as bool? ?? false;
    if (listId == null) return {'error': 'list_id is required'};
    if (!confirm) {
      return {
        'requires_confirmation': true,
        'question':
            'Delete the whole list "$listName" and everything on it? This can\'t be undone.',
      };
    }
    await ref.read(listsNotifierProvider.notifier).deleteList(listId);
    return {'success': true, 'deleted': listName};
  }

  Future<Map<String, Object?>> _toolUpdateItem(
    Map<String, Object?> args,
    WidgetRef ref,
  ) async {
    final listId = args['list_id'] as String?;
    final itemId = args['item_id'] as String?;
    if (listId == null || itemId == null) {
      return {'error': 'list_id and item_id are required'};
    }
    final newName = (args['new_name'] as String?)?.trim();
    final quantity = (args['quantity'] as num?)?.toDouble();
    final unit = args['unit'] as String?;
    final notes = args['notes'] as String?;

    // Same update keys the list detail screen's own edit sheet writes.
    final updates = <String, dynamic>{
      if (newName != null && newName.isNotEmpty) 'name': newName,
      if (quantity != null && quantity > 0) 'quantity': quantity,
      if (unit != null) 'unit': unit.trim().isEmpty ? null : unit.trim(),
      if (notes != null) 'notes': notes.trim().isEmpty ? null : notes.trim(),
    };
    if (updates.isEmpty) {
      return {
        'error':
            'Nothing to change — pass new_name, quantity, unit, or notes',
      };
    }
    await ref
        .read(itemsNotifierProvider(listId).notifier)
        .updateItem(itemId, updates);
    ref.invalidate(listsNotifierProvider);
    return {'success': true, 'updated_fields': updates.keys.toList()};
  }

  Future<Map<String, Object?>> _toolMoveItems(
    Map<String, Object?> args,
    WidgetRef ref,
  ) async {
    final fromListId = args['from_list_id'] as String?;
    final toListId = args['to_list_id'] as String?;
    final itemIds = _stringList(args['item_ids']);
    if (fromListId == null || toListId == null || itemIds.isEmpty) {
      return {'error': 'from_list_id, to_list_id and item_ids are required'};
    }
    if (fromListId == toListId) {
      return {'error': 'Those items are already on that list'};
    }
    // Changing list_id keeps the item's id, checked state, category, and
    // price. RLS only permits this when the user is a member of BOTH lists
    // (the UPDATE policy's USING clause applies to old and new row alike),
    // so a move to a foreign list fails closed instead of silently leaking.
    final notifier = ref.read(itemsNotifierProvider(fromListId).notifier);
    var moved = 0;
    String? failure;
    for (final id in itemIds) {
      try {
        await notifier.updateItem(id, {'list_id': toListId});
        moved++;
      } catch (e) {
        failure = e.toString();
        break;
      }
    }
    ref.invalidate(itemsNotifierProvider(toListId));
    ref.invalidate(listsNotifierProvider);
    if (failure != null) {
      return {
        'error': 'Move failed after $moved of ${itemIds.length} items: $failure',
        'moved_count': moved,
      };
    }
    return {'success': true, 'moved_count': moved, 'to_list_id': toListId};
  }

  Future<Map<String, Object?>> _toolCreateList(
    Map<String, Object?> args,
    WidgetRef ref,
  ) async {
    final name = (args['name'] as String?)?.trim();
    if (name == null || name.isEmpty) return {'error': 'name is required'};
    final newList =
        await ref.read(listsNotifierProvider.notifier).createList(name);
    return {
      'success': true,
      'list_id': newList.id,
      'name': newList.name,
      'hint': 'Use this list_id with add_item_to_list to add items.',
    };
  }

  Future<Map<String, Object?>> _toolRenameList(
    Map<String, Object?> args,
    WidgetRef ref,
  ) async {
    final listId = args['list_id'] as String?;
    final newName = (args['new_name'] as String?)?.trim();
    if (listId == null || newName == null || newName.isEmpty) {
      return {'error': 'list_id and new_name are required'};
    }
    await ref
        .read(listsNotifierProvider.notifier)
        .updateList(listId, {'name': newName});
    return {'success': true, 'renamed_to': newName};
  }

  // ── Profile & preference-guidance tools ─────────────────────────

  Future<Map<String, Object?>> _toolGetUserProfile(WidgetRef ref) async {
    final user = await ref.read(currentUserProvider.future);
    if (user == null) return {'error': 'Not signed in'};

    final trackingOn = ref.read(calorieTrackingEnabledProvider);
    final zip = await UserLocationService.instance.getManualZipCode();
    final goal =
        trackingOn ? await NutritionGoalService.instance.getGoal() : null;

    return {
      'display_name': user.displayName ?? 'not set',
      'age': user.age ?? 'not set',
      'gender': user.gender ?? 'not set',
      'height': user.height == null
          ? 'not set'
          : '${user.height!.round()} ${user.heightUnit ?? 'cm'}',
      'diet_preferences':
          user.dietPreferences.isEmpty ? 'none' : user.dietPreferences,
      'allergies': user.allergies.isEmpty ? 'none' : user.allergies,
      'language': ref.read(languageProvider.notifier).savedSetting,
      'theme': ref.read(themeModeProvider).name,
      'notifications_enabled': user.notificationEnabled,
      'calorie_tracking_enabled': trackingOn,
      'zip_code_for_offers': zip ?? 'not set',
      if (trackingOn)
        'nutrition_goal': (goal != null && goal.isConfigured)
            ? {
                'goal_type': goal.goalType.dbValue,
                'daily_calorie_target': goal.dailyCalorieTarget,
                'protein_target_g': goal.proteinTargetG,
                'carbs_target_g': goal.carbsTargetG,
                'fat_target_g': goal.fatTargetG,
                if (goal.targetWeightKg != null)
                  'target_weight_kg': goal.targetWeightKg,
              }
            : 'not configured — offer setup_nutrition_goal',
      'note': 'Anything "not set" can be changed via update_setting; the '
          'calorie goal via setup_nutrition_goal.',
    };
  }

  Future<Map<String, Object?>> _toolSetupNutritionGoal(
    Map<String, Object?> args,
    WidgetRef ref,
  ) async {
    if (!ref.read(calorieTrackingEnabledProvider)) {
      return {'tracking_enabled': false, 'note': _trackingDisabledNote};
    }
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return {'error': 'Not signed in'};

    // Validate the enum-ish args strictly so a hallucinated value can't be
    // silently coerced into the wrong goal.
    NutritionGoalType? goalType;
    final goalArg = (args['goal_type'] as String?)?.toLowerCase().trim();
    if (goalArg != null && goalArg.isNotEmpty) {
      const valid = {'lose_weight', 'gain_muscle', 'maintain', 'custom'};
      if (!valid.contains(goalArg)) {
        return {'error': 'goal_type must be one of: ${valid.join(', ')}'};
      }
      goalType = NutritionGoalTypeX.fromDb(goalArg);
    }
    ActivityLevel? activityLevel;
    final activityArg =
        (args['activity_level'] as String?)?.toLowerCase().trim();
    if (activityArg != null && activityArg.isNotEmpty) {
      const valid = {'sedentary', 'light', 'moderate', 'active', 'very_active'};
      if (!valid.contains(activityArg)) {
        return {'error': 'activity_level must be one of: ${valid.join(', ')}'};
      }
      activityLevel = ActivityLevelX.fromDb(activityArg);
    }
    var gender = (args['gender'] as String?)?.toLowerCase().trim();
    if (gender != null && gender.isNotEmpty &&
        gender != 'male' && gender != 'female') {
      return {
        'error': 'gender must be "male" or "female" — it is only used to pick '
            'the BMR formula variant.',
      };
    }

    // Prefill everything not passed from the profile, the existing goal and
    // the weight log — the same sources the goal-setup screen prefills from.
    final user = await ref.read(currentUserProvider.future);
    final existing = await NutritionGoalService.instance.getGoal();
    final hasConfiguredGoal = existing != null && existing.isConfigured;

    if (gender == null || gender.isEmpty) {
      gender = (user?.gender == 'male' || user?.gender == 'female')
          ? user!.gender
          : null;
    }
    final age = (args['age'] as num?)?.round() ?? user?.age;
    if (age != null && (age < 10 || age > 120)) {
      return {'error': 'age must be between 10 and 120'};
    }
    var heightCm = (args['height_cm'] as num?)?.toDouble() ?? existing?.heightCm;
    if (heightCm == null &&
        user?.height != null &&
        (user!.heightUnit == null || user.heightUnit == 'cm')) {
      heightCm = user.height;
    }
    if (heightCm != null && (heightCm < 100 || heightCm > 250)) {
      return {'error': 'height_cm must be between 100 and 250'};
    }
    var weight = (args['current_weight_kg'] as num?)?.toDouble() ??
        existing?.currentWeightKg;
    weight ??= (await WeightLogService.instance.getLatest())?.weightKg;
    if (weight != null && (weight < 20 || weight > 400)) {
      return {'error': 'current_weight_kg must be between 20 and 400'};
    }
    goalType ??= hasConfiguredGoal ? existing.goalType : null;
    activityLevel ??= hasConfiguredGoal ? existing.activityLevel : null;
    final needsTarget = goalType == NutritionGoalType.loseWeight ||
        goalType == NutritionGoalType.gainMuscle;
    final targetWeight = (args['target_weight_kg'] as num?)?.toDouble() ??
        existing?.targetWeightKg;
    if (needsTarget && targetWeight != null &&
        (targetWeight < 20 || targetWeight > 400)) {
      return {'error': 'target_weight_kg must be between 20 and 400'};
    }
    final timelineWeeks =
        ((args['timeline_weeks'] as num?)?.round() ?? existing?.timelineWeeks ?? 12)
            .clamp(4, 104)
            .toInt();

    final missing = <String>[
      if (goalType == null) 'goal_type',
      if (gender == null) 'gender',
      if (age == null) 'age',
      if (heightCm == null) 'height_cm',
      if (weight == null) 'current_weight_kg',
      if (needsTarget && targetWeight == null) 'target_weight_kg',
      if (activityLevel == null) 'activity_level',
    ];
    if (missing.isNotEmpty) {
      return {
        'incomplete': true,
        'missing': missing,
        'known': {
          if (goalType != null) 'goal_type': goalType.dbValue,
          if (activityLevel != null) 'activity_level': activityLevel.dbValue,
          if (age != null) 'age': age,
          if (gender != null) 'gender': gender,
          if (heightCm != null) 'height_cm': heightCm,
          if (weight != null) 'current_weight_kg': weight,
          if (needsTarget && targetWeight != null)
            'target_weight_kg': targetWeight,
        },
        'note': 'Ask the user for the missing fields (at most two per '
            'message), then call setup_nutrition_goal again with everything. '
            'The "known" values were prefilled from their profile — mention '
            'them briefly so the user can correct any that changed.',
      };
    }

    // Replacing an already-configured goal needs an explicit yes.
    final confirm = args['confirm_replace'] as bool? ?? false;
    if (hasConfiguredGoal && !confirm) {
      return {
        'requires_confirmation': true,
        'question':
            'Replace the current ${existing.goalType.dbValue} goal '
            '(${existing.dailyCalorieTarget} kcal/day) with a new '
            '${goalType!.dbValue} goal?',
        'note': 'If the user agrees, call setup_nutrition_goal again with '
            'confirm_replace=true AND all the same field values — do not '
            'drop any of them.',
      };
    }

    final targets = NutritionGoalCalculator.calculate(
      goalType: goalType!,
      activityLevel: activityLevel!,
      currentWeightKg: weight!,
      heightCm: heightCm!,
      age: age!,
      gender: gender!,
      targetWeightKg: needsTarget ? targetWeight : null,
      timelineWeeks: needsTarget ? timelineWeeks : null,
    );

    final now = DateTime.now();
    await NutritionGoalService.instance.saveGoal(NutritionGoal(
      userId: userId,
      calorieTrackingEnabled: true,
      goalType: goalType,
      activityLevel: activityLevel,
      currentWeightKg: weight,
      targetWeightKg: needsTarget ? targetWeight : null,
      heightCm: heightCm,
      timelineWeeks: needsTarget ? timelineWeeks : null,
      dailyCalorieTarget: targets.dailyCalorieTarget,
      proteinTargetG: targets.proteinTargetG,
      carbsTargetG: targets.carbsTargetG,
      fatTargetG: targets.fatTargetG,
      waterTargetMl: existing?.waterTargetMl ?? 2000,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    ));
    await WeightLogService.instance.logWeight(weightKg: weight);

    // Keep the profile fields in sync — same as the goal-setup screen, since
    // age/height/gender are used elsewhere (personal info, diet logic).
    if (user != null) {
      await UserService.instance.updateUserProfile(user.copyWith(
        age: age,
        height: heightCm,
        heightUnit: 'cm',
        gender: gender,
      ));
    }
    ref.invalidate(nutritionGoalProvider);
    ref.invalidate(currentUserProvider);
    ref.invalidate(userProfileProvider);
    invalidateNutritionLog(ref);
    await MascotNotificationService.instance
        .rearmDinnerIdeasReminder(force: true);

    return {
      'success': true,
      'goal_type': goalType.dbValue,
      'daily_calorie_target': targets.dailyCalorieTarget,
      'protein_target_g': targets.proteinTargetG,
      'carbs_target_g': targets.carbsTargetG,
      'fat_target_g': targets.fatTargetG,
      if (needsTarget) 'target_weight_kg': targetWeight,
      if (needsTarget) 'timeline_weeks': timelineWeeks,
      'note': 'Goal saved. Tell the user their daily calorie target and '
          'macros, and that they can fine-tune it anytime in the calories '
          'tab or by asking you.',
    };
  }

  // ── Nutrition / calorie-tracking tools ───────────────────────────

  static const _trackingDisabledNote =
      'Calorie tracking is turned off for this user, so nothing was logged '
      'or read. Ask if they want to enable it — if yes, call update_setting '
      'with key "calorie_tracking" and value "true".';

  Future<Map<String, Object?>> _toolNutritionStatus(WidgetRef ref) async {
    if (!ref.read(calorieTrackingEnabledProvider)) {
      return {'tracking_enabled': false, 'note': _trackingDisabledNote};
    }
    final today = DateTime.now();
    final goal = await NutritionGoalService.instance.getGoal();
    final entries = await FoodLogService.instance.getEntriesForDate(today);
    final totals = DailyNutritionTotals.fromEntries(entries);
    final waterMl = await WaterLogService.instance.getTotalForDate(today);

    final result = <String, Object?>{
      'tracking_enabled': true,
      'goal_configured': goal?.isConfigured ?? false,
      'consumed_today': {
        'calories': totals.calories,
        'protein_g': _round1(totals.proteinG),
        'carbs_g': _round1(totals.carbsG),
        'fat_g': _round1(totals.fatG),
        'water_ml': waterMl,
      },
      'entries_today': entries
          .map((e) => {
                'entry_id': e.id,
                'meal': e.mealType.dbValue,
                'food': e.foodName,
                'calories': e.calories,
              })
          .toList(),
    };
    if (goal != null && goal.isConfigured) {
      result['goal_type'] = goal.goalType.dbValue;
      result['targets'] = {
        'calories': goal.dailyCalorieTarget,
        'protein_g': goal.proteinTargetG,
        'carbs_g': goal.carbsTargetG,
        'fat_g': goal.fatTargetG,
        'water_ml': goal.waterTargetMl,
      };
      result['remaining'] = {
        'calories': goal.dailyCalorieTarget! - totals.calories,
        if (goal.proteinTargetG != null)
          'protein_g': _round1(goal.proteinTargetG! - totals.proteinG),
        if (goal.carbsTargetG != null)
          'carbs_g': _round1(goal.carbsTargetG! - totals.carbsG),
        if (goal.fatTargetG != null)
          'fat_g': _round1(goal.fatTargetG! - totals.fatG),
        'water_ml': goal.waterTargetMl - waterMl,
      };
    } else {
      result['note'] =
          'No calorie goal is configured yet, so there are no targets — '
          'totals only. Offer to set one up right here in chat via '
          'setup_nutrition_goal.';
    }
    return result;
  }

  Future<Map<String, Object?>> _toolLogFood(
    Map<String, Object?> args,
    WidgetRef ref,
  ) async {
    if (!ref.read(calorieTrackingEnabledProvider)) {
      return {'tracking_enabled': false, 'note': _trackingDisabledNote};
    }
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return {'error': 'Not signed in'};
    final foodName = (args['food_name'] as String?)?.trim() ?? '';
    if (foodName.isEmpty) return {'error': 'food_name is required'};

    final portion = (args['portion'] as String?)?.trim() ?? '';
    var calories = (args['calories'] as num?)?.round();
    var protein = (args['protein_g'] as num?)?.toDouble();
    var carbs = (args['carbs_g'] as num?)?.toDouble();
    var fat = (args['fat_g'] as num?)?.toDouble();

    var estimated = false;
    if (calories == null) {
      final description = portion.isEmpty ? foodName : '$portion $foodName';
      final estimate = await _estimateFoodNutrition(description);
      if (estimate == null) {
        return {
          'error': 'Could not estimate nutrition for "$description" — ask '
              'the user for the calories and call log_food again with them.',
        };
      }
      calories = (estimate['calories'] as num?)?.round() ?? 0;
      protein ??= (estimate['protein_g'] as num?)?.toDouble();
      carbs ??= (estimate['carbs_g'] as num?)?.toDouble();
      fat ??= (estimate['fat_g'] as num?)?.toDouble();
      estimated = true;
    }

    final mealType = _mealTypeFromArg(args['meal_type'] as String?);
    final now = DateTime.now();
    final entry = await FoodLogService.instance.addEntry(FoodLogEntry(
      id: '',
      userId: userId,
      loggedDate: now,
      mealType: mealType,
      source: FoodLogSource.manual,
      foodName: portion.isEmpty ? foodName : '$foodName ($portion)',
      calories: calories,
      proteinG: protein,
      carbsG: carbs,
      fatG: fat,
      createdAt: now,
    ));
    invalidateNutritionLog(ref);

    // Fresh totals so Avo can say "that puts you at X of Y kcal".
    final goal = await NutritionGoalService.instance.getGoal();
    final totals = DailyNutritionTotals.fromEntries(
        await FoodLogService.instance.getEntriesForDate(now));
    return {
      'success': true,
      'entry_id': entry.id,
      'logged': entry.foodName,
      'meal': mealType.dbValue,
      'calories': calories,
      'estimated': estimated,
      'consumed_today_calories': totals.calories,
      if (goal?.dailyCalorieTarget != null)
        'remaining_calories': goal!.dailyCalorieTarget! - totals.calories,
      if (estimated)
        'note': 'Nutrition was AI-estimated from the description — briefly '
            'mention it is an estimate.',
    };
  }

  Future<Map<String, Object?>> _toolLogWater(
    Map<String, Object?> args,
    WidgetRef ref,
  ) async {
    if (!ref.read(calorieTrackingEnabledProvider)) {
      return {'tracking_enabled': false, 'note': _trackingDisabledNote};
    }
    final amount = ((args['amount_ml'] as num?)?.round() ?? 250).clamp(1, 3000);
    await WaterLogService.instance.addEntry(amount);
    invalidateNutritionLog(ref);
    final total = await WaterLogService.instance.getTotalForDate(DateTime.now());
    final goal = await NutritionGoalService.instance.getGoal();
    return {
      'success': true,
      'added_ml': amount,
      'total_today_ml': total,
      'target_ml': goal?.waterTargetMl ?? 2000,
    };
  }

  Future<Map<String, Object?>> _toolLogWeight(
    Map<String, Object?> args,
    WidgetRef ref,
  ) async {
    if (!ref.read(calorieTrackingEnabledProvider)) {
      return {'tracking_enabled': false, 'note': _trackingDisabledNote};
    }
    final weight = (args['weight_kg'] as num?)?.toDouble();
    if (weight == null || weight < 20 || weight > 400) {
      return {'error': 'weight_kg must be between 20 and 400'};
    }
    final previous = await WeightLogService.instance.getLatest();
    await WeightLogService.instance.logWeight(weightKg: weight);
    invalidateNutritionLog(ref);
    final goal = await NutritionGoalService.instance.getGoal();
    return {
      'success': true,
      'weight_kg': weight,
      if (previous != null) 'previous_weight_kg': previous.weightKg,
      if (previous != null)
        'previous_logged_date':
            previous.loggedDate.toIso8601String().substring(0, 10),
      if (goal?.targetWeightKg != null) 'target_weight_kg': goal!.targetWeightKg,
    };
  }

  Future<Map<String, Object?>> _toolDeleteFoodLog(
    Map<String, Object?> args,
    WidgetRef ref,
  ) async {
    final entryId = args['entry_id'] as String?;
    final foodName = (args['food_name'] as String?) ?? 'this entry';
    final confirm = args['confirm'] as bool? ?? false;
    if (entryId == null || entryId.isEmpty) {
      return {
        'error': 'entry_id is required — call get_nutrition_status first '
            'to find the entry id.',
      };
    }
    if (!confirm) {
      return {
        'requires_confirmation': true,
        'question': 'Remove "$foodName" from today\'s food diary?',
      };
    }
    await FoodLogService.instance.deleteEntry(entryId);
    invalidateNutritionLog(ref);
    return {'success': true, 'deleted': foodName};
  }

  Future<Map<String, Object?>> _toolWeeklyNutritionSummary(WidgetRef ref) async {
    if (!ref.read(calorieTrackingEnabledProvider)) {
      return {'tracking_enabled': false, 'note': _trackingDisabledNote};
    }
    final goal = await ref.read(nutritionGoalProvider.future);
    if (goal == null || !goal.isConfigured) {
      return {
        'found': false,
        'note': 'No calorie goal is configured yet, so there is nothing to '
            'summarize. Offer to set one up via setup_nutrition_goal.',
      };
    }
    final summary = await ref.read(weeklyNutritionSummaryProvider.future);
    if (summary == null || !summary.hasAnyData) {
      return {
        'found': false,
        'note': 'Nothing was logged in the last 7 days.',
      };
    }
    return summarizeWeeklyNutrition(summary, goal);
  }

  /// Pure, unit-tested shaping of a [WeeklyNutritionSummary] into the JSON
  /// handed back to Gemini.
  @visibleForTesting
  static Map<String, Object?> summarizeWeeklyNutrition(
    WeeklyNutritionSummary s,
    NutritionGoal goal,
  ) {
    return {
      'found': true,
      'days_logged': s.loggedDayCount,
      'avg_calories': s.avgCalories,
      'calorie_target': goal.dailyCalorieTarget,
      'days_within_calorie_budget': s.daysWithinBudget,
      'avg_protein_g': _round1(s.avgProteinG),
      'avg_carbs_g': _round1(s.avgCarbsG),
      'avg_fat_g': _round1(s.avgFatG),
      if (goal.proteinTargetG != null) 'protein_target_g': goal.proteinTargetG,
      'protein_target_reached_days': s.proteinReachedDays,
      if (s.waterLoggedDayCount > 0) 'avg_water_ml': s.avgWaterMl,
      'logging_streak_days': s.loggingStreak,
      'cooked_meals_this_week': s.cookedMealCount,
      'cooked_high_protein_meals_this_week': s.cookedHighProteinMealCount,
      if (s.weightDeltaKg != null) 'weight_change_kg': _round1(s.weightDeltaKg!),
      if (s.latestWeightKg != null) 'latest_weight_kg': s.latestWeightKg,
    };
  }

  Future<Map<String, Object?>> _toolChallengeStatus(WidgetRef ref) async {
    final challenges = await ref.read(activeChallengesProvider.future);
    return summarizeChallengeStatus(challenges);
  }

  /// Pure, unit-tested shaping of the user's active [DietChallenge]s into
  /// the JSON handed back to Gemini.
  @visibleForTesting
  static Map<String, Object?> summarizeChallengeStatus(
    List<DietChallenge> challenges,
  ) {
    if (challenges.isEmpty) {
      return {
        'found': 0,
        'note': 'No active diet challenge. Available types: 16:8 '
            'intermittent fasting, 30-day no sugar — started from the '
            'Challenges screen off the calorie dashboard (this tool cannot '
            'start one).',
      };
    }
    return {
      'found': challenges.length,
      'challenges': challenges
          .map((c) => {
                'type': _challengeTypeLabel(c.type),
                'checked_in_today': c.isCheckedInToday,
                'current_streak_days': c.currentStreak,
                'total_checkins': c.totalCheckins,
                'kept_count': c.keptCount,
                'adherence_rate_percent': (c.adherenceRate * 100).round(),
                if (c.daysRemaining != null) 'days_remaining': c.daysRemaining,
              })
          .toList(),
    };
  }

  static String _challengeTypeLabel(ChallengeType type) => switch (type) {
        ChallengeType.fasting16_8 => '16:8 intermittent fasting',
        ChallengeType.noSugar30 => '30-day no sugar',
        ChallengeType.custom => 'custom challenge',
      };

  Future<Map<String, Object?>> _toolSavingsSummary() async {
    final history = await ShoppingHistoryService().getShoppingHistory();
    return summarizeLifetimeSavings(history, DateTime.now());
  }

  /// Pure, unit-tested lifetime + this-month savings aggregation — reuses
  /// [totalSavingsOf]/[tripsInMonth] (the same helpers
  /// [ShoppingHistoryScreen] computes its "you've saved €X" lines from), so
  /// a chat answer and the Shopping History screen can never disagree.
  @visibleForTesting
  static Map<String, Object?> summarizeLifetimeSavings(
    List<ShoppingHistory> history,
    DateTime now,
  ) {
    final total = totalSavingsOf(history);
    final tripsWithSavings =
        history.where((trip) => totalSavingsOf([trip]) > 0.01).length;

    if (total <= 0.01) {
      return {
        'total_saved_eur': 0,
        'note': 'No tracked savings yet. This only counts items bought at a '
            'live offer/deal price and is not retroactive — it grows from '
            'the first time an offer price is applied to a list item that '
            'is later bought.',
      };
    }

    final monthEntries =
        tripsInMonth(history, year: now.year, month: now.month);
    final monthSavings = totalSavingsOf(monthEntries);
    final prevMonth = DateTime(now.year, now.month - 1);
    final prevMonthSavings = totalSavingsOf(
      tripsInMonth(history, year: prevMonth.year, month: prevMonth.month),
    );

    final result = <String, Object?>{
      'total_saved_eur': double.parse(total.toStringAsFixed(2)),
      'trips_with_savings': tripsWithSavings,
      'month_saved_eur': double.parse(monthSavings.toStringAsFixed(2)),
      'note': 'total_saved_eur is a lifetime figure across all of shopping '
          'history; month_saved_eur is scoped to the current calendar month '
          'only and may be 0 even when the lifetime total is not.',
    };
    if (prevMonthSavings > 0.01) {
      result['prev_month_saved_eur'] =
          double.parse(prevMonthSavings.toStringAsFixed(2));
    }
    return result;
  }

  /// One-shot Gemini estimate for a free-text food description ("1 banana",
  /// "200 g chicken breast") — same pattern as [_estimateNutrition] for
  /// recipes. Returns null when no usable estimate came back.
  Future<Map<String, Object?>?> _estimateFoodNutrition(String description) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-2.0-flash-lite',
        apiKey: Env.geminiApiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          responseSchema: Schema.object(properties: {
            'calories': Schema.integer(),
            'protein_g': Schema.number(),
            'carbs_g': Schema.number(),
            'fat_g': Schema.number(),
          }),
        ),
      );
      final prompt =
          'Estimate the nutrition of this food as actually eaten: "$description". '
          'If no amount is given, assume one typical portion. Return JSON with '
          'calories (int), protein_g, carbs_g, fat_g.';
      final resp = await model.generateContent([Content.text(prompt)]);
      final decoded = _parseJson(resp.text ?? '{}');
      if (decoded['calories'] == null) return null;
      return decoded;
    } catch (e) {
      debugPrint('❌ [AVO] Food nutrition estimate failed: $e');
      return null;
    }
  }

  static MealType _mealTypeFromArg(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'breakfast':
        return MealType.breakfast;
      case 'lunch':
        return MealType.lunch;
      case 'dinner':
        return MealType.dinner;
      case 'snack':
        return MealType.snack;
    }
    final hour = DateTime.now().hour;
    if (hour < 11) return MealType.breakfast;
    if (hour < 15) return MealType.lunch;
    if (hour >= 17 && hour < 22) return MealType.dinner;
    return MealType.snack;
  }

  static double _round1(double v) => (v * 10).round() / 10;

  // ── Data access helpers ──────────────────────────────────────────

  /// Lists the user owns or is a member of, with item counts — the loaded
  /// lists state when available, otherwise a fresh repository fetch.
  Future<List<ShoppingListModel>> _fetchLists(WidgetRef ref) async {
    final loaded = ref.read(listsNotifierProvider).valueOrNull;
    if (loaded != null) return loaded;
    if (_supabase.auth.currentUser == null) return [];
    return ListRepository.instance.getUserLists();
  }

  /// Bookkeeping after a tool changed several items at once: mark the list
  /// read (the user's own change must not show as unread) and, for adds,
  /// send one push to the other members instead of one per item.
  Future<void> _afterBulkListChange(
    WidgetRef ref,
    String listId, {
    String? addedItemName,
  }) async {
    try {
      await UnreadService().markAsRead(listId);
      final userId = _supabase.auth.currentUser?.id;
      if (addedItemName != null && userId != null) {
        await ref.read(itemRepositoryProvider).sendItemAddedNotification(
              listId: listId,
              itemName: addedItemName,
              addedByUserId: userId,
            );
      }
    } catch (e) {
      debugPrint('⚠️ [AVO] Post-change bookkeeping failed: $e');
    }
  }

  // ── Context builder ──────────────────────────────────────────────

  String _buildContextString(AvoContext? context) {
    if (context == null) return '';
    final parts = <String>[];

    if (context.lists != null && context.lists!.isNotEmpty) {
      final info = context.lists!
          .map((l) => '- "${l.name}" (ID:${l.id}, ${l.itemCount ?? 0} items)')
          .join('\n');
      parts.add('Lists:\n$info');
    }
    if (context.allListItems != null) {
      for (final entry in context.allListItems!.entries) {
        if (entry.value.isEmpty) continue;
        String listName = 'Unknown';
        if (context.lists != null) {
          for (final l in context.lists!) {
            if (l.id == entry.key) {
              listName = l.name;
              break;
            }
          }
        }
        final items = entry.value
            .take(20)
            .map((i) => '  - ${i.name} (id:${i.id})${i.isChecked ? ' ✓' : ''}')
            .join('\n');
        parts.add('"$listName" items:\n$items');
      }
    }
    if (context.dietPreferences != null && context.dietPreferences!.isNotEmpty) {
      parts.add('User diet: ${context.dietPreferences!.join(', ')}');
    }
    if (context.allergies != null && context.allergies!.isNotEmpty) {
      parts.add('User allergies: ${context.allergies!.join(', ')}');
    }
    if (context.userName != null && context.userName!.isNotEmpty) {
      parts.add('User name: ${context.userName}');
    }
    if (context.appPriorities != null && context.appPriorities!.isNotEmpty) {
      final labels = context.appPriorities!
          .map((id) => _appPriorityLabels[id])
          .whereType<String>()
          .toList();
      if (labels.isNotEmpty) {
        parts.add('What this user said matters to them: ${labels.join(', ')} '
            '(see system instructions for how to use this)');
      }
    }
    return parts.join('\n\n');
  }

  /// Human-readable form of each `AppPriority.id`
  /// (`core/constants/app_priorities.dart`), for the model context only —
  /// never shown to the user directly.
  static const _appPriorityLabels = {
    'save_money': 'saving money',
    'share_lists': 'sharing lists with others',
    'eat_healthier': 'eating healthier',
    'discover_recipes': 'discovering new recipes',
    'stay_organized': 'staying organized',
  };

  AvoExpressionType _inferExpression(String text, List<AvoWidgetPayload> payloads) {
    final m = text.toLowerCase();
    if (m.contains('added') || m.contains('done') || m.contains('perfect')) {
      return AvoExpressionType.celebrating;
    }
    if (payloads.isNotEmpty) return AvoExpressionType.happy;
    if (m.contains('sorry') || m.contains('not sure') || m.contains("can't")) {
      return AvoExpressionType.confused;
    }
    return AvoExpressionType.happy;
  }

  // ── Parsing helpers ──────────────────────────────────────────────

  static List<String> _stringList(Object? v) {
    if (v == null) return [];
    if (v is List) return v.map((e) => e.toString()).toList();
    if (v is String) {
      if (v.trim().isEmpty) return [];
      return v.split(RegExp(r'[,;]')).map((e) => e.trim()).where((s) => s.isNotEmpty).toList();
    }
    return [];
  }

  static Map<String, Object?> _parseJson(String text) {
    try {
      final cleaned = text
          .replaceAll(RegExp(r'```(?:json)?'), '')
          .replaceAll('```', '')
          .trim();
      final decoded = jsonDecode(cleaned);
      if (decoded is Map) return decoded.cast<String, Object?>();
      return {};
    } catch (_) {
      return {};
    }
  }
}

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shoply/core/config/env.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/nutrition_goal.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/services/avo_app_knowledge.dart';
import 'package:shoply/data/services/avo_nudge_service.dart';
import 'package:shoply/data/services/avo_settings_bridge.dart';
import 'package:shoply/data/services/expense_split_service.dart';
import 'package:shoply/data/services/food_log_service.dart';
import 'package:shoply/data/services/nutrition_goal_service.dart';
import 'package:shoply/data/services/offer_price_service.dart';
import 'package:shoply/data/services/recipe_service.dart';
import 'package:shoply/data/services/shopping_history_service.dart';
import 'package:shoply/data/services/user_location_service.dart';
import 'package:shoply/data/services/water_log_service.dart';
import 'package:shoply/data/services/weight_log_service.dart';
import 'package:shoply/presentation/state/calorie_tracking_provider.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/state/lists_provider.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide FunctionResponse;

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

  bool get isInitialized => _model != null && _chatSession != null;

  // ── System prompt ────────────────────────────────────────────────

  static final String _systemPrompt = '''
You are Avo, the friendly avocado mascot for the Shoply shopping list app.

Personality: warm, concise, helpful. Occasionally use a light food pun.
Keep text replies to 1-2 sentences — the UI renders rich cards, so let
the widgets speak for themselves.

TOOLS — You have real tools to search data and change the app. Always
PREFER calling a tool over guessing. Never make up recipes, list items,
or prices.

When the user asks to:
• see/find recipes → call search_recipes (pass dietary_filters and
  exclude_allergens from the user profile if set)
• know calories/nutrition → call get_recipe_nutrition
• see their shopping history → call get_shopping_history
• add past items to a list → call add_history_items_to_list
• see a list's contents → call get_list_contents
• check / mark items → call check_items
• finish shopping for a list → call complete_list
• add an item to a list → call add_item_to_list (if multiple lists
  exist and they didn't specify, call ask_pick_list instead)
• change ANY setting (theme, language, name, diet, allergies,
  calorie tracking on/off, etc.) → call update_setting
• find prices, deals, offers, or "which store is cheapest" for a
  product → call search_offers
• know what they might need to buy / what's running low / restock
  ideas → call get_restock_suggestions (based on their real purchase
  rhythm), then offer to add the items via add_item_to_list
• split / share the cost of a past shopping trip with other people
  ("split yesterday's Lidl trip with Max and Jonas") → first call
  get_shopping_history to find the right history_id, then call
  split_trip_cost
• remove/delete an item or a whole list → call delete_item /
  delete_list WITHOUT confirm first. It will NOT delete anything and
  instead returns a confirmation question — ask the user that question
  verbatim and wait for their reply. Only call the same tool again with
  confirm=true if they clearly say yes. Never skip this step.
• ask how many calories/macros they have left, what they ate today, or
  their water intake → call get_nutrition_status
• say they ate or drank something ("I just ate a banana", "log 200g
  chicken for lunch") → call log_food. Pass portion/meal_type when the
  user gives them. Only pass calories/protein_g/carbs_g/fat_g if the
  USER stated the numbers — otherwise leave them out and the tool
  estimates them (then mention it's an estimate).
• log water ("I drank a glass of water") → call log_water
• tell you their current body weight → call log_weight
• remove a food diary entry → call delete_food_log (same confirm flow
  as delete_item; get entry_id from get_nutrition_status first)
• ask "what can I still eat today?" or want meal ideas for their
  remaining calories → call get_nutrition_status first, then
  search_recipes, and prefer recipes whose calories_per_serving fits
  the remaining calories — say how many kcal each suggestion has.
If a nutrition tool reports tracking is disabled, offer to enable it
(update_setting key "calorie_tracking" value "true") — ask first,
never enable it without the user agreeing.
• know ANYTHING about Shoply itself (premium, pricing, features,
  how-tos, privacy) → call get_app_info with the topic

Available get_app_info topics: ${AvoAppKnowledge.topicsSummary}.

After a tool returns, write a short natural-language confirmation
(1 sentence) and do not repeat the data the widget already shows.
''';

  // ── Lifecycle ────────────────────────────────────────────────────

  Future<void> initialize() async {
    final apiKey = Env.geminiApiKey;
    if (apiKey.isEmpty) {
      // ignore: avoid_print
      print('❌ [AVO] Gemini API key is empty');
      return;
    }
    _model = GenerativeModel(
      model: 'gemini-2.0-flash-lite',
      apiKey: apiKey,
      systemInstruction: Content.text(_systemPrompt),
      tools: _buildTools(),
    );
    _chatSession = _model!.startChat();
    // ignore: avoid_print
    print('✅ [AVO] Assistant initialized with function calling');
  }

  void resetChat() {
    if (_model != null) _chatSession = _model!.startChat();
  }

  void dispose() {
    _chatSession = null;
    _model = null;
  }

  // ── Tool declarations ────────────────────────────────────────────

  List<Tool> _buildTools() => [
        Tool(functionDeclarations: [
          FunctionDeclaration(
            'search_recipes',
            'Search the Shoply recipe library and display matching recipes as cards. '
                'Pass dietary_filters (e.g. ["vegan", "gluten-free"]) and/or '
                'exclude_allergens (e.g. ["nuts", "eggs"]) based on the user profile.',
            Schema.object(properties: {
              'query': Schema.string(description: 'Search terms — ingredients, cuisine, or meal type'),
              'dietary_filters': Schema.array(
                description: 'Dietary tags that recipes MUST match (vegan, vegetarian, keto, etc.)',
                items: Schema.string(),
              ),
              'exclude_allergens': Schema.array(
                description: 'Allergen ingredients to avoid (e.g. nuts, gluten, dairy)',
                items: Schema.string(),
              ),
              'max_results': Schema.integer(description: 'Maximum recipes to return (default 5)'),
            }, requiredProperties: ['query']),
          ),
          FunctionDeclaration(
            'get_saved_recipes',
            'Display the user\'s bookmarked recipes as cards.',
            Schema.object(properties: {}),
          ),
          FunctionDeclaration(
            'get_recipe_nutrition',
            'Return calories and macros for a recipe. If the recipe already '
                'stores nutrition, returns it directly; otherwise ESTIMATES from ingredients. '
                'Pass either recipe_id or a free-text recipe_name.',
            Schema.object(properties: {
              'recipe_id': Schema.string(description: 'Recipe ID from search_recipes'),
              'recipe_name': Schema.string(description: 'Recipe name to look up by name'),
            }),
          ),
          FunctionDeclaration(
            'get_shopping_history',
            'Display recent shopping history cards. Each card has "Add all" and per-item add buttons.',
            Schema.object(properties: {
              'limit': Schema.integer(description: 'Max history entries (default 5)'),
            }),
          ),
          FunctionDeclaration(
            'get_lists',
            'Display all of the user\'s shopping lists as cards.',
            Schema.object(properties: {}),
          ),
          FunctionDeclaration(
            'get_list_contents',
            'Display items inside a specific shopping list. Omit list_id to use the first list.',
            Schema.object(properties: {
              'list_id': Schema.string(description: 'ID of the list'),
            }),
          ),
          FunctionDeclaration(
            'add_item_to_list',
            'Add a single item to a shopping list.',
            Schema.object(properties: {
              'list_id': Schema.string(description: 'Target list ID'),
              'name': Schema.string(description: 'Item name'),
              'quantity': Schema.number(description: 'Quantity (default 1)'),
              'unit': Schema.string(description: 'Unit (g, ml, pcs, etc.)'),
            }, requiredProperties: ['list_id', 'name']),
          ),
          FunctionDeclaration(
            'ask_pick_list',
            'Show a picker so the user can choose which list to add an item to. '
                'Use this when the user said "add X" but has multiple lists.',
            Schema.object(properties: {
              'name': Schema.string(description: 'Item name'),
              'quantity': Schema.number(description: 'Quantity (default 1)'),
              'unit': Schema.string(description: 'Unit'),
            }, requiredProperties: ['name']),
          ),
          FunctionDeclaration(
            'check_items',
            'Mark one or many items as checked (or unchecked) in a list.',
            Schema.object(properties: {
              'list_id': Schema.string(),
              'item_ids': Schema.array(items: Schema.string()),
              'checked': Schema.boolean(description: 'True to check, false to uncheck'),
            }, requiredProperties: ['list_id', 'item_ids']),
          ),
          FunctionDeclaration(
            'complete_list',
            'Mark every unchecked item in a list as checked — "finish shopping" for that list.',
            Schema.object(properties: {
              'list_id': Schema.string(),
            }, requiredProperties: ['list_id']),
          ),
          FunctionDeclaration(
            'add_history_items_to_list',
            'Add items from a past shopping history entry into a target list. '
                'If item_names is omitted, adds ALL items from the history entry.',
            Schema.object(properties: {
              'history_id': Schema.string(description: 'Shopping history entry ID'),
              'list_id': Schema.string(description: 'Target list ID'),
              'item_names': Schema.array(
                description: 'Specific item names to add; omit for all',
                items: Schema.string(),
              ),
            }, requiredProperties: ['history_id', 'list_id']),
          ),
          FunctionDeclaration(
            'update_setting',
            'Change any user setting. Supported keys: theme_mode (light/dark/system), '
                'accent_color (hex), language (en/de/system), notifications (true/false), '
                'display_name, diet_preferences (array), allergies (array), age, gender, '
                'height, calorie_tracking (true/false — shows/hides the calorie tab).',
            Schema.object(properties: {
              'key': Schema.string(description: 'Setting key'),
              'value': Schema.string(
                description:
                    'New value as a string. For arrays, pass comma-separated values.',
              ),
            }, requiredProperties: ['key', 'value']),
          ),
          FunctionDeclaration(
            'get_app_info',
            'Look up factual information about Shoply itself (pricing, premium, '
                'features, how-tos, privacy). ALWAYS use this instead of guessing.',
            Schema.object(properties: {
              'topic': Schema.string(
                description:
                    'Topic keyword, e.g. "premium", "pricing", "share", "recipes", "widgets"',
              ),
            }, requiredProperties: ['topic']),
          ),
          FunctionDeclaration(
            'search_offers',
            'Search LIVE current supermarket offers (Angebote) for a product near the '
                'user, sorted cheapest first, across German grocery chains. Use this for '
                '"how much does X cost", "find X on offer", or "which store is cheapest '
                'for X". Only covers active promotional offers, not regular shelf prices — '
                'say so if nothing is found.',
            Schema.object(properties: {
              'query': Schema.string(description: 'Product to search for, e.g. "milk"'),
            }, requiredProperties: ['query']),
          ),
          FunctionDeclaration(
            'split_trip_cost',
            'Split a completed shopping trip\'s cost between the current user and named '
                'participants (equal split). ALWAYS call get_shopping_history first to '
                'resolve history_id from a hint like "yesterday\'s Lidl trip". If the trip '
                'has no known total_cost yet, you must ask the user for it and pass it.',
            Schema.object(properties: {
              'history_id': Schema.string(description: 'Shopping history entry ID to split'),
              'participant_names': Schema.array(
                description: 'Names of the other people to split with (not including the current user)',
                items: Schema.string(),
              ),
              'total_cost': Schema.number(
                description: 'Total trip cost in EUR, only if not already known',
              ),
            }, requiredProperties: ['history_id', 'participant_names']),
          ),
          FunctionDeclaration(
            'get_restock_suggestions',
            'Items the user is probably running low on, based on their own '
                'purchase rhythm (how often they historically re-buy each item). '
                'Excludes items already on an open list. Use when the user asks '
                'what they might need, what to buy, or restock ideas.',
            Schema.object(properties: {
              'limit': Schema.integer(
                  description: 'Max suggestions to return (default 5)'),
            }),
          ),
          FunctionDeclaration(
            'delete_item',
            'Delete an item from a shopping list. SAFETY: call this WITHOUT confirm '
                'first — it returns a confirmation question instead of deleting. Only '
                'call again with confirm=true after the user explicitly agrees.',
            Schema.object(properties: {
              'list_id': Schema.string(),
              'item_id': Schema.string(),
              'item_name': Schema.string(description: 'Item name, for the confirmation question'),
              'confirm': Schema.boolean(description: 'Set true only after the user said yes'),
            }, requiredProperties: ['list_id', 'item_id', 'item_name']),
          ),
          FunctionDeclaration(
            'delete_list',
            'Permanently delete a whole shopping list. SAFETY: call this WITHOUT '
                'confirm first — it returns a confirmation question instead of deleting. '
                'Only call again with confirm=true after the user explicitly agrees.',
            Schema.object(properties: {
              'list_id': Schema.string(),
              'list_name': Schema.string(description: 'List name, for the confirmation question'),
              'confirm': Schema.boolean(description: 'Set true only after the user said yes'),
            }, requiredProperties: ['list_id', 'list_name']),
          ),
          FunctionDeclaration(
            'get_nutrition_status',
            'Today\'s calorie tracking status: calories/protein/carbs/fat consumed '
                'and remaining vs. the user\'s targets, water intake, and every food '
                'diary entry logged today (with entry ids). Use for "how many calories '
                'do I have left", "what did I eat today", or before suggesting meals '
                'that fit the remaining budget.',
            Schema.object(properties: {}),
          ),
          FunctionDeclaration(
            'log_food',
            'Log a food the user ate into today\'s food diary. Only pass '
                'calories/protein_g/carbs_g/fat_g if the user explicitly stated them; '
                'when omitted, the tool AI-estimates nutrition from food_name + portion '
                'and reports estimated=true.',
            Schema.object(properties: {
              'food_name': Schema.string(description: 'What was eaten, e.g. "banana", "Spaghetti Bolognese"'),
              'portion': Schema.string(
                  description: 'Amount as the user said it, e.g. "200 g", "1 slice", "a large bowl"'),
              'meal_type': Schema.string(
                  description: 'One of: breakfast, lunch, dinner, snack. Omit to infer from the time of day.'),
              'calories': Schema.integer(description: 'ONLY if the user stated the calories'),
              'protein_g': Schema.number(description: 'ONLY if the user stated it'),
              'carbs_g': Schema.number(description: 'ONLY if the user stated it'),
              'fat_g': Schema.number(description: 'ONLY if the user stated it'),
            }, requiredProperties: ['food_name']),
          ),
          FunctionDeclaration(
            'log_water',
            'Log drinking water. A glass is ~250 ml, a small bottle 500 ml, a large '
                'bottle 1000 ml.',
            Schema.object(properties: {
              'amount_ml': Schema.integer(description: 'Amount in ml (default 250)'),
            }),
          ),
          FunctionDeclaration(
            'log_weight',
            'Log the user\'s current body weight for today (overwrites today\'s '
                'earlier entry if any). Use when the user tells you what they weigh.',
            Schema.object(properties: {
              'weight_kg': Schema.number(description: 'Weight in kilograms'),
            }, requiredProperties: ['weight_kg']),
          ),
          FunctionDeclaration(
            'delete_food_log',
            'Delete one entry from today\'s food diary. SAFETY: call WITHOUT confirm '
                'first — it returns a confirmation question instead of deleting. Only '
                'call again with confirm=true after the user explicitly agrees. Get the '
                'entry_id from get_nutrition_status.',
            Schema.object(properties: {
              'entry_id': Schema.string(description: 'Diary entry id from get_nutrition_status'),
              'food_name': Schema.string(description: 'Food name, for the confirmation question'),
              'confirm': Schema.boolean(description: 'Set true only after the user said yes'),
            }, requiredProperties: ['entry_id', 'food_name']),
          ),
        ]),
      ];

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
      final contextStr = _buildContextString(context);
      final fullMessage = contextStr.isNotEmpty
          ? 'Context:\n$contextStr\n\nUser: $userMessage'
          : userMessage;

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

      final text = (response.text ?? '').trim();
      return AvoResponse(
        message: text,
        payloads: payloads,
        expression: _inferExpression(text, payloads),
      );
    } catch (e) {
      // ignore: avoid_print
      print('❌ [AVO] Chat error: $e');
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
        case 'get_shopping_history':
          return await _toolShoppingHistory(args, payloads);
        case 'get_lists':
          return await _toolGetLists(payloads);
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
        case 'split_trip_cost':
          return await _toolSplitTripCost(args);
        case 'delete_item':
          return await _toolDeleteItem(args, ref);
        case 'delete_list':
          return await _toolDeleteList(args, ref);
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

  Future<Map<String, Object?>> _toolRecipeNutrition(
    Map<String, Object?> args,
    List<AvoWidgetPayload> payloads,
  ) async {
    final id = args['recipe_id'] as String?;
    final name = args['recipe_name'] as String?;

    Recipe? recipe;
    if (id != null && id.isNotEmpty) {
      final all = await RecipeService.instance.getRecipes();
      for (final r in all) {
        if (r.id == id) {
          recipe = r;
          break;
        }
      }
    } else if (name != null && name.isNotEmpty) {
      final results = await RecipeService.instance.searchRecipes(name);
      if (results.isNotEmpty) recipe = results.first;
    }

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
    List<AvoWidgetPayload> payloads,
  ) async {
    final lists = await _fetchLists();
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
    final items = await _fetchListItems(listId);
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
    final notifier = ref.read(itemsNotifierProvider(listId).notifier);
    for (final id in itemIds) {
      await notifier.toggleItemChecked(id, checked);
    }
    return {'updated': itemIds.length, 'checked': checked};
  }

  Future<Map<String, Object?>> _toolCompleteList(
    Map<String, Object?> args,
    WidgetRef ref,
  ) async {
    final listId = args['list_id'] as String?;
    if (listId == null) return {'error': 'list_id is required'};
    final items = await _fetchListItems(listId);
    final notifier = ref.read(itemsNotifierProvider(listId).notifier);
    var count = 0;
    for (final item in items) {
      if (!item.isChecked) {
        await notifier.toggleItemChecked(item.id, true);
        count++;
      }
    }
    return {'checked_count': count};
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
        'note': 'No location available — ask the user to set their zip code '
            'in Profile settings to enable offer search.',
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
    return {
      'found': suggestions.length,
      'suggestions': suggestions
          .map((s) => {
                'item': s.displayName,
                'buys_about_every_days': s.averageDays,
                'last_bought_days_ago': s.daysSince,
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
          'totals only. The user can set a goal in the calories tab.';
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
      // ignore: avoid_print
      print('❌ [AVO] Food nutrition estimate failed: $e');
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

  Future<List<ShoppingListModel>> _fetchLists() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];
    final response = await _supabase
        .from('shopping_lists')
        .select('*')
        .eq('user_id', userId)
        .order('updated_at', ascending: false);
    return (response as List).map((j) => ShoppingListModel.fromJson(j)).toList();
  }

  Future<List<ShoppingItemModel>> _fetchListItems(String listId) async {
    final response = await _supabase
        .from('shopping_items')
        .select('*')
        .eq('list_id', listId)
        .order('created_at', ascending: false);
    return (response as List).map((j) => ShoppingItemModel.fromJson(j)).toList();
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
    return parts.join('\n\n');
  }

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

enum AvoExpressionType { happy, excited, thinking, confused, celebrating, waving }

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
  });

  factory AvoWidgetPayload.recipes(List<Recipe> recipes) =>
      AvoWidgetPayload._(kind: AvoPayloadKind.recipes, recipes: recipes);

  factory AvoWidgetPayload.listItems({
    required String listId,
    required String listName,
    required List<ShoppingItemModel> items,
  }) =>
      AvoWidgetPayload._(
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
  }) =>
      AvoWidgetPayload._(
        kind: AvoPayloadKind.pickList,
        pickListData: AvoPickListData(itemName: itemName, quantity: quantity, unit: unit),
      );

  factory AvoWidgetPayload.nutrition({
    required String recipeName,
    required int servings,
    int? calories,
    double? proteinG,
    double? carbsG,
    double? fatG,
    bool estimated = false,
  }) =>
      AvoWidgetPayload._(
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
      AvoWidgetPayload._(kind: AvoPayloadKind.settingChange, settingChange: result);

  factory AvoWidgetPayload.appInfo({required String topic, required String answer}) =>
      AvoWidgetPayload._(
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
  });
}


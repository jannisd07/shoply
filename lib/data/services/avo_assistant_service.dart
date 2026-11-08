import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:shoply/core/constants/app_brand.dart';
import 'package:shoply/core/localization/app_translations.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/models/diet_challenge.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/meal_plan.dart';
import 'package:shoply/data/models/nutrition_goal.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/recipe_offer_highlight.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/models/weekly_nutrition_summary.dart';
import 'package:shoply/data/models/workout.dart';
import 'package:shoply/data/repositories/item_repository.dart';
import 'package:shoply/data/repositories/list_repository.dart';
import 'package:shoply/data/services/avo_assistant_models.dart';
import 'package:shoply/data/services/avo_consents.dart';
import 'package:shoply/data/services/avo_conversation.dart';
import 'package:shoply/data/services/avo_nudge_service.dart';
import 'package:shoply/data/services/avo_settings_bridge.dart';
import 'package:shoply/data/services/claude_service.dart';
import 'package:shoply/data/services/expense_split_service.dart';
import 'package:shoply/data/services/food_log_service.dart';
import 'package:shoply/data/services/mascot_notification_service.dart';
import 'package:shoply/data/services/meal_plan_aggregator.dart';
import 'package:shoply/data/services/nutrition_goal_service.dart';
import 'package:shoply/data/services/offer_price_service.dart';
import 'package:shoply/data/services/recipe_offer_service.dart';
import 'package:shoply/data/services/recipe_service.dart';
import 'package:shoply/data/services/shopping_history_service.dart';
import 'package:shoply/data/services/subscription_service.dart';
import 'package:shoply/data/services/unread_service.dart';
import 'package:shoply/data/services/user_location_service.dart';
import 'package:shoply/data/services/user_service.dart';
import 'package:shoply/data/services/water_log_service.dart';
import 'package:shoply/data/services/weight_log_service.dart';
import 'package:shoply/data/services/workout_log_service.dart';
import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/providers/avo_screen_context_provider.dart';
import 'package:shoply/presentation/providers/meal_plan_provider.dart';
import 'package:shoply/presentation/providers/price_comparison_provider.dart';
import 'package:shoply/presentation/providers/store_for_list_provider.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/calorie_tracking_provider.dart';
import 'package:shoply/presentation/state/diet_challenge_provider.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/state/language_provider.dart';
import 'package:shoply/presentation/state/lists_provider.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';
import 'package:shoply/presentation/state/theme_provider.dart';


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

  final _supabase = Supabase.instance.client;

  final AvoConversation _conversation = AvoConversation();
  final AvoPendingDeletes _pendingDeletes = AvoPendingDeletes();

  /// Answer rounds per question (answer → tool results → next answer).
  static const _maxRounds = 8;

  /// User the conversation belongs to; a different user (sign-out, account
  /// switch) gets a fresh one so no list names, items or allergies leak
  /// between accounts.
  String? _sessionUserId;
  StreamSubscription<AuthState>? _authSubscription;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  // ── Lifecycle ────────────────────────────────────────────────────

  /// Avo talks to Claude through the Edge Function `ai`; there is no key in
  /// the app, so getting ready only means following the signed-in user.
  Future<void> initialize() async {
    if (_initialized) return;
    _sessionUserId = _supabase.auth.currentUser?.id;
    _authSubscription ??= _supabase.auth.onAuthStateChange.listen((data) {
      final userId = data.session?.user.id;
      if (userId != _sessionUserId) {
        _sessionUserId = userId;
        resetChat();
      }
    });
    _initialized = true;
    debugPrint('✅ [AVO] Assistant ready (Claude via Edge Function)');
  }

  /// "Neues Gespräch": forgets the conversation and every pending deletion.
  void resetChat() {
    _conversation.reset();
    _pendingDeletes.clear();
  }

  void dispose() {
    _authSubscription?.cancel();
    _authSubscription = null;
    _initialized = false;
    resetChat();
  }

  /// Stops the answer that is being written ("Stopp").
  void stop() => ClaudeService.instance.cancelAvoStream();

  // ── Chat entry point ─────────────────────────────────────────────

  /// Send a message to Avo. The chat screen passes its [ref] so the
  /// service can call Riverpod notifiers (settings bridge, item provider,
  /// etc.) while running tool calls.
  Future<AvoResponse> chat(
    String userMessage, {
    required WidgetRef ref,
    AvoContext? context,
  }) async {
    return _ask(userMessage, ref, context, onText: (_) {});
  }

  /// Like [chat], but reports the answer text while it is written.
  Stream<String> chatStream(
    String userMessage, {
    required WidgetRef ref,
    AvoContext? context,
    void Function(AvoResponse response)? onDone,
  }) {
    final controller = StreamController<String>();
    _ask(userMessage, ref, context, onText: controller.add).then((response) {
      onDone?.call(response);
    }).whenComplete(controller.close);
    return controller.stream;
  }

  Future<AvoResponse> _ask(
    String userMessage,
    WidgetRef ref,
    AvoContext? context, {
    required void Function(String delta) onText,
  }) async {
    if (!_initialized) await initialize();
    if (_conversation.isExpired) resetChat();

    final consents = await AvoConsents.load();
    _conversation.applyConsents(health: consents.health, body: consents.body);
    _conversation.toolsVariant ??=
        ref.read(offersRemoteEnabledProvider) ? 'full' : 'no_offers';

    final payloads = <AvoWidgetPayload>[];
    final mark = _conversation.addQuestion(userMessage);
    _conversation.trim();
    var answer = '';

    try {
      for (var round = 0; round < _maxRounds; round++) {
        final done = await _streamOneAnswer(
          ref,
          context,
          consents: consents,
          onText: onText,
        );
        _conversation.addAnswer(done.content, contextMessage: done.contextMessage);
        final text = AvoConversation.textOf(done.content);
        if (text.isNotEmpty) answer = text;
        if (done.stopReason != 'tool_use') break;

        final results = <Map<String, dynamic>>[];
        for (final call in done.toolCalls) {
          results.add(await _runToolCall(call, ref, context, payloads, consents));
        }
        _conversation.addToolResults(results);
        if (round == _maxRounds - 1) {
          // Out of rounds with tool results pending: one more question
          // would make the history end on unanswered tools, so close here.
          _conversation.rollback(mark);
          return AvoResponse(
            message: _t(ref, 'avo_error_too_many_steps'),
            payloads: payloads,
            expression: AvoExpressionType.confused,
          );
        }
      }
      return AvoResponse(
        message: answer,
        payloads: payloads,
        expression: _inferExpression(answer, payloads),
      );
    } on _AvoStreamFailure catch (failure) {
      _conversation.rollback(mark);
      debugPrint('❌ [AVO] Answer failed: ${failure.code}');
      return AvoResponse(
        message: _t(ref, _errorKeyFor(failure.code)),
        payloads: payloads,
        expression: AvoExpressionType.confused,
      );
    } catch (e) {
      _conversation.rollback(mark);
      debugPrint('❌ [AVO] Chat error: $e');
      return AvoResponse(
        message: _t(ref, 'avo_error_generic'),
        payloads: payloads,
        expression: AvoExpressionType.confused,
      );
    }
  }

  /// One streamed answer of the server task `avo_chat`.
  Future<AvoMessageDone> _streamOneAnswer(
    WidgetRef ref,
    AvoContext? context, {
    required ({bool health, bool body}) consents,
    required void Function(String delta) onText,
  }) async {
    final input = {
      'messages': _conversation.messages,
      'context': _contextJson(ref, context, consents),
      'tools_variant': _conversation.toolsVariant,
    };
    AvoMessageDone? done;
    await for (final event in ClaudeService.instance.streamAvo(input)) {
      switch (event) {
        case AvoTextDelta(:final text):
          onText(text);
        case AvoMessageDone():
          done = event;
        case AvoStreamError(:final code):
          throw _AvoStreamFailure(code);
      }
    }
    final result = done;
    if (result == null) throw const _AvoStreamFailure('provider_error');
    return result;
  }

  static String _t(WidgetRef ref, String key) =>
      AppTranslations.get(key, ref.read(languageProvider));

  static String _errorKeyFor(String code) => switch (code) {
        'quota_exceeded' || 'rate_limited' => 'avo_error_limit',
        'network_error' || 'timeout' => 'avo_error_offline',
        'ai_disabled' => 'avo_error_unavailable',
        'refused' => 'avo_error_refused',
        _ => 'avo_error_generic',
      };

  /// The context of the question (server `avo_chat`): today, where the
  /// person is, which modules are on, and allergies or diet only with the
  /// consent "Ernährung und Allergien".
  Map<String, Object?> _contextJson(
    WidgetRef ref,
    AvoContext? context,
    ({bool health, bool body}) consents,
  ) {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final screen = ref.read(avoScreenContextProvider);
    final listId = screen?.listId ?? context?.currentListId;
    return {
      'today': '${now.year}-${two(now.month)}-${two(now.day)}',
      if (screen != null) 'screen': screen.screen,
      if (listId != null && RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(listId))
        'list_id': listId,
      'modules': {
        'offers': ref.read(offersAvailableProvider),
        'calories': ref.read(moduleEnabledProvider(AppModule.calories)),
        'meal_plan': ref.read(moduleEnabledProvider(AppModule.mealPlan)),
        'cost_split': ref.read(moduleEnabledProvider(AppModule.costSplit)),
      },
      'consent_health': consents.health,
      'consent_body': consents.body,
      if (consents.health && (context?.allergies?.isNotEmpty ?? false))
        'allergies': context!.allergies,
      if (consents.health && (context?.dietPreferences?.isNotEmpty ?? false))
        'diet': context!.dietPreferences,
    };
  }

  // ── Tool dispatcher ──────────────────────────────────────────────

  /// Runs one checked tool call and answers with its tool_result block.
  Future<Map<String, dynamic>> _runToolCall(
    AvoToolCall call,
    WidgetRef ref,
    AvoContext? context,
    List<AvoWidgetPayload> payloads,
    ({bool health, bool body}) consents,
  ) async {
    final error = call.error;
    if (error != null) {
      return AvoConversation.toolResult(call.id, error, isError: true);
    }
    if (_bodyDataTools.contains(call.name) && !consents.body) {
      payloads.add(AvoWidgetPayload.consentRequest(AvoConsentKind.body));
      return AvoConversation.toolResult(
        call.id,
        'The person has not shared calories, weight and goals with Avo. The '
            'app shows a card to share them; ask them to tap it.',
        isError: true,
      );
    }
    final result = await _runTool(call.name, call.input, ref, context, payloads);
    final failed = result['error'] != null || result['not_available'] == true;
    return AvoConversation.toolResult(call.id, result, isError: failed);
  }

  /// Tools that read calories, weight or goals (server BODY_DATA_TOOLS).
  static const _bodyDataTools = {
    'get_nutrition_status',
    'get_weekly_nutrition_summary',
    'setup_nutrition_goal',
    'get_challenge_status',
  };

  Future<Map<String, Object?>> _runTool(
    String name,
    Map<String, Object?> args,
    WidgetRef ref,
    AvoContext? context,
    List<AvoWidgetPayload> payloads,
  ) async {
    try {
      switch (name) {
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
        case 'set_module':
          return await _toolSetModule(args, ref);
        case 'get_app_info':
          return _toolAppInfo(args);
        case 'search_offers':
          return await _toolSearchOffers(args, ref, context);
        case 'get_restock_suggestions':
          return await _toolRestockSuggestions(args);
        case 'get_personalized_deals':
          return await _toolGetPersonalizedDeals(args, ref);
        case 'split_trip_cost':
          return await _toolSplitTripCost(args);
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
        case 'log_workout':
          return await _toolLogWorkout(args);
        case 'get_weekly_nutrition_summary':
          return await _toolWeeklyNutritionSummary(ref);
        case 'get_challenge_status':
          return await _toolChallengeStatus(ref);
        case 'get_savings_summary':
          return await _toolSavingsSummary();
        case 'get_plan':
          return _toolGetPlan(args, ref);
        case 'add_to_plan':
          return await _toolAddToPlan(args, ref);
        case 'move_in_plan':
          return await _toolMoveInPlan(args, ref);
        case 'plan_to_list':
          return await _toolPlanToList(args, ref);
        case 'propose_delete':
          return await _toolProposeDelete(args, ref, payloads);
        default:
          return {
            'not_available': true,
            'error': _t(ref, 'avo_tool_not_available'),
          };
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

  /// Offers for one product at the market of the list in context (Kap. 12:
  /// only that market, never a comparison across markets, prices "laut
  /// Händler", "in deiner Region"). Without a region or a confirmed market
  /// it asks for it instead of searching.
  Future<Map<String, Object?>> _toolSearchOffers(
    Map<String, Object?> args,
    WidgetRef ref,
    AvoContext? context,
  ) async {
    final query = (args['query'] as String?)?.trim() ?? '';
    if (query.isEmpty) return {'error': 'query is required'};

    final region = await UserLocationService.instance.getRegion();
    if (region == null) {
      return {
        'found': 0,
        'note': 'No region set. Ask the user for their zip code (PLZ), set it '
            'via update_setting key "zip_code", then search again.',
      };
    }

    final listId = (args['list_id'] as String?) ??
        (context?.lists?.isNotEmpty == true ? context!.lists!.first.id : null);
    final store = listId == null ? null : ref.read(storeForListProvider(listId));
    if (store == null) {
      return {
        'found': 0,
        'note': 'The list has no confirmed market. Ask which market the user '
            'shops at; never compare markets.',
      };
    }

    final offers = await OfferPriceService.instance
        .searchOffers(query, zipCode: region.zip, chainId: store.id);
    if (offers.isEmpty) {
      return {
        'found': 0,
        'store': store.name,
        'note': 'No current offer for "$query" at ${store.name} in the '
            "user's region.",
      };
    }

    final top = offers.take(5).toList();
    return {
      'found': top.length,
      'store': store.name,
      'wording': 'Say "bei ${store.name} im Angebot, in deiner Region" and '
          '"laut Händler" for any regular price. Never compare markets.',
      'offers': [
        for (final o in top)
          {
            'product': o.productName,
            'price': o.price,
            if (o.regularPrice != null) 'regular_price_per_retailer': o.regularPrice,
            'unit': o.unitShortName,
          },
      ],
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

  // ── Modules, workouts, meal plan, deletions ──────────────────────

  static AppModule? _moduleFromId(String? id) {
    for (final module in AppModule.values) {
      if (module.storageKey == id) return module;
    }
    return null;
  }

  Future<Map<String, Object?>> _toolSetModule(
    Map<String, Object?> args,
    WidgetRef ref,
  ) async {
    final module = _moduleFromId(args['module'] as String?);
    final enabled = args['enabled'] as bool?;
    if (module == null || enabled == null) {
      return {'error': 'module and enabled are required'};
    }
    if (!module.released) {
      return {'not_available': true, 'error': _t(ref, 'avo_tool_not_available')};
    }
    await ref.read(appModulesProvider.notifier).setEnabled(module, enabled);
    return {'success': true, 'module': module.storageKey, 'enabled': enabled};
  }

  /// What the app knows at runtime; the static app knowledge is in the
  /// server's system prompt.
  Map<String, Object?> _toolAppInfo(Map<String, Object?> args) {
    final subscription = SubscriptionService.instance;
    switch (args['topic']) {
      case 'my_subscription':
        return {'is_pro': subscription.isSubscribed, 'plan_name': AppBrand.proName};
      case 'pro_plan':
        return {
          'plan_name': AppBrand.proName,
          'offers_are_never_pro': true,
          'prices_from_app_store': [
            for (final p in subscription.products)
              {'title': p.title, 'price': p.price},
          ],
        };
      default:
        return {'error': 'topic must be pro_plan or my_subscription'};
    }
  }

  Future<Map<String, Object?>> _toolLogWorkout(Map<String, Object?> args) async {
    final activity = (args['activity'] as String?)?.trim() ?? '';
    final minutes = (args['duration_min'] as num?)?.toInt() ?? 0;
    if (activity.isEmpty || minutes <= 0) {
      return {'error': 'activity and duration_min are required'};
    }
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return {'error': 'not signed in'};
    final lower = activity.toLowerCase();
    final type = WorkoutType.values.firstWhere(
      (t) => lower.contains(t.name),
      orElse: () => WorkoutType.other,
    );
    final given = (args['calories'] as num?)?.toInt();
    final kcal = given ??
        estimateWorkoutCalories(
          type: type,
          intensity: WorkoutIntensity.moderate,
          durationMin: minutes,
        ).kcal;
    final now = DateTime.now();
    await WorkoutLogService.instance.upsert(Workout(
      id: const Uuid().v4(),
      userId: userId,
      startedAt: now.subtract(Duration(minutes: minutes)),
      durationMin: minutes,
      type: type,
      calories: kcal,
      createdAt: now,
    ));
    return {
      'success': true,
      'activity': type.name,
      'duration_min': minutes,
      'calories': kcal,
      'calories_estimated': given == null,
    };
  }

  bool _planOn(WidgetRef ref) => ref.read(moduleEnabledProvider(AppModule.mealPlan));

  Map<String, Object?> _planOff(WidgetRef ref) =>
      {'not_available': true, 'error': _t(ref, 'avo_plan_module_off')};

  static String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime? _day(Object? value) {
    final parsed = DateTime.tryParse(value as String? ?? '');
    return parsed == null ? null : DateTime(parsed.year, parsed.month, parsed.day);
  }

  Map<String, Object?> _toolGetPlan(Map<String, Object?> args, WidgetRef ref) {
    if (!_planOn(ref)) return _planOff(ref);
    final now = DateTime.now();
    final from = _day(args['from']) ?? DateTime(now.year, now.month, now.day);
    final days = ((args['days'] as num?)?.toInt() ?? 7).clamp(1, 14);
    return {
      'from': _ymd(from),
      'days': days,
      'entries': [
        for (var i = 0; i < days; i++)
          for (final e in ref.read(planEntriesForDayProvider(from.add(Duration(days: i)))))
            {
              'entry_id': e.id,
              'date': _ymd(e.planDate),
              'recipe': e.snapshot.name,
              'servings': e.servings,
              if (e.snapshot.kcalPerServing != null)
                'kcal_per_serving': e.snapshot.kcalPerServing,
              'on_list': e.isSent,
            },
      ],
    };
  }

  Future<Map<String, Object?>> _toolAddToPlan(
    Map<String, Object?> args,
    WidgetRef ref,
  ) async {
    if (!_planOn(ref)) return _planOff(ref);
    final day = _day(args['date']);
    if (day == null) return {'error': 'date must be YYYY-MM-DD'};
    final recipe = await _resolveRecipe(
      args['recipe_id'] as String?,
      args['recipe_name'] as String?,
    );
    if (recipe == null) return {'error': 'Recipe not found'};
    final servings = (args['servings'] as num?)?.toInt() ??
        ref.read(mealPlanSettingsProvider).defaultServings;
    final added = await ref
        .read(mealPlanControllerProvider)
        .addRecipeToPlan(recipe.id, day, servings, recipe: recipe);
    if (added == null) return {'error': 'Recipe not found'};
    return {
      'success': true,
      'entry_id': added.entry.id,
      'date': _ymd(day),
      'recipe': recipe.name,
      'servings': servings,
    };
  }

  Future<Map<String, Object?>> _toolMoveInPlan(
    Map<String, Object?> args,
    WidgetRef ref,
  ) async {
    if (!_planOn(ref)) return _planOff(ref);
    final id = args['entry_id'] as String?;
    final day = _day(args['date']);
    if (id == null || day == null) return {'error': 'entry_id and date are required'};
    await ref.read(mealPlanControllerProvider).moveEntry(id, day);
    return {'success': true, 'entry_id': id, 'date': _ymd(day)};
  }

  Future<Map<String, Object?>> _toolPlanToList(
    Map<String, Object?> args,
    WidgetRef ref,
  ) async {
    if (!_planOn(ref)) return _planOff(ref);
    final from = _day(args['from']);
    final listId = args['list_id'] as String?;
    if (from == null || listId == null) return {'error': 'from and list_id are required'};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = await ref.read(mealPlanControllerProvider).sendToList(
          weekStart: planWeekStart(from),
          range: from.isAfter(today) || from == today
              ? PlanRange.fromToday
              : PlanRange.wholeWeek,
          listId: listId,
          noteFor: (names) => names.isEmpty ? null : names.join(', '),
        );
    return {
      'success': result.failedNames.isEmpty,
      'added': result.addedCount,
      if (result.failedNames.isNotEmpty) 'failed': result.failedNames,
    };
  }

  /// Avo cannot delete: it asks for a card, and only the person's tap on it
  /// deletes ([confirmPendingDelete]). The card shows the app's own stored
  /// name, never the model's [label].
  Future<Map<String, Object?>> _toolProposeDelete(
    Map<String, Object?> args,
    WidgetRef ref,
    List<AvoWidgetPayload> payloads,
  ) async {
    final target = avoDeleteTargetFromJson(args['target_type'] as String?);
    final id = (args['target_id'] as String?)?.trim() ?? '';
    final label = (args['label'] as String?)?.trim() ?? '';
    if (target == null || id.isEmpty) {
      return {'error': 'target_type and target_id are required'};
    }
    final found = await _lookUpDeleteTarget(target, id);
    if (found == null) {
      return {'error': 'Nothing with this id exists for the person, or it cannot be deleted from Avo yet.'};
    }
    if (label.isNotEmpty && !_sameName(found.name, label)) {
      return {'error': 'This id belongs to "${found.name}", not "$label". Check the id first.'};
    }
    final pending = _pendingDeletes.propose(
      target: target,
      targetId: id,
      name: found.name,
      parentId: found.parentId,
      version: found.version,
    );
    payloads.add(AvoWidgetPayload.confirmDelete(pending));
    return {
      'shown': true,
      'note': 'The app shows a confirmation card. Nothing is deleted until the person taps it.',
    };
  }

  static bool _sameName(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase() ||
      a.toLowerCase().contains(b.toLowerCase()) ||
      b.toLowerCase().contains(a.toLowerCase());

  /// The target as the person's own rights see it (RLS); null when it does
  /// not exist for them or Avo cannot delete that kind yet.
  Future<({String name, String? parentId, String? version})?> _lookUpDeleteTarget(
    AvoDeleteTarget target,
    String id,
  ) async {
    switch (target) {
      case AvoDeleteTarget.item:
        final row = await _supabase
            .from('shopping_items')
            .select('name, list_id, updated_at')
            .eq('id', id)
            .maybeSingle();
        if (row == null) return null;
        return (
          name: row['name'] as String? ?? '',
          parentId: row['list_id'] as String?,
          version: row['updated_at']?.toString(),
        );
      case AvoDeleteTarget.list:
        final row = await _supabase
            .from('shopping_lists')
            .select('name, updated_at')
            .eq('id', id)
            .maybeSingle();
        if (row == null) return null;
        return (
          name: row['name'] as String? ?? '',
          parentId: null,
          version: row['updated_at']?.toString(),
        );
      case AvoDeleteTarget.foodLog:
        final row = await _supabase
            .from('food_log_entries')
            .select('food_name')
            .eq('id', id)
            .maybeSingle();
        if (row == null) return null;
        return (name: row['food_name'] as String? ?? '', parentId: null, version: null);
      case AvoDeleteTarget.planEntry:
      case AvoDeleteTarget.historyTrip:
      case AvoDeleteTarget.listMember:
        return null;
    }
  }

  /// Runs a deletion Avo proposed, from the tap on its card: only with the
  /// one-time [token], within 10 minutes and while the target is unchanged.
  /// A typed or spoken "ja" never gets here.
  Future<bool> confirmPendingDelete(String token, WidgetRef ref) async {
    final pending = _pendingDeletes.take(token);
    if (pending == null) return false;
    final current = await _lookUpDeleteTarget(pending.target, pending.targetId);
    if (current == null || current.version != pending.version) return false;
    switch (pending.target) {
      case AvoDeleteTarget.item:
        final listId = pending.parentId;
        if (listId == null) return false;
        await ref.read(itemsNotifierProvider(listId).notifier).deleteItem(pending.targetId);
      case AvoDeleteTarget.list:
        await ref.read(listsNotifierProvider.notifier).deleteList(pending.targetId);
      case AvoDeleteTarget.foodLog:
        await FoodLogService.instance.deleteEntry(pending.targetId);
        invalidateNutritionLog(ref);
      case AvoDeleteTarget.planEntry:
      case AvoDeleteTarget.historyTrip:
      case AvoDeleteTarget.listMember:
        return false;
    }
    return true;
  }

  /// Nutrition per serving from the server task `nutrition_estimate`.
  Future<Map<String, Object?>> _estimateNutrition(Recipe recipe) async {
    final ingredients = recipe.ingredients
        .map((i) => '- ${i.amount} ${i.unit} ${i.name}'.trim())
        .join('\n');
    final estimate = await _askNutrition(
      '${recipe.name}\n$ingredients',
      servings: recipe.defaultServings,
    );
    return estimate ?? {'error': 'No estimate available'};
  }

  /// Nutrition of a free-text food ("1 Banane", "200 g Hähnchenbrust").
  Future<Map<String, Object?>?> _estimateFoodNutrition(String description) =>
      _askNutrition(description);

  Future<Map<String, Object?>?> _askNutrition(String text, {int? servings}) async {
    try {
      final result = await ClaudeService.instance.run(
        'nutrition_estimate',
        {'text': text, if (servings != null && servings > 0) 'servings': servings},
        timeout: const Duration(seconds: 15),
      );
      final kcal = (result['kcal'] as num?)?.round();
      if (kcal == null) return null;
      return {
        'calories': kcal,
        'protein_g': (result['protein_g'] as num?)?.toDouble(),
        'carbs_g': (result['carbs_g'] as num?)?.toDouble(),
        'fat_g': (result['fat_g'] as num?)?.toDouble(),
        'estimated': true,
      };
    } on ClaudeException catch (e) {
      debugPrint('❌ [AVO] Nutrition estimate failed: ${e.code}');
      return null;
    }
  }

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
        ref.read(itemRepositoryProvider).sendItemAddedNotification(
              listId: listId,
              itemName: addedItemName,
            );
      }
    } catch (e) {
      debugPrint('⚠️ [AVO] Post-change bookkeeping failed: $e');
    }
  }

  // ── Context builder ──────────────────────────────────────────────


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

}

/// An answer stream that ended with an error event (code as in
/// [ClaudeException]).
class _AvoStreamFailure implements Exception {
  const _AvoStreamFailure(this.code);

  final String code;
}

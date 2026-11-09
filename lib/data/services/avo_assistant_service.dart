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
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/models/weekly_nutrition_summary.dart';
import 'package:shoply/data/models/workout.dart';
import 'package:shoply/data/repositories/item_repository.dart';
import 'package:shoply/data/repositories/list_repository.dart';
import 'package:shoply/data/services/allergen_matcher.dart';
import 'package:shoply/data/services/avo_assistant_models.dart';
import 'package:shoply/data/services/avo_consent_filter.dart';
import 'package:shoply/data/services/avo_consents.dart';
import 'package:shoply/data/services/avo_conversation.dart';
import 'package:shoply/data/services/avo_list_changes.dart';
import 'package:shoply/data/services/avo_stores.dart';
import 'package:shoply/data/services/avo_tool_gates.dart';
import 'package:shoply/data/services/avo_tool_writes.dart';
import 'package:shoply/data/services/avo_nudge_service.dart';
import 'package:shoply/data/services/avo_settings_bridge.dart';
import 'package:shoply/data/services/claude_service.dart';
import 'package:shoply/data/services/food_log_service.dart';
import 'package:shoply/data/services/mascot_notification_service.dart';
import 'package:shoply/data/services/meal_photo_storage_service.dart';
import 'package:shoply/data/services/meal_plan_aggregator.dart';
import 'package:shoply/data/services/meal_plan_repository.dart' show MealPlanUndo;
import 'package:shoply/data/services/nutrition_goal_service.dart';
import 'package:shoply/data/services/offer_price_service.dart';
import 'package:shoply/data/services/offer_savings.dart';
import 'package:shoply/data/services/recipe_service.dart';
import 'package:shoply/data/services/shopping_history_service.dart';
import 'package:shoply/data/services/subscription_service.dart';
import 'package:shoply/data/services/unread_service.dart';
import 'package:shoply/data/services/user_location_service.dart';
import 'package:shoply/data/services/water_log_service.dart';
import 'package:shoply/data/services/weight_log_service.dart';
import 'package:shoply/data/services/workout_log_service.dart';
import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/providers/avo_screen_context_provider.dart';
import 'package:shoply/presentation/providers/list_offer_prefs_provider.dart';
import 'package:shoply/presentation/providers/meal_plan_provider.dart';
import 'package:shoply/presentation/providers/offer_display_prefs_provider.dart';
import 'package:shoply/presentation/providers/price_comparison_provider.dart';
import 'package:shoply/presentation/providers/region_provider.dart';
import 'package:shoply/presentation/providers/store_for_list_provider.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/diet_challenge_provider.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/state/language_provider.dart';
import 'package:shoply/presentation/state/lists_provider.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';
import 'package:shoply/presentation/state/theme_provider.dart';

export 'package:shoply/data/services/avo_assistant_models.dart';

part 'avo_tools_lists.dart';
part 'avo_tools_history.dart';
part 'avo_tools_recipes.dart';
part 'avo_tools_health.dart';
part 'avo_tools_offers.dart';
part 'avo_tools_settings.dart';

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

  /// Read when used, so tests can make the service without Supabase.
  SupabaseClient get _supabase => Supabase.instance.client;

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
  ///
  /// [onText] gets the answer text while it is written, [onTool] each tool
  /// right before the app runs it (the tab's "Schreibt auf Wocheneinkauf"),
  /// [onPayload] each card as soon as its tool is done.
  Future<AvoResponse> chat(
    String userMessage, {
    required WidgetRef ref,
    AvoContext? context,
    void Function(String delta)? onText,
    void Function(String name, Map<String, Object?> input)? onTool,
    void Function(AvoWidgetPayload payload)? onPayload,
  }) async {
    return _ask(
      userMessage,
      ref,
      context,
      onText: onText ?? (_) {},
      onTool: onTool,
      onPayload: onPayload,
    );
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
    void Function(String name, Map<String, Object?> input)? onTool,
    void Function(AvoWidgetPayload payload)? onPayload,
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
          onTool?.call(call.name, call.input);
          final before = payloads.length;
          results.add(await _runToolCall(call, ref, context, payloads, consents));
          for (var i = before; i < payloads.length; i++) {
            onPayload?.call(payloads[i]);
          }
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
        errorCode: failure.code,
        retryAfterS: failure.retryAfterS,
      );
    } catch (e) {
      _conversation.rollback(mark);
      debugPrint('❌ [AVO] Chat error: $e');
      return AvoResponse(
        message: _t(ref, 'avo_error_generic'),
        payloads: payloads,
        expression: AvoExpressionType.confused,
        errorCode: 'generic',
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
        case AvoStreamError(:final code, :final retryAfterS):
          throw _AvoStreamFailure(code, retryAfterS: retryAfterS);
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
  /// [run] stands in for the tool itself in tests ([debugRunToolCall]).
  Future<Map<String, dynamic>> _runToolCall(
    AvoToolCall call,
    WidgetRef ref,
    AvoContext? context,
    List<AvoWidgetPayload> payloads,
    ({bool health, bool body}) consents, {
    Future<Map<String, Object?>> Function()? run,
  }) async {
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
    final before = payloads.length;
    final result = avoConsentFilter(
      call.name,
      await (run?.call() ??
          _runTool(call.name, call.input, ref, context, payloads, consents)),
      health: consents.health,
      body: consents.body,
    );
    // A write without a card of its own still counts as done for a retry.
    await avoNoteWrite(
      payloads,
      before: before,
      tool: call.name,
      input: call.input,
      result: result,
      listName: (id) => _changes(ref).listName(id),
    );
    // A calories tool with the module off: the card offers "Einschalten"
    // (once per answer). Never for the meal plan while it is unreleased.
    if (result['tracking_enabled'] == false &&
        !payloads.any((p) =>
            p.kind == AvoPayloadKind.moduleOff &&
            p.module == AppModule.calories)) {
      payloads.add(AvoWidgetPayload.moduleOff(AppModule.calories));
    }
    final failed = result['error'] != null || result['not_available'] == true;
    return AvoConversation.toolResult(call.id, result, isError: failed);
  }

  /// The tool-result path for tests: [name] with [input] as the model would
  /// call it, with the consents; [run] replaces the tool (to check what the
  /// filter and the markers do with its result).
  @visibleForTesting
  Future<Map<String, dynamic>> debugRunToolCall(
    String name,
    Map<String, Object?> input,
    WidgetRef ref,
    List<AvoWidgetPayload> payloads, {
    required bool health,
    required bool body,
    Future<Map<String, Object?>> Function()? run,
  }) => _runToolCall(
    AvoToolCall(id: 'test', name: name, input: input),
    ref,
    null,
    payloads,
    (health: health, body: body),
    run: run,
  );

  /// A service for tests (no conversation shared with the app's).
  @visibleForTesting
  factory AvoAssistantService.forTest() => AvoAssistantService._();

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
    ({bool health, bool body}) consents,
  ) async {
    try {
      switch (name) {
        case 'search_recipes':
          return await _toolSearchRecipes(args, context, payloads);
        case 'get_saved_recipes':
          return await _toolSavedRecipes(payloads);
        case 'get_recipe_nutrition':
          return await _toolRecipeNutrition(args, payloads);
        case 'add_recipe_to_list':
          return await _toolAddRecipeToList(args, ref, payloads);
        case 'get_shopping_history':
          return await _toolShoppingHistory(args, ref, context, payloads);
        case 'get_lists':
          return await _toolGetLists(ref, payloads);
        case 'get_list_contents':
          return await _toolGetListContents(args, context, payloads);
        case 'add_item_to_list':
          return await _toolAddItem(args, ref, payloads);
        case 'ask_pick_list':
          return await _toolPickList(args, payloads);
        case 'check_items':
          return await _toolCheckItems(args, ref, payloads);
        case 'complete_list':
          return await _toolCompleteList(args, ref, payloads);
        case 'add_history_items_to_list':
          return await _toolAddHistoryItems(args, ref, payloads);
        case 'update_setting':
          return await _toolUpdateSetting(args, ref, payloads, consents);
        case 'set_module':
          return await _toolSetModule(args, ref, payloads);
        case 'get_app_info':
          return _toolAppInfo(args, payloads);
        case 'show_settings_link':
          return toolSettingsLink(args, payloads);
        case 'search_offers':
          return await _toolSearchOffers(args, ref, context, payloads);
        case 'get_restock_suggestions':
          return await _toolRestockSuggestions(args, ref, context, payloads);
        case 'get_personalized_deals':
          return await _toolGetPersonalizedDeals(args, ref, context, payloads);
        case 'split_trip_cost':
          return await _toolSplitTripCost(args, ref, payloads);
        case 'update_item':
          return await _toolUpdateItem(args, ref, payloads);
        case 'move_items':
          return await _toolMoveItems(args, ref, payloads);
        case 'create_list':
          return await _toolCreateList(args, ref, payloads);
        case 'rename_list':
          return await _toolRenameList(args, ref, payloads);
        case 'get_user_profile':
          return await _toolGetUserProfile(ref);
        case 'setup_nutrition_goal':
          return await _toolSetupNutritionGoal(args, ref, payloads);
        case 'get_nutrition_status':
          return await _toolNutritionStatus(ref, payloads);
        case 'log_food':
          return await _toolLogFood(args, ref, payloads);
        case 'log_water':
          return await _toolLogWater(args, ref, payloads);
        case 'log_weight':
          return await _toolLogWeight(args, ref, payloads);
        case 'log_workout':
          return await _toolLogWorkout(args, ref, payloads);
        case 'get_weekly_nutrition_summary':
          return await _toolWeeklyNutritionSummary(ref, payloads);
        case 'get_challenge_status':
          return await _toolChallengeStatus(ref, payloads);
        case 'get_savings_summary':
          return await _toolSavingsSummary(ref, payloads);
        case 'get_plan':
          return _toolGetPlan(args, ref, payloads);
        case 'add_to_plan':
          return await _toolAddToPlan(args, ref, payloads);
        case 'move_in_plan':
          return await _toolMoveInPlan(args, ref, payloads);
        case 'plan_to_list':
          return await _toolPlanToList(args, ref, payloads);
        case 'propose_delete':
          return await _toolProposeDelete(args, ref, payloads);
        default:
          return {
            'not_available': true,
            'error': _t(ref, 'avo_tool_not_available'),
          };
      }
    } catch (e) {
      // Never the exception's text (it can hold rows or ids) to the model.
      debugPrint('❌ [AVO] Tool $name failed: ${e.runtimeType}');
      return {
        'error': 'tool_failed',
        'note': 'The app could not do that right now. Say so briefly; the '
            'person can try again.',
      };
    }
  }

  // ── Tool implementations ─────────────────────────────────────────

  /// Avo's list changes with the person's providers.
  static AvoListChanges _changes(WidgetRef ref) =>
      AvoListChanges(_RefListWriter(ref));

  static Future<List<ShoppingItemModel>> _itemsOrEmpty(
    ItemRepository repository,
    String listId,
  ) async {
    try {
      return await repository.getListItems(listId);
    } catch (e) {
      debugPrint('⚠️ [AVO] Items not loaded for the card: $e');
      return const [];
    }
  }

  // ── Profile & preference-guidance tools ─────────────────────────

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ── Nutrition / calorie-tracking tools ───────────────────────────

  static const _trackingDisabledNote =
      'Calorie tracking is turned off for this user, so nothing was logged '
      'or read. The app shows a card to turn the module on; if they ask you '
      'to, call set_module with module "calories" and enabled true.';

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

  /// What the person saved through offers, as the app says it: rounded to
  /// 10 ct with "ca.", nothing below 0,50 € and nothing without a real
  /// region ([realRegion]); the same helpers as the history screen
  /// ([totalSavingsOf], [tripsInMonth]).
  @visibleForTesting
  static Map<String, Object?> summarizeSavings(
    List<ShoppingHistory> history,
    DateTime now, {
    required bool realRegion,
  }) {
    int? rounded(Iterable<ShoppingHistory> trips) {
      if (!realRegion) return null;
      final cents = (totalSavingsOf(trips) * 100).round();
      return roundedSavingsCents(cents < 0 ? 0 : cents);
    }

    double? euros(int? cents) => cents == null ? null : cents / 100;
    final month = tripsInMonth(history, year: now.year, month: now.month).toList();
    final prev = DateTime(now.year, now.month - 1);
    final monthCents = rounded(month);
    final prevCents = rounded(
      tripsInMonth(history, year: prev.year, month: prev.month),
    );
    final totalCents = rounded(history);
    return {
      'month_trips': month.length,
      'month_saved_cents': monthCents,
      if (monthCents != null) 'month_saved_about_eur': euros(monthCents),
      if (prevCents != null) 'prev_month_saved_about_eur': euros(prevCents),
      if (totalCents != null) 'total_saved_about_eur': euros(totalCents),
      'note': realRegion
          ? 'Amounts are already rounded ("ca."), according to the retailer; '
              'say them as they are. A missing month amount means no savings '
              'were recorded for it.'
          : 'No region is set, so there is no savings figure.',
    };
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
    return avoMealAt(DateTime.now());
  }

  static double _round1(double v) => (v * 10).round() / 10;

  // ── Modules, workouts, meal plan, deletions ──────────────────────

  static AppModule? _moduleFromId(String? id) {
    for (final module in AppModule.values) {
      if (module.storageKey == id) return module;
    }
    return null;
  }

  /// Words people use for a workout, to its type ("Joggen" is running).
  static const Map<String, WorkoutType> _workoutWords = {
    'jogg': WorkoutType.running,
    'lauf': WorkoutType.running,
    'run': WorkoutType.running,
    'spazier': WorkoutType.walking,
    'walk': WorkoutType.walking,
    'gehen': WorkoutType.walking,
    'rad': WorkoutType.cycling,
    'bike': WorkoutType.cycling,
    'cycl': WorkoutType.cycling,
    'schwimm': WorkoutType.swimming,
    'swim': WorkoutType.swimming,
    'kraft': WorkoutType.strength,
    'strength': WorkoutType.strength,
    'gym': WorkoutType.strength,
    'yoga': WorkoutType.yoga,
    'hiit': WorkoutType.hiit,
    'wander': WorkoutType.hiking,
    'hik': WorkoutType.hiking,
    'tanz': WorkoutType.dance,
    'danc': WorkoutType.dance,
  };

  /// A row to Konto or Konto löschen (A8, Kap. 16 5.7): the account is
  /// never changed through Avo, the person acts on that page.
  @visibleForTesting
  static Map<String, Object?> toolSettingsLink(
    Map<String, Object?> args,
    List<AvoWidgetPayload> payloads,
  ) {
    final page = AvoSettingsLink.fromId(args['page'] as String?);
    if (page == null) return {'error': 'page must be account or account_delete'};
    payloads.add(AvoWidgetPayload.settingsLinkTo(page));
    return {
      'shown': true,
      'page': page.id,
      'note': 'A row to that page is shown; nothing changed. The person does '
          'it there.',
    };
  }

  @visibleForTesting
  static WorkoutType workoutTypeOf(String activity) {
    final lower = activity.toLowerCase();
    for (final e in _workoutWords.entries) {
      if (lower.contains(e.key)) return e.value;
    }
    return WorkoutType.other;
  }

  static String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime? _day(Object? value) {
    final parsed = DateTime.tryParse(value as String? ?? '');
    return parsed == null ? null : DateTime(parsed.year, parsed.month, parsed.day);
  }

  static bool _sameName(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase() ||
      a.toLowerCase().contains(b.toLowerCase()) ||
      b.toLowerCase().contains(a.toLowerCase());

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

/// [AvoListWriter] on the person's providers: writes go through the items
/// and lists notifiers (optimistic state, offline queue, pushes) like the list
/// screens.
class _RefListWriter implements AvoListWriter {
  const _RefListWriter(this.ref);

  final WidgetRef ref;

  @override
  Future<List<ShoppingItemModel>> itemsOf(String listId) =>
      ref.read(itemRepositoryProvider).getListItems(listId);

  @override
  List<ShoppingItemModel>? shownItems(String listId) =>
      ref.exists(itemsNotifierProvider(listId))
          ? ref.read(itemsNotifierProvider(listId)).valueOrNull
          : null;

  @override
  Future<void> addItem(
    String listId, {
    required String name,
    required double quantity,
    String? unit,
  }) =>
      ref
          .read(itemsNotifierProvider(listId).notifier)
          .addItem(name: name, quantity: quantity, unit: unit);

  @override
  Future<List<ShoppingItemModel>> addItems(
    String listId,
    List<NewItem> items,
  ) async =>
      (await ref.read(itemRepositoryProvider).addItems(listId, items)).items;

  @override
  Future<void> deleteItem(String listId, String itemId) =>
      ref.read(itemsNotifierProvider(listId).notifier).deleteItem(itemId);

  @override
  Future<void> updateItem(
    String listId,
    String itemId,
    Map<String, dynamic> updates,
  ) =>
      ref.read(itemsNotifierProvider(listId).notifier).updateItem(itemId, updates);

  @override
  Future<void> setChecked(String listId, String itemId, bool checked) async {
    await ref.read(itemRepositoryProvider).toggleItemChecked(itemId, checked);
  }

  // Minor 7 of the W1 review (open): this creates a notifier, and with it a
  // realtime channel, for a list that may not be open.
  @override
  Future<void> moveItem(String fromListId, String toListId, String itemId) =>
      ref
          .read(itemsNotifierProvider(fromListId).notifier)
          .updateItem(itemId, {'list_id': toListId});

  @override
  Future<void> deleteList(String listId) =>
      ref.read(listsNotifierProvider.notifier).deleteList(listId);

  @override
  Future<void> renameList(String listId, String name) =>
      ref.read(listsNotifierProvider.notifier).updateList(listId, {'name': name});

  @override
  Future<List<ShoppingListModel>> lists() =>
      ListRepository.instance.getUserLists();

  @override
  List<ShoppingListModel>? shownLists() =>
      ref.read(listsNotifierProvider).valueOrNull;

  @override
  void changed(Iterable<String> listIds) {
    for (final id in listIds) {
      ref.invalidate(itemsNotifierProvider(id));
    }
    ref.invalidate(listsNotifierProvider);
  }
}

/// An answer stream that ended with an error event (code as in
/// [ClaudeException]).
class _AvoStreamFailure implements Exception {
  const _AvoStreamFailure(this.code, {this.retryAfterS});

  final String code;
  final int? retryAfterS;
}

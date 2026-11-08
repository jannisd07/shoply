import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/categories.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/meal_plan.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/services/ai_categorization_service.dart';
import 'package:shoply/data/services/category_order_service.dart';
import 'package:shoply/data/services/ingredient_substitution_service.dart';
import 'package:shoply/data/services/meal_plan_aggregator.dart';
import 'package:shoply/data/services/meal_plan_list_writer.dart';
import 'package:shoply/data/services/meal_plan_repository.dart';
import 'package:shoply/data/services/offline_cache_service.dart';
import 'package:shoply/data/services/recipe_service.dart';
import 'package:shoply/presentation/screens/recipes/recipe_user_diet.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/state/language_provider.dart';
import 'package:shoply/presentation/state/last_list_provider.dart';
import 'package:uuid/uuid.dart';

// Wochenplan (B7): providers for the plan screens (B7 P2), the home card
// "Heute kochen", the calories diary ("Aus dem Plan"), the widget and Avo's
// plan tools. Data and logic only; no widgets here.
//
// Module rule: everything that shows plan content to the person checks
// moduleEnabledProvider(AppModule.mealPlan) at the surface; kcal only appear
// with AppModule.calories.

// ---------------------------------------------------------------- injection

/// The server side per account; null keeps the plan on the device.
final mealPlanRemoteFactoryProvider =
    Provider<MealPlanRemote? Function(String userId)>((ref) => SupabaseMealPlanRemote.new);

final mealPlanClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// New entry ids (uuid v4, made on the device).
final mealPlanIdProvider = Provider<String Function()>((ref) => const Uuid().v4);

/// How ingredients get onto a list (Teil A's batch API today).
final mealPlanListWriterProvider = Provider<MealPlanListWriter>((ref) => ItemRepositoryPlanListWriter());

/// Local category id of a name, without waiting for the AI.
final mealPlanCategorizerProvider =
    Provider<String Function(String name)>((ref) => AiCategorizationService.instance.categorizeLocal);

/// A recipe by id: the device cache first, then the server; null when gone.
final mealPlanRecipeLookupProvider = Provider<Future<Recipe?> Function(String id)>((ref) {
  return (id) async {
    for (final r in OfflineCacheService.instance.getCachedRecipesSync() ?? const <Recipe>[]) {
      if (r.id == id) return r;
    }
    try {
      return await RecipeService.instance.getRecipeById(id);
    } catch (e) {
      debugPrint('⚠️ [MEAL_PLAN] Recipe $id not available: $e');
      return null;
    }
  };
});

/// Diet and allergy replacements of the signed-in person, or null.
final mealPlanSubstituterProvider = Provider<PlanSubstituter?>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null || !user.hasDietProfile) return null;
  final allergies = user.allergyTypes;
  final diets = user.dietTypes;
  return (ingredients) => [
        for (final i in IngredientSubstitutionService.getIngredientsWithSubstitutions(
          ingredients: ingredients,
          allergies: allergies,
          diets: diets,
        ))
          i.needsSubstitution && i.bestSubstitute != null
              ? PlanSubstitution(ingredient: i.adaptedIngredient, reason: i.reasons.join(', '))
              : null,
      ];
});

/// Unchecked items of a list: live when the list is loaded, else the cache.
final planListItemsProvider = Provider.family<List<ShoppingItemModel>, String>((ref, listId) {
  final live = ref.watch(itemsNotifierProvider(listId)).valueOrNull ??
      OfflineCacheService.instance.getCachedListItemsSync(listId) ??
      const <ShoppingItemModel>[];
  return [for (final i in live) if (!i.isChecked) i];
});

/// Reloads a list after the plan wrote to it.
final planListRefreshProvider = Provider<Future<void> Function(String listId)>((ref) {
  return (listId) => ref.read(itemsNotifierProvider(listId).notifier).loadItems();
});

/// Item id → amounts the plan put on that list (W-17).
final planContributionsProvider =
    FutureProvider.family<Map<String, List<PlanContribution>>, String>((ref, listId) {
  return ref.watch(mealPlanListWriterProvider).contributionsForList(listId);
});

/// Category order of a list (custom order or the market default).
final planCategoryOrderProvider = FutureProvider.family<List<String>, String>((ref, listId) {
  return CategoryOrderService().getCategoryOrder(listId);
});

// ---------------------------------------------------------------- store

final mealPlanRepositoryProvider = Provider<MealPlanRepository>((ref) {
  final userId = ref.watch(authUserIdProvider);
  final repo = MealPlanRepository(
    userId: userId ?? 'signed_out',
    remote: userId == null ? null : ref.watch(mealPlanRemoteFactoryProvider)(userId),
    now: ref.watch(mealPlanClockProvider),
    newId: ref.watch(mealPlanIdProvider),
  );
  ref.onDispose(repo.dispose);
  return repo;
});

/// The whole plan as loaded so far; updates on every change.
final mealPlanSnapshotProvider = StateNotifierProvider<MealPlanSnapshotNotifier, MealPlanSnapshot>((ref) {
  return MealPlanSnapshotNotifier(ref.watch(mealPlanRepositoryProvider));
});

class MealPlanSnapshotNotifier extends StateNotifier<MealPlanSnapshot> {
  MealPlanSnapshotNotifier(MealPlanRepository repo) : super(repo.snapshot) {
    _sub = repo.changes.listen((s) {
      if (mounted) state = s;
    });
    unawaited(repo.load());
  }

  late final StreamSubscription<MealPlanSnapshot> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final mealPlanSettingsProvider = Provider<MealPlanSettings>(
  (ref) => ref.watch(mealPlanSnapshotProvider.select((s) => s.settings)),
);

// ---------------------------------------------------------------- week

/// One day of the plan.
class PlanDay {
  const PlanDay({required this.date, required this.entries, this.kcalPerPerson, this.kcalIncomplete = false});

  final DateTime date;
  final List<MealPlanEntry> entries;

  /// One serving of each recipe ("pro Person", W-09). Null without the
  /// calories module or when no recipe has nutrition values.
  final int? kcalPerPerson;

  /// At least one recipe lacks values ("ab 480 kcal").
  final bool kcalIncomplete;

  bool get isEmpty => entries.isEmpty;
}

/// Monday to Sunday of one week.
class WeekPlan {
  const WeekPlan({required this.weekStart, required this.days, this.meta});

  final DateTime weekStart;
  final List<PlanDay> days;

  /// The week's own row (target list, first send), if any.
  final MealPlanWeek? meta;

  /// "4 von 7 Tagen geplant".
  int get plannedDayCount => days.where((d) => !d.isEmpty).length;

  int get entryCount => days.fold(0, (n, d) => n + d.entries.length);

  List<MealPlanEntry> get entries => [for (final d in days) ...d.entries];
}

/// The week containing [day] (pass any day; it is normalized to Monday).
/// Loads that week from the server once per app run in the background.
final weekPlanProvider = Provider.family<WeekPlan, DateTime>((ref, day) {
  final start = planWeekStart(day);
  final snapshot = ref.watch(mealPlanSnapshotProvider);
  final withKcal = ref.watch(moduleEnabledProvider(AppModule.calories));
  final repo = ref.watch(mealPlanRepositoryProvider);
  Future.microtask(() => repo.ensureWeek(start));

  final entries = snapshot.entriesForWeek(start);
  return WeekPlan(
    weekStart: start,
    meta: snapshot.week(start),
    days: [
      for (final date in planWeekDays(start))
        _planDay(date, [for (final e in entries) if (e.planDate == date) e], withKcal),
    ],
  );
});

PlanDay _planDay(DateTime date, List<MealPlanEntry> entries, bool withKcal) {
  if (!withKcal) return PlanDay(date: date, entries: entries);
  final known = [for (final e in entries) if (e.snapshot.kcalPerServing != null) e.snapshot.kcalPerServing!];
  return PlanDay(
    date: date,
    entries: entries,
    kcalPerPerson: known.isEmpty ? null : known.fold<int>(0, (a, b) => a + b),
    kcalIncomplete: known.isNotEmpty && known.length < entries.length,
  );
}

/// The entries of one local day, in order (calories "Aus dem Plan", the
/// home card, the widget).
final planEntriesForDayProvider = Provider.family<List<MealPlanEntry>, DateTime>((ref, day) {
  final d = planDay(day);
  return ref.watch(weekPlanProvider(planWeekStart(d))).days.firstWhere((p) => p.date == d).entries;
});

/// Where the week's ingredients go: the week's own list, else the default
/// from the settings, else the list opened last ("Liste von heute").
final planTargetListIdProvider = Provider.family<String?, DateTime>((ref, day) {
  final start = planWeekStart(day);
  final week = ref.watch(mealPlanSnapshotProvider.select((s) => s.week(start)));
  final settings = ref.watch(mealPlanSettingsProvider);
  return week?.targetListId ?? settings.targetListId ?? ref.watch(lastAccessedListProvider).valueOrNull;
});

// ---------------------------------------------------------------- ingredients

typedef PlanAggregationRequest = ({DateTime weekStart, PlanRange range, String listId});

/// "Zutaten der Woche" for one week, range and target list.
final planAggregationProvider = Provider.family<PlanAggregation, PlanAggregationRequest>((ref, request) {
  final week = ref.watch(weekPlanProvider(request.weekStart));
  final today = ref.watch(mealPlanClockProvider)();
  final entries = entriesInRange(week.entries, weekStart: week.weekStart, range: request.range, today: today);
  return _aggregate(ref, entries, request.listId);
});

PlanAggregation _aggregate(Ref ref, List<MealPlanEntry> entries, String? listId) {
  if (entries.isEmpty) return PlanAggregation.empty;
  final settings = ref.watch(mealPlanSettingsProvider);
  final contributions = listId == null
      ? const <String, List<PlanContribution>>{}
      : ref.watch(planContributionsProvider(listId)).valueOrNull ?? const {};
  final items = listId == null ? const <ShoppingItemModel>[] : ref.watch(planListItemsProvider(listId));
  final order = listId == null ? null : ref.watch(planCategoryOrderProvider(listId)).valueOrNull;
  return aggregatePlanIngredients(
    entries: entries,
    recipesById: {
      for (final r in OfflineCacheService.instance.getCachedRecipesSync() ?? const <Recipe>[]) r.id: r,
    },
    pantry: settings.pantry,
    openItems: [
      for (final i in items)
        PlanListItem(
          id: i.id,
          name: i.name,
          quantity: i.quantity,
          unit: i.unit,
          contributions: contributions[i.id] ?? const [],
        ),
    ],
    substitute: ref.watch(mealPlanSubstituterProvider),
    categoryOf: ref.watch(mealPlanCategorizerProvider),
    categoryOrder: order ?? Categories.allIds,
    localeCode: ref.watch(languageProvider),
  );
}

// ---------------------------------------------------------------- home card

enum TodayPlanHintKind {
  /// "Heute im Plan: Chili sin Carne."
  today,

  /// From 20:00: "Morgen im Plan: …".
  tomorrow,

  /// Sunday from 16:00, next week empty: "Nächste Woche ist noch leer".
  nextWeekEmpty,
}

/// Data for the home card "Heute kochen" (Konzept 14, 10.2). The card itself
/// is built on A's home (TodayHintSource contract, status-A request 5).
class TodayPlanHint {
  const TodayPlanHint({
    required this.kind,
    required this.day,
    this.entry,
    this.entryCount = 0,
    this.missingCount = 0,
    this.missingNames = const [],
    this.ingredientCount = 0,
    this.listId,
    this.sentListId,
    this.kcalPerServing,
  });

  final TodayPlanHintKind kind;

  /// The day shown; for [TodayPlanHintKind.nextWeekEmpty] next Monday.
  final DateTime day;

  /// The first recipe of the day by meal, then position.
  final MealPlanEntry? entry;

  /// Recipes on that day ("Alle" opens the plan at that day).
  final int entryCount;

  /// Ingredients still missing on the target list ("2 Zutaten fehlen
  /// noch"); 0 when everything is on a list.
  final int missingCount;

  /// Their names in recipe order ("Koriander und Paprika").
  final List<String> missingNames;

  /// Ingredients without pantry items ("4 von 6 Zutaten auf der Liste").
  final int ingredientCount;

  /// Target list of the day's week.
  final String? listId;

  /// Where the ingredients were sent, if they were.
  final String? sentListId;

  /// One serving, only with the calories module.
  final int? kcalPerServing;

  int get onListCount => ingredientCount - missingCount;

  /// "Zutaten für heute stehen auf Wocheneinkauf."
  bool get sentToOtherList => sentListId != null && sentListId != listId;
}

const _mealOrder = {
  MealType.breakfast: 0,
  MealType.lunch: 1,
  MealType.dinner: 2,
  MealType.snack: 3,
};

/// The home card's data, or null when there is nothing to show.
final todayPlanHintProvider = Provider<TodayPlanHint?>((ref) {
  if (!ref.watch(moduleEnabledProvider(AppModule.mealPlan))) return null;
  if (!ref.watch(mealPlanSettingsProvider).showTodayHint) return null;
  final now = ref.watch(mealPlanClockProvider)();
  final today = planDay(now);
  final tomorrow = planAddDays(today, 1);

  final tomorrowEntries = now.hour >= 20 ? ref.watch(planEntriesForDayProvider(tomorrow)) : const <MealPlanEntry>[];
  final todayEntries = ref.watch(planEntriesForDayProvider(today));
  final (kind, day, entries) = tomorrowEntries.isNotEmpty
      ? (TodayPlanHintKind.tomorrow, tomorrow, tomorrowEntries)
      : (TodayPlanHintKind.today, today, todayEntries);

  if (entries.isEmpty) {
    if (now.weekday != DateTime.sunday || now.hour < 16) return null;
    final nextWeek = planAddDays(planWeekStart(today), 7);
    final thisWeekUsed = ref.watch(weekPlanProvider(planWeekStart(today))).entryCount > 0;
    final nextWeekEmpty = ref.watch(weekPlanProvider(nextWeek)).entryCount == 0;
    return thisWeekUsed && nextWeekEmpty ? TodayPlanHint(kind: TodayPlanHintKind.nextWeekEmpty, day: nextWeek) : null;
  }

  final sorted = [...entries]..sort((a, b) {
      final byMeal = _mealOrder[a.mealType ?? MealType.dinner]!.compareTo(_mealOrder[b.mealType ?? MealType.dinner]!);
      return byMeal != 0 ? byMeal : a.position.compareTo(b.position);
    });
  final entry = sorted.first;
  final listId = ref.watch(planTargetListIdProvider(day));
  // All ingredients of the recipe (without pantry), and of those the ones
  // the servings not yet sent still need from the target list.
  final ingredientCount =
      _aggregate(ref, [entry.clearSent()], null).lines.where((l) => l.reason != PlanLineReason.pantry).length;
  final missing = entry.openServings == 0
      ? const <String>[]
      : _aggregate(ref, [entry], listId).missingNamesByEntry[entry.id] ?? const <String>[];

  return TodayPlanHint(
    kind: kind,
    day: day,
    entry: entry,
    entryCount: entries.length,
    missingCount: missing.length,
    missingNames: missing,
    ingredientCount: ingredientCount,
    listId: listId,
    sentListId: entry.sentListId,
    kcalPerServing: ref.watch(moduleEnabledProvider(AppModule.calories)) ? entry.snapshot.kcalPerServing : null,
  );
});

// ---------------------------------------------------------------- actions

/// What "auf die Liste" did, for the success moment, the toast and undo.
class PlanSendResult {
  const PlanSendResult({
    this.listToken,
    this.planUndo = const MealPlanUndo(),
    this.firstSend = false,
    this.addedCount = 0,
    this.failedNames = const [],
    this.listId,
  });

  /// Undo token of the list batch.
  final String? listToken;
  final MealPlanUndo planUndo;

  /// First send of the week: success moment with Avo (W-13/E-15).
  final bool firstSend;

  /// Items put on the list ("9 Zutaten zu Wocheneinkauf").
  final int addedCount;

  /// Items that failed ("Dill und Koriander").
  final List<String> failedNames;
  final String? listId;
}

/// Plan actions for screens (WidgetRef) and services (Ref).
class MealPlanController {
  MealPlanController(this._ref);

  final Ref _ref;

  MealPlanRepository get _repo => _ref.read(mealPlanRepositoryProvider);

  /// Puts a recipe at the end of [day] ("Zum Wochenplan", "Rezept wählen",
  /// Avo add_to_plan). Null when the recipe cannot be found.
  Future<({MealPlanEntry entry, MealPlanUndo undo})?> addRecipeToPlan(
    String recipeId,
    DateTime day,
    int servings, {
    Recipe? recipe,
    MealType? mealType,
  }) async {
    final r = recipe ?? await _ref.read(mealPlanRecipeLookupProvider)(recipeId);
    if (r == null) return null;
    return _repo.addEntry(
      recipeId: recipeId,
      snapshot: PlanRecipeSnapshot.fromRecipe(r),
      day: day,
      servings: servings,
      mealType: mealType,
    );
  }

  /// The recipe detail put a planned recipe's ingredients on [listId]
  /// (Konzept 13.3), so the plan does not add them again.
  Future<MealPlanUndo> markPlanEntrySent(String entryId, String listId, int servings) async =>
      (await _repo.markEntriesSent(servingsById: {entryId: servings}, listId: listId)).undo;

  Future<MealPlanUndo> setServings(String entryId, int servings) => _repo.setServings(entryId, servings);

  Future<MealPlanUndo> moveEntry(String entryId, DateTime day) => _repo.moveEntry(entryId, day);

  Future<MealPlanUndo> reorderDay(List<String> orderedIds) => _repo.reorderDay(orderedIds);

  Future<MealPlanUndo> setMealType(String entryId, MealType? mealType) => _repo.setMealType(entryId, mealType);

  Future<MealPlanUndo> removeEntries(Iterable<String> entryIds) => _repo.removeEntries(entryIds);

  Future<MealPlanUndo> clearWeek(DateTime weekStart) => _repo.clearWeek(weekStart);

  Future<MealPlanUndo> copyPreviousWeek(DateTime weekStart) => _repo.copyPreviousWeek(weekStart);

  Future<MealPlanUndo> setWeekTargetList(DateTime weekStart, String? listId) =>
      _repo.setWeekTargetList(weekStart, listId);

  Future<void> updateSettings(MealPlanSettings settings) => _repo.updateSettings(settings);

  Future<void> undo(MealPlanUndo undo) => _repo.undo(undo);

  /// "N Zutaten auf die Liste" (and Avo plan_to_list): writes the selected
  /// lines in one batch, then marks the entries whose lines all landed.
  Future<PlanSendResult> sendToList({
    required DateTime weekStart,
    required PlanRange range,
    required String listId,
    required String? Function(List<String> recipeNames) noteFor,
    Set<String>? selectedKeys,
    Map<String, PlanQuantity> overrides = const {},
  }) async {
    await _repo.load();
    final aggregation = _ref.read(planAggregationProvider((weekStart: planWeekStart(weekStart), range: range, listId: listId)));
    final items = planWriteItems(aggregation, noteFor: noteFor, selectedKeys: selectedKeys, overrides: overrides);
    if (aggregation.contributingEntryIds.isEmpty) return PlanSendResult(listId: listId);

    final written = items.isEmpty
        ? const PlanListWriteResult()
        : await _ref.read(mealPlanListWriterProvider).addItems(listId, items);
    final failedKeys = {for (final i in items) if (!written.writtenLineKeys.contains(i.lineKey)) i.lineKey};
    final failedEntries = {
      for (final line in aggregation.lines)
        if (failedKeys.contains(line.key)) ...line.entryIds,
    };
    final snapshot = _ref.read(mealPlanSnapshotProvider);
    final sent = await _repo.markEntriesSent(
      servingsById: {
        for (final id in aggregation.contributingEntryIds)
          if (!failedEntries.contains(id) && snapshot.entries[id] != null) id: snapshot.entries[id]!.servings,
      },
      listId: listId,
      noteFirstSend: written.addedCount > 0,
    );
    if (written.token != null) {
      _ref.invalidate(planContributionsProvider(listId));
      unawaited(_refreshList(listId));
    }
    return PlanSendResult(
      listToken: written.token,
      planUndo: sent.undo,
      firstSend: sent.firstSend,
      addedCount: written.addedCount,
      failedNames: written.failedNames,
      listId: listId,
    );
  }

  /// "Widerrufen" after [sendToList].
  Future<void> undoSend(PlanSendResult result) async {
    final token = result.listToken;
    if (token != null) await _ref.read(mealPlanListWriterProvider).undoAddItems(token);
    await _repo.undo(result.planUndo);
    final listId = result.listId;
    if (listId != null) {
      _ref.invalidate(planContributionsProvider(listId));
      unawaited(_refreshList(listId));
    }
  }

  Future<void> _refreshList(String listId) async {
    try {
      await _ref.read(planListRefreshProvider)(listId);
    } catch (e) {
      debugPrint('⚠️ [MEAL_PLAN] List $listId not reloaded: $e');
    }
  }
}

final mealPlanControllerProvider = Provider<MealPlanController>(MealPlanController.new);

/// Puts a recipe into the plan (contract for Teil A's recipe detail and
/// RecipeCard menu "Zum Wochenplan"). Widgets call
/// `ref.read(mealPlanControllerProvider).addRecipeToPlan(...)`.
Future<({MealPlanEntry entry, MealPlanUndo undo})?> addRecipeToPlan(
  Ref ref,
  String recipeId,
  DateTime day,
  int servings, {
  Recipe? recipe,
  MealType? mealType,
}) =>
    ref.read(mealPlanControllerProvider).addRecipeToPlan(recipeId, day, servings, recipe: recipe, mealType: mealType);

/// Marks a plan entry as sent (contract for Teil A's "Zutaten auf Liste").
/// Widgets call `ref.read(mealPlanControllerProvider).markPlanEntrySent(...)`.
Future<MealPlanUndo> markPlanEntrySent(Ref ref, String entryId, String listId, int servings) =>
    ref.read(mealPlanControllerProvider).markPlanEntrySent(entryId, listId, servings);

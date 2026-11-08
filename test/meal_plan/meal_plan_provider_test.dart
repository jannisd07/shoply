// Wochenplan (B7): the providers screens, the home card and Avo read.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/meal_plan.dart';
import 'package:shoply/data/models/nutrition_info.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/services/meal_plan_aggregator.dart';
import 'package:shoply/data/services/meal_plan_list_writer.dart';
import 'package:shoply/presentation/providers/meal_plan_provider.dart';
import 'package:shoply/presentation/state/auth_provider.dart';

import 'meal_plan_fakes.dart';

class _MemoryModuleStore implements ModuleStore {
  Map<String, dynamic>? local;

  @override
  Future<Map<String, dynamic>?> readLocal() async => local;
  @override
  Future<void> writeLocal(Map<String, bool> json) async => local = json;
  @override
  Future<bool?> readLegacyCalories() async => null;
  @override
  Future<Map<String, dynamic>?> readRemote() async => null;
  @override
  Future<void> writeRemote(Map<String, bool> json) async {}
}

class _FakeWriter implements MealPlanListWriter {
  final batches = <(String, List<PlanListWriteItem>)>[];
  final undone = <String>[];
  final ledger = <String, Map<String, List<PlanContribution>>>{};
  List<String> failNames = const [];

  @override
  Future<PlanListWriteResult> addItems(String listId, List<PlanListWriteItem> items) async {
    batches.add((listId, items));
    final ok = [for (final i in items) if (!failNames.contains(i.name)) i];
    final token = 'tok-${batches.length}';
    for (final i in ok) {
      (ledger[listId] ??= {})['item-${i.name}'] = [
        for (final c in i.contributions)
          PlanContribution(entryId: c.entryId, family: c.family, baseAmount: c.baseAmount, undoToken: token),
      ];
    }
    return PlanListWriteResult(
      token: ok.isEmpty ? null : token,
      writtenLineKeys: {for (final i in ok) i.lineKey},
      failedNames: [for (final i in items) if (failNames.contains(i.name)) i.name],
    );
  }

  @override
  Future<void> undoAddItems(String token) async => undone.add(token);

  @override
  Future<Map<String, List<PlanContribution>>> contributionsForList(String listId) async => ledger[listId] ?? {};

  @override
  Future<void> forgetItemsExcept(String listId, Set<String> liveItemIds) async {}
}

Recipe _recipe(String id, String name, List<Ingredient> ingredients, {int servings = 2, int? kcal}) => Recipe(
      id: id,
      name: name,
      description: '',
      imageUrl: '',
      prepTimeMinutes: 5,
      cookTimeMinutes: 20,
      defaultServings: servings,
      ingredients: ingredients,
      instructions: const [],
      authorId: 'a',
      authorName: 'a',
      createdAt: DateTime(2026),
      nutrition: kcal == null ? null : NutritionInfo(calories: kcal),
    );

final _chili = _recipe('chili', 'Chili sin Carne', const [
  Ingredient(name: 'Zwiebeln', amount: 2, unit: ''),
  Ingredient(name: 'Koriander', amount: 1, unit: 'Bund'),
  Ingredient(name: 'Salz', amount: 1, unit: 'Prise'),
  Ingredient(name: 'Reis', amount: 250, unit: 'g'),
], kcal: 480);
final _crumble = _recipe('crumble', 'Apfel-Crumble', const [
  Ingredient(name: 'Äpfel', amount: 4, unit: ''),
  Ingredient(name: 'Butter', amount: 100, unit: 'g'),
], kcal: null);

ShoppingItemModel _item(String name, double qty, String? unit) => ShoppingItemModel(
      id: 'list-item-$name',
      listId: 'list-1',
      name: name,
      quantity: qty,
      unit: unit,
      createdAt: DateTime(2026, 11, 1),
      updatedAt: DateTime(2026, 11, 1),
    );

final _refProvider = Provider<Ref>((ref) => ref);

void main() {
  late FakeMealPlanRemote remote;
  late _FakeWriter writer;
  late _MemoryModuleStore modules;
  late DateTime now;
  late Map<String, List<ShoppingItemModel>> listItems;
  var ids = 0;

  ProviderContainer make({bool unlockPlan = true, bool calories = false}) {
    final c = ProviderContainer(overrides: [
      authUserIdProvider.overrideWithValue('u1'),
      moduleStoreProvider.overrideWithValue(modules),
      mealPlanRemoteFactoryProvider.overrideWithValue((_) => remote),
      mealPlanClockProvider.overrideWithValue(() => now),
      mealPlanIdProvider.overrideWithValue(() => 'id-${ids++}'),
      mealPlanListWriterProvider.overrideWithValue(writer),
      planListItemsProvider.overrideWith((ref, listId) => listItems[listId] ?? const []),
      planListRefreshProvider.overrideWithValue((_) async {}),
      mealPlanCategorizerProvider.overrideWithValue((_) => 'other'),
      mealPlanSubstituterProvider.overrideWithValue(null),
      mealPlanRecipeLookupProvider.overrideWithValue((id) async => {'chili': _chili, 'crumble': _crumble}[id]),
    ]);
    addTearDown(c.dispose);
    if (unlockPlan) c.read(appModulesProvider.notifier).setDebugUnlocked(AppModule.mealPlan, true);
    if (calories) c.read(appModulesProvider.notifier).setEnabled(AppModule.calories, true);
    return c;
  }

  Future<void> settle(ProviderContainer c) async {
    await c.read(mealPlanRepositoryProvider).load();
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    remote = FakeMealPlanRemote();
    writer = _FakeWriter();
    modules = _MemoryModuleStore();
    now = DateTime(2026, 11, 11, 10); // Wednesday
    listItems = {};
    ids = 0;
  });

  group('week and day', () {
    test('weekPlanProvider has seven days Monday to Sunday', () async {
      final c = make();
      await settle(c);
      final ctrl = c.read(mealPlanControllerProvider);
      await ctrl.addRecipeToPlan('chili', DateTime(2026, 11, 11), 4, recipe: _chili);
      await ctrl.addRecipeToPlan('crumble', DateTime(2026, 11, 14), 4, recipe: _crumble);
      await ctrl.addRecipeToPlan('chili', DateTime(2026, 11, 14), 2, recipe: _chili);

      final week = c.read(weekPlanProvider(DateTime(2026, 11, 12, 15)));
      expect(week.weekStart, DateTime(2026, 11, 9));
      expect(week.days.map((d) => d.date.day), [9, 10, 11, 12, 13, 14, 15]);
      expect(week.days[2].entries.single.snapshot.name, 'Chili sin Carne');
      expect(week.days[5].entries.map((e) => e.recipeId), ['crumble', 'chili']);
      expect(week.plannedDayCount, 2);
      expect(week.entryCount, 3);
      expect(week.days[2].kcalPerPerson, isNull, reason: 'kcal only with the calories module');
    });

    test('kcal per person per day with the calories module, "ab" when one is missing', () async {
      final c = make(calories: true);
      await settle(c);
      final ctrl = c.read(mealPlanControllerProvider);
      await ctrl.addRecipeToPlan('chili', DateTime(2026, 11, 14), 4, recipe: _chili);
      await ctrl.addRecipeToPlan('crumble', DateTime(2026, 11, 14), 4, recipe: _crumble);
      final saturday = c.read(weekPlanProvider(DateTime(2026, 11, 9))).days[5];
      expect(saturday.kcalPerPerson, 480);
      expect(saturday.kcalIncomplete, isTrue);
    });

    test('planEntriesForDayProvider lists one day', () async {
      final c = make();
      await settle(c);
      await c.read(mealPlanControllerProvider).addRecipeToPlan('chili', DateTime(2026, 11, 12), 2, recipe: _chili);
      expect(c.read(planEntriesForDayProvider(DateTime(2026, 11, 12, 20))), hasLength(1));
      expect(c.read(planEntriesForDayProvider(DateTime(2026, 11, 13))), isEmpty);
    });
  });

  group('addRecipeToPlan and markPlanEntrySent', () {
    test('a recipe id is enough; the recipe is looked up', () async {
      final c = make();
      await settle(c);
      final ref = c.read(_refProvider);
      final added = await addRecipeToPlan(ref, 'crumble', DateTime(2026, 11, 13), 3);
      expect(added, isNotNull);
      final entry = c.read(planEntriesForDayProvider(DateTime(2026, 11, 13))).single;
      expect((entry.recipeId, entry.servings, entry.snapshot.name), ('crumble', 3, 'Apfel-Crumble'));
      expect(entry.snapshot.ingredients, hasLength(2));

      expect(await addRecipeToPlan(ref, 'gone', DateTime(2026, 11, 13), 2), isNull);
    });

    test('undo of an add removes it', () async {
      final c = make();
      await settle(c);
      final ctrl = c.read(mealPlanControllerProvider);
      final added = await ctrl.addRecipeToPlan('chili', DateTime(2026, 11, 12), 2, recipe: _chili);
      await ctrl.undo(added!.undo);
      expect(c.read(planEntriesForDayProvider(DateTime(2026, 11, 12))), isEmpty);
    });

    test('markPlanEntrySent marks one entry from the recipe detail', () async {
      final c = make();
      await settle(c);
      final added = await c.read(mealPlanControllerProvider).addRecipeToPlan('chili', DateTime(2026, 11, 12), 4, recipe: _chili);
      await markPlanEntrySent(c.read(_refProvider), added!.entry.id, 'list-1', 4);
      final e = c.read(planEntriesForDayProvider(DateTime(2026, 11, 12))).single;
      expect((e.sentListId, e.sentServings, e.openServings), ('list-1', 4, 0));
    });
  });

  group('Zutaten der Woche', () {
    test('aggregation uses the pantry, the open items and the plan amounts', () async {
      listItems['list-1'] = [_item('Reis', 1, 'kg')];
      final c = make();
      await settle(c);
      await c.read(mealPlanControllerProvider).addRecipeToPlan('chili', DateTime(2026, 11, 12), 2, recipe: _chili);
      final a = c.read(planAggregationProvider(
          (weekStart: DateTime(2026, 11, 9), range: PlanRange.fromToday, listId: 'list-1')));
      final byName = {for (final l in a.lines) l.displayName: l};
      expect(byName['Salz']!.reason, PlanLineReason.pantry);
      expect(byName['Reis']!.reason, PlanLineReason.alreadyOnList);
      expect(a.selectedCount, 2);
    });

    test('sending writes once, marks the entries, the first time is the first send', () async {
      final c = make();
      await settle(c);
      final ctrl = c.read(mealPlanControllerProvider);
      final chili = await ctrl.addRecipeToPlan('chili', DateTime(2026, 11, 12), 4, recipe: _chili);
      await ctrl.addRecipeToPlan('crumble', DateTime(2026, 11, 14), 2, recipe: _crumble);

      final sent = await ctrl.sendToList(
        weekStart: DateTime(2026, 11, 9),
        range: PlanRange.fromToday,
        listId: 'list-1',
        noteFor: (names) => 'für ${names.join(', ')}',
      );
      expect(writer.batches, hasLength(1));
      expect(writer.batches.single.$2.map((i) => i.name),
          containsAll(['Zwiebeln', 'Koriander', 'Reis', 'Äpfel', 'Butter']));
      expect(sent.firstSend, isTrue);
      expect(sent.addedCount, 5);
      expect(sent.failedNames, isEmpty);
      final e = c.read(planEntriesForDayProvider(DateTime(2026, 11, 12))).single;
      expect((e.sentListId, e.sentServings), ('list-1', 4));

      // Nothing new: no second write, and the main action counts 0.
      final again = await ctrl.sendToList(
        weekStart: DateTime(2026, 11, 9),
        range: PlanRange.fromToday,
        listId: 'list-1',
        noteFor: (_) => null,
      );
      expect(writer.batches, hasLength(1));
      expect(again.addedCount, 0);

      // The 4 onions the plan sent are on the list now. Two more servings
      // need 2 more: the plan's own onions do not cover them (W-05, W-17).
      listItems['list-1'] = [
        ShoppingItemModel(
          id: 'item-Zwiebeln',
          listId: 'list-1',
          name: 'Zwiebeln',
          quantity: 4,
          createdAt: DateTime(2026, 11, 11),
          updatedAt: DateTime(2026, 11, 11),
        ),
      ];
      c.invalidate(planListItemsProvider('list-1'));
      await ctrl.setServings(chili!.entry.id, 6);
      await settle(c);
      final more = c.read(planAggregationProvider(
          (weekStart: DateTime(2026, 11, 9), range: PlanRange.fromToday, listId: 'list-1')));
      final onions = more.lines.firstWhere((l) => l.displayName == 'Zwiebeln');
      expect(onions.selected, isTrue);
      expect(onions.onList, isNull);
      expect(onions.toAdd!.amount, 2);
    });

    test('undo of a send takes the items back and unmarks the entries', () async {
      final c = make();
      await settle(c);
      final ctrl = c.read(mealPlanControllerProvider);
      await ctrl.addRecipeToPlan('chili', DateTime(2026, 11, 12), 2, recipe: _chili);
      final sent = await ctrl.sendToList(
          weekStart: DateTime(2026, 11, 9), range: PlanRange.wholeWeek, listId: 'list-1', noteFor: (_) => null);
      await ctrl.undoSend(sent);
      expect(writer.undone, [sent.listToken]);
      expect(c.read(planEntriesForDayProvider(DateTime(2026, 11, 12))).single.isSent, isFalse);
      final again = await ctrl.sendToList(
          weekStart: DateTime(2026, 11, 9), range: PlanRange.wholeWeek, listId: 'list-1', noteFor: (_) => null);
      expect(again.firstSend, isTrue);
    });

    test('when everything is already on the list, it is not the first send', () async {
      listItems['list-1'] = [_item('Äpfel', 10, null), _item('Butter', 1, 'kg')];
      final c = make();
      await settle(c);
      final ctrl = c.read(mealPlanControllerProvider);
      await ctrl.addRecipeToPlan('crumble', DateTime(2026, 11, 13), 2, recipe: _crumble);
      final nothing = await ctrl.sendToList(
          weekStart: DateTime(2026, 11, 9), range: PlanRange.wholeWeek, listId: 'list-1', noteFor: (_) => null);
      expect(writer.batches, isEmpty);
      expect(nothing.firstSend, isFalse);
      expect(c.read(planEntriesForDayProvider(DateTime(2026, 11, 13))).single.isSent, isTrue);

      listItems['list-1'] = const [];
      c.invalidate(planListItemsProvider('list-1'));
      await ctrl.addRecipeToPlan('chili', DateTime(2026, 11, 14), 2, recipe: _chili);
      final real = await ctrl.sendToList(
          weekStart: DateTime(2026, 11, 9), range: PlanRange.wholeWeek, listId: 'list-1', noteFor: (_) => null);
      expect(real.firstSend, isTrue);
    });

    test('an entry whose items failed stays unsent', () async {
      writer.failNames = ['Äpfel'];
      final c = make();
      await settle(c);
      final ctrl = c.read(mealPlanControllerProvider);
      final chili = await ctrl.addRecipeToPlan('chili', DateTime(2026, 11, 12), 2, recipe: _chili);
      final crumble = await ctrl.addRecipeToPlan('crumble', DateTime(2026, 11, 13), 2, recipe: _crumble);
      final sent = await ctrl.sendToList(
          weekStart: DateTime(2026, 11, 9), range: PlanRange.wholeWeek, listId: 'list-1', noteFor: (_) => null);
      expect(sent.failedNames, ['Äpfel']);
      final snapshot = c.read(mealPlanSnapshotProvider);
      expect(snapshot.entries[chili!.entry.id]!.isSent, isTrue);
      expect(snapshot.entries[crumble!.entry.id]!.isSent, isFalse);
    });
  });

  group('todayPlanHintProvider ("Heute kochen")', () {
    test('nothing while the module is off', () async {
      final c = make(unlockPlan: false);
      await settle(c);
      await c.read(mealPlanControllerProvider).addRecipeToPlan('chili', DateTime(2026, 11, 11), 2, recipe: _chili);
      expect(c.read(todayPlanHintProvider), isNull);
    });

    test("today's recipe with the missing ingredients of the target list", () async {
      SharedPreferences.setMockInitialValues({'last_accessed_list_u1': 'list-1'});
      listItems['list-1'] = [_item('Zwiebel', 3, null)];
      final c = make(calories: true);
      await settle(c);
      await c.read(mealPlanControllerProvider).addRecipeToPlan('chili', DateTime(2026, 11, 11), 2, recipe: _chili);
      c.listen(todayPlanHintProvider, (_, __) {}); // like the home screen
      await settle(c); // "Liste von heute" is read from the device
      final hint = c.read(todayPlanHintProvider)!;
      expect(hint.kind, TodayPlanHintKind.today);
      expect(hint.entry!.recipeId, 'chili');
      expect(hint.listId, 'list-1');
      // Koriander and Reis are missing; Zwiebeln are on the list, Salz is pantry.
      expect(hint.missingCount, 2);
      expect(hint.missingNames, ['Koriander', 'Reis']);
      expect(hint.ingredientCount, 3);
      expect(hint.kcalPerServing, 480);
    });

    test('from 20:00 the next day', () async {
      now = DateTime(2026, 11, 11, 20, 5);
      final c = make();
      await settle(c);
      await c.read(mealPlanControllerProvider).addRecipeToPlan('crumble', DateTime(2026, 11, 12), 2, recipe: _crumble);
      final hint = c.read(todayPlanHintProvider)!;
      expect(hint.kind, TodayPlanHintKind.tomorrow);
      expect(hint.day, DateTime(2026, 11, 12));
      expect(hint.kcalPerServing, isNull, reason: 'calories module is off');
    });

    test('the first meal of the day is picked, breakfast before dinner', () async {
      final c = make();
      await settle(c);
      final ctrl = c.read(mealPlanControllerProvider);
      await ctrl.addRecipeToPlan('chili', DateTime(2026, 11, 11), 2, recipe: _chili);
      await ctrl.addRecipeToPlan('crumble', DateTime(2026, 11, 11), 2, recipe: _crumble, mealType: MealType.breakfast);
      final hint = c.read(todayPlanHintProvider)!;
      expect(hint.entry!.recipeId, 'crumble');
      expect(hint.entryCount, 2);
    });

    test('ingredients on another list', () async {
      final c = make();
      await settle(c);
      final ctrl = c.read(mealPlanControllerProvider);
      await ctrl.updateSettings(c.read(mealPlanSettingsProvider).copyWith(targetListId: 'list-1'));
      final added = await ctrl.addRecipeToPlan('chili', DateTime(2026, 11, 11), 2, recipe: _chili);
      await ctrl.markPlanEntrySent(added!.entry.id, 'list-2', 2);
      final hint = c.read(todayPlanHintProvider)!;
      expect(hint.missingCount, 0);
      expect(hint.sentToOtherList, isTrue);
      expect(hint.sentListId, 'list-2');
    });

    test('more servings after sending: only the added servings are missing', () async {
      SharedPreferences.setMockInitialValues({'last_accessed_list_u1': 'list-1'});
      // What the plan sent for 2 servings is on the list; it does not cover
      // the 2 servings added later (W-17).
      listItems['list-1'] = [
        _item('Zwiebeln', 2, null),
        _item('Koriander', 1, 'bunch'),
        _item('Reis', 250, 'g'),
      ];
      final c = make();
      await settle(c);
      final ctrl = c.read(mealPlanControllerProvider);
      final added = await ctrl.addRecipeToPlan('chili', DateTime(2026, 11, 11), 2, recipe: _chili);
      await ctrl.markPlanEntrySent(added!.entry.id, 'list-1', 2);
      writer.ledger['list-1'] = {
        'list-item-Zwiebeln': [PlanContribution(entryId: added.entry.id, family: 'pieces', baseAmount: 2)],
        'list-item-Koriander': [PlanContribution(entryId: added.entry.id, family: 'bunch', baseAmount: 1)],
        'list-item-Reis': [PlanContribution(entryId: added.entry.id, family: 'mass', baseAmount: 250)],
      };
      c.listen(todayPlanHintProvider, (_, __) {});
      await settle(c);
      expect(c.read(todayPlanHintProvider)!.missingCount, 0);

      await ctrl.setServings(added.entry.id, 4);
      await settle(c);
      final hint = c.read(todayPlanHintProvider)!;
      expect(hint.missingNames, ['Zwiebeln', 'Koriander', 'Reis']);
      expect(hint.ingredientCount, 3);
    });

    test('switched off in the settings', () async {
      final c = make();
      await settle(c);
      final ctrl = c.read(mealPlanControllerProvider);
      await ctrl.addRecipeToPlan('chili', DateTime(2026, 11, 11), 2, recipe: _chili);
      await ctrl.updateSettings(c.read(mealPlanSettingsProvider).copyWith(showTodayHint: false));
      expect(c.read(todayPlanHintProvider), isNull);
    });

    test('Sunday from 16:00: next week is still empty', () async {
      now = DateTime(2026, 11, 15, 16, 30);
      final c = make();
      await settle(c);
      await c.read(mealPlanControllerProvider).addRecipeToPlan('chili', DateTime(2026, 11, 13), 2, recipe: _chili);
      final hint = c.read(todayPlanHintProvider)!;
      expect(hint.kind, TodayPlanHintKind.nextWeekEmpty);
      expect(hint.day, DateTime(2026, 11, 16));
    });

    test('nothing planned: no card', () async {
      final c = make();
      await settle(c);
      expect(c.read(todayPlanHintProvider), isNull);
    });
  });
}

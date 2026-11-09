// The tool path as the model calls it (W1b re-review N8): `_runToolCall`
// applies the consent filter, and the tools for cost splitting, goals,
// allergy/diet removal and a busy plan day only answer with their card;
// nothing is written on the model's call.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/models/expense_split.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/meal_plan.dart';
import 'package:shoply/data/models/nutrition_goal.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/models/user_model.dart';
import 'package:shoply/data/models/weight_log_entry.dart';
import 'package:shoply/data/services/avo_assistant_service.dart';
import 'package:shoply/data/services/avo_settings_bridge.dart';
import 'package:shoply/data/services/avo_stores.dart';
import 'package:shoply/data/services/expense_split_service.dart';
import 'package:shoply/data/services/meal_plan_repository.dart';
import 'package:shoply/presentation/providers/meal_plan_provider.dart';
import 'package:shoply/presentation/state/auth_provider.dart';

final _user = UserModel(
  id: 'u1',
  email: 'a@b.test',
  displayName: 'Jannis',
  allergies: const ['Erdnüsse'],
  dietPreferences: const ['Vegetarisch'],
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

class _Splits implements AvoSplitStore {
  int writes = 0;

  @override
  String? get userId => 'u1';

  @override
  Future<ShoppingHistory?> trip(String historyId) async => ShoppingHistory(
    id: historyId,
    userId: 'u1',
    listName: 'Wocheneinkauf',
    totalItems: 2,
    completedAt: DateTime(2026, 10, 31),
    totalCost: 42.8,
  );

  @override
  Future<List<ExpenseSplit>> splits(String historyId) async => const [];

  @override
  Future<void> createSplits({
    required String historyId,
    required double totalCost,
    required List<SplitShare> shares,
    String? paidByUserId,
    String? paidByName,
  }) async => writes++;
}

class _Goals implements AvoGoalStore {
  int writes = 0;
  NutritionGoal stored = NutritionGoal(
    userId: 'u1',
    dailyCalorieTarget: 2000,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  @override
  String? get userId => 'u1';

  @override
  Future<NutritionGoal?> goal() async => stored;

  @override
  Future<NutritionGoal> saveGoal(NutritionGoal goal) async {
    writes++;
    return stored = goal;
  }

  @override
  Future<WeightLogEntry?> latestWeight() async => null;

  @override
  Future<WeightLogEntry> logWeight(double kg) async {
    writes++;
    throw StateError('no write expected');
  }

  @override
  Future<void> deleteWeight(String id) async => writes++;
}

final _day = DateTime(2026, 11, 11);

MealPlanEntry _entry(String id, String name) => MealPlanEntry(
  id: id,
  userId: 'u1',
  planDate: _day,
  recipeId: 'x-$id',
  snapshot: PlanRecipeSnapshot(name: name, defaultServings: 2),
  servings: 2,
  createdAt: _day,
  updatedAt: _day,
);

/// The plan as "Ersetzen" sees it: records the order of the calls.
class _Plan extends MealPlanController {
  _Plan(super.ref);

  final calls = <String>[];
  final undos = <MealPlanUndo>[];
  bool failRemove = false;

  @override
  Future<({MealPlanEntry entry, MealPlanUndo undo})?> addRecipeToPlan(
    String recipeId,
    DateTime day,
    int servings, {
    Recipe? recipe,
    MealType? mealType,
  }) async {
    calls.add('add');
    return (
      entry: _entry('new', 'Ofengemüse'),
      undo: const MealPlanUndo(entries: {'new': null}),
    );
  }

  @override
  Future<MealPlanUndo> removeEntries(Iterable<String> entryIds) async {
    calls.add('remove');
    // As the device cache write can fail after the plan changed locally.
    if (failRemove) throw StateError('cache');
    return MealPlanUndo(entries: {for (final id in entryIds) id: null});
  }

  @override
  Future<void> undo(MealPlanUndo undo) async {
    calls.add('undo');
    undos.add(undo);
  }
}

/// The person's diet and allergies as the removal card's tap changes them.
class _Profile {
  _Profile(this.user);

  UserModel user;
  final calls = <String>[];

  Future<SettingChangeResult> update(
    WidgetRef ref,
    String key,
    Object? value,
  ) async {
    calls.add('$key:$value');
    final entry = '$value';
    final diet = key.startsWith('diet');
    final list = diet ? user.dietPreferences : user.allergies;
    final next = key.endsWith('_add')
        ? [...list, entry]
        : [
            for (final e in list)
              if (e != entry) e,
          ];
    user = diet
        ? user.copyWith(dietPreferences: next)
        : user.copyWith(allergies: next);
    ref.invalidate(currentUserProvider);
    return SettingChangeResult(
      success: true,
      key: key,
      displayName: key,
      newValue: entry,
    );
  }
}

Recipe _recipe() => Recipe(
  id: 'r',
  name: 'Ofengemüse',
  description: '',
  imageUrl: '',
  prepTimeMinutes: 10,
  cookTimeMinutes: 20,
  defaultServings: 2,
  ingredients: const [],
  instructions: const [],
  authorId: 'a',
  authorName: 'A',
  createdAt: DateTime(2026),
);

/// A [WidgetRef] with the overrides of the tool path.
Future<WidgetRef> _ref(WidgetTester tester, List<Override> overrides) async {
  late WidgetRef ref;
  await tester.pumpWidget(
    ProviderScope(
      // A fresh container each time: overrides cannot change in place.
      key: UniqueKey(),
      overrides: overrides,
      child: Consumer(
        builder: (context, r, _) {
          ref = r;
          return const SizedBox();
        },
      ),
    ),
  );
  return ref;
}

/// The JSON a tool_result carries.
String _content(Map<String, dynamic> block) => block['content'] as String;

void main() {
  final service = AvoAssistantService.forTest();
  final splits = _Splits();
  final goals = _Goals();

  List<Override> overrides({
    Set<AppModule> on = const {},
    _Goals? goalStore,
    _Splits? splitStore,
    _Profile? profile,
    void Function(_Plan plan)? plan,
  }) => [
    currentUserProvider.overrideWith((ref) async => profile?.user ?? _user),
    moduleEnabledProvider.overrideWith((ref, m) => on.contains(m)),
    avoSplitStoreProvider.overrideWithValue(splitStore ?? splits),
    avoGoalStoreProvider.overrideWithValue(goalStore ?? goals),
    if (profile != null)
      avoSettingUpdateProvider.overrideWithValue(profile.update),
    if (plan != null)
      mealPlanControllerProvider.overrideWith((ref) {
        final p = _Plan(ref);
        plan(p);
        return p;
      }),
    mealPlanRecipeLookupProvider.overrideWithValue((id) async => _recipe()),
    planEntriesForDayProvider.overrideWith(
      (ref, day) => [
        MealPlanEntry(
          id: 'e1',
          userId: 'u1',
          planDate: _day,
          recipeId: 'x',
          snapshot: const PlanRecipeSnapshot(
            name: 'Linsencurry',
            defaultServings: 2,
          ),
          servings: 2,
          createdAt: _day,
          updatedAt: _day,
        ),
      ],
    ),
  ];

  testWidgets('_runToolCall applies the consent filter to every result', (
    tester,
  ) async {
    final ref = await _ref(tester, overrides());
    final payloads = <AvoWidgetPayload>[];
    final block = await service.debugRunToolCall(
      'log_water',
      const {'amount_ml': 250},
      ref,
      payloads,
      health: false,
      body: false,
      run: () async => {
        'success': true,
        'added_ml': 250,
        'total_today_ml': 1250,
        'target_ml': 2000,
      },
    );
    expect(_content(block), isNot(contains('total_today_ml')));
    expect(_content(block), isNot(contains('target_ml')));
    expect(_content(block), contains('added_ml'));
  });

  testWidgets('a failing tool tells the model nothing of the exception', (
    tester,
  ) async {
    final ref = await _ref(tester, overrides());
    // The item read fails here (no Supabase in tests), as a real tool can.
    final block = await service.debugRunToolCall(
      'get_list_contents',
      const {'list_id': 'w'},
      ref,
      [],
      health: true,
      body: true,
    );
    expect(_content(block), contains('tool_failed'));
    expect(_content(block).toLowerCase(), isNot(contains('supabase')));
    expect(block['is_error'], isTrue);
  });

  testWidgets('split_trip_cost only shows the preview; nothing is split', (
    tester,
  ) async {
    final ref = await _ref(tester, overrides(on: {AppModule.costSplit}));
    final payloads = <AvoWidgetPayload>[];
    final block = await service.debugRunToolCall(
      'split_trip_cost',
      const {
        'history_id': 't1',
        'participant_names': ['Mallory'],
        'total_cost': 999,
      },
      ref,
      payloads,
      health: true,
      body: true,
    );
    final card = payloads.single.card! as AvoSplitPreviewCard;
    expect(card.total, 42.8);
    expect(splits.writes, 0);
    expect(_content(block), contains('requires_confirmation'));
    expect(payloads.any((p) => p.isDoneChange), isFalse);
  });

  testWidgets('setup_nutrition_goal only shows the preview, confirm_replace '
      'or not; nothing is saved', (tester) async {
    final ref = await _ref(tester, overrides(on: {AppModule.calories}));
    for (final confirm in [false, true]) {
      final payloads = <AvoWidgetPayload>[];
      final block = await service.debugRunToolCall(
        'setup_nutrition_goal',
        {
          'goal_type': 'lose_weight',
          'activity_level': 'moderate',
          'age': 31,
          'gender': 'male',
          'height_cm': 180,
          'current_weight_kg': 80,
          'target_weight_kg': 75,
          'confirm_replace': confirm,
        },
        ref,
        payloads,
        health: true,
        body: true,
      );
      final card = payloads.single.card! as AvoGoalPreviewCard;
      expect(card.previous?.dailyCalorieTarget, 2000);
      expect(card.writesWeight, isTrue, reason: 'no weight today yet');
      // A write after the card would end as tool_failed here.
      expect(_content(block), contains('"requires_confirmation":true'));
      expect(_content(block), contains('would_log_weight_today'));
      expect(block['is_error'], isNot(isTrue));
    }
    expect(goals.writes, 0);
  });

  testWidgets('allergy and diet removal: the card with consent, the consent '
      'card and one neutral answer without', (tester) async {
    final ref = await _ref(tester, overrides());
    for (final (key, value) in [
      ('allergies_remove', 'Erdnüsse'),
      ('diet_remove', 'Vegetarisch'),
    ]) {
      final shared = <AvoWidgetPayload>[];
      final asked = await service.debugRunToolCall(
        'update_setting',
        {'key': key, 'value': value},
        ref,
        shared,
        health: true,
        body: false,
      );
      expect((shared.single.card! as AvoRemovalCard).entry, value);
      expect(_content(asked), contains('"requires_confirmation":true'));
      expect(_content(asked), isNot(contains('tool_failed')));

      final known = <AvoWidgetPayload>[];
      final a = await service.debugRunToolCall(
        'update_setting',
        {'key': key, 'value': value},
        ref,
        known,
        health: false,
        body: false,
      );
      final b = await service.debugRunToolCall(
        'update_setting',
        {'key': key, 'value': 'Mango'},
        ref,
        [],
        health: false,
        body: false,
      );
      expect(_content(a), _content(b), reason: 'no membership oracle');
      expect(known.single.kind, AvoPayloadKind.consentRequest);
    }
    final user = await ref.read(currentUserProvider.future);
    expect(user!.allergies, ['Erdnüsse']);
  });

  testWidgets('add_to_plan on a busy day asks first', (tester) async {
    final ref = await _ref(tester, overrides(on: {AppModule.mealPlan}));
    final payloads = <AvoWidgetPayload>[];
    final block = await service.debugRunToolCall(
      'add_to_plan',
      const {'date': '2026-11-11', 'recipe_id': 'r', 'servings': 2},
      ref,
      payloads,
      health: true,
      body: true,
    );
    final card = payloads.single.card! as AvoPlanTakenCard;
    expect(card.plannedNames, ['Linsencurry']);
    expect(_content(block), contains('"asked":true'));
  });

  testWidgets('log_food only shows the estimate; nothing is saved', (
    tester,
  ) async {
    final ref = await _ref(tester, overrides(on: {AppModule.calories}));
    final payloads = <AvoWidgetPayload>[];
    final block = await service.debugRunToolCall(
      'log_food',
      const {'food_name': 'Banane', 'calories': 105, 'meal_type': 'snack'},
      ref,
      payloads,
      health: true,
      body: true,
    );
    final card = payloads.single.card! as AvoEstimateCard;
    expect(card.kcal, 105);
    expect(_content(block), contains('"saved":false'));
    expect(_content(block), isNot(contains('tool_failed')));
    expect(payloads.any((p) => p.isDoneChange), isFalse);
  });

  testWidgets('a refused postcode answers with the stored state, not the '
      'attempt (M-e)', (tester) async {
    for (final (stored, expected) in [(null, false), ('79098', true)]) {
      SharedPreferences.setMockInitialValues({
        if (stored != null) 'offers_zip_manual': stored,
      });
      final ref = await _ref(tester, overrides());
      final payloads = <AvoWidgetPayload>[];
      final block = await tester.runAsync(
        () => service.debugRunToolCall(
          'update_setting',
          const {'key': 'zip_code', 'value': '12'},
          ref,
          payloads,
          health: true,
          body: true,
        ),
      );
      expect(_content(block!), contains('"postcode_set":$expected'));
      expect(_content(block), isNot(contains('79098')));
      expect(_content(block), isNot(contains('new_value')));
      expect(payloads.single.card, isA<AvoSettingFailedCard>());
    }
  });

  group('the taps (M-b)', () {
    AvoSplitPreviewCard splitCard() => AvoSplitPreviewCard(
      historyId: 't1',
      tripDate: DateTime(2026, 10, 31),
      total: 42.8,
      totalFromTrip: true,
      yourUserId: 'u1',
      payerUserId: 'u1',
      payerName: 'Jannis',
      payerIsNew: true,
      shares: const [
        (name: 'Jannis', amount: 21.4, isYou: true),
        (name: 'Lena', amount: 21.4, isYou: false),
      ],
    );

    testWidgets('"Teilen" reads the module at the tap', (tester) async {
      final store = _Splits();
      var ref = await _ref(tester, overrides(splitStore: store));
      expect(await service.splitTripForAvo(ref, splitCard()), isNull);
      expect(store.writes, 0, reason: 'module off at the tap');
      ref = await _ref(
        tester,
        overrides(splitStore: store, on: {AppModule.costSplit}),
      );
      expect(await service.splitTripForAvo(ref, splitCard()), isNotNull);
      expect(store.writes, 1);
    });

    testWidgets('"Übernehmen" saves through the goal store and undoes', (
      tester,
    ) async {
      final store = _Goals();
      final ref = await _ref(tester, overrides(goalStore: store));
      final record = await service.applyGoalForAvo(
        ref,
        AvoGoalPreviewCard(
          goal: NutritionGoal(
            userId: 'u1',
            dailyCalorieTarget: 1800,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        ),
      );
      expect(record.kcal, 1800);
      expect(record.previousKcal, 2000);
      expect(store.stored.dailyCalorieTarget, 1800);
      expect(await record.undo!(), AvoUndoResult.undone);
      expect(store.stored.dailyCalorieTarget, 2000);
    });

    testWidgets('"Entfernen" removes from the right list; undo only while '
        'unchanged', (tester) async {
      final profile = _Profile(_user);
      final ref = await _ref(tester, overrides(profile: profile));
      final diet = await service.removeEntryForAvo(
        ref,
        const AvoRemovalCard('Vegetarisch', diet: true),
      );
      expect(diet.key, 'diet_remove');
      expect(profile.user.dietPreferences, isEmpty);
      expect(profile.user.allergies, ['Erdnüsse']);
      expect(await diet.undo!(), AvoUndoResult.undone);
      expect(profile.user.dietPreferences, ['Vegetarisch']);

      final allergy = await service.removeEntryForAvo(
        ref,
        const AvoRemovalCard('Erdnüsse'),
      );
      expect(allergy.key, 'allergies_remove');
      expect(profile.user.allergies, isEmpty);
      // The person added another allergy since: undo leaves it alone.
      profile.user = profile.user.copyWith(allergies: ['Sesam']);
      ref.invalidate(currentUserProvider);
      expect(await allergy.undo!(), AvoUndoResult.changedSince);
      expect(profile.user.allergies, ['Sesam']);
      expect(profile.calls, [
        'diet_remove:Vegetarisch',
        'diet_add:Vegetarisch',
        'allergies_remove:Erdnüsse',
      ]);
    });

    testWidgets('"Ersetzen" plans the new recipe first, then takes the old '
        'ones out (M-d)', (tester) async {
      late _Plan plan;
      final ref = await _ref(
        tester,
        overrides(on: {AppModule.mealPlan}, plan: (p) => plan = p),
      );
      final record = await service.planRecipeForAvo(
        ref,
        recipeId: 'r',
        recipe: _recipe(),
        day: _day,
        servings: 2,
        replacing: const ['e1'],
      );
      expect(record, isNotNull);
      expect(plan.calls, ['add', 'remove']);
    });

    testWidgets('"Ersetzen" that fails half-way puts the day back in one '
        'step: the old recipe in, the new one out (M-d)', (tester) async {
      late _Plan plan;
      final ref = await _ref(
        tester,
        overrides(
          on: {AppModule.mealPlan},
          plan: (p) => plan = p..failRemove = true,
        ),
      );
      await expectLater(
        service.planRecipeForAvo(
          ref,
          recipeId: 'r',
          recipe: _recipe(),
          day: _day,
          servings: 2,
          replacing: const ['e1'],
        ),
        throwsStateError,
      );
      expect(plan.calls, ['add', 'remove', 'undo']);
      final back = plan.undos.single.entries;
      expect(back['new'], isNull);
      expect(back.containsKey('new'), isTrue);
      expect(back['e1']?.snapshot.name, 'Linsencurry');
    });
  });
}

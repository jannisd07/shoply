// The tool path as the model calls it (W1b re-review N8): `_runToolCall`
// applies the consent filter, and the tools for cost splitting, goals,
// allergy/diet removal and a busy plan day only answer with their card;
// nothing is written on the model's call.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/models/expense_split.dart';
import 'package:shoply/data/models/meal_plan.dart';
import 'package:shoply/data/models/nutrition_goal.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/models/user_model.dart';
import 'package:shoply/data/models/weight_log_entry.dart';
import 'package:shoply/data/services/avo_assistant_service.dart';
import 'package:shoply/data/services/avo_stores.dart';
import 'package:shoply/data/services/expense_split_service.dart';
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

  @override
  String? get userId => 'u1';

  @override
  Future<NutritionGoal?> goal() async => NutritionGoal(
    userId: 'u1',
    dailyCalorieTarget: 2000,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  @override
  Future<NutritionGoal> saveGoal(NutritionGoal goal) async {
    writes++;
    return goal;
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

  List<Override> overrides({Set<AppModule> on = const {}}) => [
    currentUserProvider.overrideWith((ref) async => _user),
    moduleEnabledProvider.overrideWith((ref, m) => on.contains(m)),
    avoSplitStoreProvider.overrideWithValue(splits),
    avoGoalStoreProvider.overrideWithValue(goals),
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
      await service.debugRunToolCall(
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
      await service.debugRunToolCall(
        'update_setting',
        {'key': key, 'value': value},
        ref,
        shared,
        health: true,
        body: false,
      );
      expect((shared.single.card! as AvoRemovalCard).entry, value);

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
}

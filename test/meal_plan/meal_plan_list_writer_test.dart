// Wochenplan (B7): putting "Zutaten der Woche" on the target list in one
// batch (ItemRepository.addItems from Teil A5) with undo, and remembering
// which amounts came from which plan entry (W-17).
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/models/meal_plan.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/repositories/item_batch.dart';
import 'package:shoply/data/services/meal_plan_aggregator.dart';
import 'package:shoply/data/services/meal_plan_list_writer.dart';

MealPlanEntry _entry(String id, String name, List<Ingredient> ingredients,
        {int servings = 2, int defaultServings = 2, int? sentServings}) =>
    MealPlanEntry(
      id: id,
      userId: 'u1',
      planDate: DateTime(2026, 11, 11),
      recipeId: 'r-$id',
      snapshot: PlanRecipeSnapshot(name: name, defaultServings: defaultServings, ingredients: ingredients),
      servings: servings,
      sentServings: sentServings,
      sentAt: sentServings == null ? null : DateTime.utc(2026, 11, 7),
      sentListId: sentServings == null ? null : 'list-1',
      createdAt: DateTime(2026, 11, 1),
      updatedAt: DateTime(2026, 11, 1),
    );

Ingredient _i(String name, num amount, String unit) =>
    Ingredient(name: name, amount: amount.toDouble(), unit: unit);

String _note(List<String> recipes) =>
    recipes.length >= 3 ? 'für ${recipes.length} Rezepte' : 'für ${recipes.join(', ')}';

ShoppingItemModel _row(String id, String name, double qty, String? unit) => ShoppingItemModel(
      id: id,
      listId: 'list-1',
      name: name,
      quantity: qty,
      unit: unit,
      createdAt: DateTime(2026, 11, 7),
      updatedAt: DateTime(2026, 11, 7),
    );

/// Stand-in for ItemRepository.addItems / undoAddItems.
class _FakeBatches {
  final calls = <(String, List<NewItem>)>[];
  final undone = <String>[];
  Object? failWith;
  var _n = 0;

  /// Existing unchecked rows that absorb a new item of the same name/unit.
  final existing = <ShoppingItemModel>[];

  Future<AddItemsResult> addItems(String listId, List<NewItem> items) async {
    calls.add((listId, items));
    if (failWith != null) throw failWith!;
    final token = 'batch-${_n++}';
    final rows = <ShoppingItemModel>[];
    for (final item in items) {
      final hit = existing.where((e) =>
          e.name.toLowerCase() == item.name.toLowerCase() && (e.unit ?? '') == (item.unit ?? ''));
      rows.add(hit.isNotEmpty
          ? _row(hit.first.id, hit.first.name, hit.first.quantity + item.quantity, hit.first.unit)
          : _row('new-${item.name}', item.name, item.quantity, item.unit));
    }
    return AddItemsResult(token: token, items: rows);
  }

  Future<void> undoAddItems(String token) async => undone.add(token);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('planWriteItems', () {
    late PlanAggregation aggregation;

    setUp(() {
      aggregation = aggregatePlanIngredients(
        entries: [
          _entry('chili', 'Chili', [
            _i('Zwiebeln', 2, ''),
            _i('Passierte Tomaten', 500, 'g'),
            _i('Kidneybohnen', 2, 'Dosen'),
            _i('Olivenöl', 2, 'EL'),
          ], servings: 4, defaultServings: 4),
          _entry('bolo', 'Bolognese', [_i('Zwiebel', 1, ''), _i('Passierte Tomaten', 0.5, 'kg'), _i('Zimt', 1, 'TL')]),
          _entry('curry', 'Curry', [_i('Onion', 1, 'pcs'), _i('Kokosmilch', 400, 'ml'), _i('Butter', 100, 'g')],
              servings: 5, defaultServings: 3, sentServings: 3),
        ],
        pantry: MealPlanSettings.defaultPantry,
        openItems: const [PlanListItem(id: 'butter', name: 'Butter', quantity: 30, unit: 'g')],
      );
    });

    test('only selected lines, with list units and the note', () {
      final items = planWriteItems(aggregation, noteFor: _note);
      final byName = {for (final i in items) i.name: i};
      expect(byName.keys, containsAll(['Zwiebeln', 'Passierte Tomaten', 'Kidneybohnen', 'Kokosmilch', 'Zimt', 'Butter']));
      expect(byName.containsKey('Olivenöl'), isFalse, reason: 'pantry is not selected');

      expect((byName['Passierte Tomaten']!.quantity, byName['Passierte Tomaten']!.unit), (1.0, 'kg'));
      expect((byName['Kidneybohnen']!.quantity, byName['Kidneybohnen']!.unit), (2.0, 'can'));
      expect((byName['Zwiebeln']!.quantity, byName['Zwiebeln']!.unit), (4.0, null));
      expect((byName['Zimt']!.quantity, byName['Zimt']!.unit), (1.0, null));
      // 66.7 g for 2 more servings minus 30 g on the list → 40 g.
      expect((byName['Butter']!.quantity, byName['Butter']!.unit), (40.0, 'g'));
      expect(byName['Zwiebeln']!.note, 'für 3 Rezepte');
      expect(byName['Kidneybohnen']!.note, 'für Chili');
    });

    test('contributions split what is added over the entries', () {
      final items = planWriteItems(aggregation, noteFor: _note);
      final onions = items.singleWhere((i) => i.name == 'Zwiebeln');
      expect({for (final c in onions.contributions) c.entryId: c.baseAmount},
          {'chili': 2, 'bolo': 1, 'curry': 1});
      expect(onions.contributions.map((c) => c.family).toSet(), {'pieces'});
      final coconut = items.singleWhere((i) => i.name == 'Kokosmilch');
      expect(coconut.contributions.single.baseAmount, 275, reason: 'the rounded amount that lands on the list');
    });

    test('an item already on the list grows in its own name and unit', () {
      final a = aggregatePlanIngredients(
        entries: [
          _entry('curry', 'Curry', [_i('Zwiebeln', 4, ''), _i('Kokosmilch', 400, 'ml'), _i('Reis', 600, 'g')],
              servings: 5, defaultServings: 3, sentServings: 3),
        ],
        openItems: const [
          PlanListItem(id: 'onion', name: 'Zwiebel', quantity: 1, unit: 'pcs'),
          // Sent by the plan before: does not count, but still grows (400 → 675 ml).
          PlanListItem(id: 'coco', name: 'Kokosmilch', quantity: 400, unit: 'ml', contributions: [
            PlanContribution(entryId: 'curry', family: 'volume', baseAmount: 400),
          ]),
          PlanListItem(id: 'rice', name: 'Basmati', quantity: 1, unit: 'kg'),
          PlanListItem(id: 'rice2', name: 'Reis', quantity: 0.2, unit: 'kg'),
        ],
      );
      final items = {for (final i in planWriteItems(a, noteFor: _note)) i.name: i};
      // 4 × 2/3 = 2.67 → 3 onions, 1 on the list → 2 more, as "Zwiebel".
      expect((items['Zwiebel']!.quantity, items['Zwiebel']!.unit), (2.0, 'pcs'));
      expect((items['Kokosmilch']!.quantity, items['Kokosmilch']!.unit), (275.0, 'ml'));
      // 400 g needed, 200 g on the list: 200 g more, written in kg.
      expect((items['Reis']!.quantity, items['Reis']!.unit), (0.2, 'kg'));
      expect(items['Reis']!.note, isNull, reason: 'notes only on new items');
      expect(items.containsKey('Zwiebeln'), isFalse);
    });

    test('the person can pick other lines than the preselection', () {
      final oil = aggregation.lines.singleWhere((l) => l.displayName == 'Olivenöl');
      final onion = aggregation.lines.singleWhere((l) => l.displayName == 'Zwiebeln');
      final items = planWriteItems(aggregation, noteFor: _note, selectedKeys: {oil.key, onion.key});
      expect(items.map((i) => i.name), ['Zwiebeln', 'Olivenöl']);
    });

    test('a changed amount ("Menge ändern") replaces the computed one', () {
      final onion = aggregation.lines.singleWhere((l) => l.displayName == 'Zwiebeln');
      final items = planWriteItems(aggregation, noteFor: _note, overrides: {
        onion.key: const PlanQuantity(amount: 6, family: PlanUnitFamily.pieces),
      });
      expect(items.singleWhere((i) => i.name == 'Zwiebeln').quantity, 6);
    });
  });

  group('ItemRepositoryPlanListWriter', () {
    late _FakeBatches batches;
    late ItemRepositoryPlanListWriter writer;

    const onions = PlanListWriteItem(
      lineKey: 'zwiebel|pieces',
      name: 'Zwiebeln',
      quantity: 3,
      categoryId: 'fruits_vegetables',
      note: 'für Chili, Curry',
      contributions: [
        PlanContribution(entryId: 'chili', family: 'pieces', baseAmount: 2),
        PlanContribution(entryId: 'curry', family: 'pieces', baseAmount: 1),
      ],
    );
    const coconut = PlanListWriteItem(
      lineKey: 'kokosmilch|volume',
      name: 'Kokosmilch',
      quantity: 275,
      unit: 'ml',
      contributions: [PlanContribution(entryId: 'curry', family: 'volume', baseAmount: 275)],
    );

    setUp(() {
      batches = _FakeBatches();
      writer = ItemRepositoryPlanListWriter(
        addItems: batches.addItems,
        undoAddItems: batches.undoAddItems,
      );
    });

    test('one batch call with local categories and notes, no parsing', () async {
      final result = await writer.addItems('list-1', [onions, coconut]);
      expect(batches.calls, hasLength(1));
      final (listId, sent) = batches.calls.single;
      expect(listId, 'list-1');
      expect(sent.map((i) => (i.name, i.quantity, i.unit, i.category, i.notes)), [
        ('Zwiebeln', 3.0, null, 'fruits_vegetables', 'für Chili, Curry'),
        ('Kokosmilch', 275.0, 'ml', null, null),
      ]);
      expect(result.token, 'batch-0');
      expect(result.writtenLineKeys, {'zwiebel|pieces', 'kokosmilch|volume'});
      expect(result.failedNames, isEmpty);
      expect(result.addedCount, 2);
    });

    test('remembers the amounts per item, also merged ones', () async {
      batches.existing.add(_row('coco', 'Kokosmilch', 400, 'ml'));
      await writer.addItems('list-1', [onions, coconut]);
      final byItem = await writer.contributionsForList('list-1');
      expect(byItem.keys, unorderedEquals(['new-Zwiebeln', 'coco']));
      expect(byItem['coco']!.single.baseAmount, 275);
      expect(byItem['coco']!.single.undoToken, 'batch-0');

      // A new writer (app restart) still knows them.
      final again = ItemRepositoryPlanListWriter(addItems: batches.addItems, undoAddItems: batches.undoAddItems);
      expect((await again.contributionsForList('list-1')).keys, hasLength(2));
      expect(await again.contributionsForList('other-list'), isEmpty);
    });

    test('undo takes the batch back and forgets its amounts', () async {
      await writer.addItems('list-1', [onions]);
      final second = await writer.addItems('list-1', [coconut]);
      await writer.undoAddItems(second.token!);
      expect(batches.undone, ['batch-1']);
      final byItem = await writer.contributionsForList('list-1');
      expect(byItem.keys, ['new-Zwiebeln']);
    });

    test('a failed batch names every item and stores nothing', () async {
      batches.failWith = Exception('offline');
      final result = await writer.addItems('list-1', [onions, coconut]);
      expect(result.token, isNull);
      expect(result.writtenLineKeys, isEmpty);
      expect(result.failedNames, ['Zwiebeln', 'Kokosmilch']);
      expect(await writer.contributionsForList('list-1'), isEmpty);
    });

    test('nothing to add makes no call', () async {
      final result = await writer.addItems('list-1', const []);
      expect(batches.calls, isEmpty);
      expect(result.token, isNull);
      expect(result.addedCount, 0);
    });

    test('forgets amounts of items that are gone', () async {
      await writer.addItems('list-1', [onions, coconut]);
      await writer.forgetItemsExcept('list-1', {'new-Kokosmilch'});
      expect((await writer.contributionsForList('list-1')).keys, ['new-Kokosmilch']);
    });
  });
}

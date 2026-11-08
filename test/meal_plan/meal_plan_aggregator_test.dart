// Wochenplan (B7): "Zutaten der Woche" — the pure function that merges the
// ingredients of planned recipes into one clean shopping list (Konzept 14,
// 6.4 and 13.2; Plan 5 / Verbesserungsliste 11 acceptance).
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/models/meal_plan.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/services/meal_plan_aggregator.dart';

const _order = [
  'fruits_vegetables',
  'bakery',
  'meat_fish',
  'staples',
  'snacks',
  'beverages',
  'household',
  'dairy',
  'frozen',
  'other',
];

/// Local stand-in for the keyword categorizer.
String _category(String name) {
  final n = name.toLowerCase();
  const byWord = {
    'zwiebel': 'fruits_vegetables',
    'onion': 'fruits_vegetables',
    'knoblauch': 'fruits_vegetables',
    'paprika': 'fruits_vegetables',
    'koriander': 'fruits_vegetables',
    'potato': 'fruits_vegetables',
    'lemon': 'fruits_vegetables',
    'dill': 'fruits_vegetables',
    'brokkoli': 'fruits_vegetables',
    'äpfel': 'fruits_vegetables',
    'salmon': 'meat_fish',
    'butter': 'dairy',
    'joghurt': 'dairy',
    'milch': 'dairy',
  };
  for (final e in byWord.entries) {
    if (n.contains(e.key)) return e.value;
  }
  return 'staples';
}

Ingredient _i(String name, num amount, String unit) =>
    Ingredient(name: name, amount: amount.toDouble(), unit: unit);

int _id = 0;

MealPlanEntry _entry(
  String recipeName,
  List<Ingredient> ingredients, {
  required DateTime day,
  int servings = 2,
  int defaultServings = 2,
  String language = 'de',
  String? id,
  String? recipeId = 'r',
  int? sentServings,
  String? sentListId,
}) {
  final entryId = id ?? 'e${_id++}';
  return MealPlanEntry(
    id: entryId,
    userId: 'u1',
    planDate: day,
    recipeId: recipeId == 'r' ? 'recipe-$entryId' : recipeId,
    snapshot: PlanRecipeSnapshot(
      name: recipeName,
      defaultServings: defaultServings,
      language: language,
      ingredients: ingredients,
    ),
    servings: servings,
    sentServings: sentServings,
    sentAt: sentServings == null ? null : DateTime.utc(2026, 11, 7),
    sentListId: sentServings == null ? null : (sentListId ?? 'list-1'),
    createdAt: DateTime(2026, 11, 1),
    updatedAt: DateTime(2026, 11, 1),
  );
}

PlanListItem _item(String name, double qty, String? unit,
        {String id = 'item', List<PlanContribution> contributions = const []}) =>
    PlanListItem(id: id, name: name, quantity: qty, unit: unit, contributions: contributions);

PlanIngredientLine _line(PlanAggregation a, String displayName) =>
    a.lines.singleWhere((l) => l.displayName == displayName,
        orElse: () => throw StateError(
            'no line "$displayName" in ${a.lines.map((l) => l.displayName).toList()}'));

final _mon = DateTime(2026, 11, 9);
final _wed = DateTime(2026, 11, 11);
final _thu = DateTime(2026, 11, 12);
final _fri = DateTime(2026, 11, 13);
final _sat = DateTime(2026, 11, 14);

void main() {
  group('acceptance: a plan with 5 recipes becomes one clean list', () {
    late List<MealPlanEntry> entries;
    late PlanAggregation result;

    setUp(() {
      entries = [
        _entry('Chili sin Carne', [
          _i('Zwiebeln', 2, ''),
          _i('Knoblauchzehen', 2, ''),
          _i('Paprika', 1, 'Stück'),
          _i('Koriander', 1, 'Bund'),
          _i('Kidneybohnen', 2, 'Dosen'),
          _i('Mais', 1, 'Dose'),
          _i('Passierte Tomaten', 500, 'g'),
          _i('Reis', 250, 'g'),
          _i('Salz', 1, 'Prise'),
          _i('Olivenöl', 2, 'EL'),
        ], day: _wed, servings: 4, defaultServings: 4),
        _entry('Linsen-Bolognese', [
          _i('Spaghetti', 500, 'g'),
          _i('Rote Linsen', 200, 'g'),
          _i('Passierte Tomaten', 0.5, 'kg'),
          _i('Zwiebel', 1, 'Stk'),
          _i('Knoblauch', 1, 'Zehe'),
          _i('Olivenöl', 1, 'EL'),
        ], day: _thu),
        _entry('Salmon with potatoes', [
          _i('Salmon fillet', 2, 'pcs'),
          _i('Potatoes', 0.6, 'kg'),
          _i('Lemon', 1, 'pc'),
          _i('Dill', 1, 'bunch'),
          _i('Olive oil', 1, 'tbsp'),
          _i('Salt', 1, 'pinch'),
        ], day: _fri, language: 'en'),
        _entry('Vegetable curry', [
          _i('Coconut milk', 400, 'ml'),
          _i('Chickpeas', 1, 'can'),
          _i('Broccoli', 1, 'pcs'),
          _i('Onion', 1, 'pcs'),
          _i('Yogurt', 150, 'g'),
          _i('Rice', 225, 'g'),
        ], day: _sat, servings: 3, defaultServings: 3, language: 'en'),
        _entry('Apfel-Crumble', [
          _i('Äpfel', 4, ''),
          _i('Butter', 100, 'g'),
          _i('Mehl', 150, 'g'),
          _i('Zucker', 80, 'g'),
          _i('Zimt', 1, 'TL'),
        ], day: _sat, servings: 4, defaultServings: 4),
      ];
      result = aggregatePlanIngredients(
        entries: entries,
        pantry: MealPlanSettings.defaultPantry,
        openItems: [
          _item('Reis', 1, 'kg', id: 'rice'),
          _item('Butter', 50, 'g', id: 'butter'),
          _item('Milch', 1, null, id: 'milk'),
        ],
        categoryOf: _category,
        categoryOrder: _order,
      );
    });

    test('no duplicate lines', () {
      final keys = result.lines.map((l) => l.key).toList();
      expect(keys.toSet(), hasLength(keys.length));
      final names = result.lines.map((l) => '${l.nameKey}|${l.family.id}').toList();
      expect(names.toSet(), hasLength(names.length));
    });

    test('mixed German and English names merge (onion/Zwiebel)', () {
      final onion = _line(result, 'Zwiebeln');
      expect(onion.needed!.amount, 4);
      expect(onion.recipeNames,
          ['Chili sin Carne', 'Linsen-Bolognese', 'Vegetable curry']);
      expect(result.lines.where((l) => l.nameKey == 'zwiebel'), hasLength(1));
    });

    test('same unit family is summed: g and kg, cloves', () {
      expect(_line(result, 'Passierte Tomaten').needed!.format('de'), '1 kg');
      expect(_line(result, 'Potatoes').needed!.format('de'), '600 g');
      // "Knoblauchzehen" (pieces) and "Knoblauch" (Zehe) are one line.
      final garlic = _line(result, 'Knoblauch');
      expect(garlic.family, PlanUnitFamily.clove);
      expect(garlic.needed!.format('de'), '3 Zehen');
      expect(_line(result, 'Kidneybohnen').needed!.format('de'), '2 Dosen');
    });

    test('pantry items are excluded by default', () {
      for (final name in ['Salz', 'Olivenöl', 'Mehl', 'Zucker']) {
        final l = _line(result, name);
        expect(l.selected, isFalse, reason: name);
        expect(l.reason, PlanLineReason.pantry, reason: name);
      }
      // "Olivenöl" (EL) and "Olive oil" (tbsp) are one line without quantity.
      expect(_line(result, 'Olivenöl').needed, isNull);
      expect(result.lines.where((l) => l.nameKey == 'olivenoel'), hasLength(1));
    });

    test('items already on the list are not added again', () {
      final rice = _line(result, 'Reis');
      expect(rice.selected, isFalse);
      expect(rice.reason, PlanLineReason.alreadyOnList);
      expect(rice.onList!.format('de'), '1 kg');
      expect(rice.toAdd, isNull);
    });

    test('partly on the list: selected, only the rest is added', () {
      final butter = _line(result, 'Butter');
      expect(butter.selected, isTrue);
      expect(butter.reason, isNull);
      expect(butter.onList!.format('de'), '50 g');
      expect(butter.toAdd!.format('de'), '50 g');
    });

    test('lines are sorted by the category order of the list', () {
      final indexes = [for (final l in result.lines) _order.indexOf(l.categoryId)];
      expect(indexes, orderedEquals([...indexes]..sort()));
      expect(result.lines.first.categoryId, 'fruits_vegetables');
    });

    test('every quantity is rounded to a shoppable step', () {
      for (final l in result.lines) {
        final q = l.toAdd ?? l.needed;
        if (q == null) continue;
        final a = q.amount;
        switch (l.family) {
          case PlanUnitFamily.mass || PlanUnitFamily.volume:
            expect(a < 100 ? a % 10 : a % 25, 0, reason: l.displayName);
          default:
            expect(a, a.roundToDouble(), reason: l.displayName);
        }
      }
    });

    test('the selected count is the number of merged lines to add', () {
      expect(result.selectedCount, result.lines.where((l) => l.selected).length);
      expect(result.selectedLines.map((l) => l.displayName),
          isNot(contains('Reis')));
      expect(result.alreadyOnListCount, 1);
    });

    test('missing count per entry for the plan rows', () {
      final curry = entries[3];
      // Coconut milk, chickpeas, broccoli, onion, yogurt; rice is on the list.
      expect(result.missingByEntry[curry.id], 5);
      final crumble = entries[4];
      // Äpfel, Butter (partly), Zimt; Mehl and Zucker are pantry.
      expect(result.missingByEntry[crumble.id], 3);
      expect(result.missingNamesByEntry[crumble.id], ['Äpfel', 'Butter', 'Zimt']);
    });

    test('a typed result for Avo (plan_to_list)', () {
      final json = result.toAvoJson('de');
      expect(json['recipe_count'], 5);
      expect(json['selected_count'], result.selectedCount);
      expect(json['already_on_list_count'], 1);
      final lines = json['lines'] as List;
      final rice = lines.cast<Map<String, dynamic>>().singleWhere((l) => l['name'] == 'Reis');
      expect(rice['selected'], isFalse);
      expect(rice['reason'], 'already_on_list');
      expect(rice['on_list'], '1 kg');
    });
  });

  group('scaling', () {
    test('a recipe with 0 default servings does not crash', () {
      final a = aggregatePlanIngredients(entries: [
        _entry('Kaputt', [_i('Mehl', 200, 'g'), _i('Eier', 2, '')],
            day: _wed, servings: 2, defaultServings: 0),
      ]);
      expect(a.lines, hasLength(2));
      for (final l in a.lines) {
        expect(l.needed!.amount.isFinite, isTrue);
      }
      expect(_line(a, 'Eier').needed!.amount, 4);
    });

    test('133.333 g never appears, it is rounded up', () {
      final a = aggregatePlanIngredients(entries: [
        _entry('Kuchen', [
          _i('Quark', 400, 'g'),
          _i('Kokosmilch', 400, 'ml'),
          _i('Joghurt', 150, 'g'),
          _i('Nüsse', 70, 'g'),
          _i('Eier', 5, ''),
        ], day: _wed, servings: 2, defaultServings: 3),
      ]);
      expect(_line(a, 'Quark').needed!.format('de'), '275 g');
      expect(_line(a, 'Kokosmilch').needed!.format('de'), '275 ml');
      expect(_line(a, 'Joghurt').needed!.format('de'), '100 g');
      expect(_line(a, 'Nüsse').needed!.format('de'), '50 g');
      expect(_line(a, 'Eier').needed!.format('de'), '4');
      for (final l in a.lines) {
        expect(l.needed!.format('de'), isNot(contains('133')));
        expect(l.needed!.format('de'), isNot(contains('.')));
      }
    });

    test('one serving of 400 g for three is 150 g, not 133.333 g', () {
      final a = aggregatePlanIngredients(entries: [
        _entry('Pasta', [_i('Nudeln', 400, 'g')], day: _wed, servings: 1, defaultServings: 3),
      ]);
      expect(_line(a, 'Nudeln').needed!.amount, 150);
    });

    test('pieces are rounded up: 2.5 onions become 3', () {
      final a = aggregatePlanIngredients(entries: [
        _entry('Suppe', [_i('Zwiebeln', 5, '')], day: _wed, servings: 1, defaultServings: 2),
      ]);
      expect(_line(a, 'Zwiebeln').needed!.amount, 3);
    });

    test('a sent entry only counts the added servings (W-05)', () {
      final a = aggregatePlanIngredients(entries: [
        _entry('Curry', [_i('Kokosmilch', 400, 'ml')],
            day: _sat, servings: 5, defaultServings: 3, sentServings: 3),
        _entry('Gestern', [_i('Brot', 1, '')],
            day: _sat, servings: 2, sentServings: 4),
      ]);
      expect(a.lines.single.displayName, 'Kokosmilch');
      expect(a.lines.single.needed!.format('de'), '275 ml');
    });
  });

  group('units', () {
    test('EL, TL and Prise are listed without quantity', () {
      final a = aggregatePlanIngredients(entries: [
        _entry('Dressing', [
          _i('Senf', 1, 'TL'),
          _i('Essig', 2, 'EL'),
          _i('Muskat', 1, 'Prise'),
          _i('Honey', 1, 'tsp'),
          _i('Basilikum', 0, 'nach Geschmack'),
        ], day: _wed),
      ]);
      for (final l in a.lines) {
        expect(l.family, PlanUnitFamily.unquantified, reason: l.displayName);
        expect(l.needed, isNull, reason: l.displayName);
        expect(l.quantityLabel('de'), '', reason: l.displayName);
        expect(l.selected, isTrue, reason: l.displayName);
      }
    });

    test('different families stay separate lines of the same name', () {
      final a = aggregatePlanIngredients(entries: [
        _entry('A', [_i('Butter', 100, 'g')], day: _wed),
        _entry('B', [_i('Butter', 2, 'EL')], day: _thu),
      ]);
      expect(a.lines.where((l) => l.nameKey == 'butter'), hasLength(2));
    });

    test('pieces only merge with pieces, containers only with themselves', () {
      final a = aggregatePlanIngredients(entries: [
        _entry('A', [_i('Tomaten', 2, ''), _i('Tomaten', 1, 'Dose')], day: _wed),
        _entry('B', [_i('Tomatoes', 1, 'pcs'), _i('Tomaten', 400, 'g')], day: _thu, language: 'en'),
      ]);
      final tomato = a.lines.where((l) => l.nameKey == 'tomate').toList();
      expect(tomato.map((l) => l.family).toSet(),
          {PlanUnitFamily.pieces, PlanUnitFamily.can, PlanUnitFamily.mass});
      expect(tomato.firstWhere((l) => l.family == PlanUnitFamily.pieces).needed!.amount, 3);
    });

    test('ml, cl, dl and l convert', () {
      final a = aggregatePlanIngredients(entries: [
        _entry('A', [_i('Milch', 0.5, 'l'), _i('Milch', 2, 'dl'), _i('Milch', 5, 'cl'), _i('Milk', 250, 'ml')],
            day: _wed),
      ]);
      expect(a.lines.single.needed!.format('de'), '1 l');
    });

    test('English bell peppers counted in pieces are Paprika, not pepper', () {
      final a = aggregatePlanIngredients(
        entries: [
          _entry('A', [_i('Peppers', 2, 'pcs'), _i('Pepper', 1, 'pinch')], day: _wed, language: 'en'),
        ],
        pantry: MealPlanSettings.defaultPantry,
      );
      expect(a.lines.firstWhere((l) => l.family == PlanUnitFamily.pieces).nameKey, 'paprika');
      final pepper = a.lines.firstWhere((l) => l.family == PlanUnitFamily.unquantified);
      expect(pepper.reason, PlanLineReason.pantry);
    });
  });

  group('matching the target list', () {
    test("the plan's own amounts never count as on the list (W-17)", () {
      final curry = _entry('Curry', [_i('Kokosmilch', 400, 'ml')],
          id: 'curry', day: _sat, servings: 5, defaultServings: 3, sentServings: 3);
      final a = aggregatePlanIngredients(entries: [curry], openItems: [
        _item('Kokosmilch', 400, 'ml', contributions: const [
          PlanContribution(entryId: 'curry', family: 'volume', baseAmount: 400),
        ]),
      ]);
      final line = a.lines.single;
      expect(line.selected, isTrue);
      expect(line.reason, isNull);
      expect(line.onList, isNull);
      expect(line.toAdd!.format('de'), '275 ml');
    });

    test('on the list and in the pantry: already on the list wins', () {
      final a = aggregatePlanIngredients(
        entries: [_entry('A', [_i('Salz', 1, 'Prise'), _i('Zucker', 50, 'g')], day: _wed)],
        pantry: MealPlanSettings.defaultPantry,
        openItems: [_item('Salz', 1, null), _item('Zucker', 1, 'kg', id: 'sugar')],
      );
      expect(_line(a, 'Salz').reason, PlanLineReason.alreadyOnList);
      expect(_line(a, 'Zucker').reason, PlanLineReason.alreadyOnList);
    });

    test('another unit family on the list is no match', () {
      final a = aggregatePlanIngredients(
        entries: [_entry('A', [_i('Butter', 100, 'g')], day: _wed)],
        openItems: [_item('Butter', 1, 'pack')],
      );
      final butter = a.lines.single;
      expect(butter.selected, isTrue);
      expect(butter.onList, isNull);
      expect(butter.toAdd!.format('de'), '100 g');
    });

    test('a pantry word covers compounds: Öl covers Olivenöl and Rapsöl', () {
      final a = aggregatePlanIngredients(
        entries: [
          _entry('A', [_i('Olivenöl', 50, 'ml'), _i('Rapsöl', 2, 'EL'), _i('Meersalz', 1, 'TL'), _i('Ölsardinen', 1, 'Dose')],
              day: _wed),
        ],
        pantry: MealPlanSettings.defaultPantry,
      );
      expect(_line(a, 'Olivenöl').reason, PlanLineReason.pantry);
      expect(_line(a, 'Rapsöl').reason, PlanLineReason.pantry);
      expect(_line(a, 'Meersalz').reason, PlanLineReason.pantry);
      expect(_line(a, 'Ölsardinen').reason, isNull);
    });
  });

  group('substitutions and recipes without ingredients', () {
    test('substitutions are applied before merging', () {
      List<PlanSubstitution?> lactoseFree(List<Ingredient> ingredients) => [
            for (final i in ingredients)
              i.name == 'Milch'
                  ? PlanSubstitution(
                      ingredient: Ingredient(name: 'Hafermilch', amount: i.amount, unit: i.unit),
                      reason: 'lactose')
                  : null,
          ];
      final entries = [
        _entry('A', [_i('Milch', 200, 'ml')], day: _wed),
        _entry('B', [_i('Hafermilch', 300, 'ml')], day: _thu),
      ];
      final a = aggregatePlanIngredients(entries: entries, substitute: lactoseFree);
      final oat = a.lines.single;
      expect(oat.displayName, 'Hafermilch');
      expect(oat.needed!.format('de'), '500 ml');
      expect(oat.substitution!.originalName, 'Milch');
      expect(oat.substitution!.reason, 'lactose');

      final original = aggregatePlanIngredients(
          entries: entries, substitute: lactoseFree, keepOriginal: {'milch'});
      expect(original.lines.map((l) => l.displayName), ['Milch', 'Hafermilch']);
    });

    test('a deleted recipe or one without ingredients is listed apart', () {
      final gone = _entry('Gelöscht', [_i('Mehl', 1, 'kg')], day: _wed, recipeId: null);
      final empty = _entry('Flammkuchen mit Lauch', const [], day: _thu);
      final a = aggregatePlanIngredients(entries: [gone, empty]);
      expect(a.lines, isEmpty);
      expect(a.withoutIngredients.map((w) => (w.recipeName, w.reason)), [
        ('Gelöscht', PlanSkipReason.recipeUnavailable),
        ('Flammkuchen mit Lauch', PlanSkipReason.noIngredients),
      ]);
    });

    test('the loaded recipe wins over the snapshot', () {
      final e = _entry('Alt', [_i('Mehl', 100, 'g')], day: _wed, id: 'x');
      final recipe = Recipe(
        id: e.recipeId!,
        name: 'Neu',
        description: '',
        imageUrl: '',
        prepTimeMinutes: 0,
        cookTimeMinutes: 0,
        defaultServings: 2,
        ingredients: [_i('Dinkelmehl', 300, 'g')],
        instructions: const [],
        authorId: 'a',
        authorName: 'a',
        createdAt: DateTime(2026),
      );
      final a = aggregatePlanIngredients(entries: [e], recipesById: {recipe.id: recipe});
      expect(a.lines.single.displayName, 'Dinkelmehl');
      expect(a.lines.single.recipeNames, ['Neu']);
    });
  });

  group('range', () {
    final entries = [
      _entry('Mo', [_i('A', 1, '')], day: _mon),
      _entry('Mi', [_i('B', 1, '')], day: _wed),
      _entry('Sa', [_i('C', 1, '')], day: _sat),
      _entry('Next', [_i('D', 1, '')], day: DateTime(2026, 11, 16)),
    ];

    test('"Ab heute" in the current week starts today', () {
      final r = entriesInRange(entries,
          weekStart: _mon, range: PlanRange.fromToday, today: DateTime(2026, 11, 11, 19));
      expect(r.map((e) => e.snapshot.name), ['Mi', 'Sa']);
    });

    test('"Ganze Woche" is Monday to Sunday', () {
      final r = entriesInRange(entries,
          weekStart: _mon, range: PlanRange.wholeWeek, today: _wed);
      expect(r.map((e) => e.snapshot.name), ['Mo', 'Mi', 'Sa']);
    });

    test('a future week is always whole', () {
      final r = entriesInRange(entries,
          weekStart: DateTime(2026, 11, 16), range: PlanRange.fromToday, today: _wed);
      expect(r.map((e) => e.snapshot.name), ['Next']);
    });
  });

  group('formatting', () {
    test('German comma, English point, kg and l from 1000', () {
      const q = PlanQuantity(amount: 1500, family: PlanUnitFamily.mass);
      expect(q.format('de'), '1,5 kg');
      expect(q.format('en'), '1.5 kg');
      expect(const PlanQuantity(amount: 1250, family: PlanUnitFamily.volume).format('de'), '1,25 l');
      expect(const PlanQuantity(amount: 475, family: PlanUnitFamily.mass).format('de'), '475 g');
    });

    test('container words in both languages', () {
      expect(const PlanQuantity(amount: 1, family: PlanUnitFamily.can).format('de'), '1 Dose');
      expect(const PlanQuantity(amount: 2, family: PlanUnitFamily.can).format('de'), '2 Dosen');
      expect(const PlanQuantity(amount: 2, family: PlanUnitFamily.can).format('en'), '2 cans');
      expect(const PlanQuantity(amount: 1, family: PlanUnitFamily.bunch).format('de'), '1 Bund');
      expect(const PlanQuantity(amount: 3, family: PlanUnitFamily.pieces).format('de'), '3');
    });
  });

  group('names', () {
    test('singular, plural and synonyms share one key', () {
      expect(planNameKey('Zwiebeln'), planNameKey('onion'));
      expect(planNameKey('Onions'), planNameKey('Zwiebel'));
      expect(planNameKey('Tomaten'), planNameKey('tomatoes'));
      expect(planNameKey('Eier'), planNameKey('egg'));
      expect(planNameKey('Äpfel'), planNameKey('Apfel'));
      expect(planNameKey('Kartoffeln'), planNameKey('potatoes'));
      expect(planNameKey('Lachs'), planNameKey('salmon'));
      expect(planNameKey('Kichererbsen'), planNameKey('chickpeas'));
      expect(planNameKey('Reis'), 'reis');
      expect(planNameKey('Mais'), 'mais');
    });
  });
}

import 'dart:math' as math;

import 'package:intl/intl.dart';

import 'package:shoply/core/utils/item_quantity.dart';
import 'package:shoply/data/models/dietary_preference.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/user_model.dart';
import 'package:shoply/data/repositories/item_batch.dart';
import 'package:shoply/data/services/allergen_matcher.dart';

// Allergies, diets and amounts of one recipe for one person (Konzept 13
// §2.2, §2.3). Pure Dart, no widgets: the detail, "Zutaten auf die Liste"
// and the cooking mode (through the adapted recipe) read the same result.
//
// Allergens are found with Teil B's [AllergenMatcher] (word boundaries,
// German compounds, look-alikes such as Kokosmilch or Erdnussbutter). A
// substitute is only offered when it resolves every reason of its
// ingredient AND brings no allergen or diet conflict of its own; otherwise
// nothing is replaced and the notice says so.

// ------------------------------------------------------------------ profile

/// The diets the adaptation knows (`users.diet_preferences` ids).
enum RecipeDiet { vegan, vegetarian, pescatarian }

RecipeDiet? _dietOf(String id) => switch (id.trim().toLowerCase()) {
  'vegan' => RecipeDiet.vegan,
  'vegetarian' || 'vegetarisch' => RecipeDiet.vegetarian,
  'pescatarian' || 'pescetarian' || 'pescetarisch' => RecipeDiet.pescatarian,
  _ => null,
};

/// Diet ids that are really "must not eat" constraints (Konzept 13 §2.3:
/// allergies first, never hidden), with the allergies they stand for.
const Map<String, List<String>> _dietAllergies = {
  'gluten_free': ['gluten'],
  'dairy_free': ['milk'],
  'nut_free': ['nuts', 'peanuts'],
};

/// One thing the person must not eat.
class AllergyConstraint {
  const AllergyConstraint({required this.raw, this.fromDiet});

  /// As stored: an [AllergyType] name (`milk`), a label or free text
  /// (`Kiwi`).
  final String raw;

  /// The diet id this comes from (`gluten_free`), null for an allergy.
  final String? fromDiet;

  /// Resolved type; null for free text.
  AllergyType? get type => AllergenMatcher.resolve(raw);

  @override
  bool operator ==(Object other) =>
      other is AllergyConstraint &&
      other.raw == raw &&
      other.fromDiet == fromDiet;

  @override
  int get hashCode => Object.hash(raw, fromDiet);
}

/// What one person avoids: allergies (also from "glutenfrei", "milchfrei",
/// "nussfrei") and the diets vegan, vegetarisch, pescetarisch.
class RecipeDietProfile {
  const RecipeDietProfile({this.allergies = const [], this.diets = const []});

  /// From the stored lists; unknown diets are ignored, unknown allergies
  /// stay as free text. Each allergy type counts once.
  factory RecipeDietProfile.of({
    List<String> allergies = const [],
    List<String> diets = const [],
  }) {
    final constraints = <AllergyConstraint>[];
    final types = <AllergyType>{};
    final texts = <String>{};
    void add(AllergyConstraint c) {
      final type = c.type;
      if (type != null) {
        if (!types.add(type)) return;
      } else {
        final key = AllergenMatcher.fold(c.raw).trim();
        if (key.isEmpty || !texts.add(key)) return;
      }
      constraints.add(c);
    }

    for (final raw in allergies) {
      add(AllergyConstraint(raw: raw));
    }
    final known = <RecipeDiet>{};
    for (final id in diets) {
      final mapped = _dietAllergies[id.trim().toLowerCase()];
      if (mapped != null) {
        for (final raw in mapped) {
          add(AllergyConstraint(raw: raw, fromDiet: id.trim().toLowerCase()));
        }
        continue;
      }
      final diet = _dietOf(id);
      if (diet != null) known.add(diet);
    }
    return RecipeDietProfile(
      allergies: constraints,
      diets: [
        for (final d in RecipeDiet.values)
          if (known.contains(d)) d,
      ],
    );
  }

  /// The signed-in person's profile; empty without a person.
  factory RecipeDietProfile.ofUser(UserModel? user) => user == null
      ? const RecipeDietProfile()
      : RecipeDietProfile.of(
          allergies: user.allergies,
          diets: user.dietPreferences,
        );

  final List<AllergyConstraint> allergies;
  final List<RecipeDiet> diets;

  bool get isEmpty => allergies.isEmpty && diets.isEmpty;
}

// ------------------------------------------------------------------- result

/// One ingredient with what it means for the person.
class AdaptedIngredient {
  const AdaptedIngredient({
    required this.original,
    this.substitute,
    this.substitutionKey,
    this.allergens = const [],
    this.diets = const [],
    this.unchecked = false,
  });

  final Ingredient original;

  /// A safe replacement, same amount and unit; null when none is known.
  final Ingredient? substitute;

  /// The word of [original] that was replaced ("Milch" in "Vollmilch").
  final String? substitutionKey;

  /// The person's allergies this ingredient contains.
  final List<AllergyConstraint> allergens;

  /// The person's diets it breaks.
  final List<RecipeDiet> diets;

  /// It could not be checked for allergens ("Pesto", "Gewürzmischung").
  final bool unchecked;

  bool get isAdapted => substitute != null;

  /// Contains an allergen and nothing safe replaces it.
  bool get isUnsafe => allergens.isNotEmpty && substitute == null;

  /// Breaks a diet (no allergen) and nothing replaces it.
  bool get breaksDietOnly =>
      allergens.isEmpty && diets.isNotEmpty && substitute == null;

  /// The ingredient as shown in [adapted] or original mode.
  Ingredient shown({required bool adapted}) =>
      adapted && substitute != null ? substitute! : original;
}

/// The recipe for one person: every ingredient checked, safe substitutes,
/// and the steps with substitutes named in them.
class RecipeAdaptation {
  const RecipeAdaptation({
    required this.ingredients,
    required this.adaptedSteps,
    required this.stepSubstitutions,
    required this.profile,
  });

  /// The recipe without changes (no profile, or the person is signed out).
  factory RecipeAdaptation.none(Recipe recipe) => RecipeAdaptation(
    ingredients: [
      for (final i in recipe.ingredients) AdaptedIngredient(original: i),
    ],
    adaptedSteps: recipe.instructions,
    stepSubstitutions: [for (final _ in recipe.instructions) const []],
    profile: const RecipeDietProfile(),
  );

  /// Checks every ingredient of [recipe] against [profile].
  factory RecipeAdaptation.of(Recipe recipe, RecipeDietProfile profile) {
    if (profile.isEmpty) return RecipeAdaptation.none(recipe);
    final matchers = {
      for (final c in profile.allergies) c: AllergenMatcher([c.raw]),
    };
    final ingredients = [
      for (final ingredient in recipe.ingredients)
        _check(ingredient, profile, matchers),
    ];
    final steps = <String>[];
    final notes = <List<AdaptedIngredient>>[];
    for (final step in recipe.instructions) {
      var text = step;
      final used = <AdaptedIngredient>[];
      for (final ingredient in ingredients) {
        final sub = ingredient.substitute;
        if (sub == null) continue;
        final replaced = _replaceWords(text, [
          ingredient.original.name,
          ?ingredient.substitutionKey,
        ], _stepName(sub.name));
        if (replaced != text) {
          text = replaced;
          used.add(ingredient);
        }
      }
      steps.add(text);
      notes.add(used);
    }
    return RecipeAdaptation(
      ingredients: ingredients,
      adaptedSteps: steps,
      stepSubstitutions: notes,
      profile: profile,
    );
  }

  final List<AdaptedIngredient> ingredients;

  /// Steps with substitutes in place of the replaced ingredients.
  final List<String> adaptedSteps;

  /// Per step, the ingredients whose substitute appears in it.
  final List<List<AdaptedIngredient>> stepSubstitutions;

  final RecipeDietProfile profile;

  /// There is something to switch between ("Für dich angepasst | Original").
  bool get hasSubstitutes => ingredients.any((i) => i.isAdapted);

  /// Something the notice has to say.
  bool get hasNotice => ingredients.any(
    (i) => i.allergens.isNotEmpty || i.diets.isNotEmpty || i.unchecked,
  );

  /// At least one allergen of the person is in the recipe (with or without
  /// a substitute): the warning haptic plays once.
  bool get hasAllergen => ingredients.any((i) => i.allergens.isNotEmpty);

  /// Ingredients that could not be checked.
  List<AdaptedIngredient> get unchecked => [
    for (final i in ingredients)
      if (i.unchecked) i,
  ];

  /// [recipe] as the person cooks it: substitutes in the ingredients and in
  /// the steps (what the cooking mode and the list get).
  Recipe applyTo(Recipe recipe, {required bool adapted}) {
    if (!adapted || !hasSubstitutes) return recipe;
    return recipe.copyWith(
      ingredients: [for (final i in ingredients) i.shown(adapted: true)],
      instructions: adaptedSteps,
    );
  }

  /// Steps for [adapted] or original mode.
  List<String> steps(Recipe recipe, {required bool adapted}) =>
      adapted ? adaptedSteps : recipe.instructions;
}

// ------------------------------------------------------------------ checks

AdaptedIngredient _check(
  Ingredient ingredient,
  RecipeDietProfile profile,
  Map<AllergyConstraint, AllergenMatcher> matchers,
) {
  final name = ingredient.name;
  final allergens = [
    for (final c in profile.allergies)
      if (_contains(c, matchers[c]!, name)) c,
  ];
  final diets = [
    for (final d in profile.diets)
      if (breaksRecipeDiet(name, d)) d,
  ];
  final unchecked =
      profile.allergies.isNotEmpty &&
      allergens.isEmpty &&
      isUncheckedIngredient(name);
  if (allergens.isEmpty && diets.isEmpty) {
    return AdaptedIngredient(original: ingredient, unchecked: unchecked);
  }
  final key = _substitutionKey(name);
  IngredientSubstitution? found;
  if (key != null) {
    for (final sub in SubstitutionDatabase.substitutions[key]!) {
      if (_isSafe(sub, allergens, diets, profile, matchers)) {
        found = sub;
        break;
      }
    }
  }
  return AdaptedIngredient(
    original: ingredient,
    substitute: found == null
        ? null
        : Ingredient(
            name: found.substitute,
            amount: ingredient.amount,
            unit: ingredient.unit,
          ),
    substitutionKey: found == null ? null : key,
    allergens: allergens,
    diets: diets,
  );
}

/// Milk products the shared [AllergenMatcher] does not list yet (cheeses
/// by name; Konzept 13 §12.2 uses Feta). Folded, matched as words or word
/// ends ("Schafsfeta"). Reported to Teil B for the matcher itself.
const _moreMilkWords = [
  'feta', 'halloumi', 'gouda', 'emmentaler', 'edamer', 'cheddar', //
  'camembert', 'brie', 'pecorino', 'gorgonzola', 'burrata', 'ghee', 'skyr',
  'labneh', 'paneer', 'raclette', 'manchego', 'bergkase', 'frischkase',
  'buttermilch', 'creme fraiche', 'cremefraiche', 'kondensmilch',
];

const _lactoseFree = ['laktosefrei', 'lactose free', 'lactosefree'];

/// [matcher] plus [_moreMilkWords] for milk and lactose.
bool _contains(AllergyConstraint c, AllergenMatcher matcher, String text) {
  if (matcher.contains(text)) return true;
  final type = c.type;
  if (type != AllergyType.milk && type != AllergyType.lactose) return false;
  final folded = AllergenMatcher.fold(text);
  if (type == AllergyType.lactose && _lactoseFree.any(folded.contains)) {
    return false;
  }
  final tokens = recipeTokens(text);
  final joined = ' ${tokens.join(' ')} ';
  return _moreMilkWords.any(
    (w) => w.contains(' ')
        ? joined.contains(' $w ')
        : tokens.any((t) => t == w || (t.endsWith(w) && !_plantCompound(t, w))),
  );
}

/// A substitute is safe when it is meant for every reason of its
/// ingredient and does not bring an allergen or diet conflict of its own.
bool _isSafe(
  IngredientSubstitution sub,
  List<AllergyConstraint> allergens,
  List<RecipeDiet> diets,
  RecipeDietProfile profile,
  Map<AllergyConstraint, AllergenMatcher> matchers,
) {
  for (final c in allergens) {
    if (!_avoids(sub, c)) return false;
  }
  for (final d in diets) {
    if (!_suits(sub, d)) return false;
  }
  for (final c in profile.allergies) {
    if (_avoids(sub, c)) continue;
    if (_contains(c, matchers[c]!, sub.substitute)) return false;
  }
  for (final d in profile.diets) {
    if (_suits(sub, d)) continue;
    if (breaksRecipeDiet(sub.substitute, d)) return false;
  }
  return true;
}

bool _avoids(IngredientSubstitution sub, AllergyConstraint c) {
  final type = c.type;
  if (type == null) return false;
  if (sub.avoidsAllergies.contains(type)) return true;
  // Free of milk is free of lactose.
  return type == AllergyType.lactose &&
      sub.avoidsAllergies.contains(AllergyType.milk);
}

bool _suits(IngredientSubstitution sub, RecipeDiet diet) {
  final s = sub.suitableFor;
  return switch (diet) {
    RecipeDiet.vegan => s.contains(DietType.vegan),
    RecipeDiet.vegetarian =>
      s.contains(DietType.vegan) || s.contains(DietType.vegetarian),
    RecipeDiet.pescatarian =>
      s.contains(DietType.vegan) ||
          s.contains(DietType.vegetarian) ||
          s.contains(DietType.pescetarian),
  };
}

/// The entry of [SubstitutionDatabase] for [name]: the whole name, a word
/// of it, or the end of a compound ("Vollmilch" → "Milch"); the longest
/// wins.
String? _substitutionKey(String name) {
  final folded = AllergenMatcher.fold(name).trim();
  final tokens = recipeTokens(name);
  String? best;
  for (final key in SubstitutionDatabase.substitutions.keys) {
    final k = AllergenMatcher.fold(key);
    final hit =
        folded == k ||
        tokens.any(
          (t) =>
              t == k ||
              (k.length >= 4 && t.endsWith(k) && !_plantCompound(t, k)),
        );
    if (hit && (best == null || k.length > AllergenMatcher.fold(best).length)) {
      best = key;
    }
  }
  return best;
}

const _plantPrefixes = [
  'hafer', 'kokos', 'mandel', 'soja', 'reis', 'erbsen', 'cashew', 'dinkel', //
  'nuss', 'erdnuss', 'kakao', 'shea', 'vegan', 'pflanzen', 'linsen',
];

bool _plantCompound(String token, String key) {
  final head = token.substring(0, token.length - key.length);
  return _plantPrefixes.any(head.startsWith);
}

// ------------------------------------------------------------------- diets

/// Words of [text], lower case without diacritics ("Hähnchen" → "hahnchen").
List<String> recipeTokens(String text) => AllergenMatcher.fold(text)
    .split(RegExp(r'[^a-z0-9]+'))
    .where((t) => t.isNotEmpty)
    .toList(growable: false);

const _meatParts = [
  'fleisch', 'hahnchen', 'huhn', 'schwein', 'schinken', 'speck', 'salami', //
  'wurst', 'pancetta', 'chorizo', 'bacon', 'chicken', 'beef', 'pork',
  'sausage', 'steak', 'turkey', 'prosciutto', 'gelatine', 'gelatin',
  'geflugel', 'serrano', 'mortadella', 'leberkas', 'kassler', 'hackepeter',
];
const _meatWords = [
  'rind', 'lamm', 'ham', 'lamb', 'veal', 'duck', 'ente', 'gans', 'pute', //
  'meat', 'kalb', 'hack', 'mince', 'reh', 'hirsch', 'schmalz', 'lard',
];
const _meatPrefixes = [
  'rinder', 'lamm', 'kalbs', 'puten', 'enten', 'ganse', 'hack', 'wild', //
];
const _meatLookAlikes = [
  'fleischtomate', 'huhnerei', 'wurstkraut', 'blumenkohlsteak', //
  'wildreis', 'wildkrauter', 'wildkraut', 'wildlachs', 'wildheidelbeer',
  'wildpreiselbeer', 'butterschmalz', 'gansebl',
];

bool _isMeatToken(String t) {
  if (_meatLookAlikes.any(t.startsWith)) return false;
  return _meatWords.contains(t) ||
      _meatParts.any(t.contains) ||
      _meatPrefixes.any((p) => t.startsWith(p) && t.length > p.length);
}

const _seafood = AllergenMatcher(['fish', 'crustaceans', 'molluscs']);
const _dairy = AllergenMatcher(['milk']);
const _eggs = AllergenMatcher(['eggs']);

/// Whether an ingredient called [name] breaks [diet]: meat for all three,
/// fish and seafood unless pescetarian, milk, eggs and honey for vegans.
bool breaksRecipeDiet(String name, RecipeDiet diet) {
  final tokens = recipeTokens(name);
  if (tokens.any(_isMeatToken)) return true;
  if (diet == RecipeDiet.pescatarian) return false;
  if (_seafood.contains(name)) return true;
  if (diet == RecipeDiet.vegetarian) return false;
  return _contains(const AllergyConstraint(raw: 'milk'), _dairy, name) ||
      _eggs.contains(name) ||
      tokens.any((t) => t.contains('honig') || t == 'honey');
}

const _uncheckedParts = [
  'gewurzmischung', 'gewurzzubereitung', 'wurzmischung', 'pesto', 'bruhe', //
  'fond', 'bouillon', 'sosse', 'sauce', 'paste', 'dressing', 'mischung',
  'fertig', 'teig', 'schokolade', 'kuverture', 'wurze', 'ketchup',
  'worcester', 'stock', 'broth', 'seasoning', 'spice', 'mix', 'dough',
  'chocolate', 'curry', 'marinade', 'aufstrich',
];

/// A prepared or mixed product whose allergens a word list cannot know
/// ("Pesto", "Gemüsebrühe", "Gewürzmischung").
bool isUncheckedIngredient(String name) =>
    recipeTokens(name).any((t) => _uncheckedParts.any(t.contains));

const _staples = {
  'salz', 'pfeffer', 'wasser', 'ol', 'zucker', 'olivenol', 'sonnenblumenol', //
  'rapsol', 'pflanzenol', 'speiseol', 'meersalz', 'salt', 'pepper', 'water',
  'oil', 'sugar',
};

/// A basic people usually have at home (Salz, Pfeffer, Wasser, Öl, Zucker):
/// unticked by default in "Zutaten auf die Liste" (Konzept 13 §13.1, Q-05).
bool isStapleIngredient(String name) {
  final tokens = recipeTokens(name.split(RegExp(r'[,(]')).first);
  if (tokens.isEmpty) return false;
  return _staples.contains(tokens.first) || _staples.contains(tokens.last);
}

// ------------------------------------------------------------------ steps

/// Name of a substitute inside a sentence, without its explanation:
/// "Leinsamen-Ei (1 EL Leinsamen + 3 EL Wasser)" → "Leinsamen-Ei".
String _stepName(String substitute) {
  final cut = substitute.indexOf('(');
  return (cut < 0 ? substitute : substitute.substring(0, cut)).trim();
}

/// Replaces the first of [words] found as a whole word (case-insensitive)
/// in [text] with [replacement].
String _replaceWords(String text, List<String> words, String replacement) {
  var out = text;
  for (final word in words) {
    final w = word.trim();
    if (w.isEmpty) continue;
    final pattern = RegExp(
      '(?<![\\p{L}\\p{N}])${RegExp.escape(w)}(?![\\p{L}\\p{N}])',
      caseSensitive: false,
      unicode: true,
    );
    if (pattern.hasMatch(out)) {
      return out.replaceAll(pattern, replacement);
    }
  }
  return out;
}

// ----------------------------------------------------------------- amounts

enum _UnitKind { mass, bigMass, piece, spoon, pinch, other }

const _massUnits = {'g', 'gr', 'gramm', 'ml', 'milliliter'};
const _bigMassUnits = {'kg', 'l', 'liter', 'dl', 'cl'};
const _pieceUnits = {
  'stuck', 'stk', 'st', 'zehe', 'zehen', 'scheibe', 'scheiben', 'bund', //
  'dose', 'dosen', 'packung', 'pck', 'pkg', 'becher', 'glas', 'zweig',
  'zweige', 'blatt', 'blatter', 'knolle', 'knollen', 'kopf', 'stange',
  'stangen', 'handvoll', 'clove', 'cloves', 'slice', 'slices', 'can', 'cans',
  'piece', 'pieces', 'pcs', 'pc', 'x', 'bunch', 'sprig', 'sprigs', 'head',
};
const _spoonUnits = {
  'el', 'tl', 'essloffel', 'teeloffel', 'tbsp', 'tsp', 'tasse', 'tassen', //
  'cup', 'cups', 'tablespoon', 'tablespoons', 'teaspoon', 'teaspoons',
};
const _pinchUnits = {
  'prise', 'prisen', 'pinch', 'msp', 'messerspitze', 'etwas', 'some', //
  'nach geschmack', 'to taste', 'n b', 'nb', 'bei bedarf',
};

_UnitKind _kindOf(String unit) {
  final u = AllergenMatcher.fold(unit).replaceAll('.', ' ').trim();
  if (u.isEmpty) return _UnitKind.piece;
  if (_massUnits.contains(u)) return _UnitKind.mass;
  if (_bigMassUnits.contains(u)) return _UnitKind.bigMass;
  if (_pieceUnits.contains(u)) return _UnitKind.piece;
  if (_spoonUnits.contains(u)) return _UnitKind.spoon;
  if (_pinchUnits.contains(u)) return _UnitKind.pinch;
  return _UnitKind.other;
}

bool _isEgg(String name) {
  final t = recipeTokens(name);
  return t.contains('ei') ||
      t.contains('eier') ||
      t.contains('egg') ||
      t.contains('eggs');
}

/// [ingredient] for [servings] instead of [from], rounded the way people
/// measure (Konzept 13 §2.2): grams and millilitres to 5 (below 20 to 1),
/// pieces to ½, eggs up to whole ones, spoons to ¼ or ⅓; a pinch or "nach
/// Geschmack" is not scaled.
Ingredient scaleIngredient(Ingredient ingredient, int from, int servings) {
  final amount = ingredient.amount;
  if (amount <= 0 || from <= 0 || servings <= 0 || from == servings) {
    return ingredient;
  }
  final kind = _kindOf(ingredient.unit);
  if (kind == _UnitKind.pinch) return ingredient;
  final v = amount * servings / from;
  final double rounded;
  switch (kind) {
    case _UnitKind.mass:
      rounded = v < 20
          ? math.max(1.0, v.roundToDouble())
          : (v / 5).round() * 5.0;
    case _UnitKind.bigMass:
      rounded = math.max(0.05, (v * 20).round() / 20);
    case _UnitKind.piece:
      rounded = _isEgg(ingredient.name)
          ? v.ceilToDouble()
          : math.max(0.5, (v * 2).round() / 2);
    case _UnitKind.spoon:
      rounded = _nearestFraction(v);
    case _UnitKind.pinch:
      rounded = v;
    case _UnitKind.other:
      rounded = math.max(0.1, (v * 10).round() / 10);
  }
  return Ingredient(
    name: ingredient.name,
    amount: rounded,
    unit: ingredient.unit,
  );
}

/// Common fractions of a spoon or piece and their glyphs.
const List<(double, String)> _fractions = [
  (0.25, '¼'),
  (1 / 3, '⅓'),
  (0.5, '½'),
  (2 / 3, '⅔'),
  (0.75, '¾'),
];

double _nearestFraction(double v) {
  final whole = v.floorToDouble();
  var best = whole;
  var bestDistance = (v - whole).abs();
  for (final f in [for (final (value, _) in _fractions) value, 1.0]) {
    final candidate = whole + f;
    final d = (v - candidate).abs();
    if (d < bestDistance) {
      best = candidate;
      bestDistance = d;
    }
  }
  return best <= 0 ? 0.25 : best;
}

/// "1½", "¼" or null when [v] has no common fraction part.
String? _fractionText(double v) {
  final whole = v.floor();
  final part = v - whole;
  if (part < 0.02) return '$whole';
  for (final (value, glyph) in _fractions) {
    if ((part - value).abs() < 0.02) {
      return whole == 0 ? glyph : '$whole$glyph';
    }
  }
  return null;
}

/// The amount column of an ingredient: "200 g", "½ TL", "2", "1,5 L";
/// empty for "Salz" without an amount. Units go through [formatQuantity];
/// pieces show the bare number, spoons and pieces use fractions.
String formatRecipeAmount(Ingredient ingredient, String languageCode) {
  final amount = ingredient.amount;
  final unit = ingredient.unit.trim();
  if (amount <= 0) return unit;
  final kind = _kindOf(unit);
  final decimal = NumberFormat('0.#', languageCode);
  if (kind == _UnitKind.piece || kind == _UnitKind.spoon) {
    final number = _fractionText(amount) ?? decimal.format(amount);
    if (unit.isEmpty || isPieceUnit(unit)) return number;
    return '$number $unit';
  }
  final rounded = kind == _UnitKind.mass
      ? amount.roundToDouble()
      : (amount * 100).round() / 100;
  return formatQuantity(rounded, unit, languageCode: languageCode) ?? '';
}

/// Recipe units with a list unit id (`list_detail_unit_*`).
const _listUnits = {
  'g': 'g', 'gr': 'g', 'gramm': 'g', 'kg': 'kg', 'ml': 'ml', //
  'milliliter': 'ml', 'l': 'l', 'liter': 'l',
};

/// What [ingredient] becomes on a shopping list: quantity 1 without a unit
/// when the recipe gives none, pieces without a unit, the rest as written.
NewItem recipeIngredientToItem(Ingredient ingredient) {
  final unit = ingredient.unit.trim();
  if (ingredient.amount <= 0) return NewItem(name: ingredient.name.trim());
  final kind = _kindOf(unit);
  if (kind == _UnitKind.pinch) return NewItem(name: ingredient.name.trim());
  final folded = AllergenMatcher.fold(unit).replaceAll('.', '').trim();
  final String? itemUnit;
  if (unit.isEmpty || isPieceUnit(unit) || folded == 'stuck') {
    itemUnit = null;
  } else {
    itemUnit = _listUnits[folded] ?? unit;
  }
  return NewItem(
    name: ingredient.name.trim(),
    quantity: ingredient.amount,
    unit: itemUnit,
  );
}

/// Whether a list row called [itemName] is the ingredient [ingredientName]
/// ("Kartoffeln" for "Kartoffeln, festkochend", "Zwiebel" for "Zwiebeln").
bool sameShoppingName(String ingredientName, String itemName) {
  String base(String s) =>
      AllergenMatcher.fold(s.split(RegExp(r'[,(]')).first).trim();
  final a = base(ingredientName);
  final b = base(itemName);
  if (a.isEmpty || b.isEmpty) return false;
  if (a == b) return true;
  return AllergenMatcher.stem(a) == AllergenMatcher.stem(b);
}

/// Ingredients that appear more than once with the same unit, summed
/// ("2 EL Olivenöl" + "1 EL Olivenöl" = "3 EL"); order of first mention.
List<Ingredient> mergeIngredients(Iterable<Ingredient> ingredients) {
  final merged = <String, Ingredient>{};
  for (final i in ingredients) {
    final key =
        '${AllergenMatcher.fold(i.name).trim()}|${AllergenMatcher.fold(i.unit).trim()}';
    final prev = merged[key];
    merged[key] = prev == null
        ? i
        : Ingredient(
            name: prev.name,
            amount: prev.amount + i.amount,
            unit: prev.unit,
          );
  }
  return merged.values.toList(growable: false);
}

/// "35 Min", "1 Std. 10 Min" (de) or "35 min", "1 h 10 min" (en).
String formatRecipeTime(
  int minutes,
  String Function(String key, Map<String, String> params) tr,
) {
  if (minutes < 60) {
    return tr('recipe_detail_minutes', {'n': '$minutes'});
  }
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0
      ? tr('recipe_detail_hours', {'h': '$h'})
      : tr('recipe_detail_hours_minutes', {'h': '$h', 'm': '$m'});
}

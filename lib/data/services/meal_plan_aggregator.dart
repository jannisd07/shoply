import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:shoply/core/utils/product_name_normalizer.dart';
import 'package:shoply/data/models/meal_plan.dart';
import 'package:shoply/data/models/recipe.dart';

// "Zutaten der Woche" (Konzept 14, 6.4 and 13.2): merges the ingredients of
// planned recipes into one shopping list. Everything here is a pure function
// without network or storage, so the screen, the home card and Avo's
// plan_to_list get the same answer for the same input.
//
// Steps: open servings per entry (W-05) → scale (guard against 0 servings)
// → substitutions → name key (lowercase, singular/plural, synonyms, German
// and English) → unit family → group and sum → round → pantry → match the
// open items of the target list without the plan's own amounts (W-17) →
// sort by the list's category order → missing lines per entry.

// ---------------------------------------------------------------- units

/// Which amounts can be added up. Mass and volume convert (g/kg, ml/l);
/// pieces only add to pieces; every container only to itself; spoons and
/// pinches carry no amount at all.
enum PlanUnitFamily {
  mass('mass'),
  volume('volume'),
  pieces('pieces'),
  can('can'),
  bunch('bunch'),
  clove('clove'),
  pack('pack'),
  bottle('bottle'),
  slice('slice'),
  stalk('stalk'),
  leaf('leaf'),
  jar('jar'),
  box('box'),

  /// EL, TL, Prise, "nach Geschmack": listed without quantity.
  unquantified('unquantified'),

  /// Any other unit, only added to the same unit word.
  other('other');

  const PlanUnitFamily(this.id);

  /// Stable id, also stored in [PlanContribution.family].
  final String id;

  bool get isMeasured => this == mass || this == volume;

  bool get isCounted => !isMeasured && this != unquantified && this != other;

  static PlanUnitFamily? fromId(String id) {
    for (final f in values) {
      if (f.id == id) return f;
    }
    return null;
  }
}

/// A parsed unit: its family, the factor to the family's base unit (g, ml,
/// one piece) and, for [PlanUnitFamily.other], the normalized unit word.
class PlanUnit {
  const PlanUnit(this.family, [this.factor = 1, this.otherKey]);

  final PlanUnitFamily family;
  final double factor;
  final String? otherKey;
}

const Map<String, PlanUnit> _units = {
  // mass, base g
  'g': PlanUnit(PlanUnitFamily.mass),
  'gr': PlanUnit(PlanUnitFamily.mass),
  'gramm': PlanUnit(PlanUnitFamily.mass),
  'gram': PlanUnit(PlanUnitFamily.mass),
  'grams': PlanUnit(PlanUnitFamily.mass),
  'kg': PlanUnit(PlanUnitFamily.mass, 1000),
  'kilo': PlanUnit(PlanUnitFamily.mass, 1000),
  'kilogramm': PlanUnit(PlanUnitFamily.mass, 1000),
  'kilogram': PlanUnit(PlanUnitFamily.mass, 1000),
  'mg': PlanUnit(PlanUnitFamily.mass, 0.001),
  // volume, base ml
  'ml': PlanUnit(PlanUnitFamily.volume),
  'milliliter': PlanUnit(PlanUnitFamily.volume),
  'millilitre': PlanUnit(PlanUnitFamily.volume),
  'cl': PlanUnit(PlanUnitFamily.volume, 10),
  'dl': PlanUnit(PlanUnitFamily.volume, 100),
  'l': PlanUnit(PlanUnitFamily.volume, 1000),
  'ltr': PlanUnit(PlanUnitFamily.volume, 1000),
  'liter': PlanUnit(PlanUnitFamily.volume, 1000),
  'litre': PlanUnit(PlanUnitFamily.volume, 1000),
  'liters': PlanUnit(PlanUnitFamily.volume, 1000),
  'litres': PlanUnit(PlanUnitFamily.volume, 1000),
  // pieces (same words as ShoppingItemModel.pricingQuantity)
  '': PlanUnit(PlanUnitFamily.pieces),
  'pcs': PlanUnit(PlanUnitFamily.pieces),
  'pc': PlanUnit(PlanUnitFamily.pieces),
  'piece': PlanUnit(PlanUnitFamily.pieces),
  'pieces': PlanUnit(PlanUnitFamily.pieces),
  'stk': PlanUnit(PlanUnitFamily.pieces),
  'stck': PlanUnit(PlanUnitFamily.pieces),
  'st': PlanUnit(PlanUnitFamily.pieces),
  'stück': PlanUnit(PlanUnitFamily.pieces),
  'stueck': PlanUnit(PlanUnitFamily.pieces),
  'x': PlanUnit(PlanUnitFamily.pieces),
  'dozen': PlanUnit(PlanUnitFamily.pieces, 12),
  'dutzend': PlanUnit(PlanUnitFamily.pieces, 12),
  // containers, each only with itself
  'dose': PlanUnit(PlanUnitFamily.can),
  'dosen': PlanUnit(PlanUnitFamily.can),
  'can': PlanUnit(PlanUnitFamily.can),
  'cans': PlanUnit(PlanUnitFamily.can),
  'tin': PlanUnit(PlanUnitFamily.can),
  'tins': PlanUnit(PlanUnitFamily.can),
  'bund': PlanUnit(PlanUnitFamily.bunch),
  'bd': PlanUnit(PlanUnitFamily.bunch),
  'bunch': PlanUnit(PlanUnitFamily.bunch),
  'bunches': PlanUnit(PlanUnitFamily.bunch),
  'zehe': PlanUnit(PlanUnitFamily.clove),
  'zehen': PlanUnit(PlanUnitFamily.clove),
  'clove': PlanUnit(PlanUnitFamily.clove),
  'cloves': PlanUnit(PlanUnitFamily.clove),
  'packung': PlanUnit(PlanUnitFamily.pack),
  'packungen': PlanUnit(PlanUnitFamily.pack),
  'pck': PlanUnit(PlanUnitFamily.pack),
  'pkg': PlanUnit(PlanUnitFamily.pack),
  'pack': PlanUnit(PlanUnitFamily.pack),
  'packs': PlanUnit(PlanUnitFamily.pack),
  'päckchen': PlanUnit(PlanUnitFamily.pack),
  'paeckchen': PlanUnit(PlanUnitFamily.pack),
  'packet': PlanUnit(PlanUnitFamily.pack),
  'package': PlanUnit(PlanUnitFamily.pack),
  'flasche': PlanUnit(PlanUnitFamily.bottle),
  'flaschen': PlanUnit(PlanUnitFamily.bottle),
  'fl': PlanUnit(PlanUnitFamily.bottle),
  'bottle': PlanUnit(PlanUnitFamily.bottle),
  'bottles': PlanUnit(PlanUnitFamily.bottle),
  'scheibe': PlanUnit(PlanUnitFamily.slice),
  'scheiben': PlanUnit(PlanUnitFamily.slice),
  'slice': PlanUnit(PlanUnitFamily.slice),
  'slices': PlanUnit(PlanUnitFamily.slice),
  'stange': PlanUnit(PlanUnitFamily.stalk),
  'stangen': PlanUnit(PlanUnitFamily.stalk),
  'stalk': PlanUnit(PlanUnitFamily.stalk),
  'stalks': PlanUnit(PlanUnitFamily.stalk),
  'blatt': PlanUnit(PlanUnitFamily.leaf),
  'blätter': PlanUnit(PlanUnitFamily.leaf),
  'blaetter': PlanUnit(PlanUnitFamily.leaf),
  'leaf': PlanUnit(PlanUnitFamily.leaf),
  'leaves': PlanUnit(PlanUnitFamily.leaf),
  'glas': PlanUnit(PlanUnitFamily.jar),
  'gläser': PlanUnit(PlanUnitFamily.jar),
  'glaeser': PlanUnit(PlanUnitFamily.jar),
  'jar': PlanUnit(PlanUnitFamily.jar),
  'jars': PlanUnit(PlanUnitFamily.jar),
  'schachtel': PlanUnit(PlanUnitFamily.box),
  'schachteln': PlanUnit(PlanUnitFamily.box),
  'box': PlanUnit(PlanUnitFamily.box),
  'boxes': PlanUnit(PlanUnitFamily.box),
  // no amount on the shopping list
  'el': PlanUnit(PlanUnitFamily.unquantified),
  'essl': PlanUnit(PlanUnitFamily.unquantified),
  'esslöffel': PlanUnit(PlanUnitFamily.unquantified),
  'tl': PlanUnit(PlanUnitFamily.unquantified),
  'teel': PlanUnit(PlanUnitFamily.unquantified),
  'teelöffel': PlanUnit(PlanUnitFamily.unquantified),
  'tbsp': PlanUnit(PlanUnitFamily.unquantified),
  'tablespoon': PlanUnit(PlanUnitFamily.unquantified),
  'tablespoons': PlanUnit(PlanUnitFamily.unquantified),
  'tsp': PlanUnit(PlanUnitFamily.unquantified),
  'teaspoon': PlanUnit(PlanUnitFamily.unquantified),
  'teaspoons': PlanUnit(PlanUnitFamily.unquantified),
  'prise': PlanUnit(PlanUnitFamily.unquantified),
  'prisen': PlanUnit(PlanUnitFamily.unquantified),
  'pinch': PlanUnit(PlanUnitFamily.unquantified),
  'pinches': PlanUnit(PlanUnitFamily.unquantified),
  'msp': PlanUnit(PlanUnitFamily.unquantified),
  'messerspitze': PlanUnit(PlanUnitFamily.unquantified),
  'etwas': PlanUnit(PlanUnitFamily.unquantified),
  'nach geschmack': PlanUnit(PlanUnitFamily.unquantified),
  'nach bedarf': PlanUnit(PlanUnitFamily.unquantified),
  'to taste': PlanUnit(PlanUnitFamily.unquantified),
  'some': PlanUnit(PlanUnitFamily.unquantified),
  'dash': PlanUnit(PlanUnitFamily.unquantified),
  'schuss': PlanUnit(PlanUnitFamily.unquantified),
  'spritzer': PlanUnit(PlanUnitFamily.unquantified),
};

/// The family of a recipe or list unit ("EL", "kg", "Dosen", "pcs", …).
PlanUnit parsePlanUnit(String? raw) {
  final u = (raw ?? '').trim().toLowerCase().replaceAll(RegExp(r'\.+$'), '').replaceAll(RegExp(r'\s+'), ' ');
  return _units[u] ?? PlanUnit(PlanUnitFamily.other, 1, normalizeProductName(u));
}

/// A rounded amount in its family's base unit (g, ml, pieces, cans, …).
class PlanQuantity {
  const PlanQuantity({required this.amount, required this.family, this.otherUnit});

  final double amount;
  final PlanUnitFamily family;

  /// The unit word for [PlanUnitFamily.other].
  final String? otherUnit;

  /// "600 g", "1,5 kg", "275 ml", "3", "2 Dosen" (German comma for 'de').
  String format(String localeCode) {
    final n = NumberFormat.decimalPattern(localeCode)..maximumFractionDigits = 3;
    switch (family) {
      case PlanUnitFamily.mass:
        return amount >= 1000 ? '${n.format(amount / 1000)} kg' : '${n.format(amount)} g';
      case PlanUnitFamily.volume:
        return amount >= 1000 ? '${n.format(amount / 1000)} l' : '${n.format(amount)} ml';
      case PlanUnitFamily.pieces:
        return n.format(amount);
      case PlanUnitFamily.unquantified:
        return '';
      case PlanUnitFamily.other:
        return '${n.format(amount)} ${otherUnit ?? ''}'.trim();
      default:
        return '${n.format(amount)} ${planUnitWord(family, amount, localeCode)}';
    }
  }

  /// Quantity and unit id for a shopping item (units as the item input
  /// parser stores them: g, kg, ml, l, null = pieces, can, bunch, …).
  ({double quantity, String? unit}) toItemQuantity() => switch (family) {
        PlanUnitFamily.mass => amount >= 1000 ? (quantity: amount / 1000, unit: 'kg') : (quantity: amount, unit: 'g'),
        PlanUnitFamily.volume => amount >= 1000 ? (quantity: amount / 1000, unit: 'l') : (quantity: amount, unit: 'ml'),
        PlanUnitFamily.pieces => (quantity: amount, unit: null),
        PlanUnitFamily.unquantified => (quantity: 1, unit: null),
        PlanUnitFamily.other => (quantity: amount, unit: otherUnit),
        _ => (quantity: amount, unit: family.id),
      };

  @override
  bool operator ==(Object other) =>
      other is PlanQuantity && other.amount == amount && other.family == family && other.otherUnit == otherUnit;

  @override
  int get hashCode => Object.hash(amount, family, otherUnit);

  @override
  String toString() => 'PlanQuantity(${format('en')})';
}

const Map<PlanUnitFamily, List<String>> _wordsDe = {
  PlanUnitFamily.can: ['Dose', 'Dosen'],
  PlanUnitFamily.bunch: ['Bund', 'Bund'],
  PlanUnitFamily.clove: ['Zehe', 'Zehen'],
  PlanUnitFamily.pack: ['Packung', 'Packungen'],
  PlanUnitFamily.bottle: ['Flasche', 'Flaschen'],
  PlanUnitFamily.slice: ['Scheibe', 'Scheiben'],
  PlanUnitFamily.stalk: ['Stange', 'Stangen'],
  PlanUnitFamily.leaf: ['Blatt', 'Blätter'],
  PlanUnitFamily.jar: ['Glas', 'Gläser'],
  PlanUnitFamily.box: ['Schachtel', 'Schachteln'],
};

const Map<PlanUnitFamily, List<String>> _wordsEn = {
  PlanUnitFamily.can: ['can', 'cans'],
  PlanUnitFamily.bunch: ['bunch', 'bunches'],
  PlanUnitFamily.clove: ['clove', 'cloves'],
  PlanUnitFamily.pack: ['pack', 'packs'],
  PlanUnitFamily.bottle: ['bottle', 'bottles'],
  PlanUnitFamily.slice: ['slice', 'slices'],
  PlanUnitFamily.stalk: ['stalk', 'stalks'],
  PlanUnitFamily.leaf: ['leaf', 'leaves'],
  PlanUnitFamily.jar: ['jar', 'jars'],
  PlanUnitFamily.box: ['box', 'boxes'],
};

/// Container word in the app language, singular for exactly 1.
String planUnitWord(PlanUnitFamily family, double amount, String localeCode) {
  final words = (localeCode.startsWith('de') ? _wordsDe : _wordsEn)[family];
  if (words == null) return '';
  return amount == 1 ? words[0] : words[1];
}

/// Rounds a summed amount up to something you can buy (Konzept 14, 6.4):
/// pieces and containers to whole numbers (2.5 onions → 3), grams and
/// millilitres below 100 to steps of 10, from 100 to steps of 25
/// (266.7 ml → 275 ml). Floating-point noise never adds a step
/// (150 g × 2/3 stays 100 g).
double roundPlanAmount(double amount, PlanUnitFamily family) {
  if (!amount.isFinite || amount <= 0) return 0;
  double up(double step) => ((amount / step) - 1e-9).ceilToDouble() * step;
  return switch (family) {
    PlanUnitFamily.mass || PlanUnitFamily.volume => up(amount < 100 ? 10 : 25),
    PlanUnitFamily.other => up(0.1),
    _ => math.max(1.0, up(1)),
  };
}

// ---------------------------------------------------------------- names

/// Canonical keys for the same ingredient in German and English. Keys and
/// values are normalized ([normalizeProductName]) and singular.
const Map<String, String> _synonyms = {
  'onion': 'zwiebel',
  'red onion': 'rote zwiebel',
  'spring onion': 'fruehlingszwiebel',
  'green onion': 'fruehlingszwiebel',
  'scallion': 'fruehlingszwiebel',
  'shallot': 'schalotte',
  'garlic': 'knoblauch',
  'tomato': 'tomate',
  'cherry tomato': 'kirschtomate',
  'potato': 'kartoffel',
  'sweet potato': 'suesskartoffel',
  'carrot': 'karotte',
  'moehre': 'karotte',
  'mohrrube': 'karotte',
  'egg': 'ei',
  'milk': 'milch',
  'flour': 'mehl',
  'weizenmehl': 'mehl',
  'sugar': 'zucker',
  'salt': 'salz',
  'pepper': 'pfeffer',
  'black pepper': 'pfeffer',
  'bell pepper': 'paprika',
  'red bell pepper': 'paprika',
  'paprikaschote': 'paprika',
  'water': 'wasser',
  'oil': 'oel',
  'olive oil': 'olivenoel',
  'rapeseed oil': 'rapsoel',
  'canola oil': 'rapsoel',
  'vegetable oil': 'pflanzenoel',
  'rice': 'reis',
  'lemon': 'zitrone',
  'lime': 'limette',
  'apple': 'apfel',
  'cheese': 'kaese',
  'cream': 'sahne',
  'heavy cream': 'sahne',
  'schlagsahne': 'sahne',
  'butter': 'butter',
  'pasta': 'nudel',
  'noodle': 'nudel',
  'chickpea': 'kichererbse',
  'kidney bean': 'kidneybohne',
  'coconut milk': 'kokosmilch',
  'yogurt': 'joghurt',
  'yoghurt': 'joghurt',
  'jogurt': 'joghurt',
  'broccoli': 'brokkoli',
  'spinach': 'spinat',
  'coriander': 'koriander',
  'cilantro': 'koriander',
  'parsley': 'petersilie',
  'basil': 'basilikum',
  'salmon': 'lachs',
  'salmon fillet': 'lachsfilet',
  'chicken breast': 'haehnchenbrust',
  'huehnerbrust': 'haehnchenbrust',
  'ground beef': 'hackfleisch',
  'minced meat': 'hackfleisch',
  'ginger': 'ingwer',
  'cucumber': 'gurke',
  'courgette': 'zucchini',
  'eggplant': 'aubergine',
  'mushroom': 'pilz',
  'leek': 'lauch',
  'porree': 'lauch',
  'celery': 'sellerie',
  'corn': 'mais',
  'sweetcorn': 'mais',
  'honey': 'honig',
  'mustard': 'senf',
  'vinegar': 'essig',
  'lentil': 'linse',
  'red lentil': 'rote linse',
  'oat': 'haferflocke',
  'rolled oat': 'haferflocke',
  'cinnamon': 'zimt',
  'nutmeg': 'muskat',
  'dill': 'dill',
  'oat milk': 'hafermilch',
  'feta cheese': 'feta',
};

final Set<String> _canonical = {..._synonyms.values};

/// Plurals the suffix rules do not reach (umlaut plurals, "Eier").
const Map<String, String> _irregular = {
  'eier': 'ei',
  'aepfel': 'apfel',
  'nuesse': 'nuss',
  'leaves': 'leaf',
  'knives': 'knife',
};

/// Names that already say their unit: "Knoblauchzehe" counted in pieces is
/// garlic counted in cloves.
const Map<String, (String, PlanUnitFamily)> _nameWithUnit = {
  'knoblauchzehe': ('knoblauch', PlanUnitFamily.clove),
  'garlic clove': ('knoblauch', PlanUnitFamily.clove),
};

/// German and English singular of one word, good enough for a merge key.
/// It only has to map singular and plural to the same string; the key is
/// never shown.
String _singular(String w) {
  final irregular = _irregular[w];
  if (irregular != null) return irregular;
  if (w.length <= 3) return w;
  if (w.endsWith('ies')) return '${w.substring(0, w.length - 3)}y';
  if (w.endsWith('oes')) return w.substring(0, w.length - 2);
  if (w.endsWith('ches') || w.endsWith('shes') || w.endsWith('xes') || w.endsWith('sses')) {
    return w.substring(0, w.length - 2);
  }
  if (w.endsWith('en') && w.length > 4) return w.substring(0, w.length - 1);
  if (w.endsWith('ln') || w.endsWith('rn')) return w.substring(0, w.length - 1);
  if (w.endsWith('s') && !w.endsWith('ss') && !w.endsWith('us') && !w.endsWith('is') && !w.endsWith('hs')) {
    return w.substring(0, w.length - 1);
  }
  return w;
}

/// The merge key of an ingredient or list item name: lowercase, umlauts
/// spelled out, last word in singular, German and English mapped to one
/// word ("Onions", "Zwiebeln" → "zwiebel").
String planNameKey(String name) {
  final n = normalizeProductName(name);
  if (n.isEmpty) return n;
  if (_canonical.contains(n) || _nameWithUnit.containsKey(n)) return n;
  final direct = _synonyms[n];
  if (direct != null) return direct;
  final words = n.split(' ');
  words[words.length - 1] = _singular(words.last);
  final singular = words.join(' ');
  return _synonyms[singular] ?? singular;
}

/// Name key and family together; handles names that carry their unit and
/// English "pepper" counted in pieces (bell pepper, not black pepper).
(String, PlanUnitFamily) _keyAndFamily(String name, PlanUnitFamily family) {
  var key = planNameKey(name);
  final withUnit = _nameWithUnit[key];
  if (withUnit != null && (family == PlanUnitFamily.pieces || family == withUnit.$2)) {
    return withUnit;
  }
  if (withUnit != null) key = withUnit.$1;
  if (key == 'pfeffer' && family == PlanUnitFamily.pieces && name.toLowerCase().contains('pepper')) {
    return ('paprika', family);
  }
  return (key, family);
}

bool _pantryCovers(String pantryKey, String nameKey) {
  if (pantryKey.isEmpty) return false;
  if (pantryKey == nameKey) return true;
  for (final token in nameKey.split(' ')) {
    if (token == pantryKey) return true;
    if (token.length > pantryKey.length && token.endsWith(pantryKey)) return true;
  }
  return false;
}

// ---------------------------------------------------------------- input

/// Which days count for "Zutaten der Woche".
enum PlanRange {
  /// Current week from today on ("Ab heute", default).
  fromToday,

  /// Monday to Sunday ("Ganze Woche").
  wholeWeek,
}

/// The entries of the week starting at [weekStart] that [range] covers. A
/// future week always counts whole; "Ab heute" only cuts the current week.
List<MealPlanEntry> entriesInRange(
  List<MealPlanEntry> entries, {
  required DateTime weekStart,
  required PlanRange range,
  required DateTime today,
}) {
  final start = planWeekStart(weekStart);
  final end = planAddDays(start, 7);
  final day = planDay(today);
  final from = range == PlanRange.fromToday && !day.isBefore(start) && day.isBefore(end) ? day : start;
  return [
    for (final e in entries)
      if (!e.planDate.isBefore(from) && e.planDate.isBefore(end)) e,
  ]..sort((a, b) {
      final byDay = a.planDate.compareTo(b.planDate);
      return byDay != 0 ? byDay : a.position.compareTo(b.position);
    });
}

/// An open (unchecked) item of the target list, with the amounts the plan
/// itself put there (W-17).
class PlanListItem {
  const PlanListItem({
    required this.id,
    required this.name,
    required this.quantity,
    this.unit,
    this.contributions = const [],
  });

  final String id;
  final String name;
  final double quantity;
  final String? unit;
  final List<PlanContribution> contributions;
}

/// An ingredient replaced for the person's diet or allergies, with the
/// reason to show ("Hafermilch statt Milch · wegen Laktose").
class PlanSubstitution {
  const PlanSubstitution({required this.ingredient, required this.reason});

  final Ingredient ingredient;
  final String reason;
}

/// Returns, for each of the (already scaled) [ingredients], its replacement
/// or null. Called once per entry.
typedef PlanSubstituter = List<PlanSubstitution?> Function(List<Ingredient> ingredients);

// ---------------------------------------------------------------- output

/// Why a line is not selected.
enum PlanLineReason {
  /// "Hast du meist da".
  pantry('pantry'),

  /// "Schon auf Wocheneinkauf (1 kg)".
  alreadyOnList('already_on_list');

  const PlanLineReason(this.id);

  final String id;
}

/// Why an entry adds no ingredients.
enum PlanSkipReason {
  /// The recipe was deleted ("Rezept nicht mehr verfügbar").
  recipeUnavailable('recipe_unavailable'),

  /// The recipe has no ingredient list ("Zutaten fehlen im Rezept").
  noIngredients('no_ingredients');

  const PlanSkipReason(this.id);

  final String id;
}

/// What one entry adds to a line, in the family's base unit (unrounded).
class PlanLineSource {
  const PlanLineSource({required this.entryId, required this.recipeName, required this.baseAmount});

  final String entryId;
  final String recipeName;
  final double baseAmount;
}

class PlanSubstitutionInfo {
  const PlanSubstitutionInfo({required this.originalName, required this.reason});

  final String originalName;
  final String reason;
}

/// One merged line of "Zutaten der Woche".
class PlanIngredientLine {
  const PlanIngredientLine({
    required this.key,
    required this.nameKey,
    required this.displayName,
    required this.family,
    this.otherUnit,
    required this.categoryId,
    required this.neededBase,
    this.needed,
    this.toAdd,
    this.onList,
    this.listItem,
    required this.selected,
    this.reason,
    required this.sources,
    this.substitution,
  });

  /// `nameKey|family`, unique within one result.
  final String key;
  final String nameKey;

  /// First spelling, preferring a recipe in the app language.
  final String displayName;
  final PlanUnitFamily family;
  final String? otherUnit;
  final String categoryId;

  /// Unrounded sum in the base unit (0 for [PlanUnitFamily.unquantified]).
  final double neededBase;

  /// Rounded sum; null for lines without quantity.
  final PlanQuantity? needed;

  /// What goes on the list: [needed] minus what the list already has,
  /// rounded. Null when nothing is added or the line has no quantity.
  final PlanQuantity? toAdd;

  /// What the target list already has (without the plan's own amounts);
  /// null when it has nothing of this.
  final PlanQuantity? onList;

  /// The open list item of the same name and unit family (also one the plan
  /// filled itself); what is added grows that item in its own unit.
  final PlanListItem? listItem;

  /// Preselected in "Zutaten der Woche".
  final bool selected;
  final PlanLineReason? reason;
  final List<PlanLineSource> sources;
  final PlanSubstitutionInfo? substitution;

  /// Recipes that need it, in plan order, each once ("für Chili, Curry").
  List<String> get recipeNames => [
        for (final s in sources) s.recipeName,
      ].fold<List<String>>([], (acc, n) => acc.contains(n) ? acc : (acc..add(n)));

  /// Entries that need it.
  Set<String> get entryIds => {for (final s in sources) s.entryId};

  /// Selected although the list already has some of it ("2 schon auf …").
  bool get partlyOnList => selected && onList != null;

  /// Quantity to show on the right: what is added, else what is needed.
  String quantityLabel(String localeCode) => (toAdd ?? needed)?.format(localeCode) ?? '';
}

/// An entry that adds no ingredients.
class PlanSkippedEntry {
  const PlanSkippedEntry({required this.entryId, required this.recipeName, required this.reason});

  final String entryId;
  final String recipeName;
  final PlanSkipReason reason;
}

/// Result of [aggregatePlanIngredients].
class PlanAggregation {
  const PlanAggregation({
    required this.lines,
    required this.withoutIngredients,
    required this.missingByEntry,
    required this.missingNamesByEntry,
    required this.contributingEntryIds,
  });

  static const empty = PlanAggregation(
    lines: [],
    withoutIngredients: [],
    missingByEntry: {},
    missingNamesByEntry: {},
    contributingEntryIds: {},
  );

  /// Sorted by the target list's category order.
  final List<PlanIngredientLine> lines;
  final List<PlanSkippedEntry> withoutIngredients;

  /// Per entry with open servings: its lines still to buy ("2 Zutaten
  /// fehlen"); pantry and covered lines do not count.
  final Map<String, int> missingByEntry;

  /// Names of those lines in recipe order ("Koriander und Paprika").
  final Map<String, List<String>> missingNamesByEntry;

  /// Entries with open servings and ingredients.
  final Set<String> contributingEntryIds;

  List<PlanIngredientLine> get selectedLines => [for (final l in lines) if (l.selected) l];

  /// The number on the main action ("5 fehlende Zutaten auf die Liste").
  int get selectedCount => selectedLines.length;

  int get alreadyOnListCount => lines.where((l) => l.reason == PlanLineReason.alreadyOnList).length;

  int get pantryCount => lines.where((l) => l.reason == PlanLineReason.pantry).length;

  /// For Avo's plan_to_list answer card.
  Map<String, dynamic> toAvoJson(String localeCode) => {
        'recipe_count': contributingEntryIds.length,
        'selected_count': selectedCount,
        'already_on_list_count': alreadyOnListCount,
        'pantry_count': pantryCount,
        'without_ingredients': [
          for (final w in withoutIngredients) {'recipe': w.recipeName, 'reason': w.reason.id},
        ],
        'lines': [
          for (final l in lines)
            {
              'name': l.displayName,
              'quantity': l.quantityLabel(localeCode),
              'category_id': l.categoryId,
              'selected': l.selected,
              if (l.reason != null) 'reason': l.reason!.id,
              if (l.onList != null) 'on_list': l.onList!.format(localeCode),
              'recipes': l.recipeNames,
              if (l.substitution != null) 'instead_of': l.substitution!.originalName,
            },
        ],
      };
}

// ---------------------------------------------------------------- algorithm

class _Group {
  _Group(this.key, this.nameKey, this.family, this.otherUnit);

  final String key;
  final String nameKey;
  final PlanUnitFamily family;
  final String? otherUnit;
  final sources = <PlanLineSource>[];
  final spellings = <(String name, String language, bool impliedUnit)>[];
  PlanSubstitutionInfo? substitution;
  double sum = 0;
}

/// Merges the ingredients of [entries] (already limited to the wanted days,
/// see [entriesInRange]) into shopping lines.
///
/// [recipesById] wins over an entry's snapshot when the recipe is loaded.
/// [pantry] are the "Hast du meist da" words. [openItems] are the unchecked
/// items of the target list. [substitute] replaces ingredients before
/// merging; original names (as [planNameKey]) in [keepOriginal] stay
/// ("Original verwenden"). [categoryOf] gives the local category id of a
/// name; [categoryOrder] is the list's order of category ids.
PlanAggregation aggregatePlanIngredients({
  required List<MealPlanEntry> entries,
  Map<String, Recipe> recipesById = const {},
  List<String> pantry = const [],
  List<PlanListItem> openItems = const [],
  PlanSubstituter? substitute,
  Set<String> keepOriginal = const {},
  String Function(String name)? categoryOf,
  List<String> categoryOrder = const [],
  String localeCode = 'de',
}) {
  final groups = <String, _Group>{};
  final entryGroupKeys = <String, List<String>>{};
  final skipped = <PlanSkippedEntry>[];
  final contributing = <String>{};

  for (final entry in entries) {
    final need = entry.openServings;
    if (need <= 0) continue;
    final recipe = entry.recipeId == null ? null : recipesById[entry.recipeId];
    final name = recipe?.name ?? entry.snapshot.name;
    if (entry.recipeId == null) {
      skipped.add(PlanSkippedEntry(entryId: entry.id, recipeName: name, reason: PlanSkipReason.recipeUnavailable));
      continue;
    }
    final ingredients = recipe?.ingredients ?? entry.snapshot.ingredients;
    if (ingredients.isEmpty) {
      skipped.add(PlanSkippedEntry(entryId: entry.id, recipeName: name, reason: PlanSkipReason.noIngredients));
      continue;
    }
    contributing.add(entry.id);
    final language = recipe?.language ?? entry.snapshot.language;
    final baseServings = recipe?.defaultServings ?? entry.snapshot.defaultServings;
    final scaled = [
      for (final i in ingredients) i.adjustForServings(baseServings > 0 ? baseServings : 1, need),
    ];
    final replacements = substitute?.call(scaled);
    final keys = entryGroupKeys.putIfAbsent(entry.id, () => []);

    for (var idx = 0; idx < scaled.length; idx++) {
      final original = scaled[idx];
      final replacement = replacements != null && idx < replacements.length ? replacements[idx] : null;
      final useReplacement = replacement != null && !keepOriginal.contains(planNameKey(original.name));
      final ingredient = useReplacement ? replacement.ingredient : original;
      if (ingredient.name.trim().isEmpty) continue;

      final unit = parsePlanUnit(ingredient.unit);
      final amount = ingredient.amount.isFinite ? ingredient.amount * unit.factor : 0.0;
      final family = amount > 0 ? unit.family : PlanUnitFamily.unquantified;
      final (nameKey, finalFamily) = _keyAndFamily(ingredient.name, family);
      final otherUnit = finalFamily == PlanUnitFamily.other ? unit.otherKey : null;
      final key = '$nameKey|${finalFamily.id}${otherUnit == null ? '' : ':$otherUnit'}';

      final group = groups.putIfAbsent(key, () => _Group(key, nameKey, finalFamily, otherUnit));
      final base = finalFamily == PlanUnitFamily.unquantified ? 0.0 : amount;
      group.sum += base;
      group.sources.add(PlanLineSource(entryId: entry.id, recipeName: name, baseAmount: base));
      group.spellings.add((ingredient.name.trim(), language, _nameWithUnit.containsKey(planNameKey(ingredient.name))));
      if (useReplacement) {
        group.substitution ??= PlanSubstitutionInfo(originalName: original.name.trim(), reason: replacement.reason);
      }
      if (!keys.contains(key)) keys.add(key);
    }
  }

  // Open items of the target list, by name key and family, minus the plan's
  // own amounts (W-17).
  final available = <String, double>{};
  final itemOfKey = <String, PlanListItem>{};
  final namesOnList = <String>{};
  for (final item in openItems) {
    final unit = parsePlanUnit(item.unit);
    final (nameKey, family) = _keyAndFamily(item.name, unit.family);
    namesOnList.add(nameKey);
    final otherUnit = family == PlanUnitFamily.other ? unit.otherKey : null;
    final key = '$nameKey|${family.id}${otherUnit == null ? '' : ':$otherUnit'}';
    final own = item.contributions
        .where((c) => c.family == family.id)
        .fold<double>(0, (sum, c) => sum + c.baseAmount);
    final free = item.quantity * unit.factor - own;
    available[key] = (available[key] ?? 0) + math.max(0, free);
    itemOfKey.putIfAbsent(key, () => item);
  }

  final pantryKeys = [for (final p in pantry) planNameKey(p)];
  final category = categoryOf ?? (_) => 'other';

  final lines = <PlanIngredientLine>[];
  for (final g in groups.values) {
    final display = _displayName(g, localeCode);
    final inPantry = pantryKeys.any((p) => _pantryCovers(p, g.nameKey));
    PlanQuantity? quantity(double amount) => g.family == PlanUnitFamily.unquantified
        ? null
        : PlanQuantity(amount: roundPlanAmount(amount, g.family), family: g.family, otherUnit: g.otherUnit);

    final needed = quantity(g.sum);
    PlanQuantity? onList;
    PlanQuantity? toAdd = needed;
    PlanLineReason? reason;

    if (g.family == PlanUnitFamily.unquantified) {
      if (namesOnList.contains(g.nameKey)) reason = PlanLineReason.alreadyOnList;
    } else {
      final free = available[g.key] ?? 0;
      if (free > 0) {
        onList = PlanQuantity(amount: _tidy(free), family: g.family, otherUnit: g.otherUnit);
        if (free + 1e-9 >= g.sum) {
          reason = PlanLineReason.alreadyOnList;
          toAdd = null;
        } else {
          toAdd = quantity(g.sum - free);
        }
      }
    }
    // On the list beats the pantry (Konzept 13, 13.1).
    if (reason == null && inPantry) reason = PlanLineReason.pantry;

    lines.add(PlanIngredientLine(
      key: g.key,
      nameKey: g.nameKey,
      displayName: display,
      family: g.family,
      otherUnit: g.otherUnit,
      categoryId: category(display),
      neededBase: g.sum,
      needed: needed,
      toAdd: toAdd,
      onList: onList,
      listItem: g.family == PlanUnitFamily.unquantified ? null : itemOfKey[g.key],
      selected: reason == null,
      reason: reason,
      sources: List.unmodifiable(g.sources),
      substitution: g.substitution,
    ));
  }

  final order = {for (var i = 0; i < categoryOrder.length; i++) categoryOrder[i]: i};
  final appearance = {for (var i = 0; i < lines.length; i++) lines[i].key: i};
  lines.sort((a, b) {
    final ca = order[a.categoryId] ?? categoryOrder.length;
    final cb = order[b.categoryId] ?? categoryOrder.length;
    return ca != cb ? ca.compareTo(cb) : appearance[a.key]!.compareTo(appearance[b.key]!);
  });

  final byKey = {for (final l in lines) l.key: l};
  final missing = <String, int>{};
  final missingNames = <String, List<String>>{};
  for (final e in entryGroupKeys.entries) {
    final names = [
      for (final k in e.value)
        if (byKey[k]!.selected) byKey[k]!.displayName,
    ];
    missing[e.key] = names.length;
    missingNames[e.key] = names;
  }

  return PlanAggregation(
    lines: List.unmodifiable(lines),
    withoutIngredients: List.unmodifiable(skipped),
    missingByEntry: Map.unmodifiable(missing),
    missingNamesByEntry: Map.unmodifiable(missingNames),
    contributingEntryIds: Set.unmodifiable(contributing),
  );
}

/// Shown amount of what is on the list: as it is, only float noise removed.
double _tidy(double v) => (v * 1000).roundToDouble() / 1000;

/// First spelling, preferring a recipe in the app language and a name that
/// does not carry its unit ("Knoblauch" over "Knoblauchzehen").
String _displayName(_Group g, String localeCode) {
  final lang = localeCode.split(RegExp('[-_]')).first;
  for (final pass in [
    (bool sameLang, bool implied) => sameLang && !implied,
    (bool sameLang, bool implied) => sameLang,
    (bool sameLang, bool implied) => !implied,
  ]) {
    for (final (name, language, implied) in g.spellings) {
      if (pass(language == lang, implied)) return name;
    }
  }
  return g.spellings.first.$1;
}

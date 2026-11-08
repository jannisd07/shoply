import 'package:equatable/equatable.dart';

import 'package:shoply/data/models/dietary_preference.dart';

/// One allergy found in a text.
class AllergenMatch extends Equatable {
  /// The allergy as the user stored it (`'nuts'`, `'Nüsse'`, `'Kiwi'`).
  final String allergy;

  /// Resolved type, null for free-text allergies.
  final AllergyType? type;

  /// The (normalised) word that matched, for logs and tests.
  final String matchedText;

  const AllergenMatch({required this.allergy, required this.type, required this.matchedText});

  @override
  List<Object?> get props => [allergy, type, matchedText];
}

/// Finds allergens in ingredient names, recipe ingredients and AI photo
/// components. Uses the [AllergyType] keyword lists plus German compounds
/// and plurals ("Nüsse" finds "Haselnuss", "Milch" finds "Vollmilch",
/// "Gluten" finds "Weizenmehl") and a few English words, and leaves out
/// known look-alikes (Muskatnuss, Kokosmilch, Erdnussbutter for milk,
/// Buchweizen, Reismehl).
///
/// A keyword list is never complete: callers word the result as a hint
/// ("Kann … enthalten"), never as a promise that something is free of it.
class AllergenMatcher {
  final List<String> allergies;

  const AllergenMatcher(this.allergies);

  bool contains(String text) => matches(text).isNotEmpty;

  bool anyIngredient(Iterable<String> ingredients) => ingredients.any(contains);

  /// Every allergy found in any of [texts], each once.
  List<AllergenMatch> matchesAll(Iterable<String> texts) {
    final seen = <String>{};
    final result = <AllergenMatch>[];
    for (final text in texts) {
      for (final m in matches(text)) {
        if (seen.add(m.allergy)) result.add(m);
      }
    }
    return result;
  }

  /// Every allergy of [allergies] found in [text], in the user's order.
  List<AllergenMatch> matches(String text) {
    final tokens = _tokens(text);
    if (tokens.isEmpty) return const [];
    final joined = ' ${tokens.join(' ')} ';
    final result = <AllergenMatch>[];
    final seenTypes = <AllergyType>{};
    for (final allergy in allergies) {
      final type = resolve(allergy);
      if (type != null && !seenTypes.add(type)) continue;
      final spec = type != null ? _specs[type]! : _Spec.freeText(allergy);
      final hit = spec.firstMatch(tokens, joined);
      if (hit != null) {
        result.add(AllergenMatch(allergy: allergy, type: type, matchedText: hit));
      }
    }
    return result;
  }

  /// Maps a stored allergy (enum name, German label, keyword, English name,
  /// "Erdnussallergie") to its [AllergyType], or null for free text.
  static AllergyType? resolve(String raw) {
    var key = fold(raw).trim();
    for (final suffix in const ['allergie', 'allergy', 'unvertraglichkeit', 'intoleranz', 'intolerance']) {
      if (key.length > suffix.length && key.endsWith(suffix)) {
        key = key.substring(0, key.length - suffix.length).trim();
      }
    }
    key = key.replaceAll(RegExp(r'[\s_-]+'), ' ').trim();
    if (key.isEmpty) return null;
    for (final t in AllergyType.values) {
      if (t.name.toLowerCase() == key) return t;
    }
    final alias = _aliases[key];
    if (alias != null) return alias;
    for (final t in AllergyType.values) {
      final labelParts = fold(t.label).split('/').map((p) => p.trim());
      if (labelParts.contains(key)) return t;
    }
    final keyStem = stem(key);
    for (final t in AllergyType.values) {
      for (final kw in t.keywords) {
        final f = fold(kw);
        if (f == key || stem(f) == keyStem) return t;
      }
    }
    return null;
  }

  /// Lower case without diacritics: "Nüsse" -> "nusse", "Grieß" -> "griess".
  static String fold(String input) {
    final lower = input.toLowerCase();
    final out = StringBuffer();
    for (final rune in lower.runes) {
      final ch = String.fromCharCode(rune);
      out.write(_fold[ch] ?? ch);
    }
    return out.toString();
  }

  /// Strips one German/English plural or inflection ending:
  /// "nusse" -> "nuss", "eier" -> "ei", "mandeln" -> "mandel", "kiwis" -> "kiwi".
  static String stem(String word) {
    final w = word;
    if (w.length >= 5 && w.endsWith('en')) return w.substring(0, w.length - 2);
    if (w.length >= 4 && w.endsWith('er')) return w.substring(0, w.length - 2);
    if (w.length >= 4 && w.endsWith('n')) return w.substring(0, w.length - 1);
    if (w.length >= 3 && w.endsWith('e')) return w.substring(0, w.length - 1);
    if (w.length >= 5 && w.endsWith('s') && !w.endsWith('ss')) {
      return w.substring(0, w.length - 1);
    }
    return w;
  }

  static List<String> _tokens(String text) => fold(text)
      .split(RegExp(r'[^a-z0-9]+'))
      .where((t) => t.isNotEmpty)
      .toList(growable: false);

  static const Map<String, String> _fold = {
    'ä': 'a', 'ö': 'o', 'ü': 'u', 'ß': 'ss', 'à': 'a', 'á': 'a', 'â': 'a',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'î': 'i', 'ï': 'i', 'í': 'i',
    'ô': 'o', 'ó': 'o', 'ù': 'u', 'û': 'u', 'ú': 'u', 'ç': 'c', 'ñ': 'n',
  };

  static const Map<String, AllergyType> _aliases = {
    'nut': AllergyType.nuts,
    'tree nut': AllergyType.nuts,
    'tree nuts': AllergyType.nuts,
    'nuss': AllergyType.nuts,
    'schalenfruchte': AllergyType.nuts,
    'peanut': AllergyType.peanuts,
    'erdnuss': AllergyType.peanuts,
    'dairy': AllergyType.milk,
    'milch': AllergyType.milk,
    'milchprodukte': AllergyType.milk,
    'laktose': AllergyType.lactose,
    'wheat': AllergyType.gluten,
    'weizen': AllergyType.gluten,
    'egg': AllergyType.eggs,
    'ei': AllergyType.eggs,
    'shellfish': AllergyType.crustaceans,
    'crustacean': AllergyType.crustaceans,
    'meeresfruchte': AllergyType.crustaceans,
    'soya': AllergyType.soy,
    'sulphites': AllergyType.sulfites,
    'mollusks': AllergyType.molluscs,
    'mollusk': AllergyType.molluscs,
    'nightshade': AllergyType.nightshades,
  };

  static final Map<AllergyType, _Spec> _specs = {
    for (final t in AllergyType.values) t: _Spec.forType(t),
  };
}

/// Extra words per type on top of [AllergyType.keywords] (folded).
const Map<AllergyType, List<String>> _extraKeywords = {
  AllergyType.gluten: [
    'mehl', 'grunkern', 'emmer', 'einkorn', 'bulgur', 'couscous', 'seitan', 'griess',
    'paniermehl', 'semmelbrosel', 'nudel', 'spaghetti', 'pasta', 'brot', 'brotchen',
    'wheat', 'barley', 'rye', 'spelt', 'flour', 'bread', 'semolina', 'breadcrumbs',
  ],
  AllergyType.crustaceans: ['garnele', 'krabbe', 'scampi', 'languste', 'shrimp', 'prawn', 'crab', 'lobster'],
  AllergyType.eggs: ['ruhrei', 'spiegelei', 'eiklar', 'eierlikor', 'mayonnaise', 'mayo', 'baiser', 'egg', 'eggs', 'meringue'],
  AllergyType.fish: ['forelle', 'hering', 'makrele', 'sardine', 'sardelle', 'anchovis', 'seelachs', 'dorsch', 'fish', 'salmon', 'tuna', 'anchovy'],
  AllergyType.peanuts: ['peanut', 'peanuts'],
  AllergyType.soy: ['miso', 'tempeh', 'soy', 'soya'],
  AllergyType.milk: [
    'milch', 'kase', 'butter', 'sahne', 'joghurt', 'quark', 'molke', 'mozzarella', 'parmesan',
    'ricotta', 'mascarpone', 'schmand', 'kefir', 'milk', 'cheese', 'cream', 'yogurt', 'yoghurt', 'whey',
    ..._dairyByName,
  ],
  AllergyType.nuts: [
    'nuss', 'nusse', 'mandel', 'marzipan', 'nougat', 'cashew', 'pistazie', 'pekannuss',
    'nut', 'nuts', 'hazelnut', 'walnut', 'almond', 'pecan', 'pistachio',
  ],
  AllergyType.celery: ['celery'],
  AllergyType.mustard: ['mustard'],
  AllergyType.sesame: ['tahin', 'sesame'],
  AllergyType.sulfites: ['sulfit', 'schwefel'],
  AllergyType.lupin: ['lupin'],
  AllergyType.molluscs: ['muschel', 'calamari', 'oktopus', 'auster', 'mussel', 'oyster', 'squid', 'clam'],
  AllergyType.lactose: [
    'milch', 'butter', 'kase', 'lactose', 'laktose', 'milk', 'cream', 'yogurt', ..._dairyByName,
  ],
  AllergyType.corn: ['corn'],
  AllergyType.yeast: ['yeast'],
};

/// Cheeses and dairy named without "Käse"/"Milch" in the word. Listed under
/// lactose too: a warning too many is safer than a missed one.
const _dairyByName = [
  'feta', 'halloumi', 'gouda', 'emmentaler', 'cheddar', 'camembert', 'brie', 'pecorino',
  'gorgonzola', 'burrata', 'ghee', 'skyr', 'paneer', 'creme fraiche', 'creme double',
];

/// Words that contain a keyword but are something else (token is skipped).
const Map<AllergyType, List<String>> _lookAlikes = {
  AllergyType.nuts: ['muskatnuss', 'kokos', 'butternut', 'nutmeg', 'coconut', 'donut', 'doughnut'],
  AllergyType.milk: ['butternut', 'kokos', 'brief'],
  AllergyType.lactose: ['butternut', 'kokos', 'brief'],
  AllergyType.gluten: ['buchweizen', 'buckwheat', 'glasnudel', 'glutenfrei'],
  AllergyType.eggs: ['eggplant'],
};

/// Plant prefixes that turn a keyword into something else: "Hafermilch",
/// "Erdnussbutter", "Reismehl", "coconut milk", "rice flour".
const _plantPrefixes = [
  'hafer', 'kokos', 'mandel', 'soja', 'reis', 'erbsen', 'cashew', 'dinkel', 'haselnuss', 'erdnuss',
  'nuss', 'kakao', 'shea', 'oat', 'almond', 'soy', 'rice', 'coconut', 'peanut', 'cocoa', 'vegan',
  'pflanzen',
];
const _glutenFreePrefixes = [
  'reis', 'mais', 'mandel', 'kokos', 'kichererbsen', 'kartoffel', 'lupinen', 'hirse', 'quinoa',
  'amaranth', 'tapioka', 'soja', 'linsen', 'erbsen', 'johannisbrot', 'rice', 'almond', 'coconut',
  'corn', 'chickpea', 'potato', 'tapioca', 'glutenfrei',
];

/// Phrases that cancel a type for the whole text ("glutenfreies Brot").
const Map<AllergyType, List<String>> _negations = {
  AllergyType.gluten: ['glutenfrei', 'gluten free', 'ohne gluten'],
  AllergyType.lactose: ['laktosefrei', 'lactose free', 'ohne laktose'],
};

class _Spec {
  final List<String> keywords;
  final List<String> lookAlikes;
  final List<String> prefixes;
  final List<String> negations;

  const _Spec(this.keywords, {this.lookAlikes = const [], this.prefixes = const [], this.negations = const []});

  factory _Spec.forType(AllergyType t) {
    final words = <String>{
      for (final k in t.keywords) AllergenMatcher.fold(k),
      ...?_extraKeywords[t],
    };
    return _Spec(
      words.toList(growable: false),
      lookAlikes: _lookAlikes[t] ?? const [],
      prefixes: switch (t) {
        AllergyType.milk || AllergyType.lactose => _plantPrefixes,
        AllergyType.gluten => _glutenFreePrefixes,
        _ => const [],
      },
      negations: _negations[t] ?? const [],
    );
  }

  factory _Spec.freeText(String raw) {
    final folded = AllergenMatcher.fold(raw).trim().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
    return _Spec(folded.isEmpty ? const [] : [folded]);
  }

  String? firstMatch(List<String> tokens, String joined) {
    for (final n in negations) {
      if (joined.contains(n)) return null;
    }
    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      if (lookAlikes.any(token.contains)) continue;
      final previous = i > 0 ? tokens[i - 1] : null;
      for (final kw in keywords) {
        if (kw.contains(' ')) {
          if (joined.contains(' $kw ')) return kw;
          continue;
        }
        if (!_tokenMatches(token, kw)) continue;
        final compound = prefixes.any((p) => token.startsWith(p) && !kw.startsWith(p));
        // "coconut milk", not "Haselnuss-Milchschokolade".
        final phrase = previous != null &&
            prefixes.contains(previous) &&
            AllergenMatcher.stem(token) == AllergenMatcher.stem(kw);
        if (compound || phrase) continue;
        return token;
      }
    }
    return null;
  }

  static bool _tokenMatches(String token, String kw) {
    if (kw.length >= 4) {
      if (token.contains(kw)) return true;
      final s = AllergenMatcher.stem(kw);
      return s.length >= 4 && token.contains(s);
    }
    return token == kw ||
        AllergenMatcher.stem(token) == kw ||
        AllergenMatcher.stem(token) == AllergenMatcher.stem(kw);
  }
}

/// The German grocery chains Avo knows (Kap. 12 "Markt pro Liste", 00 4.8):
/// ids, the ways people write them, their own brands and the brand colour of
/// the dot in the market chip. Pure data and pure functions, works offline.
library;

import 'dart:ui' show Brightness, Color;

import 'package:flutter/foundation.dart' show immutable;

@immutable
class StoreChain {
  const StoreChain({
    required this.id,
    required this.displayName,
    this.aliases = const [],
    this.privateLabels = const [],
    this.brandColor,
    this.nameIsCommonWord = false,
  });

  /// marktguru `uniqueName`, e.g. `lidl`, `aldi-sued`
  /// (see `OfferPriceService.groceryRetailers`).
  final String id;

  /// Name in the chip, in the chain's own spelling ("REWE", "PENNY").
  final String displayName;

  /// Other spellings, store formats and typos. Matched as whole words, case
  /// and umlauts ignored. The id and the display name always match too.
  final List<String> aliases;

  /// The chain's own brands ("Milbona" for Lidl). Only a weak signal: some
  /// are shared within a group (Gut & Günstig at Edeka and Netto).
  final List<String> privateLabels;

  /// Colour of the 8-pt dot. Null while no start value is agreed; the chip
  /// then draws a ring like for a market of the person's own (00 4.8).
  final Color? brandColor;

  /// The name is also a first name or an ordinary word ("Penny", "Globus",
  /// "Norma"). [matchChain] still finds it, but a list name that only
  /// contains it is weak evidence ("Penny Geburtstag").
  final bool nameIsCommonWord;

  /// Whether the dot needs its 0.5-pt outline in `separator` on a
  /// [brightness] background: light dots (Edeka, Netto) in light mode, very
  /// dark ones (Aldi Süd) in dark mode, where they would vanish.
  bool needsOutlineOn(Brightness brightness) {
    final color = brandColor;
    if (color == null) return false;
    final luminance = color.computeLuminance();
    return switch (brightness) {
      Brightness.light => luminance > 0.5,
      Brightness.dark => luminance < 0.05,
    };
  }
}

abstract final class StoreChainDirectory {
  /// D2 start values for the colours: Lidl, REWE, Aldi Süd, Aldi Nord, Edeka,
  /// Kaufland, Netto, PENNY (00 4.8). The other chains have none yet.
  static const List<StoreChain> chains = [
    StoreChain(
      id: 'lidl',
      displayName: 'Lidl',
      aliases: ['lidel', 'liddl', 'lidle', 'lidll'],
      privateLabels: [
        'Milbona', 'Pilos', 'Solevita', 'Freeway', 'Crivit', 'Silvercrest',
        'Parkside', 'Esmara', 'Lupilu', 'Livergy', 'W5', 'Cien', 'Fin Carré',
        'Combino', 'Vemondo', 'Chef Select', 'Kania', 'Sondey', 'Belbake',
        'Dulano', 'Gelatelli', 'Crownfield', 'Bellarom', 'Alesto', 'Nixe',
        'Lord Nelson', 'Perlenbacher', 'Italiamo', 'Eridanous', 'Ocean Sea',
        'McEnnedy', 'Baresa', 'Formil', 'Floralys', 'Trattoria Alfredo',
        'Snack Day',
      ],
      brandColor: Color(0xFF0050AA),
    ),
    StoreChain(
      id: 'rewe',
      displayName: 'REWE',
      aliases: ['rewe city', 'rewe center', 'rewee'],
      privateLabels: [
        'ja!', 'REWE Bio', 'REWE Beste Wahl', 'REWE Regional',
        'REWE Feine Welt',
      ],
      brandColor: Color(0xFFCC071E),
    ),
    StoreChain(
      id: 'edeka',
      displayName: 'Edeka',
      aliases: ['edecka', 'edeca', 'edka', 'e center', 'ecenter', 'e aktiv'],
      privateLabels: [
        'Gut & Günstig', 'Edeka Bio', 'Edeka Herzstücke', 'Edeka Selection',
        'Edeka Zuhause', 'Unsere Heimat', 'Elkos',
      ],
      brandColor: Color(0xFFFFD400),
    ),
    StoreChain(
      id: 'aldi-sued',
      displayName: 'Aldi Süd',
      // Plain "Aldi" belongs to both Aldis, so on its own it matches none.
      aliases: ['aldi', 'aldi sud', 'aldisued', 'aldisud'],
      privateLabels: [..._aldiLabels, 'Nur Nur Natur'],
      brandColor: Color(0xFF00005F),
    ),
    StoreChain(
      id: 'aldi-nord',
      displayName: 'Aldi Nord',
      aliases: ['aldi', 'aldinord'],
      privateLabels: _aldiLabels,
      brandColor: Color(0xFF00549F),
    ),
    StoreChain(
      id: 'kaufland',
      displayName: 'Kaufland',
      privateLabels: [
        'K-Classic', 'KClassic', 'K-Bio', 'K-Favourites', 'K-Purland',
        'K-Take it veggie', 'K-Free',
      ],
      brandColor: Color(0xFFE10915),
    ),
    StoreChain(
      id: 'netto-marken-discount',
      displayName: 'Netto',
      aliases: ['netto md', 'nettomd', 'netto markendiscount'],
      privateLabels: ['Gut & Günstig', 'BioBio', 'Mein Veggie Tag'],
      brandColor: Color(0xFFFFE500),
    ),
    StoreChain(
      id: 'penny',
      displayName: 'PENNY',
      aliases: ['peny'],
      privateLabels: [
        'Penny Ready', 'Naturgut', 'Food for Future', 'Mühlenhof',
      ],
      brandColor: Color(0xFFCD1414),
      nameIsCommonWord: true,
    ),
    StoreChain(id: 'norma', displayName: 'Norma', nameIsCommonWord: true),
    StoreChain(id: 'globus', displayName: 'Globus', nameIsCommonWord: true),
    StoreChain(id: 'famila', displayName: 'famila'),
    StoreChain(id: 'tegut', displayName: 'tegut', privateLabels: ['tegut']),
    StoreChain(id: 'nahkauf', displayName: 'nahkauf', aliases: ['nah kauf']),
  ];

  static const List<String> _aldiLabels = [
    'Milsani', 'Moser Roth', 'Lacura', 'Tandil', 'Choceur', "Rio d'Oro",
    'Cucina Nobile', 'Lyttos', 'Knusperone', 'Golden Seafood',
    'Almare', 'Meine Metzgerei', 'Asia Green Garden', 'Gut Bio', 'GutBio',
    'Mamia',
  ];

  static StoreChain? byId(String id) {
    for (final chain in chains) {
      if (chain.id == id) return chain;
    }
    return null;
  }
}

/// The one chain [text] names ("Lidl Wocheneinkauf" -> `lidl`, "lidel" ->
/// `lidl`), or null when it names none or several ("Kaufland/Lidl").
///
/// Chains are found as whole words. A longer match wins over a shorter one
/// inside it ("Aldi Süd" is Aldi Süd, not also "Aldi"). Single-word names of
/// six letters or more also match with one typo ("Kauflnd"), but never a
/// real word that is one letter away ("Nachkauf", "Family"). A text that
/// names both Aldis ("Aldi Süd/Nord") is no answer either.
String? matchChain(String text) {
  final tokens = _tokens(text);
  if (tokens.isEmpty) return null;
  if (tokens.contains('aldi') &&
      tokens.contains('nord') &&
      (tokens.contains('sued') || tokens.contains('sud'))) {
    return null;
  }

  final matches = <_Match>[];
  for (final entry in _aliasIndex) {
    final alias = entry.tokens;
    for (var start = 0; start + alias.length <= tokens.length; start++) {
      if (_matchesAt(tokens, alias, start)) {
        matches.add(_Match(entry.chainId, start, start + alias.length));
      }
    }
  }
  for (var i = 0; i < tokens.length; i++) {
    final token = tokens[i];
    if (token.length < 5 || _notChains.contains(token)) continue;
    for (final entry in _fuzzyIndex) {
      final name = entry.name;
      if (name[0] == token[0] && _editDistance(token, name) == 1) {
        matches.add(_Match(entry.chainId, i, i + 1));
      }
    }
  }

  final kept = matches.where((m) => !matches.any(m.isInside));
  final chainIds = {for (final m in kept) m.chainId};
  return chainIds.length == 1 ? chainIds.single : null;
}

/// Chain id -> how many of [itemNames] carry one of that chain's own brands.
/// Each item counts once per chain. Chains without hits are left out.
Map<String, int> privateLabelHits(List<String> itemNames) {
  final hits = <String, int>{};
  for (final name in itemNames) {
    final tokens = _tokens(name);
    final folded = _fold(name);
    final chainsOfItem = <String>{};
    for (final label in _labelIndex) {
      final exclamation = label.exclamation;
      final found = exclamation != null
          ? exclamation.hasMatch(folded)
          : _containsPhrase(tokens, label.tokens);
      if (found) chainsOfItem.add(label.chainId);
    }
    for (final chainId in chainsOfItem) {
      hits[chainId] = (hits[chainId] ?? 0) + 1;
    }
  }
  return hits;
}

/// The chain most of [names] point to (retailer names of one trip's items),
/// or null on a tie or when none is a known chain.
String? dominantChain(Iterable<String> names) {
  final counts = <String, int>{};
  for (final name in names) {
    final chainId = matchChain(name);
    if (chainId != null) counts[chainId] = (counts[chainId] ?? 0) + 1;
  }
  if (counts.isEmpty) return null;
  final best = counts.values.reduce((a, b) => a > b ? a : b);
  final leaders = [
    for (final e in counts.entries)
      if (e.value == best) e.key,
  ];
  return leaders.length == 1 ? leaders.single : null;
}

// ---------------------------------------------------------------------------

/// Real words one typo away from a chain name.
const _notChains = {'nachkauf', 'family', 'familia', 'famile', 'globes'};

class _Match {
  const _Match(this.chainId, this.start, this.end);
  final String chainId;
  final int start;
  final int end;

  /// True when this match lies inside the longer [other].
  bool isInside(_Match other) =>
      other.end - other.start > end - start &&
      other.start <= start &&
      other.end >= end;
}

class _AliasEntry {
  const _AliasEntry(this.chainId, this.tokens);
  final String chainId;
  final List<String> tokens;
}

class _FuzzyEntry {
  const _FuzzyEntry(this.chainId, this.name);
  final String chainId;
  final String name;
}

class _LabelEntry {
  _LabelEntry(this.chainId, String label)
      : tokens = _tokens(label),
        exclamation = label.endsWith('!')
            ? RegExp('(^|[^a-z0-9])${RegExp.escape(_fold(label))}')
            : null;
  final String chainId;
  final List<String> tokens;

  /// For "ja!": the mark is what makes it a brand, so the raw text must
  /// carry it ("ja! Milch", not "Ja Milch").
  final RegExp? exclamation;
}

final List<_AliasEntry> _aliasIndex = [
  for (final chain in StoreChainDirectory.chains)
    for (final alias in {chain.id, chain.displayName, ...chain.aliases})
      _AliasEntry(chain.id, _tokens(alias)),
];

/// Typo matching only for one-word display names of six letters or more:
/// shorter ones are too close to ordinary words ("Penny" / "Penne").
final List<_FuzzyEntry> _fuzzyIndex = [
  for (final chain in StoreChainDirectory.chains)
    if (_tokens(chain.displayName) case [final name] when name.length >= 6)
      _FuzzyEntry(chain.id, name),
];

final List<_LabelEntry> _labelIndex = [
  for (final chain in StoreChainDirectory.chains)
    for (final label in chain.privateLabels) _LabelEntry(chain.id, label),
];

String _fold(String text) => text
    .toLowerCase()
    .replaceAll('ä', 'ae')
    .replaceAll('ö', 'oe')
    .replaceAll('ü', 'ue')
    .replaceAll('ß', 'ss')
    .replaceAll(RegExp('[éèê]'), 'e');

List<String> _tokens(String text) => [
      for (final t in _fold(text).split(RegExp('[^a-z0-9]+')))
        if (t.isNotEmpty) t,
    ];

bool _matchesAt(List<String> tokens, List<String> phrase, int start) {
  for (var i = 0; i < phrase.length; i++) {
    if (tokens[start + i] != phrase[i]) return false;
  }
  return true;
}

bool _containsPhrase(List<String> tokens, List<String> phrase) {
  if (phrase.isEmpty) return false;
  for (var start = 0; start + phrase.length <= tokens.length; start++) {
    if (_matchesAt(tokens, phrase, start)) return true;
  }
  return false;
}

/// Edit distance with adjacent swaps ("kaufladn" -> "kaufland" is 1).
int _editDistance(String a, String b) {
  final d = List.generate(a.length + 1, (_) => List.filled(b.length + 1, 0));
  for (var i = 0; i <= a.length; i++) {
    d[i][0] = i;
  }
  for (var j = 0; j <= b.length; j++) {
    d[0][j] = j;
  }
  for (var i = 1; i <= a.length; i++) {
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      var best = d[i - 1][j] + 1;
      if (d[i][j - 1] + 1 < best) best = d[i][j - 1] + 1;
      if (d[i - 1][j - 1] + cost < best) best = d[i - 1][j - 1] + cost;
      if (i > 1 &&
          j > 1 &&
          a[i - 1] == b[j - 2] &&
          a[i - 2] == b[j - 1] &&
          d[i - 2][j - 2] + 1 < best) {
        best = d[i - 2][j - 2] + 1;
      }
      d[i][j] = best;
    }
  }
  return d[a.length][b.length];
}

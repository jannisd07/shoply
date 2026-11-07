/// Turns what someone types into the add-item field into items with a
/// quantity, e.g. "2 Milch", "Milch 2", "500 g Mehl", "eine halbe Melone",
/// "Milch (laktosefrei)" (Konzept 11, Plan 4). Pure: no I/O, no locale access
/// beyond [lang].
library;

/// One parsed item.
class ParsedItem {
  const ParsedItem({
    required this.name,
    this.quantity = 1,
    this.unit,
    this.note,
    this.quantityGiven = false,
  });

  /// Trimmed, single spaces, spelled as typed.
  final String name;

  /// Always > 0; 1 when none was given.
  final double quantity;

  /// Unit id (`g`, `kg`, `ml`, `l`, `pack`, `bottle`, `can`, `box`, `bunch`);
  /// null means pieces.
  final String? unit;

  /// Text from a trailing `( … )`.
  final String? note;

  /// Whether the input named a quantity or unit.
  final bool quantityGiven;

  /// A canonical way to type this item again ("1.5 l Milch (laktosefrei)").
  String get displayInput {
    final buffer = StringBuffer();
    if (quantityGiven || quantity != 1 || unit != null) {
      buffer.write(_formatNumber(quantity));
      if (unit != null) buffer.write(' $unit');
      buffer.write(' ');
    }
    buffer.write(name);
    if (note != null) buffer.write(' ($note)');
    return buffer.toString();
  }

  @override
  String toString() =>
      'ParsedItem($name, $quantity, ${unit ?? 'pcs'}, note: $note)';
}

/// Splits [raw] at line breaks and commas (not decimal commas, not inside
/// brackets) and parses every part. Parts without a name are dropped.
List<ParsedItem> parseItemInput(String raw, {String lang = 'de'}) => [
  for (final part in _split(raw))
    if (parseSingleItem(part, lang: lang) case final item?) item,
];

/// Parses one item. Returns null when there is nothing to add (empty input,
/// or only a quantity and unit).
ParsedItem? parseSingleItem(String raw, {String lang = 'de'}) {
  var s = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (s.isEmpty) return null;

  // (2) Trailing "( … )" is a note.
  String? note;
  final noteMatch = RegExp(r'^(.*?)\s*\(([^()]*)\)$').firstMatch(s);
  if (noteMatch != null) {
    final inner = noteMatch.group(2)!.trim();
    note = inner.isEmpty ? null : inner;
    s = noteMatch.group(1)!.trim();
    if (s.isEmpty) return null;
  }

  // (7) Known product names that start with a number stay names.
  final lower = s.toLowerCase();
  if (_knownNumberNames.any(lower.startsWith)) {
    return ParsedItem(name: s, note: note);
  }

  final leading = _parseLeading(s, lang);
  if (leading != null) {
    final (quantity, unit, rest) = leading;
    if (!_hasName(rest)) return null;
    if (!_validQuantity(quantity)) return ParsedItem(name: s, note: note);
    return ParsedItem(
      name: rest,
      quantity: quantity,
      unit: unit,
      note: note,
      quantityGiven: true,
    );
  }

  final trailing = _parseTrailing(s);
  if (trailing != null) {
    final (quantity, unit, rest) = trailing;
    if (_hasName(rest) && _validQuantity(quantity)) {
      return ParsedItem(
        name: rest,
        quantity: quantity,
        unit: unit,
        note: note,
        quantityGiven: true,
      );
    }
  }

  // Only a number or unit: nothing to add.
  if (!_hasName(s) || _isOnlyQuantity(s)) return null;
  return ParsedItem(name: s, note: note);
}

/// Whether two items are the same line on a list (merge): same name ignoring
/// case, same unit with "no unit" equal to pieces.
bool sameItem(ParsedItem a, ParsedItem b) =>
    a.name.toLowerCase() == b.name.toLowerCase() &&
    _normUnit(a.unit) == _normUnit(b.unit);

// ---------------------------------------------------------------- internals

const _knownNumberNames = [
  '4 jahreszeiten',
  'vier jahreszeiten',
  '7 up',
  '7up',
  '5 minuten terrine',
  '5-minuten-terrine',
  '8x4',
  '4711',
];

const Map<String, String?> _units = {
  'g': 'g',
  'gr': 'g',
  'gramm': 'g',
  'gram': 'g',
  'grams': 'g',
  'kg': 'kg',
  'kilo': 'kg',
  'kilogramm': 'kg',
  'ml': 'ml',
  'l': 'l',
  'ltr': 'l',
  'liter': 'l',
  'litre': 'l',
  'liters': 'l',
  'st': null,
  'stk': null,
  'stück': null,
  'stueck': null,
  'pcs': null,
  'pc': null,
  'pieces': null,
  'piece': null,
  'pck': 'pack',
  'pkg': 'pack',
  'packung': 'pack',
  'packungen': 'pack',
  'pack': 'pack',
  'packs': 'pack',
  'päckchen': 'pack',
  'packet': 'pack',
  'fl': 'bottle',
  'flasche': 'bottle',
  'flaschen': 'bottle',
  'bottle': 'bottle',
  'bottles': 'bottle',
  'dose': 'can',
  'dosen': 'can',
  'can': 'can',
  'cans': 'can',
  'tin': 'can',
  'tins': 'can',
  'schachtel': 'box',
  'schachteln': 'box',
  'box': 'box',
  'boxes': 'box',
  'bund': 'bunch',
  'bunch': 'bunch',
  'bunches': 'bunch',
};

const Map<String, double> _wordsDe = {
  'ein': 1,
  'eine': 1,
  'einen': 1,
  'eins': 1,
  'einem': 1,
  'einer': 1,
  'zwei': 2,
  'drei': 3,
  'vier': 4,
  'fünf': 5,
  'fuenf': 5,
  'sechs': 6,
  'sieben': 7,
  'acht': 8,
  'neun': 9,
  'zehn': 10,
  'elf': 11,
  'zwölf': 12,
  'zwoelf': 12,
};

const Map<String, double> _wordsEn = {
  'a': 1,
  'an': 1,
  'one': 1,
  'two': 2,
  'three': 3,
  'four': 4,
  'five': 5,
  'six': 6,
  'seven': 7,
  'eight': 8,
  'nine': 9,
  'ten': 10,
  'eleven': 11,
  'twelve': 12,
};

const _halfWords = {'halbe', 'halber', 'halbes', 'halben', 'half'};
const _dozenWords = {'dutzend', 'dozen'};

const Map<String, double> _unicodeFractions = {
  '½': 0.5,
  '¼': 0.25,
  '¾': 0.75,
  '⅓': 1 / 3,
  '⅔': 2 / 3,
};

bool _validQuantity(double q) => q > 0 && q <= 9999;

bool _hasName(String s) => RegExp(r'[^\W\d_]', unicode: true).hasMatch(s);

String? _normUnit(String? unit) => unit == 'pcs' ? null : unit;

bool _isUnitWord(String token) =>
    _units.containsKey(token.toLowerCase().replaceAll('.', ''));

String? _unitFor(String token) =>
    _units[token.toLowerCase().replaceAll('.', '')];

bool _isOnlyQuantity(String s) {
  final tokens = s.split(' ');
  return tokens.every(
    (t) => RegExp(r'^[\d.,/½¼¾⅓⅔x×]+$').hasMatch(t) || _isUnitWord(t),
  );
}

double? _number(String text) => double.tryParse(text.replaceAll(',', '.'));

String _formatNumber(double q) {
  if (q == q.roundToDouble()) return q.toInt().toString();
  final fixed = q.toStringAsFixed(3);
  return fixed
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

/// Reads a quantity (and unit) at the start. Returns (quantity, unit, rest)
/// or null when the text does not start with a quantity.
(double, String?, String)? _parseLeading(String s, String lang) {
  var rest = s;
  double? quantity;
  var matched = false;

  // Numerals: "1½", "½", "1/2", "1 1/2", "1,5", "500".
  final uni = RegExp(r'^(\d*)([½¼¾⅓⅔])').firstMatch(rest);
  final frac = RegExp(r'^(\d+)/(\d+)').firstMatch(rest);
  final num = RegExp(r'^(\d+(?:[.,]\d+)?)(?: (\d+)/(\d+))?').firstMatch(rest);
  if (uni != null) {
    final whole = uni.group(1)!.isEmpty ? 0 : int.parse(uni.group(1)!);
    quantity = whole + _unicodeFractions[uni.group(2)!]!;
    rest = rest.substring(uni.end);
    matched = true;
  } else if (frac != null) {
    final d = int.parse(frac.group(2)!);
    if (d == 0) return null;
    quantity = int.parse(frac.group(1)!) / d;
    rest = rest.substring(frac.end);
    matched = true;
  } else if (num != null) {
    quantity = _number(num.group(1)!);
    if (num.group(2) != null) {
      final d = int.parse(num.group(3)!);
      if (d == 0) return null;
      quantity = quantity! + int.parse(num.group(2)!) / d;
    }
    rest = rest.substring(num.end);
    matched = true;
  }

  String? unit;
  if (matched) {
    // Directly glued to the number: "%", a unit ("500g"), "x" ("2x"), or
    // letters of a name ("7Up").
    if (rest.startsWith('%')) return null;
    final glued = RegExp(r'^([^\s\d]+)').firstMatch(rest);
    if (glued != null) {
      final token = glued.group(1)!;
      if (token == 'x' || token == '×') {
        rest = rest.substring(glued.end);
      } else if (_isUnitWord(token)) {
        unit = _unitFor(token);
        rest = rest.substring(glued.end);
      } else {
        return null;
      }
    }
  }

  var tokens = rest.trim().isEmpty ? <String>[] : rest.trim().split(' ');

  // Number words: "ein", "zwei", "one", …
  if (!matched && tokens.isNotEmpty) {
    final words = lang == 'en' ? _wordsEn : _wordsDe;
    final w = words[tokens.first.toLowerCase()];
    if (w != null && tokens.length > 1) {
      quantity = w;
      tokens = tokens.sublist(1);
      matched = true;
    }
  }

  // "halbe" (0.5×) and "Dutzend" (12×), with or without a number before.
  if (tokens.length > 1 && _halfWords.contains(tokens.first.toLowerCase())) {
    quantity = (quantity ?? 1) * 0.5;
    tokens = tokens.sublist(1);
    matched = true;
  }
  if (tokens.length > 1 && _dozenWords.contains(tokens.first.toLowerCase())) {
    quantity = (quantity ?? 1) * 12;
    tokens = tokens.sublist(1);
    matched = true;
  }
  if (!matched) return null;

  // "x" between number and name: "2 x Milch".
  if (tokens.isNotEmpty && (tokens.first == 'x' || tokens.first == '×')) {
    tokens = tokens.sublist(1);
  }
  // A unit word: "500 g Mehl", "2 Pck. Butter".
  if (unit == null && tokens.isNotEmpty && _isUnitWord(tokens.first)) {
    unit = _unitFor(tokens.first);
    tokens = tokens.sublist(1);
  }
  return (quantity ?? 1, unit, tokens.join(' '));
}

/// Reads a quantity at the end: "Milch 2", "Milch x2", "Milch 2x",
/// "Mehl 500 g", "Tomaten 2 Dosen". Never "Milch 1,5 %".
(double, String?, String)? _parseTrailing(String s) {
  final m = RegExp(
    r'^(.*\S)\s+(?:[x×]\s*)?(\d+(?:[.,]\d+)?)\s*(?:([x×])|([^\s\d%x×.]+)\.?)?$',
  ).firstMatch(s);
  if (m == null) return null;
  final unitWord = m.group(4);
  String? unit;
  if (unitWord != null) {
    if (!_isUnitWord(unitWord)) return null;
    unit = _unitFor(unitWord);
  }
  final quantity = _number(m.group(2)!);
  if (quantity == null) return null;
  return (quantity, unit, m.group(1)!.trim());
}

/// Splits at newlines and commas, keeping decimal commas and bracket text.
List<String> _split(String raw) {
  final parts = <String>[];
  final buffer = StringBuffer();
  var depth = 0;
  for (var i = 0; i < raw.length; i++) {
    final c = raw[i];
    if (c == '(') depth++;
    if (c == ')' && depth > 0) depth--;
    final isDecimalComma =
        c == ',' &&
        i > 0 &&
        i + 1 < raw.length &&
        RegExp(r'\d').hasMatch(raw[i - 1]) &&
        RegExp(r'\d').hasMatch(raw[i + 1]);
    if ((c == '\n' || (c == ',' && !isDecimalComma)) && depth == 0) {
      parts.add(buffer.toString());
      buffer.clear();
    } else {
      buffer.write(c);
    }
  }
  parts.add(buffer.toString());
  return parts.where((p) => p.trim().isNotEmpty).toList();
}

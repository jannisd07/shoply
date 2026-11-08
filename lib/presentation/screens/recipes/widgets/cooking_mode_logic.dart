import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shoply/core/localization/app_translations.dart';
import 'package:shoply/core/utils/item_quantity.dart';
import 'package:shoply/data/models/recipe.dart';

/// Pure helpers of the cooking mode and the recipe editor (Konzept 13 §2.2,
/// §16.8): times found in a step text, the ingredients a step uses, amounts
/// scaled and formatted the recipe way. No I/O, no widgets.

/// A cooking time found in a step text: "15 Minuten", "10–15 min",
/// "1,5 Std.", "1 Std. 10 Min", "30 seconds".
@immutable
class StepTime {
  const StepTime({
    required this.duration,
    this.upper,
    required this.start,
    required this.end,
  });

  /// The time, for a range ("10–15 Minuten") its lower end.
  final Duration duration;

  /// The upper end of a range, otherwise null.
  final Duration? upper;

  /// Where the time stands in the text ([start] inclusive, [end] exclusive).
  final int start;
  final int end;

  @override
  bool operator ==(Object other) =>
      other is StepTime &&
      other.duration == duration &&
      other.upper == upper &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(duration, upper, start, end);

  @override
  String toString() => 'StepTime($duration, upper: $upper, $start-$end)';
}

const _number = r'(\d+(?:[.,]\d+)?)';
const _rangeJoin = r'\s*(?:-|–|—|bis|to)\s*';
// Longest spelling first: alternation is ordered.
const _unitWords =
    r'(stunden|stunde|std|hours|hour|hrs|hr|'
    r'minuten|minute|minutes|mins|min|'
    r'sekunden|sekunde|sek|seconds|second|secs|sec)';
// No letter may follow ("2 Minzblätter" is no time).
const _notLetter = r'(?![A-Za-zÄÖÜäöüß])';

final RegExp _timePattern = RegExp(
  '$_number(?:$_rangeJoin$_number)?\\s*$_unitWords\\.?$_notLetter',
  caseSensitive: false,
);

/// The longest timer the cooking mode offers.
const Duration _maxTimer = Duration(hours: 24);

Duration? _toDuration(String number, String unit) {
  final value = double.tryParse(number.replaceAll(',', '.'));
  if (value == null || value <= 0) return null;
  final u = unit.toLowerCase();
  final double seconds;
  if (u.startsWith('st') || u.startsWith('h')) {
    seconds = value * 3600;
  } else if (u.startsWith('min')) {
    seconds = value * 60;
  } else {
    seconds = value;
  }
  final d = Duration(seconds: seconds.round());
  if (d <= Duration.zero || d > _maxTimer) return null;
  return d;
}

bool _isHours(String unit) {
  final u = unit.toLowerCase();
  return u.startsWith('st') || u.startsWith('h');
}

bool _isMinutes(String unit) => unit.toLowerCase().startsWith('min');

/// Every cooking time in [text], in reading order. "1 Std. 10 Min" counts as
/// one time of 70 minutes; ranges keep both ends.
List<StepTime> detectStepTimes(String text) {
  final found = <({StepTime time, String unit})>[];
  for (final m in _timePattern.allMatches(text)) {
    final unit = m.group(3)!;
    final lower = _toDuration(m.group(1)!, unit);
    if (lower == null) continue;
    final upperText = m.group(2);
    final upper = upperText == null ? null : _toDuration(upperText, unit);
    found.add((
      time: StepTime(
        duration: lower,
        upper: upper != null && upper > lower ? upper : null,
        start: m.start,
        end: m.end,
      ),
      unit: unit,
    ));
  }

  // "1 Std. 10 Min" / "1 hour and 10 minutes": hours directly followed by
  // minutes become one time.
  final merged = <StepTime>[];
  for (var i = 0; i < found.length; i++) {
    final a = found[i];
    if (i + 1 < found.length) {
      final b = found[i + 1];
      final gap = text.substring(a.time.end, b.time.start);
      final joinable =
          a.time.upper == null &&
          b.time.upper == null &&
          _isHours(a.unit) &&
          _isMinutes(b.unit) &&
          RegExp(r'^\s*(?:und|and|,)?\s*$', caseSensitive: false).hasMatch(gap);
      if (joinable) {
        merged.add(
          StepTime(
            duration: a.time.duration + b.time.duration,
            start: a.time.start,
            end: b.time.end,
          ),
        );
        i++;
        continue;
      }
    }
    merged.add(a.time);
  }
  return merged;
}

/// "12:47", from an hour on "1:02:03". Never negative.
String formatTimerClock(Duration d) {
  final total = d.isNegative ? 0 : (d.inMilliseconds / 1000).ceil();
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// "15 Min", "1 Std. 10 Min", "45 Sek." (English "15 min", "1 hr 10 min",
/// "45 sec").
String formatDurationLabel(Duration d, String languageCode) {
  String t(String key, int n) =>
      AppTranslations.get(key, languageCode, params: {'n': '$n'});
  final totalSeconds = d.inSeconds;
  if (totalSeconds < 60) return t('recipe_cook_seconds_short', totalSeconds);
  final totalMinutes = (totalSeconds / 60).round();
  if (totalMinutes < 60) return t('recipe_cook_minutes_short', totalMinutes);
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  final h = t('recipe_cook_hours_short', hours);
  return minutes == 0 ? h : '$h ${t('recipe_cook_minutes_short', minutes)}';
}

// ------------------------------------------------------------ ingredients

/// Words in ingredient names that say nothing about the ingredient itself.
const Set<String> _descriptorWords = {
  'nach', 'geschmack', 'frisch', 'frische', 'frischer', 'gehackt',
  'gehackte', 'gerieben', 'geriebener', 'fein', 'grob', 'etwa', 'oder',
  'und', 'mit', 'für', 'festkochend', 'mehligkochend', 'klein', 'kleine',
  'groß', 'große', 'optional', 'etwas', 'ganz', 'ganze', 'gewürfelt',
  'taste', 'fresh', 'chopped', 'large', 'small', 'the', 'and', 'for',
  'finely', 'ground', 'grated', 'sliced', 'diced', 'some', //
};

Iterable<String> _keyWords(String name) => name
    .toLowerCase()
    .split(RegExp(r'[^a-zäöüß]+'))
    .where((w) => w.length >= 3 && !_descriptorWords.contains(w));

/// Indexes of [ingredients] that [step] mentions ("Kartoffeln" also matches
/// "Kartoffel"), in the order of the ingredient list.
List<int> ingredientsInStep(List<Ingredient> ingredients, String step) {
  final text = step.toLowerCase();
  final result = <int>[];
  for (var i = 0; i < ingredients.length; i++) {
    for (final word in _keyWords(ingredients[i].name)) {
      // A plural or case ending must not hide the word.
      final stem = word.length > 5 ? word.substring(0, word.length - 2) : word;
      if (text.contains(stem)) {
        result.add(i);
        break;
      }
    }
  }
  return result;
}

// ----------------------------------------------------------------- amounts

/// Units whose amounts read as fractions ("½ TL").
const Set<String> _fractionUnits = {
  'tl', 'el', 'tasse', 'tassen', 'cup', 'cups', 'tbsp', 'tsp', 'stück',
  'stk', 'stk.', 'st.', 'pcs', //
};

/// Units that are never scaled ("1 Prise Salz" stays one pinch).
const Set<String> _fixedUnits = {'prise', 'prisen', 'pinch', 'msp', 'msp.'};

const Set<String> _gramLike = {'g', 'ml', 'gramm', 'gr'};

const List<(double, String)> _fractions = [
  (0.25, '¼'),
  (1 / 3, '⅓'),
  (0.5, '½'),
  (2 / 3, '⅔'),
  (0.75, '¾'),
];

bool _isEgg(String name) {
  final lower = name.toLowerCase();
  return RegExp(r'^(ei|eier|egg|eggs)\b').hasMatch(lower);
}

/// [ingredient] scaled from [from] to [to] servings with the recipe rounding
/// rules (Konzept 13 §2.2): grams and millilitres to 5 (below 20 to 1),
/// pieces to ½, eggs up to whole ones; pinches and amounts without a number
/// stay as they are.
Ingredient scaleIngredient(Ingredient ingredient, int from, int to) {
  if (from <= 0 || from == to || ingredient.amount <= 0) return ingredient;
  final unit = ingredient.unit.trim().toLowerCase();
  if (_fixedUnits.contains(unit)) return ingredient;
  var amount = ingredient.amount * to / from;
  if (_gramLike.contains(unit)) {
    amount = amount < 20 ? amount.roundToDouble() : (amount / 5).round() * 5;
    if (amount <= 0) amount = 1;
  } else if (isPieceUnit(unit)) {
    amount = _isEgg(ingredient.name)
        ? amount.ceilToDouble()
        : (amount * 2).round() / 2;
    if (amount <= 0) amount = 0.5;
  } else {
    amount = (amount * 10).round() / 10;
  }
  return Ingredient(
    name: ingredient.name,
    amount: amount,
    unit: ingredient.unit,
  );
}

String? _fraction(double value) {
  final whole = value.floor();
  final rest = value - whole;
  for (final (value, glyph) in _fractions) {
    if ((rest - value).abs() < 0.02) {
      return whole == 0 ? glyph : '$whole$glyph';
    }
  }
  return null;
}

/// The amount of [ingredient] the recipe way: "200 g", "½ TL", "3", "1,5 l";
/// null when it has none ("Salz nach Geschmack"), never "0".
String? formatIngredientAmount(Ingredient ingredient, String languageCode) {
  final unit = ingredient.unit.trim();
  final lower = unit.toLowerCase();
  if (ingredient.amount <= 0) return unit.isEmpty ? null : unit;
  final amount = ingredient.amount;
  final whole = amount == amount.roundToDouble();
  if (!whole && (unit.isEmpty || _fractionUnits.contains(lower))) {
    final fraction = _fraction(amount);
    if (fraction != null) {
      return isPieceUnit(unit) ? fraction : '$fraction $unit';
    }
  }
  if (isPieceUnit(unit)) {
    return NumberFormat('0.#', languageCode).format(amount);
  }
  return formatQuantity(amount, unit, languageCode: languageCode);
}

/// "3 EL Olivenöl", "Salz nach Geschmack".
String formatIngredientLine(Ingredient ingredient, String languageCode) {
  final amount = formatIngredientAmount(ingredient, languageCode);
  return amount == null ? ingredient.name : '$amount ${ingredient.name}';
}

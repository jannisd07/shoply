import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:shoply/core/localization/app_translations.dart';
import 'package:shoply/core/utils/item_input_parser.dart';
import 'package:shoply/core/utils/item_quantity.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/recipe_draft.dart';

/// Default servings of a new recipe (Konzept 13 §17.4, Q-06: 2, not 4).
const int kEditorDefaultServings = 2;
const int kEditorMinServings = 1;
const int kEditorMaxServings = 20;

/// Longest preparation or cooking time the steppers offer (10 h).
const int kEditorMaxMinutes = 600;

/// Difficulty labels, the same ids as the recipe filters (Konzept 13 §5.1).
const List<String> kEditorDifficulties = ['easy', 'medium', 'advanced'];

/// The four steps of the editor.
const int kEditorStepCount = 4;

/// Units the list parser does not know but recipes use ("2 EL Olivenöl").
final RegExp _recipeUnit = RegExp(
  r'^(el|tl|prisen?|msp|tassen?|zehen?|scheiben?|becher|cups?|tbsp|tsp|'
  r'pinch(?:es)?|cloves?|slices?)\.?\s+(.+)$',
  caseSensitive: false,
);

/// Unit ids of the list parser that read the same in every language.
const Set<String> _plainUnits = {'g', 'kg', 'ml', 'l'};

/// One typed ingredient line, split the way the add-item field does it
/// ("200 g Feta" → 200, "g", "Feta").
@immutable
class ParsedIngredientLine {
  const ParsedIngredientLine({required this.name, this.amount, this.unit = ''});

  /// Empty when the line has a quantity but no name ("200 g").
  final String name;

  /// Null for "Salz nach Geschmack".
  final double? amount;

  /// "g", "EL", "Pck." or empty (pieces, no amount).
  final String unit;

  bool get hasName => name.trim().isNotEmpty;

  /// The ingredient as a recipe stores it (no amount = 0, Konzept 13 §2.2).
  Ingredient toIngredient() =>
      Ingredient(name: name, amount: amount ?? 0, unit: unit);
}

/// Parses one ingredient line with the add-item parser ([parseSingleItem],
/// the per-line half of `parseItemInput`; commas stay part of the name, so
/// "1 kg Kartoffeln, festkochend" is one ingredient), plus recipe units.
/// Null for an empty line.
ParsedIngredientLine? parseIngredientLine(String text, String languageCode) {
  final raw = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (raw.isEmpty) return null;
  final item = parseSingleItem(raw, lang: languageCode);
  if (item == null) return const ParsedIngredientLine(name: '');
  var name = item.name;
  final amount = item.quantityGiven ? item.quantity : null;
  var unit = '';
  final id = item.unit;
  if (id != null) {
    unit = _plainUnits.contains(id)
        ? id
        : AppTranslations.get('list_detail_unit_$id', languageCode);
  } else if (amount != null) {
    final m = _recipeUnit.firstMatch(name);
    if (m != null) {
      unit = m.group(1)!;
      name = m.group(2)!;
    }
  }
  final note = item.note;
  if (note != null) name = '$name ($note)';
  return ParsedIngredientLine(name: name, amount: amount, unit: unit);
}

String _number(double value, String languageCode) =>
    NumberFormat('0.##', languageCode).format(value);

/// The line someone would type for [ingredient] ("200 g Feta").
String ingredientInputText(Ingredient ingredient, String languageCode) {
  final parts = [
    if (ingredient.amount > 0) _number(ingredient.amount, languageCode),
    if (ingredient.unit.trim().isNotEmpty) ingredient.unit.trim(),
    ingredient.name.trim(),
  ];
  return parts.join(' ');
}

/// What the parser understood, under the line: "200 g · Feta".
String ingredientSummary(ParsedIngredientLine line, String languageCode) {
  final amount = line.amount;
  if (amount == null) {
    return '${line.name} · ${AppTranslations.get('recipe_editor_no_amount', languageCode)}';
  }
  final quantity =
      formatQuantity(amount, line.unit, languageCode: languageCode) ??
      _number(amount, languageCode);
  return '$quantity · ${line.name}';
}

/// One editable row (ingredient or step) with its own controller and focus.
class RecipeEditorLine {
  RecipeEditorLine([String text = ''])
    : controller = TextEditingController(text: text),
      id = _nextId++;

  static int _nextId = 0;

  /// Stable key for dismissing and reordering.
  final int id;
  final TextEditingController controller;
  final FocusNode focus = FocusNode();

  String get text => controller.text;

  void dispose() {
    controller.dispose();
    focus.dispose();
  }
}

/// What still blocks "Weiter" or "Veröffentlichen".
enum RecipeEditorIssue {
  /// Step 1: no name.
  name,

  /// Step 3: no ingredient.
  ingredients,

  /// Step 4: no step.
  steps,

  /// Step 4: publishing to everyone needs a display name (never the email
  /// address, Inv-D 20).
  authorName;

  /// The editor step (0-based) the issue belongs to.
  int get step => switch (this) {
    RecipeEditorIssue.name => 0,
    RecipeEditorIssue.ingredients => 2,
    RecipeEditorIssue.steps || RecipeEditorIssue.authorName => 3,
  };

  /// Translation key of the sentence under the field.
  String get messageKey => switch (this) {
    RecipeEditorIssue.name => 'recipe_editor_error_name',
    RecipeEditorIssue.ingredients => 'recipe_editor_error_ingredients',
    RecipeEditorIssue.steps => 'recipe_editor_error_steps',
    RecipeEditorIssue.authorName => 'recipe_editor_error_author',
  };
}

/// Everything the recipe editor edits, independent of widgets and services.
/// Notifies on every change (text, numbers, rows, photo), which drives the
/// automatic draft and the change detection.
class RecipeEditorForm extends ChangeNotifier {
  RecipeEditorForm() {
    name.addListener(notifyListeners);
    description.addListener(notifyListeners);
    _listen(ingredients);
    _listen(steps);
  }

  final TextEditingController name = TextEditingController();
  final FocusNode nameFocus = FocusNode();
  final TextEditingController description = TextEditingController();
  final FocusNode descriptionFocus = FocusNode();

  int _prepMinutes = 10;
  int _cookMinutes = 20;
  int _servings = kEditorDefaultServings;
  String _difficulty = kEditorDifficulties.first;

  /// A photo picked in this session or loaded from the draft.
  File? _photo;

  /// The photo of the published recipe (edit mode), kept unless replaced or
  /// removed.
  String? _photoUrl;

  final List<RecipeEditorLine> ingredients = [RecipeEditorLine()];
  final List<RecipeEditorLine> steps = [RecipeEditorLine()];

  /// Rows removed with undo; disposed with the form.
  final List<RecipeEditorLine> _removed = [];

  bool _disposed = false;

  int get prepMinutes => _prepMinutes;
  int get cookMinutes => _cookMinutes;
  int get servings => _servings;
  String get difficulty => _difficulty;
  File? get photo => _photo;
  String? get photoUrl => _photoUrl;
  bool get hasPhoto => _photo != null || (_photoUrl?.isNotEmpty ?? false);

  set prepMinutes(int v) =>
      _set(() => _prepMinutes = v.clamp(0, kEditorMaxMinutes));
  set cookMinutes(int v) =>
      _set(() => _cookMinutes = v.clamp(0, kEditorMaxMinutes));
  set servings(int v) =>
      _set(() => _servings = v.clamp(kEditorMinServings, kEditorMaxServings));
  set difficulty(String v) {
    if (kEditorDifficulties.contains(v)) _set(() => _difficulty = v);
  }

  void setPhoto(File? file) => _set(() {
    _photo = file;
    if (file != null) _photoUrl = null;
  });

  /// Removes the photo; returns a function that puts it back (undo).
  VoidCallback removePhoto() {
    final file = _photo;
    final url = _photoUrl;
    _set(() {
      _photo = null;
      _photoUrl = null;
    });
    return () => _set(() {
      _photo = file;
      _photoUrl = url;
    });
  }

  void _set(VoidCallback change) {
    change();
    notifyListeners();
  }

  void _listen(List<RecipeEditorLine> lines) {
    for (final l in lines) {
      l.controller.addListener(notifyListeners);
    }
  }

  // ------------------------------------------------------------------ rows

  /// Adds an empty row after [after] (or at the end) and returns it.
  RecipeEditorLine insertLine(
    List<RecipeEditorLine> lines, {
    RecipeEditorLine? after,
    String text = '',
  }) {
    final line = RecipeEditorLine(text)
      ..controller.addListener(notifyListeners);
    final index = after == null ? lines.length : lines.indexOf(after) + 1;
    lines.insert(index.clamp(0, lines.length), line);
    notifyListeners();
    return line;
  }

  /// Removes [line]; returns a function that puts it back where it was.
  /// One empty row always stays.
  VoidCallback removeLine(List<RecipeEditorLine> lines, RecipeEditorLine line) {
    final index = lines.indexOf(line);
    if (index < 0) return () {};
    lines.removeAt(index);
    _removed.add(line);
    RecipeEditorLine? filler;
    if (lines.isEmpty) {
      filler = RecipeEditorLine()..controller.addListener(notifyListeners);
      lines.add(filler);
    }
    notifyListeners();
    return () {
      if (_disposed || lines.contains(line)) return;
      if (filler != null && lines.length == 1 && filler.text.isEmpty) {
        lines.remove(filler);
        _removed.add(filler);
      }
      lines.insert(index.clamp(0, lines.length), line);
      _removed.remove(line);
      notifyListeners();
    };
  }

  /// A pasted block of several lines becomes one ingredient per line
  /// (Konzept 13 §17.5). Returns the last row, for focus.
  RecipeEditorLine splitPastedIngredient(RecipeEditorLine line) {
    final text = line.text;
    if (!text.contains('\n')) return line;
    final parts = text
        .split(RegExp(r'\r?\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    final first = parts.isEmpty ? '' : parts.first;
    line.controller.value = TextEditingValue(
      text: first,
      selection: TextSelection.collapsed(offset: first.length),
    );
    var last = line;
    for (final part in parts.skip(1)) {
      last = insertLine(ingredients, after: last, text: part);
    }
    return last;
  }

  // ------------------------------------------------------------- content

  List<String> get stepTexts => [
    for (final s in steps)
      if (s.text.trim().isNotEmpty) s.text.trim(),
  ];

  List<ParsedIngredientLine> parsedIngredients(String languageCode) => [
    for (final l in ingredients)
      if (parseIngredientLine(l.text, languageCode) case final p?) p,
  ];

  /// Anything typed or picked (a draft exists only from here on).
  bool get hasContent =>
      name.text.trim().isNotEmpty ||
      description.text.trim().isNotEmpty ||
      _photo != null ||
      ingredients.any((l) => l.text.trim().isNotEmpty) ||
      steps.any((l) => l.text.trim().isNotEmpty);

  /// What blocks step [step]; [needsAuthorName] when publishing to everyone
  /// without a display name.
  List<RecipeEditorIssue> issuesFor(
    int step, {
    required String languageCode,
    bool needsAuthorName = false,
  }) {
    return [
      if (step == 0 && name.text.trim().isEmpty) RecipeEditorIssue.name,
      if (step == 2 && !parsedIngredients(languageCode).any((p) => p.hasName))
        RecipeEditorIssue.ingredients,
      if (step == 3 && stepTexts.isEmpty) RecipeEditorIssue.steps,
      if (step == 3 && needsAuthorName) RecipeEditorIssue.authorName,
    ];
  }

  /// Whether step [step] is complete (step menu ticks).
  bool stepComplete(int step, {required String languageCode}) =>
      issuesFor(step, languageCode: languageCode).isEmpty;

  /// Every field, rows in order: changes anywhere change it (Inv-D 7).
  String signature() => [
    name.text.trim(),
    description.text.trim(),
    '$_prepMinutes/$_cookMinutes/$_servings/$_difficulty',
    _photo?.path ?? '',
    _photoUrl ?? '',
    for (final l in ingredients) 'i:${l.text.trim()}',
    for (final l in steps) 's:${l.text.trim()}',
  ].join('\u0001');

  // ---------------------------------------------------------- conversion

  void _replaceRows(List<RecipeEditorLine> lines, Iterable<String> texts) {
    for (final l in lines) {
      l.controller.removeListener(notifyListeners);
      _removed.add(l);
    }
    lines
      ..clear()
      ..addAll(texts.map(RecipeEditorLine.new));
    if (lines.isEmpty) lines.add(RecipeEditorLine());
    _listen(lines);
  }

  /// Fills the form from a saved draft; [photo] is its resolved image.
  void fillFromDraft(RecipeDraft draft, {File? photo}) {
    name.text = draft.name;
    description.text = draft.description;
    _prepMinutes = (draft.prepTimeMinutes ?? _prepMinutes).clamp(
      0,
      kEditorMaxMinutes,
    );
    _cookMinutes = (draft.cookTimeMinutes ?? _cookMinutes).clamp(
      0,
      kEditorMaxMinutes,
    );
    _servings = (draft.defaultServings ?? _servings).clamp(
      kEditorMinServings,
      kEditorMaxServings,
    );
    _photo = photo;
    _replaceRows(ingredients, [
      for (final i in draft.ingredients)
        [
          i.amount.trim(),
          i.unit.trim(),
          i.name.trim(),
        ].where((p) => p.isNotEmpty).join(' '),
    ]);
    _replaceRows(steps, draft.instructions);
    notifyListeners();
  }

  /// Fills the form from a published recipe (edit mode).
  void fillFromRecipe(Recipe recipe, {required String languageCode}) {
    name.text = recipe.name;
    description.text = recipe.description;
    _prepMinutes = recipe.prepTimeMinutes.clamp(0, kEditorMaxMinutes);
    _cookMinutes = recipe.cookTimeMinutes.clamp(0, kEditorMaxMinutes);
    _servings = recipe.defaultServings.clamp(
      kEditorMinServings,
      kEditorMaxServings,
    );
    _difficulty = recipe.labels.firstWhere(
      kEditorDifficulties.contains,
      orElse: () => _difficulty,
    );
    _photo = null;
    _photoUrl = recipe.imageUrl.isEmpty ? null : recipe.imageUrl;
    _replaceRows(ingredients, [
      for (final i in recipe.ingredients) ingredientInputText(i, languageCode),
    ]);
    _replaceRows(steps, recipe.instructions);
    notifyListeners();
  }

  /// The draft to save; [imagePath] is the photo copy in the drafts folder.
  RecipeDraft toDraft({
    required String id,
    required String languageCode,
    String? imagePath,
    DateTime? createdAt,
  }) {
    final now = DateTime.now();
    return RecipeDraft(
      id: id,
      name: name.text.trim(),
      description: description.text.trim(),
      localImagePath: imagePath,
      prepTimeMinutes: _prepMinutes,
      cookTimeMinutes: _cookMinutes,
      defaultServings: _servings,
      ingredients: [
        for (final l in ingredients)
          if (l.text.trim().isNotEmpty)
            if (parseIngredientLine(l.text, languageCode) case final p?
                when p.hasName)
              DraftIngredient(
                name: p.name,
                amount: p.amount == null
                    ? ''
                    : _number(p.amount!, languageCode),
                unit: p.unit,
              )
            else
              // Not understood: keep the text as typed.
              DraftIngredient(name: l.text.trim(), amount: '', unit: ''),
      ],
      instructions: [
        for (final s in steps)
          if (s.text.trim().isNotEmpty) s.text.trim(),
      ],
      createdAt: createdAt ?? now,
      updatedAt: now,
    );
  }

  /// Ingredients for publishing (lines without a name are dropped).
  List<Ingredient> toIngredients(String languageCode) => [
    for (final p in parsedIngredients(languageCode))
      if (p.hasName) p.toIngredient(),
  ];

  @override
  void dispose() {
    _disposed = true;
    name.dispose();
    nameFocus.dispose();
    description.dispose();
    descriptionFocus.dispose();
    for (final l in [...ingredients, ...steps, ..._removed]) {
      l.dispose();
    }
    super.dispose();
  }
}

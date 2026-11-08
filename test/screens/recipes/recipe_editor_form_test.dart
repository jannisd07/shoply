import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/recipe_draft.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_editor_form.dart';

void main() {
  group('parseIngredientLine', () {
    ParsedIngredientLine p(String s) => parseIngredientLine(s, 'de')!;

    test('amount, unit and name like the add-item field', () {
      final feta = p('200 g Feta');
      expect(feta.amount, 200);
      expect(feta.unit, 'g');
      expect(feta.name, 'Feta');
      expect(p('1,5 l Brühe').amount, 1.5);
      expect(p('1/2 Zitrone').amount, 0.5);
      expect(p('½ TL Kreuzkümmel').unit, 'TL');
    });

    test('recipe units the list parser does not know', () {
      final oil = p('2 EL Olivenöl');
      expect(oil.amount, 2);
      expect(oil.unit, 'EL');
      expect(oil.name, 'Olivenöl');
      expect(p('1 Prise Muskat').unit, 'Prise');
    });

    test('no amount is fine, commas stay in the name', () {
      final salt = p('Salz nach Geschmack');
      expect(salt.amount, isNull);
      expect(salt.name, 'Salz nach Geschmack');
      expect(salt.toIngredient().amount, 0);
      expect(p('1 kg Kartoffeln, festkochend').name, 'Kartoffeln, festkochend');
    });

    test('a line without a name says so; empty lines are nothing', () {
      expect(p('200 g').hasName, isFalse);
      expect(parseIngredientLine('   ', 'de'), isNull);
    });

    test('summary under the line', () {
      expect(ingredientSummary(p('200 g Feta'), 'de'), '200 g · Feta');
      expect(ingredientSummary(p('Pfeffer'), 'de'), 'Pfeffer · ohne Menge');
    });

    test('a stored ingredient becomes the same line again', () {
      const ing = Ingredient(name: 'Brühe', amount: 1.5, unit: 'l');
      final text = ingredientInputText(ing, 'de');
      expect(text, '1,5 l Brühe');
      expect(p(text).toIngredient(), ing);
    });
  });

  group('RecipeEditorForm', () {
    late RecipeEditorForm form;
    setUp(() => form = RecipeEditorForm());
    tearDown(() => form.dispose());

    test('empty: no content, issues per step', () {
      expect(form.hasContent, isFalse);
      expect(form.servings, 2);
      expect(form.issuesFor(0, languageCode: 'de'), [RecipeEditorIssue.name]);
      expect(form.issuesFor(1, languageCode: 'de'), isEmpty);
      expect(form.issuesFor(2, languageCode: 'de'), [
        RecipeEditorIssue.ingredients,
      ]);
      expect(
        form.issuesFor(3, languageCode: 'de', needsAuthorName: true),
        [RecipeEditorIssue.steps, RecipeEditorIssue.authorName],
      );
    });

    test('rows: insert after, remove with undo, one row always stays', () {
      final first = form.ingredients.single..controller.text = 'Feta';
      final second = form.insertLine(form.ingredients, after: first);
      expect(form.ingredients, [first, second]);
      final undo = form.removeLine(form.ingredients, first);
      expect(form.ingredients, [second]);
      undo();
      expect(form.ingredients, [first, second]);
      form.removeLine(form.ingredients, first);
      final undoLast = form.removeLine(form.ingredients, second);
      expect(form.ingredients, hasLength(1));
      expect(form.ingredients.single.text, isEmpty);
      undoLast();
      expect(form.ingredients, [second]);
    });

    test('a pasted block becomes one ingredient per line', () {
      final line = form.ingredients.single;
      line.controller.text = '500 g Kartoffeln\n1 Zwiebel\n\n2 EL Öl';
      final last = form.splitPastedIngredient(line);
      expect(form.ingredients.map((l) => l.text), [
        '500 g Kartoffeln',
        '1 Zwiebel',
        '2 EL Öl',
      ]);
      expect(last.text, '2 EL Öl');
    });

    test('draft round trip keeps every field', () {
      form.name.text = 'Omas Kartoffelsalat';
      form.description.text = 'Lauwarm am besten.';
      form.prepMinutes = 20;
      form.cookMinutes = 30;
      form.servings = 4;
      form.ingredients.single.controller.text = '1 kg Kartoffeln, festkochend';
      form.insertLine(form.ingredients, text: '150 ml Brühe');
      form.insertLine(form.ingredients, text: 'Salz, Pfeffer nach Geschmack');
      form.steps.single.controller.text = 'Kartoffeln 25 Minuten kochen.';
      final draft = form.toDraft(id: 'd1', languageCode: 'de');
      expect(draft.ingredients.first.amount, '1');
      expect(draft.ingredients.first.unit, 'kg');

      final again = RecipeEditorForm()
        ..fillFromDraft(RecipeDraft.fromJson(draft.toJson()));
      addTearDown(again.dispose);
      expect(again.signature(), form.signature());
      expect(again.toIngredients('de'), form.toIngredients('de'));
    });

    test('a line the parser cannot read is kept as typed in the draft', () {
      form.ingredients.single.controller.text = '200 g';
      final draft = form.toDraft(id: 'd', languageCode: 'de');
      expect(draft.ingredients.single.name, '200 g');
    });

    test('signature changes with every field (change detection)', () {
      final recipe = Recipe(
        id: 'r1',
        name: 'Ofengemüse',
        description: '',
        imageUrl: 'https://example.com/a.jpg',
        prepTimeMinutes: 10,
        cookTimeMinutes: 25,
        defaultServings: 2,
        ingredients: const [Ingredient(name: 'Feta', amount: 200, unit: 'g')],
        instructions: const ['Backen.'],
        labels: const ['healthy', 'medium'],
        authorId: 'me',
        authorName: 'Jannis D.',
        createdAt: DateTime(2026),
      );
      form.fillFromRecipe(recipe, languageCode: 'de');
      expect(form.difficulty, 'medium');
      expect(form.hasPhoto, isTrue);
      final base = form.signature();
      form.ingredients.single.controller.text = '250 g Feta';
      expect(form.signature(), isNot(base));
      form.ingredients.single.controller.text = '200 g Feta';
      expect(form.signature(), base);
      final undo = form.removePhoto();
      expect(form.signature(), isNot(base));
      undo();
      expect(form.signature(), base);
    });
  });
}

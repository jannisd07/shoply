import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/localization/app_translations.dart';
import 'package:shoply/data/models/nutrition_info.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_detail_action_bar.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_detail_header.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_detail_report.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_detail_sections.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_detail_texts.dart';
import 'package:shoply/presentation/widgets/recipes/nutrition_info_widget.dart';
import 'package:shoply/presentation/widgets/recipes/star_rating_widget.dart';

import '../../layout/layout_matrix.dart';

String _en(String key, [Map<String, String>? params]) =>
    AppTranslations.get(key, 'en', params: params);

const _lines = [
  RecipeIngredientLine(name: 'Kartoffeln, festkochend', amount: '500 g'),
  RecipeIngredientLine(
    name: 'laktosefreier Hirtenkäse',
    amount: '200 g',
    adapted: true,
    sublines: [
      'instead of Feta · because of lactose',
      'Already on Weekly shop',
    ],
  ),
  RecipeIngredientLine(
    name: 'geröstete Erdnüsse',
    amount: '50 g',
    allergen: 'peanut',
  ),
  RecipeIngredientLine(name: 'Pesto', amount: '2 EL', unchecked: true),
  RecipeIngredientLine(name: 'Salz', amount: ''),
];

const _notice = [
  RecipeNoticeLine(
    RecipeNoticeKind.allergen,
    'Contains peanut (geröstete Erdnüsse). You entered a peanut allergy. '
    'We know no safe substitute for peanut.',
  ),
  RecipeNoticeLine(
    RecipeNoticeKind.adapted,
    'Adapted for you: 1 ingredient replaced because you eat vegetarian.',
  ),
  RecipeNoticeLine(
    RecipeNoticeKind.unchecked,
    '1 ingredient could not be checked for allergens: Pesto.',
  ),
];

/// The test surface at an iPhone width (the harness only sets MediaQuery).
void _phone(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width * 3, kLayoutHeight * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  layoutMatrix(
    'RecipeAllergenNotice',
    (_) => const RecipeAllergenNotice(lines: _notice),
    scrollable: true,
  );

  layoutMatrix(
    'RecipeIngredientsSection',
    (_) => RecipeIngredientsSection(
      lines: _lines,
      servings: 2,
      onServings: (_) {},
      adapted: true,
      onAdapted: (_) {},
    ),
    scrollable: true,
  );

  layoutMatrix(
    'RecipeStepsSection',
    (_) => const RecipeStepsSection(
      steps: [
        RecipeStepLine(text: 'Ofen auf 200 °C Umluft vorheizen.'),
        RecipeStepLine(
          text: 'Hirtenkäse zerbröseln und weitere 10 Minuten backen.',
          note: 'instead of Feta · because of lactose',
        ),
      ],
    ),
    scrollable: true,
  );

  layoutMatrix(
    'RecipeNutritionSection',
    (_) => const RecipeNutritionSection(
      nutrition: NutritionInfo(
        calories: 540,
        proteinG: 18,
        carbsG: 52,
        fatG: 29,
      ),
    ),
    scrollable: true,
  );

  layoutMatrix(
    'RecipeRatingRow',
    (_) => RecipeRatingRow(rating: 4, onRate: (_) {}),
    scrollable: true,
  );

  layoutMatrix(
    'RecipeDetailActionBar',
    (_) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: RecipeDetailActionBar(onToList: () {}, onCook: () {}),
    ),
  );

  layoutMatrix(
    'RecipeDetailActionBar resume',
    (_) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: RecipeDetailActionBar(
        onToList: () {},
        onCook: () {},
        resumeStep: 3,
      ),
    ),
  );

  layoutMatrix(
    'RecipeDetailTitle',
    (_) => const RecipeDetailTitle(
      title: 'Ofengemüse mit Feta und sehr langem Namen für kleine Displays',
      metaParts: ['35 Min', '★ 4,7 (128)', 'vegetarisch'],
      authorName: 'Mara Köhler',
    ),
    scrollable: true,
  );

  layoutMatrix(
    'RecipeDescription and source',
    (_) => Column(
      children: [
        const RecipeDescription(
          text:
              'Ein Blech, wenig Abwasch: Kartoffeln und Gemüse rösten, Feta '
              'obendrauf, fertig. Dazu passt ein grüner Salat und frisches '
              'Brot. Reste schmecken am nächsten Tag kalt. Wer mag, gibt '
              'Chili dazu. Im Sommer mit Tomaten aus dem Garten.',
        ),
        RecipeSourceFooter(
          source: 'Wikibooks Kochbuch',
          license: 'CC BY-SA 4.0',
          onOpen: () {},
        ),
      ],
    ),
    scrollable: true,
  );

  layoutMatrix(
    'RecipeDetailPlaceholder and problems',
    (_) => Column(
      children: [
        const RecipeDetailPlaceholder(photoHeight: 200),
        RecipeDetailProblem(gone: true, onAction: () {}),
        RecipeDetailProblem(gone: false, offline: true, onAction: () {}),
      ],
    ),
    scrollable: true,
  );

  layoutMatrix(
    'RecipeDetailToolbar',
    (_) => RecipeDetailToolbar(
      onBack: () {},
      title: 'Ofengemüse mit Feta',
      saved: true,
      onSave: () {},
      onShare: () {},
      onMore: () {},
    ),
  );

  layoutMatrix(
    'RecipeReportScreen',
    (_) => const SizedBox(height: kLayoutHeight, child: RecipeReportScreen()),
  );

  testWidgets('stars: tap and VoiceOver adjust', (tester) async {
    await loadLayoutFonts();
    _phone(tester, 390);
    final rated = <int>[];
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      layoutHarness(
        const LayoutCase(width: 390, scale: 1),
        RecipeRatingRow(rating: 2, onRate: rated.add),
      ),
    );
    final row = find.bySemanticsLabel(_en('recipe_detail_your_rating'));
    final semantics = tester.getSemantics(row);
    expect(semantics.value, _en('recipe_detail_stars', {'n': '2'}));
    tester
        .widget<Semantics>(
          find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                w.properties.label == _en('recipe_detail_your_rating'),
          ),
        )
        .properties
        .onIncrease!();
    expect(rated, [3]);
    final rect = tester.getRect(row);
    // The last star sits 16 pt + half a target from the right edge.
    await tester.tapAt(Offset(rect.right - 16 - 22, rect.center.dy));
    expect(rated, [3, 5]);
    handle.dispose();
  });

  testWidgets('long description: "More" shows all of it', (tester) async {
    await loadLayoutFonts();
    _phone(tester, 320);
    await tester.pumpWidget(
      layoutHarness(
        const LayoutCase(width: 320, scale: 1),
        const RecipeDescription(
          text:
              'Eins zwei drei vier fünf sechs sieben acht neun zehn elf zwölf '
              'dreizehn vierzehn fünfzehn sechzehn siebzehn achtzehn neunzehn '
              'zwanzig einundzwanzig zweiundzwanzig dreiundzwanzig vierundzwanzig '
              'fünfundzwanzig sechsundzwanzig siebenundzwanzig achtundzwanzig.',
        ),
      ),
    );
    expect(find.text(_en('recipe_detail_more_text')), findsOneWidget);
    await tester.tap(find.text(_en('recipe_detail_more_text')));
    await tester.pump();
    expect(find.text(_en('recipe_detail_more_text')), findsNothing);
  });

  testWidgets('report: "Send" only with a reason', (tester) async {
    await loadLayoutFonts();
    _phone(tester, 390);
    await tester.pumpWidget(
      layoutHarness(
        const LayoutCase(width: 390, scale: 1),
        const SizedBox(height: kLayoutHeight, child: RecipeReportScreen()),
      ),
    );
    final send = find.bySemanticsLabel(_en('recipe_detail_report_send'));
    expect(tester.getSemantics(send), isSemantics(isEnabled: false));
    await tester.tap(find.text(_en('recipe_detail_report_spam')));
    await tester.pump();
    expect(tester.getSemantics(send), isSemantics(isEnabled: true));
  });
}

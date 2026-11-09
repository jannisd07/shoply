import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/amount_field.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';

import '../../../layout/layout_matrix.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  LayoutCase layout = const LayoutCase(width: 390, scale: 1),
}) async {
  await loadLayoutFonts();
  tester.view.physicalSize = Size(layout.width * 3, kLayoutHeight * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    layoutHarness(
      layout,
      Align(
        alignment: Alignment.topCenter,
        child: SizedBox(width: layout.width, child: child),
      ),
    ),
  );
}

CupertinoTextField _field(WidgetTester tester) =>
    tester.widget<CupertinoTextField>(find.byType(CupertinoTextField));

String _text(WidgetTester tester) => _field(tester).controller!.text;

Future<void> _blur(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
}

void main() {
  group('input', () {
    testWidgets('reports cents for German notations', (tester) async {
      final reported = <int?>[];
      final inputs = <AmountInput>[];
      await _pump(
        tester,
        AmountField(
          languageCode: 'de',
          onChanged: reported.add,
          onInputChanged: inputs.add,
        ),
      );
      for (final text in ['42,8', '42.80', '1.234,56', '1234,5', '€ 12']) {
        await tester.enterText(find.byType(CupertinoTextField), text);
      }
      expect(reported, [4280, 4280, 123456, 123450, 1200]);

      await tester.enterText(find.byType(CupertinoTextField), '4,567');
      expect(reported.last, isNull);
      expect(inputs.last.isEmpty, isFalse, reason: 'invalid, not empty');

      await tester.enterText(find.byType(CupertinoTextField), '');
      expect(reported.last, isNull);
      expect(inputs.last.isEmpty, isTrue);
    });

    testWidgets('English reads 1,234.56 and the lone comma as thousands', (
      tester,
    ) async {
      final reported = <int?>[];
      await _pump(
        tester,
        AmountField(languageCode: 'en', onChanged: reported.add),
      );
      for (final text in ['1,234.56', '1,234', '42.8']) {
        await tester.enterText(find.byType(CupertinoTextField), text);
      }
      expect(reported, [123456, 123400, 4280]);
    });

    testWidgets('number pad with a decimal key', (tester) async {
      await _pump(tester, AmountField(onChanged: (_) {}));
      expect(
        _field(tester).keyboardType,
        const TextInputType.numberWithOptions(decimal: true),
      );
    });

    testWidgets('letters cannot be typed', (tester) async {
      await _pump(tester, AmountField(languageCode: 'de', onChanged: (_) {}));
      await tester.enterText(find.byType(CupertinoTextField), '4a2,5x');
      expect(_text(tester), '42,5');
    });
  });

  group('currency sign', () {
    testWidgets('German: "42,80 €" after editing, digits while editing', (
      tester,
    ) async {
      final reported = <int?>[];
      await _pump(
        tester,
        AmountField(languageCode: 'de', onChanged: reported.add),
      );
      await tester.tap(find.byType(CupertinoTextField));
      await tester.enterText(find.byType(CupertinoTextField), '42,8');
      await _blur(tester);
      expect(_text(tester), '42,80 €');
      expect(reported, [4280], reason: 'reformatting reports nothing');

      await tester.tap(find.byType(CupertinoTextField));
      await tester.pump();
      expect(_text(tester), '42,80');
    });

    testWidgets('English: sign before the amount', (tester) async {
      await _pump(tester, AmountField(languageCode: 'en', onChanged: (_) {}));
      await tester.tap(find.byType(CupertinoTextField));
      await tester.enterText(find.byType(CupertinoTextField), '1234.5');
      await _blur(tester);
      expect(_text(tester), '€1,234.50');
    });

    testWidgets('an invalid amount is left as typed', (tester) async {
      await _pump(tester, AmountField(languageCode: 'de', onChanged: (_) {}));
      await tester.tap(find.byType(CupertinoTextField));
      await tester.enterText(find.byType(CupertinoTextField), '4,567');
      await _blur(tester);
      expect(_text(tester), '4,567');
    });

    testWidgets('initialCents is shown formatted', (tester) async {
      await _pump(
        tester,
        AmountField(
          languageCode: 'de',
          initialCents: 123456,
          onChanged: (_) {},
        ),
      );
      expect(_text(tester), '1.234,56 €');
    });

    testWidgets('the language comes from the app locale by default', (
      tester,
    ) async {
      // The test harness runs in English.
      await _pump(tester, AmountField(initialCents: 4280, onChanged: (_) {}));
      expect(_text(tester), '€42.80');
    });
  });

  group('variants', () {
    testWidgets('compact: body, tabular, right aligned', (tester) async {
      await _pump(
        tester,
        AmountField(placeholder: 'optional', onChanged: (_) {}),
      );
      final field = _field(tester);
      expect(field.textAlign, TextAlign.end);
      expect(field.style!.fontSize, 17);
      expect(
        field.style!.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      expect(field.placeholder, 'optional');
      expect(field.placeholderStyle!.color, AvoColors.light.placeholder);
      expect(
        tester.getSize(find.byType(AmountField)).height,
        greaterThanOrEqualTo(AvoSizes.hitTarget),
      );
    });

    testWidgets('large: large title style, left aligned', (tester) async {
      await _pump(
        tester,
        AmountField(size: AmountFieldSize.large, onChanged: (_) {}),
      );
      final field = _field(tester);
      expect(field.textAlign, TextAlign.start);
      expect(field.style!.fontSize, 34);
      expect(
        field.style!.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });

    testWidgets('large: never bigger than 51 pt', (tester) async {
      await _pump(
        tester,
        AmountField(size: AmountFieldSize.large, onChanged: (_) {}),
        layout: const LayoutCase(width: 390, scale: 3.1),
      );
      final style = _field(tester).style!;
      final shown = const TextScaler.linear(3.1).scale(style.fontSize!);
      expect(shown, closeTo(51, 0.5));
    });

    testWidgets('no fixed width: fills what it gets', (tester) async {
      await _pump(tester, AmountField(onChanged: (_) {}));
      expect(tester.getSize(find.byType(CupertinoTextField)).width, 390);
    });

    testWidgets('with label: title left, amount right; stacked from xxxL', (
      tester,
    ) async {
      await _pump(tester, AmountField(label: 'Betrag', onChanged: (_) {}));
      expect(
        tester.getRect(find.text('Betrag')).right,
        lessThan(tester.getRect(find.byType(CupertinoTextField)).left + 1),
      );

      await _pump(
        tester,
        AmountField(label: 'Betrag', onChanged: (_) {}),
        layout: const LayoutCase(width: 390, scale: 1.35),
      );
      expect(
        tester.getRect(find.byType(CupertinoTextField)).top,
        greaterThanOrEqualTo(tester.getRect(find.text('Betrag')).bottom),
      );
      expect(_field(tester).textAlign, TextAlign.start);
    });

    testWidgets('tapping the row title focuses the field', (tester) async {
      await _pump(tester, AmountField(label: 'Betrag', onChanged: (_) {}));
      await tester.tap(find.text('Betrag'));
      await tester.pump();
      expect(_field(tester).focusNode!.hasFocus, isTrue);
    });
  });

  group('error and VoiceOver', () {
    testWidgets('errorText: red mark and sentence, announced', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        AmountField(
          label: 'Betrag',
          errorText: 'Gib den Betrag als Zahl ein.',
          onChanged: (_) {},
        ),
      );
      expect(find.text('Gib den Betrag als Zahl ein.'), findsOneWidget);
      final icon = tester.widget<AvoIcon>(find.byType(AvoIcon));
      expect(icon.icon, AvoIcons.exclamationmarkCircle);
      expect(icon.color, AvoColors.light.destructive);
      expect(
        find.semantics.byPredicate(
          (node) =>
              node.label == 'Gib den Betrag als Zahl ein.' &&
              node.flagsCollection.isLiveRegion,
        ),
        findsOne,
      );
      expect(
        find.semantics.byPredicate(
          (node) =>
              node.flagsCollection.isTextField &&
              node.hint.contains('Gib den Betrag als Zahl ein.'),
        ),
        findsOne,
      );
      handle.dispose();
    });

    testWidgets('one text field with label, placeholder and hint', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        AmountField(
          label: 'Betrag',
          placeholder: 'optional',
          semanticHint: 'Für deinen Monatsrückblick.',
          onChanged: (_) {},
        ),
      );
      expect(
        find.semantics.byPredicate(
          (node) =>
              node.flagsCollection.isTextField &&
              node.label.contains('Betrag') &&
              node.hint == 'Für deinen Monatsrückblick.',
        ),
        findsOne,
      );
      handle.dispose();
    });

    testWidgets('disabled: dimmed, no input', (tester) async {
      await _pump(
        tester,
        AmountField(
          enabled: false,
          initialCents: 500,
          languageCode: 'de',
          onChanged: (_) {},
        ),
      );
      expect(_field(tester).enabled, isFalse);
      expect(_field(tester).style!.color, AvoColors.light.secondaryLabel);
    });
  });

  layoutMatrix(
    'AmountField compact in a row',
    (context) => InsetSection(
      children: [
        AmountField(
          label: 'Betrag',
          placeholder: 'optional',
          languageCode: 'de',
          onChanged: (_) {},
        ),
        AmountField(
          label: 'Anteil von Laktosefreie-Bio-Vollmilch-Lena',
          initialCents: 123456,
          languageCode: 'de',
          onChanged: (_) {},
        ),
      ],
    ),
    scrollable: true,
  );

  layoutMatrix(
    'AmountField large with error',
    (context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
      child: AmountField(
        size: AmountFieldSize.large,
        initialCents: 10000000,
        languageCode: 'de',
        errorText:
            'Gib den Betrag als Zahl ein, zum Beispiel 42,80. Höchstens '
            '100.000 €.',
        onChanged: (_) {},
      ),
    ),
    scrollable: true,
  );
}

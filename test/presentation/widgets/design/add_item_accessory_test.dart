import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/common/liquid_glass_container.dart';
import 'package:shoply/presentation/widgets/design/add_item_accessory.dart';
import 'package:shoply/presentation/widgets/design/glass_surface.dart';

import '../../../layout/layout_matrix.dart';

const _placeholder = 'Artikel hinzufügen';
const _price = '≈ 23,80 €';
const _long =
    'Bio-Vollmilch 3,8 % Fett aus der Region, laktosefrei, dazu '
    'Haferflocken, Bananen, Vollkornbrot und Olivenöl für die ganze Woche';

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
        child: Padding(
          padding: const EdgeInsets.all(AvoSpacing.screen),
          child: child,
        ),
      ),
    ),
  );
}

/// The glass behind the capsule (sized like the capsule).
Finder _glass([Type of = AddItemAccessory]) => find
    .descendant(of: find.byType(of), matching: find.byType(GlassSurface))
    .first;

ShapeDecoration _glassDecoration(
  WidgetTester tester, [
  Type of = AddItemAccessory,
]) =>
    tester
            .widget<DecoratedBox>(
              find
                  .descendant(
                    of: _glass(of),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .decoration
        as ShapeDecoration;

Finder get _tintCircles => find.byWidgetPredicate(
  (w) =>
      w is DecoratedBox &&
      w.decoration is ShapeDecoration &&
      (w.decoration as ShapeDecoration).shape is CircleBorder,
);

Finder get _field => find.byType(CupertinoTextField);

void _expectFieldNotClipped(WidgetTester tester, String label) {
  final box = tester.renderObject<RenderBox>(_field);
  final needed = box.getMinIntrinsicHeight(box.size.width);
  expect(
    box.size.height,
    greaterThanOrEqualTo(needed - 0.5),
    reason:
        '$label: field is ${box.size.height.toStringAsFixed(1)} pt tall '
        'but its text needs ${needed.toStringAsFixed(1)} pt',
  );
  final glass = tester.getSize(_glass(AddItemAccessory));
  expect(glass.height, greaterThanOrEqualTo(box.size.height - 0.5));
}

void main() {
  group('AddItemAccessory D2', () {
    testWidgets('glass capsule 52 high, radius 26, translucent glass', (
      tester,
    ) async {
      await _pump(tester, const AddItemAccessory(placeholder: _placeholder));
      expect(tester.getSize(_glass()).height, AvoSizes.accessoryHeight);
      final decoration = _glassDecoration(tester);
      expect(decoration.shape, isA<StadiumBorder>());
      expect(decoration.color, AvoColors.light.glassFill);
    });

    testWidgets('tinted 32 pt plus circle, 10 pt from the leading edge', (
      tester,
    ) async {
      await _pump(tester, const AddItemAccessory(placeholder: _placeholder));
      final circle = tester.getRect(_tintCircles.first);
      final glass = tester.getRect(_glass());
      expect(circle.size, const Size(32, 32));
      expect(circle.left - glass.left, closeTo(10, 0.01));
      expect(circle.center.dy, closeTo(glass.center.dy, 0.01));
      final decoration =
          tester.widget<DecoratedBox>(_tintCircles.first).decoration
              as ShapeDecoration;
      expect(decoration.color, AvoColors.light.glassTintFill);
    });

    testWidgets('field 17/22, placeholder in the placeholder colour', (
      tester,
    ) async {
      await _pump(tester, const AddItemAccessory(placeholder: _placeholder));
      final style = tester.widget<CupertinoTextField>(_field).style!;
      expect(style.fontSize, 17);
      expect(style.fontSize! * style.height!, closeTo(22, 0.01));
      final hint = tester.widget<Text>(find.text(_placeholder)).style!;
      expect(hint.fontSize, 17);
      expect(hint.color, AvoColors.light.placeholder);
    });

    testWidgets('mic: 44 pt, labelled, runs onDictate; price 13/18 semibold', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var dictated = 0;
      await _pump(
        tester,
        AddItemAccessory(
          placeholder: _placeholder,
          onDictate: () => dictated++,
          trailingText: _price,
        ),
      );
      final mic = find.bySemanticsLabel('Add by voice');
      expect(mic, findsOneWidget);
      expect(tester.getSize(mic), const Size(44, 44));
      await tester.tap(mic);
      expect(dictated, 1);

      final price = tester.widget<Text>(find.text(_price)).style!;
      expect(price.fontSize, 13);
      expect(price.fontWeight, FontWeight.w600);
      expect(price.fontFeatures, contains(const FontFeature.tabularFigures()));
      final priceRect = tester.getRect(find.text(_price));
      final glass = tester.getRect(_glass());
      expect(priceRect.right, closeTo(glass.right - 14, 0.5));
      expect(tester.getRect(mic).right, lessThan(priceRect.left));
      handle.dispose();
    });

    testWidgets('no mic without onDictate', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const AddItemAccessory(placeholder: _placeholder));
      expect(find.bySemanticsLabel('Add by voice'), findsNothing);
      handle.dispose();
    });

    testWidgets('price moves under the field when the field would be narrow', (
      tester,
    ) async {
      await _pump(
        tester,
        AddItemAccessory(
          placeholder: _placeholder,
          onDictate: () {},
          trailingText: _price,
        ),
        layout: const LayoutCase(width: 320, scale: 1),
      );
      final field = tester.getRect(_field);
      final price = tester.getRect(find.text(_price));
      expect(price.top, greaterThanOrEqualTo(field.bottom - 0.5));
      // Two rows: the glass becomes a rounded rectangle.
      final shape = _glassDecoration(tester).shape as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(26));
    });
  });

  group('AddItemAccessory behaviour', () {
    testWidgets('Return submits the trimmed text, keeps text and focus', (
      tester,
    ) async {
      final submitted = <String>[];
      final controller = TextEditingController();
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      await _pump(
        tester,
        AddItemAccessory(
          placeholder: _placeholder,
          controller: controller,
          focusNode: focus,
          onSubmitted: submitted.add,
        ),
      );
      await tester.showKeyboard(_field);
      await tester.enterText(_field, '  2 Milch ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(submitted, ['2 Milch']);
      expect(controller.text, '  2 Milch ', reason: 'the caller clears');
      expect(focus.hasFocus, isTrue, reason: 'keeps the keyboard up');
    });

    testWidgets('Return with only spaces does not submit', (tester) async {
      final submitted = <String>[];
      await _pump(
        tester,
        AddItemAccessory(placeholder: _placeholder, onSubmitted: submitted.add),
      );
      await tester.showKeyboard(_field);
      await tester.enterText(_field, '   ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(submitted, isEmpty);
    });

    testWidgets('plus is decorative when empty, "Add" button with text', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final submitted = <String>[];
      await _pump(
        tester,
        AddItemAccessory(placeholder: _placeholder, onSubmitted: submitted.add),
      );
      expect(find.bySemanticsLabel('Add'), findsNothing);
      await tester.enterText(_field, 'Hafermilch');
      await tester.pump();
      final add = find.bySemanticsLabel('Add');
      expect(add, findsOneWidget);
      expect(tester.getSize(add), const Size(44, 44));
      await tester.tap(add);
      await tester.pump();
      expect(submitted, ['Hafermilch']);
      expect(find.text('Hafermilch'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('custom submit label', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        AddItemAccessory(
          placeholder: _placeholder,
          submitLabel: 'Auf die Liste',
          controller: TextEditingController(text: 'Eier'),
        ),
      );
      expect(find.bySemanticsLabel('Auf die Liste'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('placeholder hides with text, returns when cleared', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await _pump(
        tester,
        AddItemAccessory(placeholder: _placeholder, controller: controller),
      );
      expect(find.text(_placeholder), findsOneWidget);
      controller.text = 'Eier';
      await tester.pump();
      expect(find.text(_placeholder), findsNothing);
      controller.clear();
      await tester.pump();
      expect(find.text(_placeholder), findsOneWidget);
    });

    testWidgets('tapping the capsule beside the text focuses the field', (
      tester,
    ) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await _pump(
        tester,
        AddItemAccessory(
          placeholder: _placeholder,
          focusNode: focus,
          trailingText: _price,
        ),
      );
      final glass = tester.getRect(_glass());
      // On the price, which is not part of the field.
      await tester.tap(find.text(_price));
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      expect(glass.height, AvoSizes.accessoryHeight);
    });

    testWidgets('onChanged reports every edit', (tester) async {
      final changes = <String>[];
      await _pump(
        tester,
        AddItemAccessory(placeholder: _placeholder, onChanged: changes.add),
      );
      await tester.enterText(_field, 'Mi');
      expect(changes.last, 'Mi');
    });

    testWidgets('grows to three lines, then scrolls; then a 26 pt rectangle', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await _pump(
        tester,
        AddItemAccessory(placeholder: _placeholder, controller: controller),
      );
      controller.text = 'Milch';
      await tester.pump();
      expect(tester.getSize(_field).height, 52);
      expect(_glassDecoration(tester).shape, isA<StadiumBorder>());

      controller.text = '$_long $_long';
      await tester.pump();
      expect(tester.getSize(_field).height, closeTo(3 * 22 + 30, 0.5));
      final shape = _glassDecoration(tester).shape as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(26));
      expect(tester.getSize(_glass()).height, closeTo(96, 0.5));
    });

    testWidgets('maxLines is honoured', (tester) async {
      await _pump(
        tester,
        AddItemAccessory(
          placeholder: _placeholder,
          maxLines: 1,
          controller: TextEditingController(text: _long),
        ),
      );
      expect(tester.getSize(_field).height, 52);
    });

    testWidgets('AX5: at most two lines, never shorter than its text', (
      tester,
    ) async {
      await _pump(
        tester,
        AddItemAccessory(
          placeholder: _placeholder,
          controller: TextEditingController(text: _long),
        ),
        layout: const LayoutCase(width: 390, scale: 3.1),
      );
      final line = AvoTypography.forFactor(3.1).lineHeightOf(AvoTextStyle.body);
      expect(tester.getSize(_field).height, closeTo(2 * line + 30, 0.5));
      _expectFieldNotClipped(tester, 'AX5');
    });

    testWidgets('above: the panel sits 8 pt above the capsule', (tester) async {
      await _pump(
        tester,
        const AddItemAccessory(
          placeholder: _placeholder,
          above: SizedBox(key: Key('panel'), height: 120),
        ),
      );
      final panel = tester.getRect(find.byKey(const Key('panel')));
      final glass = tester.getRect(_glass());
      expect(glass.top - panel.bottom, closeTo(8, 0.01));
      expect(panel.width, glass.width);
    });

    testWidgets('leading replaces the plus circle', (tester) async {
      await _pump(
        tester,
        const AddItemAccessory(
          placeholder: 'Zettel wird gelesen …',
          leading: CupertinoActivityIndicator(),
        ),
      );
      expect(_tintCircles, findsNothing);
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    });

    testWidgets('VoiceOver: field labelled with placeholder and hint', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        const AddItemAccessory(
          placeholder: _placeholder,
          semanticHint: 'Zum Beispiel 2 Milch',
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel(_placeholder)),
        isSemantics(
          isTextField: true,
          hint: 'Zum Beispiel 2 Milch',
          label: _placeholder,
        ),
      );
      handle.dispose();
    });

    testWidgets('dark mode uses the dark glass token', (tester) async {
      await _pump(
        tester,
        const AddItemAccessory(placeholder: _placeholder),
        layout: const LayoutCase(
          width: 390,
          scale: 1,
          brightness: Brightness.dark,
        ),
      );
      await tester.pumpAndSettle();
      expect(_glassDecoration(tester).color, AvoColors.dark.glassFill);
    });

    testWidgets('Increase Contrast: opaque glass and tint circle', (
      tester,
    ) async {
      await _pump(
        tester,
        const AddItemAccessory(placeholder: _placeholder),
        layout: const LayoutCase(width: 390, scale: 1, highContrast: true),
      );
      expect(
        _glassDecoration(tester).color,
        AvoColors.lightHighContrast.glassFallback,
      );
      final circle =
          tester.widget<DecoratedBox>(_tintCircles.first).decoration
              as ShapeDecoration;
      expect(circle.color, AvoColors.lightHighContrast.tintFill);
    });
  });

  group('AccessoryDock', () {
    Future<Rect> dock(
      WidgetTester tester, {
      double keyboard = 0,
      bool aboveTabBar = true,
    }) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: const Size(390, 844),
            padding: const EdgeInsets.only(top: 47, bottom: 34),
            viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
            viewInsets: EdgeInsets.only(bottom: keyboard),
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(
              children: [
                AccessoryDock(
                  aboveTabBar: aboveTabBar,
                  child: const SizedBox(key: Key('acc'), height: 52),
                ),
              ],
            ),
          ),
        ),
      );
      return tester.getRect(find.byKey(const Key('acc')));
    }

    testWidgets('above the tab bar: bottom at 96 pt, 16 pt sides (D2)', (
      tester,
    ) async {
      final rect = await dock(tester);
      expect(844 - rect.bottom, 96);
      expect(rect.left, 16);
      expect(rect.right, 390 - 16);
    });

    testWidgets('8 pt above the keyboard while it is open', (tester) async {
      final rect = await dock(tester, keyboard: 336);
      expect(844 - rect.bottom, 344);
    });

    testWidgets('without tab bar: 8 pt above the home indicator', (
      tester,
    ) async {
      final rect = await dock(tester, aboveTabBar: false);
      expect(844 - rect.bottom, 42);
    });
  });

  group('AvoComposerField', () {
    Widget composer({
      TextEditingController? controller,
      ValueChanged<String>? onSubmitted,
      VoidCallback? onVoice,
      VoidCallback? onCamera,
    }) => AvoComposerField(
      placeholder: 'Frag Avo oder suche',
      shortPlaceholder: 'Frag Avo',
      sendLabel: 'Senden',
      voiceLabel: 'Sprachmodus starten',
      cameraLabel: 'Foto aufnehmen',
      controller: controller,
      onSubmitted: onSubmitted,
      onVoice: onVoice,
      onCamera: onCamera ?? () {},
    );

    testWidgets(
      'D2: camera left, tinted 40 pt voice circle 6 pt from the end',
      (tester) async {
        final handle = tester.ensureSemantics();
        var photos = 0;
        await _pump(tester, composer(onCamera: () => photos++, onVoice: () {}));
        final glass = tester.getRect(_glass(AvoComposerField));
        expect(glass.height, 52);
        final camera = find.bySemanticsLabel('Foto aufnehmen');
        expect(tester.getSize(camera), const Size(44, 44));
        // D2: 32 wide button 14 from the edge; its 44 pt target overlaps by 6.
        expect(tester.getRect(camera).left - glass.left, closeTo(8, 0.01));
        await tester.tap(camera);
        expect(photos, 1);
        final circle = tester.getRect(_tintCircles.first);
        expect(circle.size, const Size(40, 40));
        expect(glass.right - circle.right, closeTo(6, 0.01));
        handle.dispose();
      },
    );

    testWidgets('voice while empty, "Senden" with text', (tester) async {
      final handle = tester.ensureSemantics();
      var voice = 0;
      final sent = <String>[];
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await _pump(
        tester,
        composer(
          controller: controller,
          onVoice: () => voice++,
          onSubmitted: sent.add,
        ),
      );
      await tester.tap(find.bySemanticsLabel('Sprachmodus starten'));
      expect(voice, 1);
      expect(find.bySemanticsLabel('Senden'), findsNothing);

      controller.text = 'Was koche ich mit Feta?';
      await tester.pumpAndSettle();
      final send = find.bySemanticsLabel('Senden');
      expect(send, findsOneWidget);
      await tester.tap(send);
      expect(sent, ['Was koche ich mit Feta?']);
      expect(voice, 1);
      expect(controller.text, 'Was koche ich mit Feta?');
      handle.dispose();
    });

    testWidgets('Return sends', (tester) async {
      final sent = <String>[];
      await _pump(tester, composer(onSubmitted: sent.add));
      await tester.showKeyboard(_field);
      await tester.enterText(_field, 'Plan für Freitag');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
      expect(sent, ['Plan für Freitag']);
    });

    testWidgets('without onVoice the empty button is dimmed', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, composer());
      expect(
        tester.getSemantics(find.bySemanticsLabel('Sprachmodus starten')),
        isSemantics(isButton: true, isEnabled: false, hasEnabledState: true),
      );
      handle.dispose();
    });

    testWidgets('the glyph swap springs: arrow grows from 0.6', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await _pump(tester, composer(controller: controller, onVoice: () {}));
      controller.text = 'Feta';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final scales = tester
          .widgetList<Transform>(
            find.descendant(
              of: _tintCircles.first,
              matching: find.byType(Transform),
            ),
          )
          .map((t) => t.transform.storage[0])
          .toList();
      expect(scales.any((s) => s > 0.6 && s < 1), isTrue);
      await tester.pumpAndSettle();
    });

    testWidgets('Reduce Motion: the glyphs cross-fade without scaling', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await _pump(
        tester,
        composer(controller: controller, onVoice: () {}),
        layout: const LayoutCase(width: 390, scale: 1, reduceMotion: true),
      );
      controller.text = 'Feta';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final scales = tester
          .widgetList<Transform>(
            find.descendant(
              of: _tintCircles.first,
              matching: find.byType(Transform),
            ),
          )
          .map((t) => t.transform.storage[0]);
      expect(scales, everyElement(1.0));
      await tester.pumpAndSettle();
    });

    testWidgets('short placeholder from AX1, full label for VoiceOver', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        composer(),
        layout: const LayoutCase(width: 390, scale: 2),
      );
      expect(find.text('Frag Avo'), findsOneWidget);
      expect(find.bySemanticsLabel('Frag Avo oder suche'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('no camera without onCamera', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        const AvoComposerField(
          placeholder: 'Suchen',
          sendLabel: 'Senden',
          voiceLabel: 'Sprachmodus starten',
        ),
      );
      expect(find.bySemanticsLabel('Foto aufnehmen'), findsNothing);
      handle.dispose();
    });
  });

  // A3: the old composer clipped its text on iOS (320 pt display zoom and
  // larger text sizes). Same cases on the native glass path here.
  group('A3 regression on the iOS glass path', () {
    final iOS = TargetPlatformVariant.only(TargetPlatform.iOS);
    for (final width in kLayoutWidths) {
      for (final scale in kLayoutTextScales) {
        final layout = LayoutCase(width: width, scale: scale);
        testWidgets('placeholder fits at $width pt, text x$scale', (
          tester,
        ) async {
          await _pump(
            tester,
            AddItemAccessory(
              placeholder: _placeholder,
              onDictate: () {},
              trailingText: _price,
            ),
            layout: layout,
          );
          expect(
            find.byType(LiquidGlassContainer),
            findsOneWidget,
            reason: 'the iOS glass path must be the one under test',
          );
          _expectFieldNotClipped(tester, 'empty');
          expectNoClippedText(tester, reason: 'empty at $layout');
          expect(tester.takeException(), isNull);
        }, variant: iOS);

        testWidgets('long entry wraps instead of clipping at $width pt, '
            'text x$scale', (tester) async {
          await _pump(
            tester,
            AddItemAccessory(
              placeholder: _placeholder,
              onDictate: () {},
              trailingText: _price,
              controller: TextEditingController(
                text:
                    'Laktosefreie Bio-Vollmilch 3,8 % für den Kaffee am Morgen',
              ),
            ),
            layout: layout,
          );
          _expectFieldNotClipped(tester, 'long text');
          expectNoClippedText(tester, reason: 'long at $layout');
          expect(tester.takeException(), isNull);
        }, variant: iOS);
      }
    }
  });

  layoutMatrix(
    'AddItemAccessory empty, mic and price',
    (context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
      child: AddItemAccessory(
        placeholder: _placeholder,
        onDictate: () {},
        trailingText: _price,
      ),
    ),
    checkTapTargets: true,
  );

  layoutMatrix(
    'AddItemAccessory long entry',
    (context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
      child: AddItemAccessory(
        placeholder: _placeholder,
        onDictate: () {},
        trailingText: _price,
        controller: TextEditingController(text: _long),
      ),
    ),
    checkTapTargets: true,
  );

  layoutMatrix(
    'AddItemAccessory with suggestion panel above',
    (context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
      child: AddItemAccessory(
        placeholder: _placeholder,
        controller: TextEditingController(text: '2 Paprika'),
        above: ColoredBox(
          color: context.colors.surface,
          child: Padding(
            padding: const EdgeInsets.all(AvoSpacing.l),
            child: Text(
              'Paprika · Menge 2 · Obst & Gemüse',
              style: context.text(AvoTextStyle.body),
            ),
          ),
        ),
      ),
    ),
  );

  layoutMatrix(
    'AvoComposerField empty',
    (context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
      child: AvoComposerField(
        placeholder: 'Frag Avo oder suche',
        shortPlaceholder: 'Frag Avo',
        sendLabel: 'Senden',
        voiceLabel: 'Sprachmodus starten',
        cameraLabel: 'Foto aufnehmen',
        onCamera: () {},
        onVoice: () {},
      ),
    ),
    checkTapTargets: true,
  );

  layoutMatrix(
    'AvoComposerField long question',
    (context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
      child: AvoComposerField(
        placeholder: 'Frag Avo oder suche',
        sendLabel: 'Senden',
        voiceLabel: 'Sprachmodus starten',
        cameraLabel: 'Foto aufnehmen',
        onCamera: () {},
        onVoice: () {},
        controller: TextEditingController(
          text:
              'Setz die Zutaten für Ofengemüse mit Feta auf die Liste, '
              'für 4 Personen, und sag mir, was bei Lidl im Angebot ist.',
        ),
      ),
    ),
    checkTapTargets: true,
  );
}

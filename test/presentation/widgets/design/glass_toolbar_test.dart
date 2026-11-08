import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/glass_icon_button.dart';
import 'package:shoply/presentation/widgets/design/glass_toolbar.dart';

import '../../../layout/layout_matrix.dart';

Widget _harness(
  Widget child, {
  double textScale = 1,
  TextDirection direction = TextDirection.ltr,
  Brightness brightness = Brightness.light,
}) {
  return MediaQuery(
    data: MediaQueryData(
      size: const Size(390, 844),
      textScaler: TextScaler.linear(textScale),
      platformBrightness: brightness,
    ),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: brightness),
      home: Directionality(
        textDirection: direction,
        child: AvoDesignScope(
          reduceTransparencyOverride: false,
          child: Builder(
            builder: (context) => ColoredBox(
              color: context.colors.background,
              child: Align(alignment: Alignment.topCenter, child: child),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Sizes the test view like a 390 pt iPhone.
void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _back({VoidCallback? onPressed}) => GlassIconButton(
  icon: const Icon(CupertinoIcons.chevron_back),
  semanticLabel: 'Zurück zu Wocheneinkauf',
  onPressed: onPressed ?? () {},
);

void main() {
  group('GlassToolbar', () {
    testWidgets('topOffset is the status bar inset plus 7 (D2: 54 at 47)', (
      tester,
    ) async {
      _phone(tester);
      late double offset;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(top: 47)),
          child: Builder(
            builder: (context) {
              offset = GlassToolbar.topOffset(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(offset, 54);
    });

    testWidgets('44 pt high, 16 pt side margins, title 17/22 semibold', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _harness(
          GlassToolbar(
            leading: _back(),
            title: 'Artikel',
            trailing: [
              AppButton.primary(
                label: 'Fertig',
                floating: true,
                onPressed: () {},
              ),
            ],
          ),
        ),
      );

      final bar = tester.getRect(find.byType(GlassToolbar));
      expect(bar.height, 44);
      expect(tester.getTopLeft(find.byType(GlassIconButton)).dx, 16);
      expect(tester.getTopRight(find.byType(AppButton)).dx, bar.right - 16);
      final style = tester.widget<Text>(find.text('Artikel')).style!;
      expect(style.fontSize, 17);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.color, AvoColors.light.label);
    });

    testWidgets('title is centred on the screen, not between the items', (
      tester,
    ) async {
      _phone(tester);
      await loadLayoutFonts(); // real SF widths, as on the device
      await tester.pumpWidget(
        _harness(
          GlassToolbar(
            leading: _back(),
            title: 'Artikel',
            trailing: [
              AppButton.primary(
                label: 'Fertig',
                floating: true,
                onPressed: () {},
              ),
            ],
          ),
        ),
      );

      final bar = tester.getRect(find.byType(GlassToolbar));
      expect(tester.getCenter(find.text('Artikel')).dx, bar.center.dx);
    });

    testWidgets('long title gives way and ends in an ellipsis', (tester) async {
      _phone(tester);
      const title = 'Laktosefreie Bio-Vollmilch und Haferdrink im Angebot';
      await tester.pumpWidget(
        _harness(
          GlassToolbar(
            leading: _back(),
            title: title,
            trailing: [
              AppButton.primary(
                label: 'Fertig',
                floating: true,
                onPressed: () {},
              ),
            ],
          ),
        ),
      );

      final text = tester.widget<Text>(find.text(title));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
      final titleRect = tester.getRect(find.text(title));
      expect(
        titleRect.left,
        greaterThanOrEqualTo(
          tester.getRect(find.byType(GlassIconButton)).right + 8,
        ),
      );
      expect(
        titleRect.right,
        lessThanOrEqualTo(tester.getRect(find.byType(AppButton)).left - 8),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('title is a VoiceOver header; items keep their actions', (
      tester,
    ) async {
      _phone(tester);
      var back = 0;
      var done = 0;
      await tester.pumpWidget(
        _harness(
          GlassToolbar(
            leading: _back(onPressed: () => back++),
            title: 'Artikel',
            trailing: [
              AppButton.primary(
                label: 'Fertig',
                floating: true,
                onPressed: () => done++,
              ),
            ],
          ),
        ),
      );

      expect(
        tester.getSemantics(find.text('Artikel')),
        isSemantics(label: 'Artikel', isHeader: true),
      );
      await tester.tap(find.byType(GlassIconButton));
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();
      expect(back, 1);
      expect(done, 1);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    });

    testWidgets('trailing items are 8 pt apart', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _harness(
          GlassToolbar(
            trailing: [
              GlassButtonGroup(
                items: [
                  GlassGroupItem(
                    icon: const Icon(CupertinoIcons.share),
                    semanticLabel: 'Teilen',
                    onPressed: () {},
                  ),
                  GlassGroupItem(
                    icon: const Icon(CupertinoIcons.ellipsis),
                    semanticLabel: 'Mehr',
                    onPressed: () {},
                  ),
                ],
              ),
              GlassIconButton(
                icon: const Icon(CupertinoIcons.add),
                semanticLabel: 'Neue Liste',
                tinted: true,
                onPressed: () {},
              ),
            ],
          ),
        ),
      );

      final group = tester.getRect(find.byType(GlassButtonGroup));
      final plus = tester.getRect(find.byType(GlassIconButton));
      expect(plus.left - group.right, 8);
      expect(plus.right, 390 - 16);
    });

    testWidgets('right-to-left mirrors leading and trailing', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _harness(
          GlassToolbar(
            leading: _back(),
            title: 'Artikel',
            trailing: [
              AppButton.primary(
                label: 'Fertig',
                floating: true,
                onPressed: () {},
              ),
            ],
          ),
          direction: TextDirection.rtl,
        ),
      );

      expect(tester.getTopRight(find.byType(GlassIconButton)).dx, 390 - 16);
      expect(tester.getTopLeft(find.byType(AppButton)).dx, 16);
    });

    testWidgets('grows with large text instead of clipping the title', (
      tester,
    ) async {
      _phone(tester);
      await loadLayoutFonts();
      await tester.pumpWidget(
        _harness(
          GlassToolbar(leading: _back(), title: 'Artikel'),
          textScale: 3.1,
        ),
      );

      expect(tester.takeException(), isNull);
      expectNoClippedText(tester);
      expect(tester.getSize(find.byType(GlassToolbar)).height, greaterThan(44));
    });

    testWidgets('squeezed title moves below the buttons (AX5, 320 pt)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await loadLayoutFonts();
      await tester.pumpWidget(
        _harness(
          GlassToolbar(
            leading: _back(),
            title: 'Artikel',
            trailing: [AppButton.primary(label: 'Fertig', onPressed: () {})],
          ),
          textScale: 3.1,
        ),
      );

      expect(tester.takeException(), isNull);
      final title = tester.getRect(find.text('Artikel'));
      expect(title.width, greaterThan(80));
      expect(
        title.top,
        greaterThan(tester.getRect(find.text('Fertig')).bottom),
      );
    });
  });

  group('ScrollEdgeFade', () {
    testWidgets('110 pt fade from the background (solid to 30 %)', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_harness(const ScrollEdgeFade()));

      expect(tester.getSize(find.byType(ScrollEdgeFade)), const Size(390, 110));
      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(ScrollEdgeFade),
          matching: find.byType(DecoratedBox),
        ),
      );
      final gradient =
          (box.decoration as BoxDecoration).gradient! as LinearGradient;
      expect(gradient.colors.first, AvoColors.light.background);
      expect(
        gradient.colors.last,
        AvoColors.light.background.withValues(alpha: 0),
      );
      expect(gradient.stops, [0.3, 1]);
      expect(gradient.begin, Alignment.topCenter);
    });

    testWidgets('dark mode and a custom colour', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _harness(const ScrollEdgeFade(), brightness: Brightness.dark),
      );
      var box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(ScrollEdgeFade),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect(
        ((box.decoration as BoxDecoration).gradient! as LinearGradient)
            .colors
            .first,
        AvoColors.dark.background,
      );

      await tester.pumpWidget(
        _harness(
          Builder(
            builder: (context) => ScrollEdgeFade(
              height: 104,
              color: context.colors.backgroundPlain,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(ScrollEdgeFade),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect(
        ((box.decoration as BoxDecoration).gradient! as LinearGradient)
            .colors
            .first,
        AvoColors.light.backgroundPlain,
      );
      expect(tester.getSize(find.byType(ScrollEdgeFade)).height, 104);
    });

    testWidgets('lets touches through and is hidden from VoiceOver', (
      tester,
    ) async {
      _phone(tester);
      var taps = 0;
      await tester.pumpWidget(
        _harness(
          SizedBox(
            height: 200,
            child: Stack(
              children: [
                Positioned(
                  top: 20,
                  left: 20,
                  child: GestureDetector(
                    onTap: () => taps++,
                    child: const Text('Hafermilch'),
                  ),
                ),
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: ScrollEdgeFade(),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('Hafermilch'), warnIfMissed: false);
      expect(taps, 1);
      expect(
        find.descendant(
          of: find.byType(ScrollEdgeFade),
          matching: find.byWidgetPredicate(
            (w) => w is ExcludeSemantics && w.excluding,
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(ScrollEdgeFade),
          matching: find.byWidgetPredicate(
            (w) => w is IgnorePointer && w.ignoring,
          ),
        ),
        findsOneWidget,
      );
      // The text underneath is still readable for VoiceOver.
      expect(find.bySemanticsLabel('Hafermilch'), findsOneWidget);
    });
  });

  layoutMatrix(
    'GlassToolbar (Artikel)',
    (context) => Padding(
      padding: EdgeInsets.only(top: GlassToolbar.topOffset(context)),
      child: GlassToolbar(
        leading: _back(),
        title: 'Laktosefreie Bio-Vollmilch',
        trailing: [
          AppButton.primary(label: 'Fertig', floating: true, onPressed: () {}),
        ],
      ),
    ),
    checkTapTargets: true,
  );

  layoutMatrix(
    'GlassToolbar (Liste, ohne Titel)',
    (context) => Padding(
      padding: EdgeInsets.only(top: GlassToolbar.topOffset(context)),
      child: GlassToolbar(
        leading: _back(),
        trailing: [
          GlassButtonGroup(
            items: [
              GlassGroupItem(
                icon: const Icon(CupertinoIcons.share),
                semanticLabel: 'Teilen',
                onPressed: () {},
              ),
              GlassGroupItem(
                icon: const Icon(CupertinoIcons.ellipsis),
                semanticLabel: 'Mehr',
                onPressed: () {},
              ),
            ],
          ),
          GlassIconButton(
            icon: const Icon(CupertinoIcons.add),
            semanticLabel: 'Neue Liste',
            tinted: true,
            onPressed: () {},
          ),
        ],
      ),
    ),
    checkTapTargets: true,
  );

  layoutMatrix(
    'ScrollEdgeFade',
    (context) => Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 106, 16, 0),
          child: Text(
            'Wocheneinkauf · 12 Artikel · 23,80 €',
            style: context.text(AvoTextStyle.largeTitle),
          ),
        ),
        const Positioned(top: 0, left: 0, right: 0, child: ScrollEdgeFade()),
      ],
    ),
  );
}

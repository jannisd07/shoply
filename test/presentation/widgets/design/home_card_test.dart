import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/home_card.dart';

import '../../../layout/layout_matrix.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  LayoutCase layout = const LayoutCase(width: 390, scale: 1),
}) async {
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

Widget _value(BuildContext context, String text) =>
    Text(text, style: context.text(AvoTextStyle.headline));

Widget _tiles(BuildContext context) => AvoTileGrid(children: [
      AvoTile(
        title: 'Weiter einkaufen',
        icon: const SizedBox.square(dimension: 18),
        onTap: () {},
        child: _value(context, 'Wocheneinkauf für das lange Wochenende'),
      ),
      AvoTile(
        title: 'Nochmal kaufen',
        trailing: const SizedBox.square(dimension: AvoSizes.hitTarget),
        child: _value(context, 'Hafermilch, Eier, Bananen'),
      ),
      AvoTile(
        title: 'Angebote in deiner Region',
        child: _value(context, '5'),
      ),
    ]);

void main() {
  testWidgets('D2 card: surface, radius 26, faint shadow, 16 padding',
      (tester) async {
    await _pump(tester, const AvoCard(child: Text('Inhalt')));
    final box = tester.widget<DecoratedBox>(find.descendant(
      of: find.byType(AvoCard),
      matching: find.byType(DecoratedBox),
    ));
    final decoration = box.decoration as BoxDecoration;
    expect(decoration.color, AvoColors.light.surface);
    expect(decoration.borderRadius, BorderRadius.circular(26));
    expect(decoration.boxShadow!.single.blurRadius, 2);
    expect(decoration.gradient, isNull);
    final padding = tester.widget<Padding>(find.descendant(
      of: find.byType(AvoCard),
      matching: find.byType(Padding),
    ));
    expect(padding.padding, const EdgeInsets.all(16));
  });

  testWidgets('tint tone starts with the soft green', (tester) async {
    await _pump(
      tester,
      const AvoCard(tone: AvoCardTone.tint, child: Text('Avo')),
    );
    final box = tester.widget<DecoratedBox>(find.descendant(
      of: find.byType(AvoCard),
      matching: find.byType(DecoratedBox),
    ));
    final gradient =
        (box.decoration as BoxDecoration).gradient! as LinearGradient;
    expect(gradient.colors.first, AvoColors.light.tintSoft);
    expect(gradient.colors.last, AvoColors.light.surface);
  });

  testWidgets('a tappable card is one button with its label', (tester) async {
    var taps = 0;
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      AvoCard(
        onTap: () => taps++,
        semanticLabel: 'Dein November, 183,40 Euro',
        child: const Text('Dein November'),
      ),
    );
    await tester.tap(find.byType(AvoCard));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(
      tester.getSemantics(find.byType(AvoCard)),
      matchesSemantics(
        label: 'Dein November, 183,40 Euro',
        isButton: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('tiles: at least 148 tall, rows share the tallest height',
      (tester) async {
    await _pump(tester, Builder(builder: _tiles));
    final first = tester.getSize(find.byType(AvoTile).at(0));
    final second = tester.getSize(find.byType(AvoTile).at(1));
    expect(first.height, greaterThanOrEqualTo(148));
    expect(first.height, second.height);
    // Two per row: the third tile starts below the first.
    final third = tester.getTopLeft(find.byType(AvoTile).at(2));
    expect(third.dy, greaterThan(tester.getTopLeft(find.byType(AvoTile).at(0)).dy));
    expect(third.dx, tester.getTopLeft(find.byType(AvoTile).at(0)).dx);
  });

  testWidgets('tiles stack one per row at accessibility sizes',
      (tester) async {
    await _pump(
      tester,
      const SingleChildScrollView(child: Builder(builder: _tiles)),
      layout: const LayoutCase(width: 390, scale: 2),
    );
    final a = tester.getTopLeft(find.byType(AvoTile).at(0));
    final b = tester.getTopLeft(find.byType(AvoTile).at(1));
    expect(b.dx, a.dx);
    expect(b.dy, greaterThan(a.dy));
  });

  testWidgets('section header: heading, 15/20 tint action, 44 pt target',
      (tester) async {
    var taps = 0;
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      AvoSectionHeader('Top-Listen', actionLabel: 'Alle', onAction: () => taps++),
    );
    final title = tester.widget<Text>(find.text('Top-Listen')).style!;
    expect(title.fontSize, 20);
    expect(title.fontWeight, FontWeight.w600);
    final action = tester.widget<Text>(find.text('Alle')).style!;
    expect(action.fontSize, 15);
    expect(action.color, AvoColors.light.tint);
    expect(
      tester.getSize(find.ancestor(
        of: find.text('Alle'),
        matching: find.byType(ConstrainedBox),
      ).first).height,
      greaterThanOrEqualTo(44),
    );
    expect(
      tester.getSemantics(find.text('Top-Listen')),
      matchesSemantics(label: 'Top-Listen', isHeader: true),
    );
    await tester.tap(find.text('Alle'));
    await tester.pumpAndSettle();
    expect(taps, 1);
    handle.dispose();
  });

  layoutMatrix(
    'AvoCard',
    (context) => Padding(
      padding: const EdgeInsets.all(AvoSpacing.screen),
      child: AvoCard(
        tone: AvoCardTone.tint,
        child: Text(
          'Hey Jannis! Lidl lohnt sich diese Woche, drei Artikel deiner Liste '
          'sind dort im Angebot.',
          style: context.text(AvoTextStyle.body),
        ),
      ),
    ),
    scrollable: true,
  );
  layoutMatrix(
    'AvoTileGrid',
    (context) => Padding(
      padding: const EdgeInsets.all(AvoSpacing.screen),
      child: _tiles(context),
    ),
    scrollable: true,
  );
  layoutMatrix(
    'AvoSectionHeader',
    (context) => AvoSectionHeader(
      'Letzte Einkäufe in deiner Nähe',
      actionLabel: 'Alle anzeigen',
      onAction: () {},
    ),
  );
}

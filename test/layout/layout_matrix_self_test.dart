import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';

import 'layout_matrix.dart';

/// The matrix must catch what it promises to catch.
void main() {
  Future<void> pump(WidgetTester tester, LayoutCase c, Widget child) async {
    await loadLayoutFonts();
    tester.view.physicalSize = Size(c.width * 3, kLayoutHeight * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(layoutHarness(c, child));
  }

  testWidgets('detects text cut by a fixed height (the A3 bug)',
      (tester) async {
    await pump(
      tester,
      const LayoutCase(width: 390, scale: 1.35),
      const Align(
        alignment: Alignment.topLeft,
        child: SizedBox(height: 20, child: Text('Artikel hinzufügen')),
      ),
    );
    expect(() => expectNoClippedText(tester), throwsA(isA<TestFailure>()));
  });

  testWidgets('detects a row overflow', (tester) async {
    await pump(
      tester,
      const LayoutCase(width: 320, scale: 3.1),
      const Align(
        alignment: Alignment.topLeft,
        child: Row(children: [Text('Wocheneinkauf mit Lena und Max')]),
      ),
    );
    expect(tester.takeException(), isNotNull);
  });

  testWidgets('passes text that may grow', (tester) async {
    await pump(
      tester,
      const LayoutCase(width: 320, scale: 3.1, bold: true),
      Builder(
        builder: (context) => Align(
          alignment: Alignment.topLeft,
          child: Text('Artikel hinzufügen',
              style: context.text(AvoTextStyle.body)),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expectNoClippedText(tester);
  });

  // The helper itself, on a trivially safe widget.
  layoutMatrix(
    'plain body text',
    (context) => Padding(
      padding: const EdgeInsets.all(AvoSpacing.screen),
      child: Text('Noch nichts auf der Liste.',
          style: context.text(AvoTextStyle.body)),
    ),
    cases: const [
      LayoutCase(width: 320, scale: 3.1, bold: true),
      LayoutCase(width: 440, scale: 1.0, brightness: Brightness.dark),
    ],
  );
}

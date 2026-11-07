import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/avo_figure.dart';

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
    layoutHarness(layout, Align(alignment: Alignment.topCenter, child: child)),
  );
}

String? _assetName(Image image) {
  var provider = image.image;
  if (provider is ResizeImage) provider = provider.imageProvider;
  return provider is AssetImage ? provider.assetName : null;
}

void main() {
  test('every pose has its asset on disk', () {
    for (final pose in AvoPose.values) {
      final path = AvoFigure.assetFor(pose);
      expect(path, 'assets/avo/avo_${pose.name}.png');
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });

  for (final pose in AvoPose.values) {
    testWidgets('renders the ${pose.name} asset, contained', (tester) async {
      await _pump(tester, AvoFigure(pose: pose));
      final image = tester.widget<Image>(find.byType(Image));
      expect(_assetName(image), AvoFigure.assetFor(pose));
      expect(image.fit, BoxFit.contain);
    });
  }

  testWidgets('fills a size x size box (default 120)', (tester) async {
    await _pump(tester, const AvoFigure(pose: AvoPose.waving));
    expect(tester.getSize(find.byType(AvoFigure)), const Size(120, 120));
    await _pump(tester, const AvoFigure(pose: AvoPose.excited, size: 44));
    expect(tester.getSize(find.byType(AvoFigure)), const Size(44, 44));
  });

  testWidgets('draws the soft shadow ellipse under the figure', (tester) async {
    await _pump(tester, const AvoFigure(pose: AvoPose.thinking));
    final shadow = find.descendant(
      of: find.byType(AvoFigure),
      matching: find.byType(CustomPaint),
    );
    expect(shadow, findsOneWidget);
    final rect = tester.getRect(shadow);
    final figure = tester.getRect(find.byType(AvoFigure));
    expect(rect.width, closeTo(figure.width * 0.6, 0.01));
    expect(rect.bottom, greaterThan(figure.bottom));
  });

  testWidgets('decorative figures are hidden from VoiceOver', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, const AvoFigure(pose: AvoPose.waving));
    expect(
      tester.getSemantics(find.byType(AvoFigure)),
      isNot(isSemantics(isImage: true)),
    );
    handle.dispose();
  });

  testWidgets('a non-decorative figure is an image with a label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      const AvoFigure(
        pose: AvoPose.excited,
        decorative: false,
        semanticLabel: 'Avo freut sich',
      ),
    );
    expect(
      tester.getSemantics(find.byType(AvoFigure)),
      isSemantics(label: 'Avo freut sich', isImage: true),
    );
    handle.dispose();
  });

  testWidgets('decodes at display size', (tester) async {
    await _pump(tester, const AvoFigure(pose: AvoPose.waving, size: 96));
    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image;
    expect(provider, isA<ResizeImage>());
    expect((provider as ResizeImage).height, 96 * 3);
  });

  layoutMatrix(
    'AvoFigure above a hint text',
    (context) => Padding(
      padding: const EdgeInsets.all(AvoSpacing.screen),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AvoFigure(pose: AvoPose.celebrating),
          const SizedBox(height: AvoSpacing.m),
          Text(
            'Laktosefreie Bio-Vollmilch ist wieder da: 1,29 € statt 1,79 €',
            textAlign: TextAlign.center,
            style: context.text(AvoTextStyle.subhead),
          ),
        ],
      ),
    ),
  );
}

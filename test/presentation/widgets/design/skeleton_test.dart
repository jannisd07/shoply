import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/skeleton.dart';

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
        child: SizedBox(width: layout.width, child: child),
      ),
    ),
  );
}

Finder _decorated(bool Function(BoxDecoration d) test) => find.descendant(
  of: find.byType(SkeletonSection),
  matching: find.byWidgetPredicate(
    (w) =>
        w is DecoratedBox &&
        w.decoration is BoxDecoration &&
        test(w.decoration as BoxDecoration),
  ),
);

Finder _circles() => _decorated((d) => d.shape == BoxShape.circle);

Finder _thumbs() => _decorated(
  (d) => d.borderRadius == BorderRadius.circular(AvoRadii.imageSmall),
);

void main() {
  testWidgets('one placeholder row per row, in the fill colour', (
    tester,
  ) async {
    await _pump(tester, const SkeletonSection(rows: 5));
    expect(_circles(), findsNWidgets(5));
    expect(_thumbs(), findsNWidgets(5));
    final circle = tester.widget<DecoratedBox>(_circles().first);
    expect((circle.decoration as BoxDecoration).color, AvoColors.light.fill);
    expect(
      tester.getSize(find.byType(SkeletonSection)).height,
      greaterThanOrEqualTo(5 * 60),
    );
  });

  testWidgets('without images', (tester) async {
    await _pump(tester, const SkeletonSection(withImage: false));
    expect(_circles(), findsNWidgets(3));
    expect(_thumbs(), findsNothing);
  });

  testWidgets('from AX1: plain, no images, taller bars', (tester) async {
    await _pump(tester, const SkeletonSection());
    final barAtLarge = tester
        .getSize(
          _decorated(
            (d) => d.shape == BoxShape.rectangle && d.borderRadius != null,
          ).last,
        )
        .height;
    await _pump(
      tester,
      const SkeletonSection(),
      layout: const LayoutCase(width: 390, scale: 2),
    );
    expect(_thumbs(), findsNothing);
    expect(find.byType(ClipRRect), findsNothing);
    final barAtAx = tester
        .getSize(
          _decorated(
            (d) => d.shape == BoxShape.rectangle && d.borderRadius != null,
          ).last,
        )
        .height;
    expect(barAtAx, greaterThan(barAtLarge));
  });

  testWidgets('static: no shimmer, no running animation', (tester) async {
    await _pump(tester, const SkeletonSection());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('VoiceOver: one "loading" element, shapes hidden', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, const SkeletonSection());
    final node = tester.getSemantics(find.byType(SkeletonSection));
    expect(node.label, 'Loading...');
    expect(node.childrenCount, 0);

    await _pump(tester, const SkeletonSection(loadingLabel: 'Wird geladen'));
    expect(find.bySemanticsLabel('Wird geladen'), findsOneWidget);
    handle.dispose();
  });

  layoutMatrix(
    'SkeletonSection',
    (context) => const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SkeletonSection(rows: 5, loadingLabel: 'Wird geladen'),
        SizedBox(height: AvoSpacing.section),
        SkeletonSection(withImage: false),
      ],
    ),
    scrollable: true,
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';

void main() {
  test('scale factor maps to the iOS content size category', () {
    expect(AvoTypography.categoryForFactor(1.0), ContentSizeCategory.large);
    expect(AvoTypography.categoryForFactor(1.35), ContentSizeCategory.xxxLarge);
    expect(AvoTypography.categoryForFactor(2.0), ContentSizeCategory.ax2);
    expect(AvoTypography.categoryForFactor(3.1), ContentSizeCategory.ax5);
    expect(AvoTypography.categoryForFactor(0.82), ContentSizeCategory.xSmall);
  });

  test('D2 sizes and line heights at the default size', () {
    final t = AvoTypography.forFactor(1.0);
    expect(t.sizeOf(AvoTextStyle.largeTitle), 34);
    expect(t.lineHeightOf(AvoTextStyle.largeTitle), 41);
    expect(t.sizeOf(AvoTextStyle.title3), 20);
    expect(t.lineHeightOf(AvoTextStyle.title3), 25);
    expect(t.sizeOf(AvoTextStyle.body), 17);
    expect(t.lineHeightOf(AvoTextStyle.body), 22);
    expect(t.sizeOf(AvoTextStyle.subhead), 15);
    expect(t.lineHeightOf(AvoTextStyle.subhead), 20);
    expect(t.sizeOf(AvoTextStyle.sectionCaps), 13);
    expect(t.lineHeightOf(AvoTextStyle.caption2), 13);
    expect(t.style(AvoTextStyle.largeTitle).fontWeight, FontWeight.w700);
  });

  test('large titles grow less than body text (iOS tables)', () {
    final ax5 = AvoTypography.forFactor(3.118);
    expect(ax5.sizeOf(AvoTextStyle.body), 53);
    expect(ax5.sizeOf(AvoTextStyle.largeTitle), 60);
  });

  testWidgets('rendered size equals the table size under Flutter scaling',
      (tester) async {
    for (final factor in [1.0, 1.35, 2.0, 3.1]) {
      late double rendered;
      await tester.pumpWidget(MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(factor)),
        child: Builder(builder: (context) {
          final style = context.text(AvoTextStyle.largeTitle);
          rendered = MediaQuery.textScalerOf(context).scale(style.fontSize!);
          return const SizedBox();
        }),
      ));
      final expected = AvoTypography.forFactor(factor)
          .sizeOf(AvoTextStyle.largeTitle);
      expect(rendered, closeTo(expected, 0.01), reason: 'factor $factor');
    }
  });

  test('tracking follows the SF table', () {
    expect(AvoTypography.trackingFor(17), closeTo(-0.43, 1e-9));
    expect(AvoTypography.trackingFor(12), 0);
    expect(AvoTypography.trackingFor(34), closeTo(0.40, 1e-9));
    expect(AvoTypography.trackingFor(18), closeTo(-0.4367, 1e-3));
  });

  test('tabular figures on request', () {
    final t = AvoTypography.forFactor(1.0);
    expect(t.style(AvoTextStyle.footnote, tabular: true).fontFeatures,
        isNotEmpty);
    expect(t.style(AvoTextStyle.footnote).fontFeatures, isNull);
  });
}

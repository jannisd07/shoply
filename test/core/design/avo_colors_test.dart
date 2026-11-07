import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';

double _lum(Color c) {
  double f(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
}

/// WCAG contrast of [fg] over an opaque [bg] (fg alpha is composited).
double contrast(Color fg, Color bg) {
  final composed = Color.alphaBlend(fg, bg);
  final a = _lum(composed), b = _lum(bg);
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}

void main() {
  const variants = {
    'light': AvoColors.light,
    'dark': AvoColors.dark,
    'lightHighContrast': AvoColors.lightHighContrast,
    'darkHighContrast': AvoColors.darkHighContrast,
  };

  variants.forEach((name, c) {
    group(name, () {
      test('text on surfaces reaches 4.5:1', () {
        for (final bg in [c.surface, c.background]) {
          expect(contrast(c.label, bg), greaterThanOrEqualTo(7));
          expect(contrast(c.secondaryLabel, bg), greaterThanOrEqualTo(4.5));
          expect(contrast(c.placeholder, bg), greaterThanOrEqualTo(4.5));
          expect(contrast(c.tint, bg), greaterThanOrEqualTo(4.5));
        }
        expect(contrast(c.destructive, c.surface), greaterThanOrEqualTo(4.5));
        expect(contrast(c.onTint, c.tintFill), greaterThanOrEqualTo(4.5));
        expect(contrast(c.tint, c.tintSoft), greaterThanOrEqualTo(4.5));
        expect(contrast(c.onChipSelected, c.chipSelected),
            greaterThanOrEqualTo(4.5));
        expect(contrast(c.tertiaryLabel, c.surface), greaterThanOrEqualTo(4.5));
      });

      test('glass fallback keeps text readable', () {
        expect(contrast(c.label, c.glassFallback), greaterThanOrEqualTo(7));
        expect(
            contrast(c.tertiaryLabel, c.glassFallback), greaterThanOrEqualTo(4.5));
      });
    });
  });

  test('the unchecked ring reaches 3:1 in every variant (owner 07.11.)', () {
    for (final c in variants.values) {
      expect(contrast(c.uncheckedRing, c.surface), greaterThanOrEqualTo(3));
    }
  });

  test('D2 light values are exact', () {
    const c = AvoColors.light;
    expect(c.background, const Color(0xFFF2F2F7));
    expect(c.label, const Color(0xFF1C1C1E));
    expect(c.secondaryLabel, const Color(0xFF6C6C70));
    expect(c.separator, const Color(0xFFE5E5EA));
    expect(c.tint, const Color(0xFF1F7A3A));
    expect(c.tintSoft, const Color(0xFFE7F3EA));
    expect(c.destructive, const Color(0xFFD70015));
  });

  testWidgets('resolves from brightness and Increase Contrast without a '
      'Material theme extension', (tester) async {
    late AvoColors seen;
    Future<void> pump(Brightness b, bool hc) => tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(highContrast: hc),
            child: Theme(
              data: ThemeData(brightness: b),
              child: Builder(builder: (context) {
                seen = context.colors;
                return const SizedBox();
              }),
            ),
          ),
        );
    await pump(Brightness.light, false);
    expect(seen, same(AvoColors.light));
    await pump(Brightness.dark, false);
    expect(seen, same(AvoColors.dark));
    await pump(Brightness.light, true);
    expect(seen, same(AvoColors.lightHighContrast));
    await pump(Brightness.dark, true);
    expect(seen, same(AvoColors.darkHighContrast));
  });
}

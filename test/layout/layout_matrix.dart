// Layout test matrix for every screen and component (Teil A owns it, Teil B
// uses it). One call renders a widget at every iPhone width and text size and
// fails on any overflow or clipped text.
//
// ```dart
// import '../layout/layout_matrix.dart';
//
// void main() {
//   layoutMatrix('ItemRow', (context) => const ItemRow(...));
// }
// ```
//
// What it checks per case:
// - no Flutter error (RenderFlex overflow, unbounded layout, exceptions)
// - every text (Text, RichText, TextField) is at least as tall as its lines
//   need, i.e. nothing is cut by a fixed height around it (the A3 bug)
// - optional: 44 pt tap targets and labelled tap targets
//
// Real SF Pro is loaded from macOS when available, so widths match the
// device; elsewhere the test font is used (wider, so stricter).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';

/// iPhone widths in points: display zoom "Larger Text" (320), SE/mini (375),
/// 13/14/15 (390/393), 16 Pro (402), Pro Max (440).
const List<double> kLayoutWidths = [320, 375, 390, 402, 440];

/// Linear text scale factors: default (L), xxxL, ~AX2, AX5.
const List<double> kLayoutTextScales = [1.0, 1.35, 2.0, 3.1];

/// Device height used for every case.
const double kLayoutHeight = 844;

/// One rendering condition.
class LayoutCase {
  const LayoutCase({
    required this.width,
    required this.scale,
    this.bold = false,
    this.brightness = Brightness.light,
    this.highContrast = false,
    this.reduceMotion = false,
  });

  final double width;
  final double scale;
  final bool bold;
  final Brightness brightness;
  final bool highContrast;
  final bool reduceMotion;

  @override
  String toString() => '${width.toInt()}pt x$scale'
      '${bold ? ' bold' : ''}'
      '${brightness == Brightness.dark ? ' dark' : ''}'
      '${highContrast ? ' hc' : ''}'
      '${reduceMotion ? ' rm' : ''}';
}

/// The default set: every width × every text size, plus bold text at the
/// two large sizes, dark mode and Increase Contrast at the default size.
List<LayoutCase> defaultLayoutCases() => [
      for (final w in kLayoutWidths)
        for (final s in kLayoutTextScales) LayoutCase(width: w, scale: s),
      for (final w in [320.0, 390.0])
        for (final s in [1.35, 3.1]) LayoutCase(width: w, scale: s, bold: true),
      const LayoutCase(width: 390, scale: 1, brightness: Brightness.dark),
      const LayoutCase(width: 390, scale: 1, highContrast: true),
      const LayoutCase(
          width: 320, scale: 3.1, brightness: Brightness.dark, bold: true),
    ];

bool _fontsLoaded = false;

/// Loads SF Pro from macOS under the families the design system uses.
Future<void> loadLayoutFonts() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  final file = File('/System/Library/Fonts/SFNS.ttf');
  if (!file.existsSync()) return;
  final bytes = file.readAsBytesSync();
  for (final family in [
    'CupertinoSystemText',
    'CupertinoSystemDisplay',
    '.SF UI Text',
    '.SF UI Display',
    'Roboto', // Material default in tests
  ]) {
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }
}

/// Wraps [child] like the app does: MediaQuery for the case, Material theme
/// for the brightness, the design scope, a white-ish background.
Widget layoutHarness(LayoutCase c, Widget child) {
  return MediaQuery(
    data: MediaQueryData(
      size: Size(c.width, kLayoutHeight),
      devicePixelRatio: 3,
      textScaler: TextScaler.linear(c.scale),
      boldText: c.bold,
      highContrast: c.highContrast,
      disableAnimations: c.reduceMotion,
      platformBrightness: c.brightness,
      padding: const EdgeInsets.only(top: 47, bottom: 34),
      viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
    ),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: c.brightness,
        platform: TargetPlatform.iOS,
        fontFamily: 'CupertinoSystemText',
      ),
      home: AvoDesignScope(
        reduceTransparencyOverride: c.highContrast,
        child: Builder(
          builder: (context) => ColoredBox(
            color: context.colors.background,
            child: child,
          ),
        ),
      ),
    ),
  );
}

/// Fails if any text was squeezed below the height its lines need.
void expectNoClippedText(WidgetTester tester, {String reason = ''}) {
  final problems = <String>[];
  void visit(RenderObject o) {
    if (o is RenderParagraph && o.hasSize && o.size.width > 0) {
      final needed = o.getMinIntrinsicHeight(o.size.width);
      if (o.size.height < needed - 0.5) {
        problems.add('"${o.text.toPlainText()}" is '
            '${o.size.height.toStringAsFixed(1)} pt tall, needs '
            '${needed.toStringAsFixed(1)}');
      }
    }
    if (o is RenderEditable && o.hasSize && o.size.width > 0) {
      final needed = o.getMinIntrinsicHeight(o.size.width);
      if (o.size.height < needed - 0.5) {
        problems.add('text field "${o.text?.toPlainText()}" is '
            '${o.size.height.toStringAsFixed(1)} pt tall, needs '
            '${needed.toStringAsFixed(1)}');
      }
    }
    o.visitChildren(visit);
  }

  for (final view in tester.binding.renderViews) {
    view.visitChildren(visit);
  }
  expect(problems, isEmpty, reason: '$reason clipped text:\n'
      '${problems.join('\n')}');
}

/// Registers one widget test per [cases] (default: [defaultLayoutCases]).
///
/// [build] gets the harness context (design scope, theme, MediaQuery). Put
/// the widget in whatever parent it has in the app (for example inside a
/// `ListView` or with a fixed width) so the test sees real constraints.
/// [scrollable] wraps it in a vertical scroll view, for full screens.
void layoutMatrix(
  String name,
  WidgetBuilder build, {
  List<LayoutCase>? cases,
  bool scrollable = false,
  bool checkTapTargets = false,
  Future<void> Function(WidgetTester tester)? afterPump,
}) {
  group('layout: $name', () {
    for (final c in cases ?? defaultLayoutCases()) {
      testWidgets('$c', (tester) async {
        await loadLayoutFonts();
        tester.view.physicalSize = Size(c.width * 3, kLayoutHeight * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        final handle = tester.ensureSemantics();
        await tester.pumpWidget(layoutHarness(
          c,
          Builder(builder: (context) {
            final child = build(context);
            return scrollable
                ? SingleChildScrollView(child: child)
                : Align(alignment: Alignment.topCenter, child: child);
          }),
        ));
        await tester.pump(const Duration(milliseconds: 600));
        if (afterPump != null) await afterPump(tester);

        expect(tester.takeException(), isNull, reason: '$name at $c');
        expectNoClippedText(tester, reason: '$name at $c:');
        if (checkTapTargets) {
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        }
        handle.dispose();
      });
    }
  });
}

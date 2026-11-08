import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/presentation/widgets/design/full_screen_editor.dart';
import 'package:shoply/presentation/widgets/design/gallery/component_gallery.dart';

import '../../../../layout/layout_matrix.dart';

Future<void> _pump(
  WidgetTester tester, {
  required ComponentGalleryMode mode,
  double width = 390,
}) async {
  await loadLayoutFonts();
  tester.view.physicalSize = Size(width * 3, kLayoutHeight * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    layoutHarness(
      LayoutCase(width: width, scale: 1),
      ComponentGallery(initialMode: mode),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
}

ScrollPosition _position(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(ComponentGallery.scrollKey),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

/// Scrolls the gallery from top to bottom and fails on the first exception
/// (overflow, unbounded layout) or squeezed text on the way.
Future<void> _scrollToEnd(WidgetTester tester, String reason) async {
  final position = _position(tester);
  for (var step = 0; ; step++) {
    final at = '$reason at ${position.pixels.round()} pt';
    expect(tester.takeException(), isNull, reason: at);
    expectNoClippedText(tester, reason: at);
    if (position.pixels >= position.maxScrollExtent) break;
    expect(step, lessThan(1000), reason: '$reason: no end in sight');
    position.jumpTo(
      math.min(
        position.pixels + position.viewportDimension * 0.75,
        position.maxScrollExtent,
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
  }
  expect(position.maxScrollExtent, greaterThan(0));
}

/// Advances [ms] in frames of 100 ms (spinners keep pumpAndSettle busy).
Future<void> _frames(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 100) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Scrolls the gallery until [label] is built, then taps it.
Future<void> _tapTrigger(WidgetTester tester, String label) async {
  final button = find.text(label);
  final position = _position(tester);
  while (button.evaluate().isEmpty &&
      position.pixels < position.maxScrollExtent) {
    position.jumpTo(
      math.min(
        position.pixels + position.viewportDimension * 0.75,
        position.maxScrollExtent,
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.ensureVisible(button);
  await _frames(tester, 400);
  await tester.tap(button);
  await _frames(tester, 800);
}

void main() {
  for (final (mode, width) in [
    (ComponentGalleryMode.light, 390.0),
    (ComponentGalleryMode.dark, 390.0),
    (ComponentGalleryMode.ax5, 390.0),
    (ComponentGalleryMode.ax5, 320.0),
    (ComponentGalleryMode.contrast, 390.0),
  ]) {
    testWidgets(
      'renders every component in ${mode.label} at ${width.round()} pt '
      'without exceptions or clipped text',
      (tester) async {
        await _pump(tester, mode: mode, width: width);
        await _scrollToEnd(tester, '${mode.label} ${width.round()} pt');
      },
    );
  }

  testWidgets('the switch renders the content in the chosen mode', (
    tester,
  ) async {
    await _pump(tester, mode: ComponentGalleryMode.light);
    ComponentGalleryMode scopeMode() => tester
        .widget<ComponentGalleryScope>(find.byType(ComponentGalleryScope))
        .mode;
    MediaQueryData content() =>
        MediaQuery.of(tester.element(find.byKey(ComponentGallery.scrollKey)));

    expect(scopeMode(), ComponentGalleryMode.light);
    expect(content().platformBrightness, Brightness.light);

    await tester.tap(find.text('Dunkel').first);
    await tester.pump(const Duration(milliseconds: 600));
    expect(scopeMode(), ComponentGalleryMode.dark);
    expect(content().platformBrightness, Brightness.dark);

    await tester.tap(find.text('AX5').first);
    await tester.pump(const Duration(milliseconds: 600));
    expect(content().textScaler.scale(10), closeTo(31, 0.01));

    await tester.tap(find.text('Kontrast').first);
    await tester.pump(const Duration(milliseconds: 600));
    expect(content().highContrast, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dialogs, toast, success moment and editor open and close', (
    tester,
  ) async {
    await _pump(tester, mode: ComponentGalleryMode.light);

    await _tapTrigger(tester, 'Liste löschen fragen');
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    await tester.tap(find.text('Löschen'));
    await _frames(tester, 800);
    expect(find.byType(CupertinoAlertDialog), findsNothing);
    expect(find.text('Liste gelöscht'), findsOneWidget);

    await _tapTrigger(tester, 'Modul Kalorien ist aus');
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    await tester.tap(find.byType(CupertinoDialogAction).first);
    await _frames(tester, 800);
    expect(find.byType(CupertinoAlertDialog), findsNothing);

    await _tapTrigger(tester, 'Erfolg zeigen');
    expect(find.text('Einkauf gespeichert.'), findsOneWidget);
    await _frames(tester, 3000);
    expect(find.text('Einkauf gespeichert.'), findsNothing);

    await _tapTrigger(tester, 'Artikel bearbeiten');
    expect(find.byType(FullScreenEditor), findsOneWidget);
    await tester.tap(find.text('Auf die Liste setzen'));
    await _frames(tester, 800);
    expect(find.byType(FullScreenEditor), findsNothing);

    // Let the toasts time out.
    await _frames(tester, 11000);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the editor renders at AX5 without exceptions', (tester) async {
    await _pump(tester, mode: ComponentGalleryMode.ax5, width: 320);
    await _tapTrigger(tester, 'Artikel bearbeiten');
    expect(find.byType(FullScreenEditor), findsOneWidget);
    expect(tester.takeException(), isNull);
    expectNoClippedText(tester, reason: 'editor at AX5');
  });
}

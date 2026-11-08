import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/full_screen_editor.dart';
import 'package:shoply/presentation/widgets/design/glass_surface.dart';
import 'package:shoply/presentation/widgets/design/glass_toolbar.dart';

import '../../../layout/layout_matrix.dart';

const _content = Key('content');

Widget _rows(BuildContext context) => Padding(
  key: _content,
  padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final line in [
        'Bio-Vollmilch 3,8 % Fett aus der Region, laktosefrei',
        'Obst & Gemüse · in Wocheneinkauf',
        'Notiz: z. B. reif, für Guacamole',
        'Hinzugefügt von Lena · Dienstag',
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: AvoSpacing.l),
          child: Text(line, style: context.text(AvoTextStyle.body)),
        ),
    ],
  ),
);

Future<void> _pump(
  WidgetTester tester,
  WidgetBuilder build, {
  LayoutCase layout = const LayoutCase(width: 390, scale: 1),
}) async {
  await loadLayoutFonts();
  tester.view.physicalSize = Size(layout.width * 3, kLayoutHeight * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    layoutHarness(layout, SizedBox.expand(child: Builder(builder: build))),
  );
}

/// A home screen with a button that opens [editor] via pushFullScreenEditor.
Future<List<Object?>> _pumpOpener(
  WidgetTester tester,
  WidgetBuilder editor, {
  bool cover = true,
  LayoutCase layout = const LayoutCase(width: 390, scale: 1),
}) async {
  final results = <Object?>[];
  await _pump(
    tester,
    (context) => Center(
      child: TextButton(
        onPressed: () async => results.add(
          await pushFullScreenEditor<Object?>(context, editor, cover: cover),
        ),
        child: const Text('open'),
      ),
    ),
    layout: layout,
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return results;
}

Finder get _done => find.bySemanticsLabel('Done');

void main() {
  group('FullScreenEditor D2', () {
    testWidgets('background, X left, title centred, tinted Done right', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        (context) => FullScreenEditor(
          title: 'Artikel',
          onDone: () {},
          child: _rows(context),
        ),
      );
      final background = tester.widget<ColoredBox>(
        find
            .descendant(
              of: find.byType(FullScreenEditor),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      expect(background.color, AvoColors.light.background);

      final close = find.bySemanticsLabel('Close');
      expect(tester.getRect(close), const Rect.fromLTWH(16, 54, 44, 44));
      expect(
        find.byWidgetPredicate((w) => w is AvoIcon && w.icon == AvoIcons.xmark),
        findsOneWidget,
      );

      final title = tester.widget<Text>(find.text('Artikel'));
      expect(title.style!.fontSize, 17);
      expect(title.style!.fontWeight, FontWeight.w600);
      expect(tester.getCenter(find.text('Artikel')).dx, closeTo(195, 0.5));
      expect(tester.getCenter(find.text('Artikel')).dy, closeTo(76, 0.5));

      final done = tester.getRect(_done);
      expect(done.height, 44);
      expect(done.right, 390 - 16);
      expect(done.top, 54);
      final doneText = tester.widget<Text>(find.text('Done'));
      expect(doneText.style!.fontSize, 17);
      expect(doneText.style!.fontWeight, FontWeight.w600);
      expect(doneText.style!.color, AvoColors.light.onTint);
      final glass = tester.widget<GlassSurface>(
        find.ancestor(
          of: find.text('Done'),
          matching: find.byType(GlassSurface),
        ),
      );
      expect(glass.tinted, isTrue);
      // D2 padding 0 18.
      expect(
        done.width,
        closeTo(tester.getSize(find.text('Done')).width + 36, 0.5),
      );
      handle.dispose();
    });

    testWidgets('content starts under the toolbar at 110 pt (D2)', (
      tester,
    ) async {
      await _pump(
        tester,
        (context) => FullScreenEditor(title: 'Artikel', child: _rows(context)),
      );
      expect(tester.getRect(find.byKey(_content)).top, 110);
    });

    testWidgets('scroll edge fade behind the toolbar', (tester) async {
      await _pump(
        tester,
        (context) => FullScreenEditor(title: 'Artikel', child: _rows(context)),
      );
      final fade = tester.getRect(find.byType(ScrollEdgeFade));
      expect(fade.top, 0);
      expect(fade.height, 110);
    });

    testWidgets('large text: the title wraps under the buttons', (
      tester,
    ) async {
      await _pump(
        tester,
        (context) => FullScreenEditor(
          title: 'Mittagessen eintragen',
          onDone: () {},
          child: _rows(context),
        ),
        layout: const LayoutCase(width: 320, scale: 3.1),
      );
      final title = tester.getRect(find.text('Mittagessen eintragen'));
      final done = tester.getRect(find.text('Done'));
      expect(title.top, greaterThan(done.bottom));
      final content = tester.getRect(find.byKey(_content));
      expect(content.top, greaterThanOrEqualTo(title.bottom + 12 - 0.5));
      expect(tester.takeException(), isNull);
      expectNoClippedText(tester);
    });

    testWidgets('a long title at the default size goes under the buttons', (
      tester,
    ) async {
      await _pump(
        tester,
        (context) => FullScreenEditor(
          title: 'Bio-Vollmilch 3,8 % Fett aus der Region bearbeiten',
          onDone: () {},
          child: _rows(context),
        ),
      );
      final title = tester.getRect(
        find.text('Bio-Vollmilch 3,8 % Fett aus der Region bearbeiten'),
      );
      expect(title.top, greaterThan(54 + 44 - 0.5));
    });

    testWidgets('back chevron with a custom label', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        (context) => FullScreenEditor(
          title: 'Artikel',
          leading: EditorLeading.back,
          leadingLabel: 'Zurück zu Wocheneinkauf',
          child: _rows(context),
        ),
      );
      expect(find.bySemanticsLabel('Zurück zu Wocheneinkauf'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is AvoIcon && w.icon == AvoIcons.chevronBack,
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('default back label is "Back"', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        (context) => FullScreenEditor(
          title: 'Artikel',
          leading: EditorLeading.back,
          child: _rows(context),
        ),
      );
      expect(find.bySemanticsLabel('Back'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('no Done capsule without onDone; title stays centred', (
      tester,
    ) async {
      await _pump(
        tester,
        (context) => FullScreenEditor(
          title: 'Mittagessen eintragen',
          child: _rows(context),
        ),
      );
      expect(find.text('Done'), findsNothing);
      expect(
        tester.getCenter(find.text('Mittagessen eintragen')).dx,
        closeTo(195, 0.5),
      );
    });

    testWidgets('VoiceOver: title is a header naming the screen, once', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        (context) => FullScreenEditor(
          title: 'Artikel',
          onDone: () {},
          child: _rows(context),
        ),
      );
      expect(find.semantics.byLabel('Artikel'), findsOneWidget);
      expect(find.semantics.byLabel('Done'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Artikel')),
        isSemantics(isHeader: true, namesRoute: true, label: 'Artikel'),
      );
      handle.dispose();
    });

    testWidgets('VoiceOver: toolbar first, then the content', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        (context) => FullScreenEditor(
          title: 'Artikel',
          onDone: () {},
          child: _rows(context),
        ),
      );
      final order = tester.semantics
          .simulatedAccessibilityTraversal()
          .map((n) => n.label)
          .where((l) => l.isNotEmpty)
          .toList();
      expect(order.take(3), ['Close', 'Artikel', 'Done']);
      expect(
        order.indexOf('Bio-Vollmilch 3,8 % Fett aus der Region, laktosefrei'),
        greaterThan(order.indexOf('Done')),
      );
      handle.dispose();
    });

    testWidgets('slivers as content', (tester) async {
      await _pump(
        tester,
        (context) => FullScreenEditor(
          title: 'Zutaten',
          slivers: [
            SliverList.builder(
              itemCount: 40,
              itemBuilder: (context, i) => SizedBox(
                height: 56,
                child: Text('Zutat $i', style: context.text(AvoTextStyle.body)),
              ),
            ),
          ],
        ),
      );
      expect(tester.getRect(find.text('Zutat 0')).top, 110);
      await tester.drag(find.text('Zutat 3'), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(find.text('Zutat 0'), findsNothing);
      // The toolbar stays where it is.
      expect(tester.getRect(find.text('Zutaten')).center.dy, closeTo(76, 0.5));
    });
  });

  group('FullScreenEditor done', () {
    testWidgets('Done calls onDone and does not close by itself', (
      tester,
    ) async {
      var done = 0;
      await _pumpOpener(
        tester,
        (context) => FullScreenEditor(
          title: 'Artikel',
          onDone: () => done++,
          child: _rows(context),
        ),
      );
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(done, 1);
      expect(find.byType(FullScreenEditor), findsOneWidget);
    });

    testWidgets('doneEnabled false: dimmed, no call', (tester) async {
      final handle = tester.ensureSemantics();
      var done = 0;
      await _pump(
        tester,
        (context) => FullScreenEditor(
          title: 'Artikel',
          onDone: () => done++,
          doneEnabled: false,
          child: _rows(context),
        ),
      );
      final opacity = tester.widget<Opacity>(
        find
            .ancestor(of: find.text('Done'), matching: find.byType(Opacity))
            .first,
      );
      expect(opacity.opacity, 0.4);
      await tester.tap(find.text('Done'), warnIfMissed: false);
      expect(done, 0);
      expect(
        tester.getSemantics(_done),
        isSemantics(isButton: true, isEnabled: false, hasEnabledState: true),
      );
      handle.dispose();
    });

    testWidgets('working: spinner, same width, taps blocked, announced', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var done = 0;
      Widget editor(bool working) => FullScreenEditor(
        title: 'Artikel',
        onDone: () => done++,
        working: working,
        workingLabel: 'Wird gespeichert',
        child: const SizedBox(height: 100),
      );
      await _pump(tester, (context) => editor(false));
      final width = tester.getSize(_done).width;
      await _pump(tester, (context) => editor(true));
      await tester.pump();
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      expect(tester.getSize(_done).width, width);
      await tester.tap(_done, warnIfMissed: false);
      expect(done, 0);
      expect(
        tester.getSemantics(_done),
        isSemantics(
          isButton: true,
          value: 'Wird gespeichert',
          isLiveRegion: true,
        ),
      );
      handle.dispose();
    });
  });

  group('FullScreenEditor closing', () {
    testWidgets('without changes the X closes at once', (tester) async {
      final results = await _pumpOpener(
        tester,
        (context) => FullScreenEditor(title: 'Artikel', child: _rows(context)),
      );
      expect(find.byType(FullScreenEditor), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(find.byType(FullScreenEditor), findsNothing);
      expect(results, [null]);
    });

    testWidgets('with changes: asks; Keep editing stays; Discard closes', (
      tester,
    ) async {
      await _pumpOpener(
        tester,
        (context) => FullScreenEditor(
          title: 'Artikel',
          dirty: true,
          child: _rows(context),
        ),
      );
      await tester.tap(find.bySemanticsLabel('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(find.byType(FullScreenEditor), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.byType(FullScreenEditor), findsNothing);
    });

    testWidgets('with changes the system back asks as well', (tester) async {
      await _pumpOpener(
        tester,
        (context) => FullScreenEditor(
          title: 'Artikel',
          dirty: true,
          child: _rows(context),
        ),
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.byType(FullScreenEditor), findsNothing);
    });

    testWidgets('without changes the system back closes', (tester) async {
      await _pumpOpener(
        tester,
        (context) => FullScreenEditor(title: 'Artikel', child: _rows(context)),
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(find.byType(FullScreenEditor), findsNothing);
    });

    Widget pushed({required bool dirty}) => FullScreenEditor(
      title: 'Artikel',
      leading: EditorLeading.back,
      dirty: dirty,
      child: const SizedBox(height: 100),
    );

    testWidgets('pushed editor without changes: swipe back is on', (
      tester,
    ) async {
      await _pumpOpener(tester, (_) => pushed(dirty: false), cover: false);
      final route = ModalRoute.of(
        tester.element(find.byType(FullScreenEditor)),
      )!;
      expect(route.popGestureEnabled, isTrue);
    });

    testWidgets('pushed editor with changes: swipe back is off', (
      tester,
    ) async {
      await _pumpOpener(tester, (_) => pushed(dirty: true), cover: false);
      final route = ModalRoute.of(
        tester.element(find.byType(FullScreenEditor)),
      )!;
      expect(route.popGestureEnabled, isFalse);
    });
  });

  group('pushFullScreenEditor', () {
    testWidgets('cover: Cupertino full-screen dialog on the root navigator', (
      tester,
    ) async {
      await loadLayoutFonts();
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      // A tab with its own navigator, like a go_router branch.
      await tester.pumpWidget(
        layoutHarness(
          const LayoutCase(width: 390, scale: 1),
          Navigator(
            onGenerateRoute: (_) => CupertinoPageRoute<void>(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => pushFullScreenEditor<void>(
                    context,
                    (_) => const FullScreenEditor(
                      title: 'Artikel',
                      child: SizedBox(height: 100),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final context = tester.element(find.byType(FullScreenEditor));
      final route = ModalRoute.of(context)!;
      expect(route, isA<CupertinoPageRoute<void>>());
      expect((route as CupertinoPageRoute<void>).fullscreenDialog, isTrue);
      final root = tester.state<NavigatorState>(find.byType(Navigator).first);
      expect(route.navigator, root);
      // Slides up from the bottom.
      final top = tester.getRect(find.byType(FullScreenEditor)).top;
      expect(top, greaterThan(0));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(FullScreenEditor)).top, 0);
    });

    testWidgets('cover false: pushed from the right', (tester) async {
      await _pump(
        tester,
        (context) => Center(
          child: TextButton(
            onPressed: () => pushFullScreenEditor<void>(
              context,
              (_) => const FullScreenEditor(
                title: 'Artikel',
                leading: EditorLeading.back,
                child: SizedBox(height: 100),
              ),
              cover: false,
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final route = ModalRoute.of(
        tester.element(find.byType(FullScreenEditor)),
      )!;
      expect((route as CupertinoPageRoute<void>).fullscreenDialog, isFalse);
      expect(
        tester.getRect(find.byType(FullScreenEditor)).left,
        greaterThan(0),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('Reduce Motion: a cross-fade, no slide', (tester) async {
      await _pump(
        tester,
        (context) => Center(
          child: TextButton(
            onPressed: () => pushFullScreenEditor<void>(
              context,
              (_) => const FullScreenEditor(
                title: 'Artikel',
                child: SizedBox(height: 100),
              ),
            ),
            child: const Text('open'),
          ),
        ),
        layout: const LayoutCase(width: 390, scale: 1, reduceMotion: true),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final route = ModalRoute.of(
        tester.element(find.byType(FullScreenEditor)),
      )!;
      expect(route, isNot(isA<CupertinoPageRoute<void>>()));
      expect(
        tester.getRect(find.byType(FullScreenEditor)).topLeft,
        Offset.zero,
      );
      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.byType(FullScreenEditor),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, greaterThan(0));
      expect(fade.opacity.value, lessThan(1));
      await tester.pumpAndSettle();
    });

    testWidgets('returns what the editor pops with', (tester) async {
      final results = await _pumpOpener(
        tester,
        (context) => FullScreenEditor(
          title: 'Artikel',
          onDone: () => Navigator.of(context).pop('gespeichert'),
          child: const SizedBox(height: 100),
        ),
      );
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(results, ['gespeichert']);
    });
  });

  group('FullScreenEditor keyboard and bottom action', () {
    Widget editor(BuildContext context, {double keyboard = 0}) {
      final data = MediaQuery.of(context);
      return MediaQuery(
        data: data.copyWith(
          viewInsets: EdgeInsets.only(bottom: keyboard),
          padding: keyboard > 0
              ? data.padding.copyWith(bottom: 0)
              : data.padding,
        ),
        child: FullScreenEditor(
          title: 'Mittagessen eintragen',
          bottom: AppButton.primary(
            key: const Key('action'),
            label: 'Eintragen',
            size: AppButtonSize.large,
            expand: true,
            onPressed: () {},
          ),
          child: _rows(context),
        ),
      );
    }

    testWidgets('bottom action ends at the home indicator (D2 X-Essen)', (
      tester,
    ) async {
      await _pump(tester, (context) => editor(context));
      final action = tester.getRect(find.byKey(const Key('action')));
      expect(action.bottom, 844 - 34);
      expect(action.left, 16);
      expect(action.height, 54);
    });

    testWidgets('the keyboard shrinks the content and lifts the action', (
      tester,
    ) async {
      await _pump(tester, (context) => editor(context, keyboard: 336));
      final action = tester.getRect(find.byKey(const Key('action')));
      expect(action.bottom, 844 - 336 - 16);
      final viewport = tester.getRect(find.byType(CustomScrollView));
      expect(viewport.bottom, lessThanOrEqualTo(action.top));
    });
  });

  layoutMatrix(
    'FullScreenEditor D2-Artikel',
    (context) => SizedBox.expand(
      child: FullScreenEditor(
        title: 'Artikel',
        leading: EditorLeading.back,
        leadingLabel: 'Zurück zu Wocheneinkauf',
        onDone: () {},
        dirty: true,
        child: _rows(context),
      ),
    ),
    checkTapTargets: true,
  );

  layoutMatrix(
    'FullScreenEditor long title, long done label, working',
    (context) => SizedBox.expand(
      child: FullScreenEditor(
        title: 'Bio-Vollmilch 3,8 % Fett aus der Region, laktosefrei',
        doneLabel: 'Speichern',
        onDone: () {},
        working: true,
        workingLabel: 'Wird gespeichert',
        child: _rows(context),
      ),
    ),
    checkTapTargets: true,
  );

  layoutMatrix(
    'FullScreenEditor X-Essen with bottom action',
    (context) => SizedBox.expand(
      child: FullScreenEditor(
        title: 'Mittagessen eintragen',
        bottom: AppButton.primary(
          label: 'Eintragen',
          size: AppButtonSize.large,
          expand: true,
          onPressed: () {},
        ),
        child: _rows(context),
      ),
    ),
    checkTapTargets: true,
  );
}

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';

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

const _offline = 'Offline. 1 Änderung wartet.';

void main() {
  const symbols = {
    StatusKind.offline: CupertinoIcons.wifi_slash,
    StatusKind.pending: CupertinoIcons.clock,
    StatusKind.sending: CupertinoIcons.arrow_2_circlepath,
    StatusKind.failed: CupertinoIcons.exclamationmark_circle,
    StatusKind.sectionError: CupertinoIcons.exclamationmark_triangle,
    StatusKind.permission: CupertinoIcons.hand_raised,
  };

  for (final entry in symbols.entries) {
    testWidgets('${entry.key.name}: symbol, colours, no surface', (
      tester,
    ) async {
      await _pump(tester, StatusRow(kind: entry.key, text: _offline));
      expect(find.byIcon(entry.value), findsOneWidget);
      final failed = entry.key == StatusKind.failed;
      final icon = tester.widget<Icon>(find.byIcon(entry.value));
      expect(
        icon.color,
        failed ? AvoColors.light.destructive : AvoColors.light.secondaryLabel,
      );
      expect(icon.size, 16);
      final text = tester.widget<Text>(find.text(_offline)).style!;
      expect(
        text.color,
        failed ? AvoColors.light.destructive : AvoColors.light.label,
      );
      expect(text.fontSize, 15);
      expect(
        find.descendant(
          of: find.byType(StatusRow),
          matching: find.byType(DecoratedBox),
        ),
        findsNothing,
      );
    });
  }

  testWidgets('at least 44 pt tall, 16 pt side margins', (tester) async {
    await _pump(
      tester,
      const StatusRow(kind: StatusKind.offline, text: 'Offline'),
    );
    expect(tester.getSize(find.byType(StatusRow)).height, 44);
    expect(tester.getRect(find.byType(Icon)).left, 16);
  });

  testWidgets('the symbol grows with Dynamic Type', (tester) async {
    await _pump(
      tester,
      const StatusRow(kind: StatusKind.offline, text: 'Offline'),
      layout: const LayoutCase(width: 390, scale: 2),
    );
    expect(tester.widget<Icon>(find.byType(Icon)).size, greaterThan(16));
  });

  testWidgets('action: tinted, 44 pt target, runs onAction', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      StatusRow(
        kind: StatusKind.failed,
        text: '1 Änderung konnte nicht gespeichert werden.',
        actionLabel: 'Erneut',
        onAction: () => taps++,
      ),
    );
    final action = tester.widget<Text>(find.text('Erneut'));
    expect(action.style?.color, AvoColors.light.tint);
    expect(action.style?.fontWeight, FontWeight.w600);
    final target = find.ancestor(
      of: find.text('Erneut'),
      matching: find.byType(GestureDetector),
    );
    final size = tester.getSize(target.first);
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
    await tester.tap(find.text('Erneut'));
    expect(taps, 1);
  });

  testWidgets('the action shrinks while pressed', (tester) async {
    await _pump(
      tester,
      StatusRow(
        kind: StatusKind.sectionError,
        text: 'Fehler',
        actionLabel: 'Erneut',
        onAction: () {},
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Erneut')),
    );
    await tester.pumpAndSettle();
    final transform = tester.widget<Transform>(
      find.ancestor(of: find.text('Erneut'), matching: find.byType(Transform)),
    );
    expect(
      transform.transform.storage[0],
      closeTo(AvoMotion.pressedScale, 0.002),
    );
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('VoiceOver: one live element, action as double tap', (
    tester,
  ) async {
    var taps = 0;
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      StatusRow(
        kind: StatusKind.offline,
        text: _offline,
        actionLabel: 'Erneut versuchen',
        onAction: () => taps++,
      ),
    );
    final node = tester.getSemantics(find.byType(StatusRow));
    expect(
      node,
      isSemantics(
        label: _offline,
        hint: 'Erneut versuchen',
        isLiveRegion: true,
        isButton: true,
        hasTapAction: true,
      ),
    );
    tester.semantics.tap(find.semantics.byLabel(_offline));
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('without an action it is not a button', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      const StatusRow(kind: StatusKind.pending, text: _offline),
    );
    expect(
      tester.getSemantics(find.byType(StatusRow)),
      isSemantics(
        label: _offline,
        isLiveRegion: true,
        isButton: false,
        hasTapAction: false,
      ),
    );
    handle.dispose();
  });

  testWidgets('an action label without onAction is not shown', (tester) async {
    await _pump(
      tester,
      const StatusRow(
        kind: StatusKind.offline,
        text: 'Offline',
        actionLabel: 'Erneut',
      ),
    );
    expect(find.text('Erneut'), findsNothing);
  });

  testWidgets('from AX1 the action moves below the text', (tester) async {
    await _pump(
      tester,
      StatusRow(
        kind: StatusKind.offline,
        text: 'Offline',
        actionLabel: 'Erneut',
        onAction: () {},
      ),
      layout: const LayoutCase(width: 390, scale: 2),
    );
    final text = tester.getRect(find.text('Offline'));
    final action = tester.getRect(find.text('Erneut'));
    expect(action.top, greaterThanOrEqualTo(text.bottom));
    expect(action.left, closeTo(text.left, 1));
  });

  testWidgets(
    'announces on iOS when it appears and when the text changes',
    (tester) async {
      var text = _offline;
      late StateSetter update;
      await _pump(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return StatusRow(kind: StatusKind.offline, text: text);
          },
        ),
      );
      await tester.pump();
      var announcements = tester.takeAnnouncements();
      expect(announcements.map((a) => a.message), [_offline]);

      update(() => text = '3 Änderungen werden gesendet.');
      await tester.pump();
      await tester.pump();
      announcements = tester.takeAnnouncements();
      expect(announcements.map((a) => a.message), [
        '3 Änderungen werden gesendet.',
      ]);

      update(() {});
      await tester.pump();
      await tester.pump();
      expect(tester.takeAnnouncements(), isEmpty);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('leaves announcing to the live region elsewhere', (tester) async {
    await _pump(
      tester,
      const StatusRow(kind: StatusKind.offline, text: _offline),
    );
    await tester.pump();
    expect(tester.takeAnnouncements(), isEmpty);
  });

  layoutMatrix(
    'StatusRow, every kind',
    (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        StatusRow(
          kind: StatusKind.offline,
          text:
              'Offline. Deine Änderungen werden gespeichert, sobald du wieder online bist.',
          actionLabel: 'Erneut versuchen',
          onAction: () {},
        ),
        const StatusRow(
          kind: StatusKind.pending,
          text: 'Offline. 3 Änderungen warten.',
        ),
        const StatusRow(
          kind: StatusKind.sending,
          text: '3 Änderungen werden gesendet.',
        ),
        StatusRow(
          kind: StatusKind.failed,
          text: 'Laktosefreie Bio-Vollmilch konnte nicht gespeichert werden.',
          actionLabel: 'Erneut versuchen',
          onAction: () {},
        ),
        const StatusRow(
          kind: StatusKind.sectionError,
          text: 'Beliebte Rezepte konnten nicht geladen werden.',
        ),
        const StatusRow(
          kind: StatusKind.permission,
          text: 'Standort ist aus. In Einstellungen erlauben, 1,5 km Umkreis.',
        ),
      ],
    ),
    scrollable: true,
    checkTapTargets: true,
  );
}

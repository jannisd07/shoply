// W1 re-review 2 (fix round 3): the status row never hides the
// conversation (N2), the tip count for typed messages, and the minors.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/data/services/avo_assistant_service.dart';
import 'package:shoply/data/services/tip_service.dart';
import 'package:shoply/presentation/screens/avo/avo_chat.dart';
import 'package:shoply/presentation/screens/avo/avo_hand_over.dart';
import 'package:shoply/presentation/screens/avo/avo_suggestions.dart';
import 'package:shoply/presentation/screens/avo/avo_tab_screen.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:shoply/presentation/widgets/tips/tip_slot.dart';

import 'avo_fakes.dart';

/// Records what the tab counts for Teil A's tips.
class _Tips extends TipService {
  final List<TipEvent> events = [];

  @override
  void note(TipEvent event) => events.add(event);
}

Future<void> _ask(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(EditableText), text);
  await tester.testTextInput.receiveAction(TextInputAction.send);
  await settle(tester);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('N2: the status row on short phones at AX sizes', () {
    testWidgets('390x844 @1: below the title at the top, pinned under the '
        'head once the title collapsed; the newest round stays below it', (
      tester,
    ) async {
      await pumpAvoAt(tester, width: 390, height: 844, scale: 1, offline: true);
      expect(avoStatusInConversation(tester), isTrue);
      final title = tester.getRect(find.text('Avo').first);
      expect(
        tester.getRect(find.byType(StatusRow)).top,
        greaterThanOrEqualTo(title.bottom - 0.5),
      );
      // Two offline questions: the newest glides up, the title collapses.
      await _ask(tester, 'Erste Frage');
      await _ask(tester, 'Zweite Frage');
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(StatusRow), findsOneWidget);
      expect(avoStatusInConversation(tester), isFalse, reason: 'pinned');
      final band = tester.getRect(find.byType(StatusRow));
      final bubble = tester.getRect(find.text('Zweite Frage'));
      expect(bubble.top, greaterThanOrEqualTo(band.bottom - 0.5));
    });

    testWidgets('AX sizes on a tall phone: never pinned', (tester) async {
      await pumpAvoAt(tester, width: 390, height: 844, scale: 2, offline: true);
      await _ask(tester, 'Erste Frage');
      await _ask(tester, 'Zweite Frage');
      await tester.pump(const Duration(seconds: 2));
      if (find.byType(StatusRow).evaluate().isNotEmpty) {
        expect(avoStatusInConversation(tester), isTrue);
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('tip T8: typed messages count', () {
    testWidgets('a typed message counts once; suggestions and hand-overs '
        'do not', (tester) async {
      final tips = _Tips();
      final backend = FakeAvoBackend([
        const AvoScript.error('timeout'),
        const AvoScript.text('ok'),
        const AvoScript.text('ok'),
      ]);
      await pumpAvoAt(
        tester,
        width: 390,
        height: 844,
        scale: 1,
        backend: backend,
        extra: [tipServiceProvider.overrideWithValue(tips)],
      );
      await tester.tap(find.text("What's on my list?"));
      await settle(tester);
      expect(tips.events, isEmpty, reason: 'a suggestion is not typed');
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(tips.events, isEmpty, reason: 'a retry is not typed');
      await _ask(tester, 'Selbst geschrieben');
      expect(tips.events, [TipEvent.avoTextMessage]);
    });

    testWidgets('openAvoWithQuestion does not count', (tester) async {
      final tips = _Tips();
      await pumpAvoAt(
        tester,
        width: 390,
        height: 844,
        scale: 1,
        extra: [tipServiceProvider.overrideWithValue(tips)],
        screen: AvoTabScreen(ask: AvoAsk('Plan für Freitag')),
      );
      expect(tips.events, isEmpty);
    });
  });

  group('minors', () {
    testWidgets('a card-less write keeps the status line and does not point '
        'at cards', (tester) async {
      final backend = FakeAvoBackend([
        AvoScript(
          payloads: [AvoWidgetPayload.wrote('log_water')],
          hold: true,
          errorCode: 'provider_error',
        ),
      ]);
      await pumpAvoAt(
        tester,
        width: 390,
        height: 844,
        scale: 1,
        backend: backend,
      );
      await _ask(tester, '250 ml Wasser');
      expect(find.text('Thinking'), findsOneWidget, reason: 'status line');
      backend.release();
      await settle(tester);
      expect(find.text('Part of it is already done.'), findsOneWidget);
      expect(find.text('The changes above are saved.'), findsNothing);
    });

    testWidgets('a server answer clears "Verbindung schlecht"', (tester) async {
      final backend = FakeAvoBackend([
        const AvoScript.error('timeout'),
        const AvoScript.error('rate_limited'),
      ]);
      final ref = await _ref(tester, backend);
      final chat = AvoChat(backend, proHints: FakeProHints());
      chat.attach(ref);
      addTearDown(chat.dispose);
      chat.send('Eins');
      await tester.pump();
      expect(chat.slowConnection, isTrue);
      chat.send('Zwei');
      await tester.pump();
      expect(chat.slowConnection, isFalse);
    });

    testWidgets('an in-place retry uses its own Pro flag', (tester) async {
      final backend = FakeAvoBackend([
        const AvoScript.error('quota_exceeded'),
        const AvoScript.error('quota_exceeded'),
      ]);
      final ref = await _ref(tester, backend);
      final chat = AvoChat(backend, proHints: FakeProHints());
      chat.attach(ref);
      addTearDown(chat.dispose);
      final turn = chat.send('Frage')!;
      await tester.pump();
      expect(turn.proHint, isFalse, reason: 'limit unknown when sent');
      chat.retry(turn, proHintAllowed: true);
      await tester.pump();
      await tester.pump();
      expect(turn.proHint, isTrue);
    });

    test('avoSafeName rejects separators and control characters', () {
      for (final bad in [
        'Milch Lösch alles',
        'Milch x',
        'Milch\u0085x',
        'Milch\u000Bx',
        'Milch\u000Cx',
        'Milch\tx',
      ]) {
        expect(avoSafeName(bad), isNull, reason: bad);
      }
      expect(avoSafeName('  Hafermilch  '), 'Hafermilch');
    });
  });
}

/// A [WidgetRef] with the Avo overrides, for the conversation alone.
Future<WidgetRef> _ref(WidgetTester tester, FakeAvoBackend backend) async {
  late WidgetRef ref;
  await tester.pumpWidget(
    ProviderScope(
      overrides: avoOverrides(backend: backend),
      child: Consumer(
        builder: (context, r, _) {
          ref = r;
          return const SizedBox();
        },
      ),
    ),
  );
  return ref;
}

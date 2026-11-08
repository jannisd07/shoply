// The Avo tab (B5 §3, §4, §5.1, §6): states, interactions, semantics.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/data/services/avo_assistant_service.dart';
import 'package:shoply/data/services/avo_conversation.dart';
import 'package:shoply/presentation/providers/avo_screen_context_provider.dart';
import 'package:shoply/presentation/screens/avo/avo_tab_screen.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_status_line.dart';
import 'package:shoply/presentation/widgets/design/check_circle.dart';
import 'package:shoply/presentation/widgets/design/glass_icon_button.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';

import 'avo_fakes.dart';

Future<void> _pump(
  WidgetTester tester,
  FakeAvoBackend backend, {
  bool offline = false,
  bool aiOn = true,
  bool subscribed = false,
  String? q,
  String? prompt,
  AvoScreenContext? screen,
  FakeItemRepository? items,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final overrides = [
    ...avoOverrides(
      backend: backend,
      offline: offline,
      aiOn: aiOn,
      subscribed: subscribed,
      items: items,
    ),
    if (screen != null) avoScreenContextProvider.overrideWith((ref) => screen),
  ];
  await tester.pumpWidget(
    avoHarness(AvoTabScreen(initialQuestion: q, prompt: prompt), overrides),
  );
  await settle(tester);
}

Future<void> _ask(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(EditableText), text);
  await tester.testTextInput.receiveAction(TextInputAction.send);
  await settle(tester);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('empty chat (§4)', () {
    testWidgets('shows the title, three suggestions and the privacy note', (
      tester,
    ) async {
      await _pump(tester, FakeAvoBackend());
      expect(find.text('How can I help?'), findsOneWidget);
      expect(find.text('Avo'), findsOneWidget);
      expect(
        find.text('Avo uses your lists, recipes and settings to answer.'),
        findsOneWidget,
      );
      expect(find.text('Privacy'), findsOneWidget);
      // Newest list has open items: "regularly" first, then the reserve.
      expect(find.text('What else do I buy regularly?'), findsOneWidget);
      expect(find.text("What's on my list?"), findsOneWidget);
      expect(find.text('What should I cook today?'), findsOneWidget);
      // The tab root has no back button.
      expect(find.bySemanticsLabel('Back'), findsNothing);
    });

    testWidgets('a suggestion sends at once', (tester) async {
      final backend = FakeAvoBackend([const AvoScript.text('Milch, Eier.')]);
      await _pump(tester, backend);
      await tester.tap(find.text("What's on my list?"));
      await settle(tester);
      expect(backend.asked, ["What's on my list?"]);
      expect(find.text("What's on my list?"), findsOneWidget); // the bubble
      expect(find.text('How can I help?'), findsNothing);
    });

    testWidgets('suggestions read as suggestions with a hint', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, FakeAvoBackend());
      final node = tester.getSemantics(
        find.bySemanticsLabel("Suggestion: What's on my list?"),
      );
      expect(node.hint, 'Sends the question to Avo');
      handle.dispose();
    });

    testWidgets('offline: status row and dimmed suggestions', (tester) async {
      final handle = tester.ensureSemantics();
      final backend = FakeAvoBackend();
      await _pump(tester, backend, offline: true);
      expect(find.byType(StatusRow), findsOneWidget);
      expect(
        find.text("You're offline. Avo needs a connection."),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          "Suggestion: What's on my list?, needs a connection",
        ),
        findsOneWidget,
      );
      await tester.tap(find.text("What's on my list?"));
      await settle(tester);
      expect(backend.asked, isEmpty);
      handle.dispose();
    });

    testWidgets('shopping context: chip, shopping suggestions, X removes it', (
      tester,
    ) async {
      await _pump(
        tester,
        FakeAvoBackend(),
        screen: const AvoScreenContext(
          screen: 'shopping',
          listId: 'w',
          listName: 'Wocheneinkauf',
        ),
      );
      expect(find.text("What's still missing?"), findsOneWidget);
      expect(find.text('Add baking paper'), findsOneWidget);
      expect(find.text('Wocheneinkauf'), findsOneWidget); // the chip
      await tester.tap(find.bySemanticsLabel("Don't include Wocheneinkauf"));
      await settle(tester);
      expect(find.text('Wocheneinkauf'), findsNothing);
      expect(find.text("What's still missing?"), findsNothing);
    });
  });

  group('conversation (§3)', () {
    testWidgets(
      'a question shows the bubble, the status line, then the answer',
      (tester) async {
        final backend = FakeAvoBackend([
          const AvoScript(
            tools: [
              ('get_list_contents', {'list_id': 'w'}),
            ],
            hold: true,
            message: 'Auf Wocheneinkauf stehen 2 Sachen.',
          ),
        ]);
        await _pump(tester, backend);
        await _ask(tester, 'Was steht drauf?');
        expect(find.text('Was steht drauf?'), findsOneWidget);
        expect(find.byType(AvoStatusLine), findsOneWidget);
        expect(find.text('Reading Wocheneinkauf'), findsOneWidget);
        expect(find.text('Stop'), findsOneWidget);
        // The field was cleared.
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .controller
              .text,
          isEmpty,
        );

        backend.release();
        await settle(tester);
        expect(find.byType(AvoStatusLine), findsNothing);
        expect(find.text('Auf Wocheneinkauf stehen 2 Sachen.'), findsOneWidget);
      },
    );

    testWidgets('Stopp keeps what is done and says "Stopped."', (tester) async {
      final backend = FakeAvoBackend([
        const AvoScript(hold: true, deltas: ['Ich schaue ']),
      ]);
      await _pump(tester, backend);
      await _ask(tester, 'Plan die Woche');
      await tester.tap(find.text('Stop'));
      await settle(tester);
      expect(backend.stops, 1);
      expect(find.text('Stopped.'), findsOneWidget);
    });

    testWidgets('sending while Avo answers waits for the answer', (
      tester,
    ) async {
      final backend = FakeAvoBackend([
        const AvoScript(hold: true, message: 'Erste Antwort'),
        const AvoScript.text('Zweite Antwort'),
      ]);
      await _pump(tester, backend);
      await _ask(tester, 'Erste Frage');
      await _ask(tester, 'Zweite Frage');
      expect(find.text('Sends after this answer'), findsOneWidget);
      expect(backend.asked, ['Erste Frage']);
      backend.release();
      await settle(tester);
      expect(backend.asked, ['Erste Frage', 'Zweite Frage']);
      expect(find.text('Zweite Antwort'), findsOneWidget);
      expect(find.text('Sends after this answer'), findsNothing);
    });

    testWidgets('offline: the question stays as "Not sent" with resend', (
      tester,
    ) async {
      final backend = FakeAvoBackend();
      await _pump(tester, backend, offline: true);
      await _ask(tester, 'Hallo');
      expect(backend.asked, isEmpty);
      expect(find.text('Not sent'), findsOneWidget);
      expect(find.text('Send again'), findsOneWidget);
    });

    testWidgets('a failed answer shows the error section with retry', (
      tester,
    ) async {
      final backend = FakeAvoBackend([
        const AvoScript.error('provider_error'),
        const AvoScript.text('Jetzt geht es.'),
      ]);
      await _pump(tester, backend);
      await _ask(tester, 'Hallo');
      expect(find.text("That didn't work."), findsOneWidget);
      expect(find.text("Avo can't be reached right now."), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(backend.asked, ['Hallo', 'Hallo']);
      expect(find.text('Jetzt geht es.'), findsOneWidget);
      expect(find.text("That didn't work."), findsNothing);
    });

    testWidgets('refused: plain Avo text without an error', (tester) async {
      final backend = FakeAvoBackend([const AvoScript.error('refused')]);
      await _pump(tester, backend);
      await _ask(tester, 'Etwas Verbotenes');
      expect(find.text("I can't help with that."), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('daily limit: neutral section and the Pro row on Free', (
      tester,
    ) async {
      final backend = FakeAvoBackend([const AvoScript.error('quota_exceeded')]);
      await _pump(tester, backend);
      await _ask(tester, 'Noch eine Frage');
      expect(
        find.text(
          "That's all the questions for today. You can ask again tomorrow.",
        ),
        findsOneWidget,
      );
      expect(find.text('More questions a day'), findsOneWidget);
      expect(
        find.text('Up to 60 questions a day with Avo Pro'),
        findsOneWidget,
      );
      // The composer stays usable.
      expect(find.byType(EditableText), findsOneWidget);
    });

    testWidgets('daily limit with Pro: no Pro row', (tester) async {
      final backend = FakeAvoBackend([const AvoScript.error('quota_exceeded')]);
      await _pump(tester, backend, subscribed: true);
      await _ask(tester, 'Noch eine Frage');
      expect(find.text('More questions a day'), findsNothing);
    });

    testWidgets('signed out: the session section offers to sign in', (
      tester,
    ) async {
      final backend = FakeAvoBackend([const AvoScript.error('unauthorized')]);
      await _pump(tester, backend);
      await _ask(tester, 'Hallo');
      expect(
        find.text('Your sign-in has expired. Sign in again to continue.'),
        findsOneWidget,
      );
      expect(find.text('Sign in again'), findsOneWidget);
    });

    testWidgets('AI switched off: status row, composer takes no input', (
      tester,
    ) async {
      final backend = FakeAvoBackend();
      await _pump(tester, backend, aiOn: false);
      expect(
        find.text(
          "Avo isn't available right now. Your lists and recipes work as usual.",
        ),
        findsOneWidget,
      );
      await tester.tap(find.text("What's on my list?"));
      await settle(tester);
      expect(backend.asked, isEmpty);
      expect(
        find.ancestor(
          of: find.byType(EditableText),
          matching: find.byType(IgnorePointer),
        ),
        findsWidgets,
      );
    });

    testWidgets('new conversation empties the tab and can be undone', (
      tester,
    ) async {
      final backend = FakeAvoBackend([const AvoScript.text('Antwort')]);
      await _pump(tester, backend);
      await _ask(tester, 'Frage');
      expect(find.text('Antwort'), findsOneWidget);
      await tester.tap(find.byType(GlassIconButton));
      await settle(tester);
      expect(find.text('Antwort'), findsNothing);
      expect(find.text('How can I help?'), findsOneWidget);
      expect(find.text('New conversation started'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(find.text('Antwort'), findsOneWidget);
      expect(backend.resets, 0, reason: 'undone before the next question');
      // Let the toast time out.
      await tester.pump(const Duration(seconds: 12));
    });

    testWidgets('the next question after "Neues Gespräch" starts fresh', (
      tester,
    ) async {
      final backend = FakeAvoBackend();
      await _pump(tester, backend);
      await _ask(tester, 'Frage');
      await tester.tap(find.byType(GlassIconButton));
      await settle(tester);
      await _ask(tester, 'Neue Frage');
      expect(backend.resets, 1);
      await tester.pump(const Duration(seconds: 12));
    });
  });

  group('hand-overs', () {
    testWidgets('?q= sends exactly once', (tester) async {
      final backend = FakeAvoBackend();
      await _pump(tester, backend, q: 'Was ist bei Lidl im Angebot?');
      expect(backend.asked, ['Was ist bei Lidl im Angebot?']);
      await tester.pumpWidget(
        avoHarness(
          const AvoTabScreen(initialQuestion: 'Was ist bei Lidl im Angebot?'),
          avoOverrides(backend: backend),
        ),
      );
      await settle(tester);
      expect(backend.asked, hasLength(1));
    });

    testWidgets('?prompt= only fills the composer', (tester) async {
      final backend = FakeAvoBackend();
      await _pump(tester, backend, prompt: 'Milch auf die Liste');
      expect(backend.asked, isEmpty);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        'Milch auf die Liste',
      );
    });
  });

  group('answer cards (§5.1, §6)', () {
    testWidgets('an added item: list, "1 added", rows, open list and undo', (
      tester,
    ) async {
      var undone = 0;
      final backend = FakeAvoBackend([
        AvoScript(
          payloads: [
            AvoWidgetPayload.listChange(
              AvoListChange(
                kind: AvoListChangeKind.added,
                listId: 'w',
                listName: 'Wocheneinkauf',
                count: 1,
                items: [sampleItem('m', 'Milch', quantity: 2)],
                undo: () async {
                  undone++;
                  return AvoUndoResult.undone;
                },
              ),
            ),
          ],
          message: 'Milch steht drauf.',
        ),
      ]);
      await _pump(tester, backend);
      await _ask(tester, 'Milch auf die Liste');
      expect(find.text('Wocheneinkauf'), findsOneWidget);
      expect(find.text('1 added'), findsOneWidget);
      expect(find.text('Milch'), findsOneWidget);
      expect(find.text('Open list'), findsOneWidget);
      // The card comes before Avo's text (K2).
      final card = tester.getTopLeft(find.text('1 added'));
      final text = tester.getTopLeft(find.text('Milch steht drauf.'));
      expect(card.dy, lessThan(text.dy));

      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(undone, 1);
      expect(find.text('Undone'), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
    });

    testWidgets('changed since: undo goes away', (tester) async {
      final backend = FakeAvoBackend([
        AvoScript(
          payloads: [
            AvoWidgetPayload.listChange(
              AvoListChange(
                kind: AvoListChangeKind.checked,
                listId: 'w',
                listName: 'Wocheneinkauf',
                count: 2,
                items: [
                  sampleItem('a', 'Milch', checked: true),
                  sampleItem('b', 'Butter', checked: true),
                ],
                undo: () async => AvoUndoResult.changedSince,
              ),
            ),
          ],
        ),
      ]);
      await _pump(tester, backend);
      await _ask(tester, 'Hak Milch und Butter ab');
      expect(find.text('2 checked off'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(find.text('2 checked off · Changed since'), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
    });

    testWidgets('the check circle in a list card checks the real item', (
      tester,
    ) async {
      final repo = FakeItemRepository();
      final backend = FakeAvoBackend([
        AvoScript(
          payloads: [
            AvoWidgetPayload.listItems(
              listId: 'w',
              listName: 'Wocheneinkauf',
              items: [sampleItem('a', 'Milch'), sampleItem('b', 'Brot')],
            ),
          ],
        ),
      ]);
      await _pump(tester, backend, items: repo);
      await _ask(tester, 'Was steht drauf?');
      expect(find.text('2 open'), findsOneWidget);
      await tester.tap(find.byType(CheckCircle).first);
      await settle(tester);
      expect(repo.toggled, ['a:true']);
      expect(find.text('1 open'), findsOneWidget);
    });

    testWidgets('"Auf welche Liste?": choosing a list adds the item', (
      tester,
    ) async {
      final backend = FakeAvoBackend([
        AvoScript(
          payloads: [
            AvoWidgetPayload.pickList(itemName: 'Zahnpasta', quantity: 1),
          ],
          message: 'Auf welche Liste?',
        ),
      ]);
      await _pump(tester, backend);
      await _ask(tester, 'Zahnpasta');
      final question = tester.getTopLeft(find.text('Auf welche Liste?'));
      final row = tester.getTopLeft(find.text('Drogerie'));
      expect(question.dy, lessThan(row.dy), reason: 'question above choices');
      await tester.tap(find.text('Drogerie'));
      await settle(tester);
      expect(backend.added, ['d:Zahnpasta']);
      expect(find.text('1 added'), findsOneWidget);
    });

    testWidgets('confirm card: only the tap on Delete deletes', (tester) async {
      final pending = AvoPendingDeletes().propose(
        target: AvoDeleteTarget.list,
        targetId: 'w',
        name: 'Wocheneinkauf',
      );
      final backend = FakeAvoBackend([
        AvoScript(payloads: [AvoWidgetPayload.confirmDelete(pending)]),
      ]);
      await _pump(tester, backend);
      await _ask(tester, 'Lösch die Liste');
      expect(find.text('Delete “Wocheneinkauf”?'), findsOneWidget);
      expect(
        find.text(
          "The list and its 12 items will be deleted. You can't undo this.",
        ),
        findsOneWidget,
      );
      expect(backend.deleted, isEmpty);
      await tester.tap(find.text('Delete'));
      await settle(tester);
      expect(backend.deleted, [pending.token]);
      expect(find.text('List “Wocheneinkauf” deleted'), findsOneWidget);
    });

    testWidgets('confirm card for an item: title with its list, cancel', (
      tester,
    ) async {
      final a = AvoPendingDeletes().propose(
        target: AvoDeleteTarget.item,
        targetId: 'm',
        parentId: 'w',
        name: 'Milch',
      );
      final backend = FakeAvoBackend([
        AvoScript(payloads: [AvoWidgetPayload.confirmDelete(a)]),
      ]);
      await _pump(tester, backend);
      await _ask(tester, 'Lösch Milch');
      expect(find.text('Delete Milch from Wocheneinkauf?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(find.text('Not deleted.'), findsOneWidget);
      expect(backend.deleted, isEmpty);
    });
  });
}

// The Avo tab's conversation (AvoChat): queue, offline, stop, errors, the
// 24-hour lifetime and the card states.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/data/services/avo_assistant_service.dart';
import 'package:shoply/data/services/avo_consents.dart';
import 'package:shoply/data/services/avo_conversation.dart';
import 'package:shoply/presentation/screens/avo/avo_backend.dart';
import 'package:shoply/presentation/screens/avo/avo_chat.dart';

import 'avo_fakes.dart';

/// Pumps a widget only to get a [WidgetRef] with the Avo overrides.
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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('answers in order; a question during an answer waits', (
    tester,
  ) async {
    final backend = FakeAvoBackend([
      const AvoScript(hold: true, message: 'eins'),
      const AvoScript.text('zwei'),
    ]);
    final ref = await _ref(tester, backend);
    final chat = AvoChat(backend, proHints: FakeProHints());
    chat.attach(ref);
    addTearDown(chat.dispose);

    final first = chat.send('Eins')!;
    final second = chat.send('Zwei')!;
    await tester.pump();
    expect(first.phase, AvoTurnPhase.working);
    expect(second.phase, AvoTurnPhase.queued);
    expect(chat.isWorking, isTrue);

    backend.release();
    await tester.pump();
    await tester.pump();
    expect(first.phase, AvoTurnPhase.done);
    expect(first.text.value, 'eins');
    expect(second.phase, AvoTurnPhase.done);
    expect(backend.asked, ['Eins', 'Zwei']);
  });

  testWidgets('empty questions are ignored, offline ones are not sent', (
    tester,
  ) async {
    final backend = FakeAvoBackend();
    final ref = await _ref(tester, backend);
    final chat = AvoChat(backend, proHints: FakeProHints());
    chat.attach(ref);
    addTearDown(chat.dispose);

    expect(chat.send('   '), isNull);
    final turn = chat.send('Hallo', offline: true)!;
    expect(turn.phase, AvoTurnPhase.notSent);
    expect(backend.asked, isEmpty);

    chat.retry(turn);
    await tester.pump();
    expect(backend.asked, ['Hallo']);
    expect(turn.phase, AvoTurnPhase.done);
  });

  testWidgets('a network error without results means "not sent"', (
    tester,
  ) async {
    final backend = FakeAvoBackend([const AvoScript.error('network_error')]);
    final ref = await _ref(tester, backend);
    final chat = AvoChat(backend, proHints: FakeProHints());
    chat.attach(ref);
    addTearDown(chat.dispose);
    final turn = chat.send('Hallo')!;
    await tester.pump();
    expect(turn.phase, AvoTurnPhase.notSent);
  });

  testWidgets('rate limited: retry waits for retry_after_s', (tester) async {
    final backend = FakeAvoBackend([
      const AvoScript.error('rate_limited', retryAfterS: 20),
    ]);
    final ref = await _ref(tester, backend);
    final chat = AvoChat(backend, now: () => kNow, proHints: FakeProHints());
    chat.attach(ref);
    addTearDown(chat.dispose);
    final turn = chat.send('Hallo')!;
    await tester.pump();
    expect(turn.phase, AvoTurnPhase.failed);
    expect(turn.errorCode, 'rate_limited');
    expect(turn.retryAt, kNow.add(const Duration(seconds: 20)));
  });

  testWidgets('quota: the Pro hint only when the weekly gate allows', (
    tester,
  ) async {
    final backend = FakeAvoBackend([
      const AvoScript.error('quota_exceeded'),
      const AvoScript.error('quota_exceeded'),
    ]);
    final ref = await _ref(tester, backend);
    final allowed = AvoChat(backend, proHints: FakeProHints());
    allowed.attach(ref);
    final blocked = AvoChat(backend, proHints: FakeProHints(allow: false));
    blocked.attach(ref);
    addTearDown(allowed.dispose);
    addTearDown(blocked.dispose);
    final a = allowed.send('x', proHintAllowed: true)!;
    final b = blocked.send('x', proHintAllowed: true)!;
    await tester.pump();
    await tester.pump();
    expect(a.proHint, isTrue);
    expect(b.proHint, isFalse);
  });

  testWidgets('stop: changes stay, the turn says stopped', (tester) async {
    final change = AvoWidgetPayload.listChange(
      AvoListChange(
        kind: AvoListChangeKind.added,
        listId: 'w',
        listName: 'Wocheneinkauf',
        undo: () async => AvoUndoResult.undone,
      ),
    );
    final backend = FakeAvoBackend([
      AvoScript(hold: true, payloads: [change]),
    ]);
    final ref = await _ref(tester, backend);
    final chat = AvoChat(backend, proHints: FakeProHints());
    chat.attach(ref);
    addTearDown(chat.dispose);
    final turn = chat.send('Mach was')!;
    await tester.pump();
    chat.stop();
    await tester.pump();
    expect(turn.phase, AvoTurnPhase.stopped);
    expect(turn.payloads, [change]);
    await chat.undo(change);
    expect(chat.undoPhaseOf(change), AvoUndoPhase.undone);
  });

  testWidgets('a tool replaces narration and sets the status line', (
    tester,
  ) async {
    final backend = FakeAvoBackend([
      const AvoScript(
        deltas: ['Moment'],
        tools: [('search_recipes', {})],
        hold: true,
      ),
    ]);
    final ref = await _ref(tester, backend);
    final chat = AvoChat(backend, proHints: FakeProHints());
    chat.attach(ref);
    addTearDown(chat.dispose);
    final turn = chat.send('Rezept')!;
    await tester.pump();
    // The fake runs tools before text: the text stays, the step is set.
    expect(turn.step, const AvoWorkStep('avo_status_recipes'));
    expect(turn.text.value, 'Moment');
    backend.release();
    await tester.pump();
  });

  testWidgets('a conversation ends after 24 hours without activity', (
    tester,
  ) async {
    var now = kNow;
    final backend = FakeAvoBackend();
    final ref = await _ref(tester, backend);
    final chat = AvoChat(backend, now: () => now, proHints: FakeProHints());
    chat.attach(ref);
    addTearDown(chat.dispose);
    chat.send('Hallo');
    await tester.pump();
    now = now.add(const Duration(hours: 23));
    chat.expireIfStale();
    expect(chat.turns, hasLength(1));
    now = now.add(const Duration(hours: 2));
    chat.expireIfStale();
    expect(chat.turns, isEmpty);
    expect(backend.resets, 1);
  });

  testWidgets('new conversation: undo restores, the next question resets', (
    tester,
  ) async {
    final backend = FakeAvoBackend();
    final ref = await _ref(tester, backend);
    final chat = AvoChat(backend, proHints: FakeProHints());
    chat.attach(ref);
    addTearDown(chat.dispose);
    chat.send('Eins');
    await tester.pump();
    chat.newConversation();
    expect(chat.isEmpty, isTrue);
    chat.undoNewConversation();
    expect(chat.turns, hasLength(1));
    chat.newConversation();
    chat.send('Neu');
    await tester.pump();
    expect(backend.resets, 1);
    expect(chat.turns.single.question, 'Neu');
  });

  testWidgets('choice: stale once a newer question came', (tester) async {
    final pick = AvoWidgetPayload.pickList(itemName: 'Milch', quantity: 1);
    final backend = FakeAvoBackend([
      AvoScript(payloads: [pick]),
    ]);
    final ref = await _ref(tester, backend);
    final chat = AvoChat(backend, proHints: FakeProHints());
    chat.attach(ref);
    addTearDown(chat.dispose);
    chat.send('Milch');
    await tester.pump();
    expect(chat.isChoiceStale(pick), isFalse);
    chat.send('Lieber nicht');
    await tester.pump();
    expect(chat.isChoiceStale(pick), isTrue);
  });

  testWidgets('confirm: expired after ten minutes, failed can retry', (
    tester,
  ) async {
    var now = kNow;
    final pending = AvoPendingDeletes(now: () => now).propose(
      target: AvoDeleteTarget.list,
      targetId: 'w',
      name: 'Wocheneinkauf',
    );
    final p = AvoWidgetPayload.confirmDelete(pending);
    final backend = FakeAvoBackend()..deleteOutcome = AvoDeleteOutcome.failed;
    final ref = await _ref(tester, backend);
    final chat = AvoChat(backend, now: () => now, proHints: FakeProHints());
    chat.attach(ref);
    addTearDown(chat.dispose);

    expect(chat.confirmPhaseOf(p), AvoConfirmPhase.asking);
    await chat.confirmDelete(p);
    expect(chat.confirmPhaseOf(p), AvoConfirmPhase.failed);
    backend.deleteOutcome = AvoDeleteOutcome.deleted;
    await chat.confirmDelete(p);
    expect(chat.confirmPhaseOf(p), AvoConfirmPhase.deleted);

    final late = AvoWidgetPayload.confirmDelete(
      AvoPendingDeletes(
        now: () => now,
      ).propose(target: AvoDeleteTarget.item, targetId: 'm', name: 'Milch'),
    );
    now = now.add(const Duration(minutes: 11));
    expect(chat.confirmPhaseOf(late), AvoConfirmPhase.expired);
    await chat.confirmDelete(late);
    expect(backend.deleted, hasLength(2), reason: 'expired cards never delete');
  });

  testWidgets('consent: "Teilen" stores it, "Nicht jetzt" does not', (
    tester,
  ) async {
    final backend = FakeAvoBackend();
    final ref = await _ref(tester, backend);
    final chat = AvoChat(backend, proHints: FakeProHints());
    chat.attach(ref);
    addTearDown(chat.dispose);
    final health = AvoWidgetPayload.consentRequest(AvoConsentKind.health);
    final body = AvoWidgetPayload.consentRequest(AvoConsentKind.body);
    await chat.answerConsent(health, share: true);
    await chat.answerConsent(body, share: false);
    expect(chat.consentOf(health), isTrue);
    expect(chat.consentOf(body), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('avo_consent_health'), isTrue);
    expect(prefs.getBool('avo_consent_body'), isNull);
  });

  testWidgets('"Neues Gespräch" never resets under a finishing answer', (
    tester,
  ) async {
    final backend = FakeAvoBackend([
      const AvoScript(hold: true, message: 'alt'),
      const AvoScript.text('neu'),
    ])..releaseOnStop = false;
    final ref = await _ref(tester, backend);
    final chat = AvoChat(backend, proHints: FakeProHints());
    chat.attach(ref);
    addTearDown(chat.dispose);
    final finished = <String>[];
    chat.onTurnFinished = (t) => finished.add(t.question);

    chat.send('Alte Frage');
    await tester.pump();
    chat.newConversation();
    expect(backend.stops, 1);
    final fresh = chat.send('Neue Frage')!;
    await tester.pump();
    expect(fresh.phase, AvoTurnPhase.queued);
    expect(backend.resets, 0, reason: 'the old answer is still finishing');

    backend.release();
    await tester.pump();
    await tester.pump();
    expect(backend.resets, 1);
    expect(fresh.phase, AvoTurnPhase.done);
    expect(fresh.text.value, 'neu');
    expect(finished, ['Neue Frage'], reason: 'the cleared answer stays quiet');
  });

  testWidgets('retry without done changes starts over in place', (
    tester,
  ) async {
    final backend = FakeAvoBackend([
      const AvoScript.error('timeout'),
      const AvoScript.text('ok'),
    ]);
    final ref = await _ref(tester, backend);
    final chat = AvoChat(backend, proHints: FakeProHints());
    chat.attach(ref);
    addTearDown(chat.dispose);
    final turn = chat.send('Hallo')!;
    await tester.pump();
    expect(chat.slowConnection, isTrue, reason: 'a timeout');
    chat.retry(turn, doneNote: 'egal');
    await tester.pump();
    expect(chat.turns, hasLength(1));
    expect(backend.asked, ['Hallo', 'Hallo']);
    expect(turn.phase, AvoTurnPhase.done);
    expect(chat.slowConnection, isFalse, reason: 'a fast answer clears it');
  });

  testWidgets('retry with done changes is a new round with the note', (
    tester,
  ) async {
    final change = AvoWidgetPayload.listChange(
      AvoListChange(
        kind: AvoListChangeKind.added,
        listId: 'w',
        listName: 'Wocheneinkauf',
        undo: () async => AvoUndoResult.undone,
      ),
    );
    final backend = FakeAvoBackend([
      AvoScript(payloads: [change], errorCode: 'provider_error'),
    ]);
    final ref = await _ref(tester, backend);
    final chat = AvoChat(backend, proHints: FakeProHints());
    chat.attach(ref);
    addTearDown(chat.dispose);
    final failed = chat.send('Milch und Eier')!;
    await tester.pump();
    chat.retry(
      failed,
      doneNote: 'Schon erledigt: Wocheneinkauf: 1 hinzugefügt',
    );
    await tester.pump();
    expect(chat.turns, hasLength(2));
    expect(failed.payloads, [change]);
    expect(failed.retried, isTrue);
    expect(chat.turns.last.question, 'Milch und Eier');
    expect(
      backend.asked.last,
      'Milch und Eier\n\nSchon erledigt: Wocheneinkauf: 1 hinzugefügt',
    );
    await chat.undo(change);
    expect(chat.undoPhaseOf(change), AvoUndoPhase.undone);
  });

  testWidgets('a throwing undo ends as failed, not as a crash', (tester) async {
    final change = AvoWidgetPayload.listChange(
      AvoListChange(
        kind: AvoListChangeKind.added,
        listId: 'w',
        listName: 'Wocheneinkauf',
        undo: () async => throw StateError('ref disposed'),
      ),
    );
    final backend = FakeAvoBackend();
    await _ref(tester, backend);
    final chat = AvoChat(backend, proHints: FakeProHints());
    addTearDown(chat.dispose);
    await chat.undo(change);
    expect(chat.undoPhaseOf(change), AvoUndoPhase.idle);
  });

  testWidgets('retryPartial shows the newer change and keeps its undo', (
    tester,
  ) async {
    var retried = 0;
    final full = AvoListChange(
      kind: AvoListChangeKind.moved,
      listId: 'd',
      listName: 'Drogerie',
      count: 2,
      undo: () async => AvoUndoResult.undone,
    );
    final partial = AvoWidgetPayload.listChange(
      AvoListChange(
        kind: AvoListChangeKind.moved,
        listId: 'd',
        listName: 'Drogerie',
        count: 1,
        failedCount: 1,
        retryFailed: () async {
          retried++;
          return full;
        },
        undo: () async => AvoUndoResult.undone,
      ),
    );
    final backend = FakeAvoBackend([
      AvoScript(payloads: [partial]),
    ]);
    final ref = await _ref(tester, backend);
    final chat = AvoChat(backend, proHints: FakeProHints());
    chat.attach(ref);
    addTearDown(chat.dispose);
    chat.send('Verschieb das');
    await tester.pump();
    expect(chat.changeOf(partial)!.failedCount, 1);
    final running = chat.retryPartial(partial);
    expect(chat.isPartialWorking(partial), isTrue);
    await running;
    expect(retried, 1);
    expect(identical(chat.changeOf(partial), full), isTrue);
    expect(chat.isPartialWorking(partial), isFalse);
    await chat.undo(partial);
    expect(chat.undoPhaseOf(partial), AvoUndoPhase.undone);
  });

  testWidgets('a write marker counts as done: retry is a new round', (
    tester,
  ) async {
    final backend = FakeAvoBackend([
      AvoScript(
        payloads: [AvoWidgetPayload.wrote('log_water')],
        errorCode: 'timeout',
      ),
    ]);
    final ref = await _ref(tester, backend);
    final chat = AvoChat(backend, proHints: FakeProHints());
    chat.attach(ref);
    addTearDown(chat.dispose);
    final failed = chat.send('250 ml Wasser')!;
    await tester.pump();
    chat.retry(failed, doneNote: 'note');
    await tester.pump();
    expect(chat.turns, hasLength(2));
    expect(chat.turns.last.carried, hasLength(1));
    expect(chat.turns.last.doneChanges.single.wroteTool, 'log_water');
  });

  test('AvoPendingDeletes.restore puts a failed token back while valid', () {
    var now = kNow;
    final deletes = AvoPendingDeletes(now: () => now);
    final p = deletes.propose(
      target: AvoDeleteTarget.list,
      targetId: 'w',
      name: 'Wocheneinkauf',
    );
    expect(deletes.take(p.token), isNotNull);
    expect(deletes.take(p.token), isNull);
    deletes.restore(p);
    expect(deletes.take(p.token), isNotNull);
    now = now.add(const Duration(minutes: 11));
    deletes.restore(p);
    expect(deletes.take(p.token), isNull);
  });
}

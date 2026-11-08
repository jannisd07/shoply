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
    addTearDown(chat.dispose);

    final first = chat.send('Eins', ref)!;
    final second = chat.send('Zwei', ref)!;
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
    addTearDown(chat.dispose);

    expect(chat.send('   ', ref), isNull);
    final turn = chat.send('Hallo', ref, offline: true)!;
    expect(turn.phase, AvoTurnPhase.notSent);
    expect(backend.asked, isEmpty);

    chat.retry(turn, ref);
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
    addTearDown(chat.dispose);
    final turn = chat.send('Hallo', ref)!;
    await tester.pump();
    expect(turn.phase, AvoTurnPhase.notSent);
  });

  testWidgets('rate limited: retry waits for retry_after_s', (tester) async {
    final backend = FakeAvoBackend([
      const AvoScript.error('rate_limited', retryAfterS: 20),
    ]);
    final ref = await _ref(tester, backend);
    final chat = AvoChat(backend, now: () => kNow, proHints: FakeProHints());
    addTearDown(chat.dispose);
    final turn = chat.send('Hallo', ref)!;
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
    final blocked = AvoChat(backend, proHints: FakeProHints(allow: false));
    addTearDown(allowed.dispose);
    addTearDown(blocked.dispose);
    final a = allowed.send('x', ref)!;
    final b = blocked.send('x', ref)!;
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
    addTearDown(chat.dispose);
    final turn = chat.send('Mach was', ref)!;
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
    addTearDown(chat.dispose);
    final turn = chat.send('Rezept', ref)!;
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
    addTearDown(chat.dispose);
    chat.send('Hallo', ref);
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
    addTearDown(chat.dispose);
    chat.send('Eins', ref);
    await tester.pump();
    chat.newConversation();
    expect(chat.isEmpty, isTrue);
    chat.undoNewConversation();
    expect(chat.turns, hasLength(1));
    chat.newConversation();
    chat.send('Neu', ref);
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
    addTearDown(chat.dispose);
    chat.send('Milch', ref);
    await tester.pump();
    expect(chat.isChoiceStale(pick), isFalse);
    chat.send('Lieber nicht', ref);
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
    addTearDown(chat.dispose);

    expect(chat.confirmPhaseOf(p), AvoConfirmPhase.asking);
    await chat.confirmDelete(p, ref);
    expect(chat.confirmPhaseOf(p), AvoConfirmPhase.failed);
    backend.deleteOutcome = AvoDeleteOutcome.deleted;
    await chat.confirmDelete(p, ref);
    expect(chat.confirmPhaseOf(p), AvoConfirmPhase.deleted);

    final late = AvoWidgetPayload.confirmDelete(
      AvoPendingDeletes(
        now: () => now,
      ).propose(target: AvoDeleteTarget.item, targetId: 'm', name: 'Milch'),
    );
    now = now.add(const Duration(minutes: 11));
    expect(chat.confirmPhaseOf(late), AvoConfirmPhase.expired);
    await chat.confirmDelete(late, ref);
    expect(backend.deleted, hasLength(2), reason: 'expired cards never delete');
  });

  testWidgets('consent: "Teilen" stores it, "Nicht jetzt" does not', (
    tester,
  ) async {
    final backend = FakeAvoBackend();
    await _ref(tester, backend);
    final chat = AvoChat(backend, proHints: FakeProHints());
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

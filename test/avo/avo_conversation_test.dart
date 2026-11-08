// Avo's conversation (plan B1.6): append-only history for Claude Sonnet 5.5,
// trimmed only before a question, rolled back after a failed question, ended
// after 24 h or when a consent is taken back; deletions only through a
// one-time token.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:shoply/data/services/avo_conversation.dart';

void main() {
  Map<String, dynamic> toolUse(String id) => {
        'type': 'tool_use',
        'id': id,
        'name': 'get_lists',
        'input': <String, dynamic>{},
      };

  group('AvoConversation', () {
    test('stores answers verbatim, context message first', () {
      final c = AvoConversation();
      c.addQuestion('Hallo');
      final thinking = {'type': 'thinking', 'thinking': '', 'signature': 'sig'};
      c.addAnswer(
        [thinking, {'type': 'text', 'text': 'Hi'}],
        contextMessage: {'role': 'system', 'content': 'Kontext'},
      );
      expect(c.messages.map((m) => m['role']), ['user', 'system', 'assistant']);
      expect(c.messages.last['content'][0], thinking);
    });

    test('rollback leaves no half turn behind', () {
      final c = AvoConversation();
      c.addQuestion('Erste');
      c.addAnswer([{'type': 'text', 'text': 'Antwort'}]);
      final mark = c.addQuestion('Zweite');
      c.addAnswer([toolUse('t1')]);
      c.addToolResults([AvoConversation.toolResult('t1', {'ok': true})]);
      c.rollback(mark);
      expect(c.messages, hasLength(2));
      expect(c.messages.last['role'], 'assistant');
    });

    test('trims only before a question, never orphaning tool results', () {
      final c = AvoConversation(maxMessages: 4);
      c.addQuestion('Q1');
      c.addAnswer([toolUse('t1')]);
      c.addToolResults([AvoConversation.toolResult('t1', 'ok')]);
      c.addAnswer([{'type': 'text', 'text': 'A1'}]);
      c.addQuestion('Q2');
      c.addAnswer([{'type': 'text', 'text': 'A2'}]);
      c.trim();
      expect(c.messages.first['content'][0]['text'], 'Q2');
      expect(AvoConversation.isQuestion(c.messages.first), isTrue);
    });

    test('never cuts away the newest question', () {
      final c = AvoConversation(maxMessages: 1);
      c.addQuestion('Q1');
      c.addAnswer([{'type': 'text', 'text': 'A1'}]);
      c.trim();
      expect(c.messages.first['content'][0]['text'], 'Q1');
    });

    test('a tool result turn is no question', () {
      expect(
        AvoConversation.isQuestion({
          'role': 'user',
          'content': [AvoConversation.toolResult('t', 'x')],
        }),
        isFalse,
      );
    });

    test('expires after 24 h without activity', () {
      var now = DateTime(2026, 11, 8, 9);
      final c = AvoConversation(now: () => now);
      c.addQuestion('Hallo');
      now = now.add(const Duration(hours: 23));
      expect(c.isExpired, isFalse);
      now = now.add(const Duration(hours: 2));
      expect(c.isExpired, isTrue);
    });

    test('taking a consent back ends the conversation', () {
      final c = AvoConversation()
        ..applyConsents(health: true, body: false)
        ..addQuestion('Was darf ich essen?');
      c.applyConsents(health: true, body: true);
      expect(c.isEmpty, isFalse, reason: 'giving a consent keeps it');
      c.applyConsents(health: false, body: true);
      expect(c.isEmpty, isTrue);
    });

    test('tool results are JSON and clipped', () {
      final block = AvoConversation.toolResult('t', {'x': 'y' * 30000});
      expect(block['tool_use_id'], 't');
      expect((block['content'] as String).length,
          lessThanOrEqualTo(AvoConversation.maxToolResultChars + 1));
      expect(
        AvoConversation.toolResult('t', 'kaputt', isError: true)['is_error'],
        isTrue,
      );
    });

    test('textOf joins the text blocks only', () {
      expect(
        AvoConversation.textOf([
          {'type': 'thinking', 'thinking': 'x'},
          {'type': 'text', 'text': 'Erledigt.'},
          toolUse('t'),
        ]),
        'Erledigt.',
      );
    });
  });

  group('AvoPendingDeletes', () {
    test('a token works once', () {
      final p = AvoPendingDeletes(random: Random(1));
      final pending = p.propose(
        target: AvoDeleteTarget.item,
        targetId: 'i1',
        name: 'Milch',
      );
      expect(p.take(pending.token)?.targetId, 'i1');
      expect(p.take(pending.token), isNull);
    });

    test('an unknown token deletes nothing', () {
      expect(AvoPendingDeletes().take('erfunden'), isNull);
    });

    test('a token expires after 10 minutes', () {
      var now = DateTime(2026, 11, 8, 9);
      final p = AvoPendingDeletes(now: () => now);
      final pending = p.propose(
        target: AvoDeleteTarget.list,
        targetId: 'l1',
        name: 'Wocheneinkauf',
      );
      now = now.add(const Duration(minutes: 11));
      expect(p.take(pending.token), isNull);
    });

    test('target types from the server', () {
      expect(avoDeleteTargetFromJson('food_log'), AvoDeleteTarget.foodLog);
      expect(avoDeleteTargetFromJson('alles'), isNull);
    });
  });
}

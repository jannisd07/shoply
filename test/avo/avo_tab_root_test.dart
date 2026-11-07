// Stufe 3 (prompt-b-vorrang.md): Avo is the root of its tab. A question
// handed over with /avo?q= is sent exactly once, the header has no back
// button, and Teil A can tell Avo where the person is.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shoply/presentation/screens/ai/avo_initial_question.dart';
import 'package:shoply/presentation/screens/ai/widgets/avo_chat_widgets.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';

void main() {
  group('AvoInitialQuestion', () {
    test('sends a handed-over question once, not on rebuilds', () {
      final gate = AvoInitialQuestion();
      expect(gate.take('Was ist bei Lidl im Angebot?'),
          'Was ist bei Lidl im Angebot?');
      expect(gate.take('Was ist bei Lidl im Angebot?'), isNull);
      expect(gate.take('Was ist bei Lidl im Angebot?'), isNull);
    });

    test('a different question is a new hand-over', () {
      final gate = AvoInitialQuestion();
      expect(gate.take('Plan für Freitag'), 'Plan für Freitag');
      expect(gate.take('Milch auf die Liste'), 'Milch auf die Liste');
    });

    test('no or blank question sends nothing and resets', () {
      final gate = AvoInitialQuestion();
      expect(gate.take(null), isNull);
      expect(gate.take('   '), isNull);
      expect(gate.take('Hallo'), 'Hallo');
      expect(gate.take(null), isNull);
      expect(gate.take('Hallo'), 'Hallo',
          reason: 'handed over again after the route lost its q');
    });

    test('trims the question', () {
      expect(AvoInitialQuestion().take('  Hallo  '), 'Hallo');
    });
  });

  testWidgets('the chat header has no back button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AvoChatHeader(
            isTyping: false,
            isSubscribed: false,
            keyboardOpen: false,
            onNewChat: () {},
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);
  });

  test('avoScreenContextProvider starts empty and takes A\'s context', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(avoScreenContextProvider), isNull);
    container.read(avoScreenContextProvider.notifier).state =
        const AvoScreenContext(
      screen: 'list',
      listId: 'l1',
      listName: 'Wocheneinkauf',
    );
    expect(
      container.read(avoScreenContextProvider),
      const AvoScreenContext(
        screen: 'list',
        listId: 'l1',
        listName: 'Wocheneinkauf',
      ),
    );
  });
}

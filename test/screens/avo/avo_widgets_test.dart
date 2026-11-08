// B building blocks of the Avo tab (B5 §2) and their pure logic.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/data/services/avo_assistant_service.dart';
import 'package:shoply/presentation/providers/avo_screen_context_provider.dart';
import 'package:shoply/presentation/screens/avo/avo_chat.dart';
import 'package:shoply/presentation/screens/avo/avo_suggestions.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_choice_card.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_composer.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_confirm_card.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_context_chip.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_large_title.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_message_text.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_result_card.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_status_line.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_user_bubble.dart';
import 'package:shoply/presentation/widgets/design/avo_figure.dart';

import 'avo_fakes.dart';

Widget _host(Widget child, {double textScale = 1}) => MediaQuery(
  data: MediaQueryData(
    size: const Size(390, 844),
    textScaler: TextScaler.linear(textScale),
  ),
  child: MaterialApp(
    home: AvoDesignScope(
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: SizedBox(width: double.infinity, child: child),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('parseAvoText (§2.3)', () {
    test('paragraphs, bullets, no markdown marks', () {
      final blocks = parseAvoText(
        '# Liste\nAuf **Wocheneinkauf** steht:\n\n- Milch\n* Brot\n\nFertig.',
      );
      expect(blocks.map((b) => b.text).toList(), [
        'Liste\nAuf Wocheneinkauf steht:',
        'Milch',
        'Brot',
        'Fertig.',
      ]);
      expect(blocks.map((b) => b.bullet).toList(), [false, true, true, false]);
    });

    test('keeps the source index of every visible character', () {
      final blocks = parseAvoText('- **Ab**');
      expect(blocks.single.chars.map((c) => c.$1).toList(), [4, 5]);
    });
  });

  group('avoWorkStepFor (§3.4)', () {
    String? name(String id) => id == 'w' ? 'Wocheneinkauf' : null;

    test('list tools name the list', () {
      expect(
        avoWorkStepFor('add_item_to_list', {'list_id': 'w'}, listName: name),
        const AvoWorkStep('avo_status_writing_list', {'list': 'Wocheneinkauf'}),
      );
      expect(
        avoWorkStepFor('get_list_contents', {'list_id': 'w'}, listName: name),
        const AvoWorkStep('avo_status_reading_list', {'list': 'Wocheneinkauf'}),
      );
      expect(
        avoWorkStepFor('move_items', {'to_list_id': 'w'}, listName: name),
        const AvoWorkStep('avo_status_writing_list', {'list': 'Wocheneinkauf'}),
      );
    });

    test('unknown list or tool: "Denkt nach"', () {
      expect(
        avoWorkStepFor('check_items', {'list_id': 'x'}, listName: name),
        AvoWorkStep.thinking,
      );
      expect(avoWorkStepFor('mystery', const {}), AvoWorkStep.thinking);
      expect(
        avoWorkStepFor('search_recipes', const {}),
        const AvoWorkStep('avo_status_recipes'),
      );
    });
  });

  group('avoEmptySuggestions (§4.2)', () {
    List<String> keys(List<AvoSuggestion> s) => s.map((e) => e.key).toList();

    test('list with open items, empty list, no list', () {
      expect(keys(avoEmptySuggestions(list: sampleList('w'))), [
        'avo_sugg_buy_regularly',
        'avo_sugg_whats_on_list',
        'avo_sugg_cook_today',
      ]);
      expect(
        keys(avoEmptySuggestions(list: sampleList('w', open: 0, items: 0))),
        [
          'avo_sugg_last_shop_again',
          'avo_sugg_cook_week',
          'avo_sugg_whats_on_list',
        ],
      );
      expect(keys(avoEmptySuggestions()), [
        'avo_sugg_last_saturday',
        'avo_sugg_party_list',
        'avo_sugg_whats_on_list',
      ]);
    });

    test('shopping mode names two open items', () {
      final s = avoEmptySuggestions(
        context: const AvoScreenContext(screen: 'shopping', listId: 'w'),
        openItemNames: const ['Milch', 'Butter', 'Eier'],
      );
      expect(keys(s), [
        'avo_sugg_whats_missing',
        'avo_sugg_check_two',
        'avo_sugg_add_baking_paper',
      ]);
      expect(s[1].params, {'a': 'Milch', 'b': 'Butter'});
    });

    test('shopping mode with one item drops the check row', () {
      final s = avoEmptySuggestions(
        context: const AvoScreenContext(screen: 'shopping'),
        openItemNames: const ['Milch'],
      );
      expect(keys(s), [
        'avo_sugg_whats_missing',
        'avo_sugg_add_baking_paper',
        'avo_sugg_whats_on_list',
      ]);
    });

    test('recipes and profile rows', () {
      expect(
        keys(
          avoEmptySuggestions(
            context: const AvoScreenContext(screen: 'recipes'),
          ),
        ),
        [
          'avo_sugg_cook_today',
          'avo_sugg_vegetarian_quick',
          'avo_sugg_saved_recipes',
        ],
      );
      expect(
        keys(
          avoEmptySuggestions(
            context: const AvoScreenContext(screen: 'profile'),
          ),
        ),
        ['avo_sugg_dark_mode', 'avo_sugg_peanut_allergy', 'avo_sugg_modules'],
      );
    });
  });

  group('avoFollowUps (§2.10)', () {
    test('at most two, from the result, never offers', () {
      final change = AvoWidgetPayload.listChange(
        const AvoListChange(
          kind: AvoListChangeKind.added,
          listId: 'w',
          listName: 'Wocheneinkauf',
        ),
      );
      expect(avoFollowUps([change]).map((s) => s.key), [
        'avo_sugg_buy_regularly',
      ]);
      expect(avoFollowUps(const []), isEmpty);
      expect(avoFollowUps([AvoWidgetPayload.recipes(const [])]), isEmpty);
    });
  });

  group('AvoUserBubble (§2.2)', () {
    testWidgets('is a heading, at most 75 % wide, shows its note', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var resent = 0;
      await tester.pumpWidget(
        _host(
          AvoUserBubble(
            text:
                'Ein sehr langer Satz, der umbrechen muss, weil er so lang ist',
            note: 'Not sent',
            noteActionLabel: 'Send again',
            onNoteAction: () => resent++,
          ),
        ),
      );
      final content = tester.getSize(find.byType(SingleChildScrollView)).width;
      final bubble = tester.getSize(
        find
            .descendant(
              of: find.byType(AvoUserBubble),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(bubble.width, lessThanOrEqualTo(content * 0.75 + 0.5));
      final data = tester
          .getSemantics(find.textContaining('Ein sehr langer'))
          .getSemanticsData();
      expect(data.flagsCollection.isHeader, isTrue);
      await tester.tap(find.text('Send again'));
      expect(resent, 1);
      handle.dispose();
    });

    testWidgets('from AX3 nearly full width', (tester) async {
      await tester.pumpWidget(
        _host(
          const AvoUserBubble(
            text:
                'Ein sehr langer Satz, der umbrechen muss, weil er so lang ist',
          ),
          textScale: 2.6,
        ),
      );
      final content = tester.getSize(find.byType(SingleChildScrollView)).width;
      final bubble = tester.getSize(
        find
            .descendant(
              of: find.byType(AvoUserBubble),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(bubble.width, greaterThan(content * 0.75));
    });
  });

  group('AvoMessageText (§2.3)', () {
    testWidgets('reads with "Avo:" in front and fades new words in', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final text = ValueNotifier('Hallo');
      await tester.pumpWidget(_host(AvoMessageText(text: text)));
      expect(find.bySemanticsLabel('Avo: Hallo'), findsOneWidget);
      text.value = 'Hallo Welt';
      await tester.pump(const Duration(milliseconds: 40));
      final rich = tester.widget<Text>(find.byType(Text).first).textSpan!;
      final spans = (rich as TextSpan).children!.cast<TextSpan>();
      expect(spans.last.text, ' Welt');
      expect(spans.last.style!.color!.a, lessThan(1));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.bySemanticsLabel('Avo: Hallo Welt'), findsOneWidget);
      handle.dispose();
    });
  });

  group('AvoStatusLine (§2.4)', () {
    testWidgets('dots, step text, Stopp with a 44 pt target', (tester) async {
      var stopped = 0;
      await tester.pumpWidget(
        _host(
          AvoStatusLine(
            step: const AvoWorkStep('avo_status_writing_list', {
              'list': 'Party',
            }),
            onStop: () => stopped++,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Adding to Party'), findsOneWidget);
      expect(find.byType(AvoActivityDots), findsOneWidget);
      expect(
        tester.getSize(find.text('Stop').hitTestable()).height,
        lessThanOrEqualTo(44),
      );
      await tester.tap(find.text('Stop'));
      expect(stopped, 1);
      expect(
        tester.getSize(find.byType(AvoStatusLine)).height,
        greaterThanOrEqualTo(44),
      );
    });
  });

  group('AvoResultSection (§2.5)', () {
    testWidgets('done, undone and changed-since', (tester) async {
      Widget section(AvoSectionState state) => _host(
        AvoResultCard(
          sections: [
            AvoResultSection(
              title: 'Wocheneinkauf',
              subtitle: '3 added',
              state: state,
              actions: [
                AvoCardAction(label: 'Open list', onPressed: () {}),
                AvoCardAction(label: 'Undo', isUndo: true, onPressed: () {}),
              ],
            ),
          ],
        ),
      );
      await tester.pumpWidget(section(AvoSectionState.done));
      expect(find.text('Undo'), findsOneWidget);
      expect(find.text('Open list'), findsOneWidget);

      await tester.pumpWidget(section(AvoSectionState.undone));
      expect(find.text('Undone'), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
      expect(find.text('Open list'), findsOneWidget);

      await tester.pumpWidget(section(AvoSectionState.changedSince));
      expect(find.text('3 added · Changed since'), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
    });

    testWidgets('running: dots instead of the image, no footer', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          AvoResultCard(
            sections: [
              AvoResultSection(
                title: 'Wocheneinkauf',
                state: AvoSectionState.running,
                actions: [AvoCardAction(label: 'Undo', onPressed: () {})],
              ),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AvoActivityDots), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
    });

    testWidgets('one VoiceOver sentence with its actions', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          AvoResultCard(
            sections: [
              AvoResultSection(
                title: 'Wocheneinkauf',
                subtitle: '1 added',
                semanticLabel: 'Wocheneinkauf: 1 added. Milch. Undo available.',
                actions: [
                  AvoCardAction(label: 'Undo', isUndo: true, onPressed: () {}),
                ],
              ),
            ],
          ),
        ),
      );
      final node = tester.getSemantics(
        find.bySemanticsLabel('Wocheneinkauf: 1 added. Milch. Undo available.'),
      );
      expect(node.getSemanticsData().customSemanticsActionIds, isNotEmpty);
      handle.dispose();
    });
  });

  group('AvoChoiceCard (§2.6)', () {
    List<AvoChoiceOption> options(int n) => [
      for (var i = 0; i < n; i++)
        AvoChoiceOption(id: '$i', title: 'Liste $i', subtitle: '$i open'),
    ];

    testWidgets('a choice marks the row; from 6 options "show all"', (
      tester,
    ) async {
      String? chosen;
      await tester.pumpWidget(
        _host(
          AvoChoiceCard(options: options(7), onSelect: (id) => chosen = id),
        ),
      );
      expect(find.text('Liste 5'), findsNothing);
      await tester.tap(find.text('Show all lists'));
      await tester.pump();
      expect(find.text('Liste 6'), findsOneWidget);
      await tester.tap(find.text('Liste 2'));
      expect(chosen, '2');
    });

    testWidgets('stale: rows inactive with "Not answered"', (tester) async {
      String? chosen;
      await tester.pumpWidget(
        _host(
          AvoChoiceCard(
            options: options(2),
            stale: true,
            onSelect: (id) => chosen = id,
          ),
        ),
      );
      expect(find.text('Not answered'), findsNWidgets(2));
      await tester.tap(find.text('Liste 1'));
      expect(chosen, isNull);
    });
  });

  group('AvoContextChip (§2.9)', () {
    testWidgets('announces the context, X removes it', (tester) async {
      final handle = tester.ensureSemantics();
      var removed = 0;
      await tester.pumpWidget(
        _host(AvoContextChip(name: 'Wocheneinkauf', onRemove: () => removed++)),
      );
      expect(
        find.bySemanticsLabel('Avo is looking at Wocheneinkauf'),
        findsOneWidget,
      );
      await tester.tap(find.bySemanticsLabel("Don't include Wocheneinkauf"));
      expect(removed, 1);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      handle.dispose();
    });
  });

  group('AvoComposer (§2.11)', () {
    testWidgets('counts down from 3,800 and stops at 4,000', (tester) async {
      final controller = TextEditingController();
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        _host(
          AvoComposer(controller: controller, focusNode: focus, onSend: (_) {}),
        ),
      );
      expect(find.textContaining('characters left'), findsNothing);
      controller.text = 'a' * 3900;
      await tester.pump();
      expect(find.text('100 characters left'), findsOneWidget);
      controller.text = 'a' * 4100;
      await tester.pump();
      expect(controller.text.length, avoMaxQuestionLength);
      expect(find.text('0 characters left'), findsOneWidget);
    });

    testWidgets('sends the trimmed text on Return', (tester) async {
      final controller = TextEditingController();
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      final sent = <String>[];
      await tester.pumpWidget(
        _host(
          AvoComposer(
            controller: controller,
            focusNode: focus,
            onSend: sent.add,
          ),
        ),
      );
      expect(find.text('Ask Avo…'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), '  Hallo  ');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      expect(sent, ['Hallo']);
    });
  });

  group('AvoConfirmCard (§6)', () {
    Widget card(
      AvoConfirmPhase phase, {
      bool offline = false,
      VoidCallback? onConfirm,
    }) => _host(
      AvoResultCard(
        sections: [
          AvoConfirmCard(
            title: 'Delete “Party”?',
            body:
                "The list and its 14 items will be deleted. You can't undo this.",
            confirmLabel: 'Delete',
            confirmHint: 'Deletes the list permanently.',
            doneText: 'List “Party” deleted',
            phase: phase,
            offline: offline,
            onConfirm: onConfirm ?? () {},
            onCancel: () {},
          ),
        ],
      ),
    );

    testWidgets('asking: grey trash, title, both buttons', (tester) async {
      final handle = tester.ensureSemantics();
      var confirmed = 0;
      await tester.pumpWidget(
        card(AvoConfirmPhase.asking, onConfirm: () => confirmed++),
      );
      expect(find.text('Cancel'), findsOneWidget);
      final delete = tester.getSemantics(find.bySemanticsLabel('Delete'));
      expect(delete.hint, 'Deletes the list permanently.');
      await tester.tap(find.text('Delete'));
      expect(confirmed, 1);
      expect(find.bySemanticsLabel('Confirmation'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('offline: Delete dimmed with the reason', (tester) async {
      var confirmed = 0;
      await tester.pumpWidget(
        card(
          AvoConfirmPhase.asking,
          offline: true,
          onConfirm: () => confirmed++,
        ),
      );
      expect(
        find.text("You're offline. You can delete once you're connected."),
        findsOneWidget,
      );
      await tester.tap(find.text('Delete'));
      expect(confirmed, 0);
    });

    testWidgets('expired, failed, deleted, cancelled', (tester) async {
      await tester.pumpWidget(card(AvoConfirmPhase.expired));
      expect(find.text('This request has expired. Ask again.'), findsOneWidget);
      await tester.pumpWidget(card(AvoConfirmPhase.failed));
      expect(find.text("That didn't work."), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      await tester.pumpWidget(card(AvoConfirmPhase.deleted));
      expect(find.text('List “Party” deleted'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);
      await tester.pumpWidget(card(AvoConfirmPhase.cancelled));
      expect(find.text('Not deleted.'), findsOneWidget);
    });

    testWidgets('stacks the buttons from AX1, destructive on top', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          AvoResultCard(
            sections: [
              AvoConfirmCard(
                title: 'Delete “Party”?',
                confirmLabel: 'Delete',
                doneText: 'deleted',
                phase: AvoConfirmPhase.asking,
                onConfirm: () {},
                onCancel: () {},
              ),
            ],
          ),
          textScale: 2,
        ),
      );
      expect(
        tester.getTopLeft(find.text('Delete')).dy,
        lessThan(tester.getTopLeft(find.text('Cancel')).dy),
      );
    });
  });

  group('AvoLargeTitle (§2.1, §2.13)', () {
    testWidgets('one figure, gone from AX1; the title is a heading', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(const AvoLargeTitle(pose: AvoPose.thinking)),
      );
      expect(find.byType(AvoFigure), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Avo')),
        matchesSemantics(isHeader: true, label: 'Avo'),
      );
      await tester.pumpWidget(
        _host(const AvoLargeTitle(pose: AvoPose.waving), textScale: 2),
      );
      expect(find.byType(AvoFigure), findsNothing);
      handle.dispose();
    });
  });
}

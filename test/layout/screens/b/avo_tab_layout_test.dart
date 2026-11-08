// Layout matrix for the Avo tab and its B building blocks (B5 W1): widths
// 320–440, text 1.0–3.1, bold, dark, contrast. Fails on any overflow or cut
// text.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/data/services/avo_assistant_service.dart';
import 'package:shoply/data/services/avo_conversation.dart';
import 'package:shoply/presentation/providers/avo_screen_context_provider.dart';
import 'package:shoply/presentation/screens/avo/avo_chat.dart';
import 'package:shoply/presentation/screens/avo/avo_suggestions.dart';
import 'package:shoply/presentation/screens/avo/avo_tab_screen.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_choice_card.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_confirm_card.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_context_chip.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_result_card.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_status_line.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_suggestion_views.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_user_bubble.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';

import '../../../screens/avo/avo_fakes.dart';
import '../../layout_matrix.dart';

/// The whole tab with its own fake backend, built once per case.
class _TabCase extends StatefulWidget {
  const _TabCase({
    this.scripts = const [],
    this.offline = false,
    this.aiOn = true,
    this.screen,
  });

  final List<AvoScript> scripts;
  final bool offline;
  final bool aiOn;
  final AvoScreenContext? screen;

  @override
  State<_TabCase> createState() => _TabCaseState();
}

class _TabCaseState extends State<_TabCase> {
  late final FakeAvoBackend _backend = FakeAvoBackend(widget.scripts);

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    child: ProviderScope(
      overrides: [
        ...avoOverrides(
          backend: _backend,
          offline: widget.offline,
          aiOn: widget.aiOn,
        ),
        if (widget.screen != null)
          avoScreenContextProvider.overrideWith((ref) => widget.screen),
      ],
      child: const AvoToastHost(child: AvoTabScreen()),
    ),
  );
}

Future<void> _askTwice(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  for (final q in [
    'Setz Milch, Butter und Eier auf den Wocheneinkauf',
    'Und was steht noch drauf?',
  ]) {
    await tester.enterText(find.byType(EditableText), q);
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await settle(tester);
  }
}

final _added = AvoWidgetPayload.listChange(
  AvoListChange(
    kind: AvoListChangeKind.added,
    listId: 'w',
    listName: 'Wocheneinkauf für das lange Wochenende',
    count: 3,
    items: [
      sampleItem('a', 'Milch', quantity: 2, unit: 'l'),
      sampleItem('b', 'Butter von der Molkerei am Markt'),
      sampleItem('c', 'Eier', quantity: 10),
    ],
    undo: () async => AvoUndoResult.undone,
  ),
);

final _contents = AvoWidgetPayload.listItems(
  listId: 'w',
  listName: 'Wocheneinkauf',
  items: [for (var i = 0; i < 10; i++) sampleItem('i$i', 'Artikel $i')],
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  layoutMatrix(
    'Avo tab, empty chat',
    (_) => const _TabCase(),
    checkTapTargets: true,
  );

  layoutMatrix(
    'Avo tab, empty chat in shopping mode with context capsule',
    (_) => const _TabCase(
      screen: AvoScreenContext(
        screen: 'shopping',
        listId: 'w',
        listName: 'Wocheneinkauf für das lange Wochenende',
      ),
    ),
    checkTapTargets: true,
  );

  layoutMatrix(
    'Avo tab, offline',
    (_) => const _TabCase(offline: true),
    checkTapTargets: true,
  );

  layoutMatrix(
    'Avo tab, AI switched off',
    (_) => const _TabCase(aiOn: false),
    checkTapTargets: true,
  );

  layoutMatrix(
    'Avo tab, conversation with cards, text and chips',
    (_) => _TabCase(
      scripts: [
        AvoScript(
          tools: const [
            ('add_item_to_list', {'list_id': 'w'}),
          ],
          payloads: [_added],
          message:
              'Ich habe Milch, Butter und Eier auf den Wocheneinkauf '
              'gesetzt.\n\n- Milch 2 l\n- Butter\n- Eier 10',
        ),
        AvoScript(payloads: [_contents], message: 'Das steht noch drauf.'),
      ],
    ),
    afterPump: _askTwice,
    checkTapTargets: true,
  );

  layoutMatrix(
    'Avo tab, errors and the daily limit',
    (_) => const _TabCase(
      scripts: [
        AvoScript.error('provider_error'),
        AvoScript.error('quota_exceeded'),
      ],
    ),
    afterPump: _askTwice,
    checkTapTargets: true,
  );

  layoutMatrix(
    'Avo tab, Avo working',
    (_) => const _TabCase(
      scripts: [
        AvoScript(
          tools: [
            ('get_list_contents', {'list_id': 'w'}),
          ],
          hold: true,
        ),
      ],
    ),
    afterPump: (tester) async {
      await tester.enterText(find.byType(EditableText), 'Was steht drauf?');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await settle(tester);
    },
    checkTapTargets: true,
  );

  layoutMatrix(
    'AvoUserBubble with note',
    (_) => const Padding(
      padding: EdgeInsets.all(16),
      child: AvoUserBubble(
        text: 'Setz bitte alles für die Lasagne auf die Liste für Samstag',
        note: 'Not sent',
        noteActionLabel: 'Send again',
        onNoteAction: _noop,
      ),
    ),
    scrollable: true,
  );

  layoutMatrix(
    'AvoStatusLine',
    (_) => const Padding(
      padding: EdgeInsets.all(16),
      child: AvoStatusLine(
        step: AvoWorkStep('avo_status_writing_list', {
          'list': 'Wocheneinkauf für das lange Wochenende',
        }),
        onStop: _noop,
      ),
    ),
    checkTapTargets: true,
    scrollable: true,
  );

  layoutMatrix(
    'AvoResultCard sections',
    (_) => Padding(
      padding: const EdgeInsets.all(16),
      child: AvoResultCard(
        sections: [
          AvoResultSection(
            title: 'Wocheneinkauf für das lange Wochenende',
            subtitle: '3 added · Lidl',
            leading: const AvoSymbolTile(icon: SizedBox()),
            actions: [
              const AvoCardAction(label: 'Open list', onPressed: _noop),
              const AvoCardAction(
                label: 'Undo',
                isUndo: true,
                onPressed: _noop,
              ),
            ],
            footnote: 'As of 14:05',
          ),
          const AvoResultSection(
            title: 'Party',
            subtitle: 'Renamed, was Grillabend',
            state: AvoSectionState.changedSince,
          ),
        ],
      ),
    ),
    checkTapTargets: true,
    scrollable: true,
  );

  layoutMatrix(
    'AvoConfirmCard',
    (_) => Padding(
      padding: const EdgeInsets.all(16),
      child: AvoResultCard(
        sections: [
          AvoConfirmCard(
            title: 'Delete “Wocheneinkauf für das lange Wochenende”?',
            body:
                'The list and its 14 items will be deleted for all members. '
                "You can't undo this.",
            confirmLabel: 'Delete',
            doneText: 'deleted',
            phase: AvoConfirmPhase.asking,
            offline: true,
            onConfirm: _noop,
            onCancel: _noop,
          ),
        ],
      ),
    ),
    checkTapTargets: true,
    scrollable: true,
  );

  layoutMatrix(
    'AvoChoiceCard',
    (_) => Padding(
      padding: const EdgeInsets.all(16),
      child: AvoChoiceCard(
        options: [
          for (var i = 0; i < 6; i++)
            AvoChoiceOption(
              id: '$i',
              title: 'Liste mit einem langen Namen $i',
              subtitle: '9 open · Lidl',
            ),
        ],
        onSelect: (_) {},
      ),
    ),
    checkTapTargets: true,
    scrollable: true,
  );

  layoutMatrix(
    'AvoContextChip',
    (_) => const Padding(
      padding: EdgeInsets.all(16),
      child: AvoContextChip(
        name: 'Wocheneinkauf für das lange Wochenende bei Oma',
        onRemove: _noop,
      ),
    ),
    checkTapTargets: true,
    scrollable: true,
  );

  layoutMatrix(
    'AvoFollowUpChips',
    (_) => Padding(
      padding: const EdgeInsets.all(16),
      child: AvoFollowUpChips(
        suggestions: const [
          AvoSuggestion('avo_chip_ingredients_to', AvoSuggestionSymbol.plus, {
            'list': 'Wocheneinkauf',
          }),
          AvoSuggestion(
            'avo_sugg_buy_regularly',
            AvoSuggestionSymbol.clockArrow,
          ),
        ],
        onSend: (_) {},
      ),
    ),
    checkTapTargets: true,
    scrollable: true,
  );

  // A pending delete for a layout run of the card inside the tab.
  layoutMatrix(
    'Avo tab, confirm card',
    (_) => _TabCase(
      scripts: [
        AvoScript(
          payloads: [
            AvoWidgetPayload.confirmDelete(
              AvoPendingDeletes().propose(
                target: AvoDeleteTarget.list,
                targetId: 'w',
                name: 'Wocheneinkauf',
              ),
            ),
          ],
        ),
      ],
    ),
    afterPump: (tester) async {
      await tester.enterText(find.byType(EditableText), 'Lösch die Liste');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await settle(tester);
    },
    cases: [
      for (final w in [320.0, 390.0])
        for (final s in [1.0, 3.1]) LayoutCase(width: w, scale: s),
    ],
    checkTapTargets: true,
  );
}

void _noop() {}

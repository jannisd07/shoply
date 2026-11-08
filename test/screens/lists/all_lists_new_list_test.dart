import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/presentation/screens/lists/widgets/all_lists_data.dart';
import 'package:shoply/presentation/screens/lists/widgets/all_lists_new_list.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_info_actions.dart';

import '../../layout/layout_matrix.dart';
import 'all_lists_fakes.dart';

ShoppingListModel _list(String id, String hex) => ShoppingListModel(
  id: id,
  name: id,
  ownerId: 'u1',
  createdAt: DateTime(2026, 10, 1),
  updatedAt: DateTime(2026, 10, 1),
  backgroundType: 'color',
  backgroundValue: hex,
);

List<Override> _overrides(FakeListActions actions) => [
  allListsSourceProvider.overrideWithValue(
    AsyncData([_list('a', '#007AFF'), _list('b', '#FF3B30')]),
  ),
  listActionsProvider.overrideWithValue(actions),
];

void main() {
  testWidgets('"Create" waits for a name, takes the next free colour or the '
      'chosen one, and returns the list', (tester) async {
    final actions = FakeListActions();
    ShoppingListModel? result;
    await loadLayoutFonts();
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(actions),
        child: layoutHarness(
          const LayoutCase(width: 390, scale: 1),
          Builder(
            builder: (context) => Center(
              child: GestureDetector(
                onTap: () async => result = await openNewListEditor(context),
                child: const Text('start'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();

    // Empty name: nothing happens.
    await tester.tap(find.text('Create'));
    await tester.pump();
    expect(actions.created, isEmpty);

    await tester.enterText(find.byType(EditableText), 'Lidl');
    await tester.pump();
    // Blue and red are taken: orange is preselected.
    expect(
      tester.getSemantics(find.bySemanticsLabel('Orange')),
      matchesSemantics(
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
        label: 'Orange',
      ),
    );
    await tester.tap(find.bySemanticsLabel('Indigo'));
    await tester.pump();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(actions.created, ['Lidl:#5856D6']);
    expect(result?.name, 'Lidl');
  });

  layoutMatrix(
    'NewListEditor',
    (context) => ProviderScope(
      overrides: _overrides(FakeListActions()),
      child: const NewListEditor(
        initialName: 'Wocheneinkauf fürs lange Wochenende mit Freunden',
      ),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/services/list_store_repository.dart';
import 'package:shoply/presentation/providers/store_for_list_provider.dart';
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

/// Records the market writes of "Neue Liste".
class _Stores extends Fake implements ListStoreRepository {
  final writes = <String>[];

  @override
  Future<void> setExplicit(String listId, String chainId) async =>
      writes.add('$listId:$chainId');
}

void main() {
  testWidgets('A-L3: a preselected market shows and is saved with the list; '
      'the id comes back', (tester) async {
    final actions = FakeListActions();
    final stores = _Stores();
    String? id;
    await loadLayoutFonts();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._overrides(actions),
          listStoreRepositoryProvider.overrideWithValue(stores),
        ],
        child: layoutHarness(
          const LayoutCase(width: 390, scale: 1),
          Builder(
            builder: (context) => Center(
              child: GestureDetector(
                onTap: () async => id = await openNewListEditorForId(
                  context,
                  initialName: 'Lidl-Einkauf',
                  storeChainId: 'lidl',
                ),
                child: const Text('start'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();
    expect(find.text('Lidl'), findsOneWidget);
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(stores.writes, ['new:lidl']);
    expect(id, 'new');
  });

  testWidgets('without a market: "No fixed store", nothing saved', (
    tester,
  ) async {
    final stores = _Stores();
    await loadLayoutFonts();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._overrides(FakeListActions()),
          listStoreRepositoryProvider.overrideWithValue(stores),
        ],
        child: layoutHarness(
          const LayoutCase(width: 390, scale: 1),
          const NewListEditor(initialName: 'Party'),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('No fixed store'), findsOneWidget);
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(stores.writes, isEmpty);
  });

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
  layoutMatrix(
    'NewListEditor with a market',
    (context) => ProviderScope(
      overrides: _overrides(FakeListActions()),
      child: const NewListEditor(
        initialName: 'Lidl',
        storeChainId: 'aldi-sued',
      ),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/presentation/screens/home/home_screen.dart';
import 'package:shoply/presentation/screens/home/widgets/home_avo_card.dart';
import 'package:shoply/presentation/screens/home/widgets/home_for_you.dart';
import 'package:shoply/presentation/screens/home/widgets/home_header.dart';
import 'package:shoply/presentation/screens/home/widgets/home_top_lists.dart';
import 'package:shoply/presentation/widgets/design/list_card.dart';

import '../../layout/layout_matrix.dart';

final _now = DateTime(2026, 11, 7, 19);

ShoppingListModel _list(
  String id, {
  String name = 'Wocheneinkauf',
  int items = 12,
  int open = 4,
  DateTime? used,
  bool shared = false,
  String type = 'color',
  String? value = '#FF9F0A',
}) => ShoppingListModel(
  id: id,
  name: name,
  ownerId: 'u1',
  isShared: shared,
  createdAt: _now,
  updatedAt: used ?? _now,
  lastAccessedAt: used,
  itemCount: items,
  uncheckedCount: open,
  backgroundType: type,
  backgroundValue: value,
);

final _lists = [
  _list('a', name: 'WG Küche', open: 7, used: DateTime(2026, 11, 6)),
  _list('b', used: DateTime(2026, 11, 7), shared: true),
  _list('c', name: 'Grillabend Samstag', open: 0, used: DateTime(2026, 11, 5)),
  _list('d', name: 'Alt', open: 1, used: DateTime(2026, 10, 1)),
];

Widget _scoped(Widget child) => ProviderScope(child: child);

void main() {
  test('greeting follows the hour', () {
    expect(homeGreetingKey(DateTime(2026, 1, 1, 7)), 'greeting_morning');
    expect(homeGreetingKey(DateTime(2026, 1, 1, 13)), 'greeting_day');
    expect(homeGreetingKey(DateTime(2026, 1, 1, 19)), 'greeting_evening');
  });

  test('"Weiter einkaufen" takes the last used list with open items', () {
    expect(continueShoppingList(_lists)!.id, 'b');
    expect(continueShoppingList([_list('x', open: 0)]), isNull);
    expect(continueShoppingList(const []), isNull);
  });

  test('top lists: three, last used first', () {
    expect(homeTopLists(_lists).map((l) => l.id), ['b', 'a', 'c']);
  });

  testWidgets('top lists show open counts and "Alles erledigt"', (
    tester,
  ) async {
    await tester.pumpWidget(
      layoutHarness(
        const LayoutCase(width: 390, scale: 1),
        SingleChildScrollView(child: HomeTopLists(lists: _lists)),
      ),
    );
    expect(find.byType(ListRow), findsNWidgets(3));
    // The harness runs in English.
    expect(find.textContaining('4 open'), findsOneWidget);
    expect(find.textContaining('7 open'), findsOneWidget);
    expect(find.text('All done'), findsOneWidget);
    expect(find.text('Alt'), findsNothing);
  });

  layoutMatrix(
    'HomeHeader',
    (context) => HomeHeader(firstName: 'Maximiliane-Sophie', now: _now),
  );
  layoutMatrix(
    'HomeAvoCard (intro)',
    (context) => _scoped(
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 48, 16, 16),
        child: HomeAvoCard(
          firstName: 'Maximiliane',
          offersOn: true,
          hasSavingsHint: false,
        ),
      ),
    ),
    scrollable: true,
  );
  layoutMatrix(
    'ContinueShoppingTile',
    (context) => Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: 171,
        child: ContinueShoppingTile(
          list: _list('b', name: 'Wocheneinkauf fürs lange Wochenende'),
        ),
      ),
    ),
    scrollable: true,
  );
  layoutMatrix(
    'HomeTopLists',
    (context) => HomeTopLists(lists: _lists),
    scrollable: true,
  );
}

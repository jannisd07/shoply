import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/presentation/screens/lists/widgets/all_lists_data.dart';
import 'package:shoply/presentation/screens/profile/settings/data/list_preferences.dart';
import 'package:shoply/presentation/screens/profile/settings/lists_settings_screen.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';

import '../../../layout/layout_matrix.dart';
import 'settings_test_helpers.dart';

ShoppingListModel _list(String id, String name) => ShoppingListModel(
  id: id,
  name: name,
  ownerId: 'u1',
  createdAt: DateTime(2026, 10, 1),
  updatedAt: DateTime(2026, 11, 7),
);

final _lists = [
  _list('w', 'Wocheneinkauf'),
  _list('g', 'Grillabend'),
  _list('d', 'Drogerie'),
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('today\'s list: pinned, else last opened, else the first', () {
    expect(todaysList(_lists, pinnedId: 'g', lastId: 'd')?.id, 'g');
    expect(todaysList(_lists, pinnedId: 'x', lastId: 'd')?.id, 'd');
    expect(todaysList(_lists)?.id, 'w');
    expect(todaysList(const []), isNull);
  });

  layoutMatrix(
    'ListsSettingsScreen',
    (_) => scoped(
      const ListsSettingsScreen(),
      overrides: settingsOverrides(lists: _lists),
    ),
  );

  testWidgets('all switches are on by default and act at once', (tester) async {
    final container = await pumpSettings(
      tester,
      const ListsSettingsScreen(),
      overrides: settingsOverrides(lists: _lists),
      height: 1200,
    );
    final toggles = tester.widgetList<ToggleRow>(find.byType(ToggleRow));
    expect(toggles.map((t) => t.value), everyElement(isTrue));
    expect(find.byType(ToggleRow), findsNWidgets(4));
    expect(
      find.text('Members of shared lists see “Jannis is shopping”.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Show others that I\'m shopping'));
    await settle(tester);
    expect(container.read(listPreferencesProvider).sharePresence, isFalse);
    final prefs = await SharedPreferences.getInstance();
    final stored =
        jsonDecode(prefs.getString('${kListPreferencesKeyPrefix}u1')!)
            as Map<String, dynamic>;
    expect(stored['share_presence'], isFalse);
    expect(stored['keep_screen_on'], isTrue);
  });

  testWidgets('"List at start" pins a list from the menu', (tester) async {
    final container = await pumpSettings(
      tester,
      const ListsSettingsScreen(),
      overrides: settingsOverrides(lists: _lists),
      height: 1200,
    );
    expect(find.text('Last used list'), findsOneWidget);
    await tester.tap(find.text('List at start'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grillabend').last);
    await tester.pumpAndSettle();
    expect(container.read(pinnedListProvider).listId, 'g');
    expect(find.text('Grillabend'), findsWidgets);

    await tester.tap(find.text('List at start'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Last used list').last);
    await tester.pumpAndSettle();
    expect(container.read(pinnedListProvider).listId, isNull);
  });

  testWidgets('"Order in the store" names today\'s list', (tester) async {
    await pumpSettings(
      tester,
      const ListsSettingsScreen(),
      overrides: settingsOverrides(lists: _lists),
      height: 1200,
    );
    final row = tester.widget<NavRow>(
      find.widgetWithText(NavRow, 'Order in the store'),
    );
    expect(row.value, 'Wocheneinkauf');
    expect(row.onTap, isNotNull);
  });

  testWidgets('without lists the order row is disabled', (tester) async {
    await pumpSettings(tester, const ListsSettingsScreen(), height: 1200);
    final row = tester.widget<NavRow>(
      find.widgetWithText(NavRow, 'Order in the store'),
    );
    expect(row.onTap, isNull);
    expect(find.text('Per list, once you have a list'), findsOneWidget);
  });

  testWidgets('German texts', (tester) async {
    await pumpSettings(
      tester,
      const ListsSettingsScreen(),
      overrides: settingsOverrides(lists: _lists),
      locale: const Locale('de'),
      height: 1200,
    );
    expect(find.text('ANZEIGE'), findsOneWidget);
    expect(find.text('Bildschirm anlassen'), findsOneWidget);
    expect(
      find.text('Mitglieder geteilter Listen sehen „Jannis kauft gerade ein“.'),
      findsOneWidget,
    );
  });
}

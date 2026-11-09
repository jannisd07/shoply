import 'package:flutter/widgets.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/presentation/screens/lists/widgets/shopping_mode_view.dart';
import 'package:shoply/presentation/widgets/design/item_row.dart';

import 'perf_harness.dart';

/// S2 "Abhaken in Serie" (Konzept 20 §5.1): shopping mode with 20 open
/// items, one checked every 300 ms; rows move on to "Im Wagen" meanwhile.
/// Target: 90th percentile ≤ 8.3 ms; limit: never a frame over 16 ms.
void main() {
  perfBinding();
  late PerfImageServer images;

  setUpAll(() async => images = await PerfImageServer.start());
  tearDownAll(() => images.close());

  testWidgets('S2 check series', (tester) async {
    coldImageCache();
    final items = shoppingModeItems();
    await tester.pumpWidget(
      perfApp(
        overrides: articleImageOverrides(images),
        home: _Host(items: items),
      ),
    );
    await idle(tester, const Duration(seconds: 2));
    expect(find.text(perfListName), findsWidgets);

    final tapped = <String>{};
    await measure('s2_check_series', () async {
      while (tapped.length < items.length) {
        final next = _nextOpenRow(tester, tapped);
        if (next == null) {
          // The next open row sits below the fold: scroll a little.
          await tester.dragFrom(
            tester.getCenter(find.byType(_Host)),
            const Offset(0, -240),
          );
          await idle(tester, const Duration(milliseconds: 300));
          continue;
        }
        tapped.add(next);
        await tester.tap(find.text(next).hitTestable().first);
        await idle(tester, const Duration(milliseconds: 300));
      }
      // The last rows move to "Im Wagen", the toast goes.
      await idle(tester, const Duration(seconds: 2));
    });
    expect(tapped, hasLength(items.length));
  });
}

/// The first open row on screen that was not tapped yet.
String? _nextOpenRow(WidgetTester tester, Set<String> tapped) {
  for (final row in tester.widgetList<ItemRow>(find.byType(ItemRow))) {
    if (row.checked || tapped.contains(row.title)) continue;
    if (find.text(row.title).hitTestable().evaluate().isNotEmpty) {
      return row.title;
    }
  }
  return null;
}

/// Feeds [ShoppingModeView] like `ShoppingModeScreen`, with checks saved
/// at once in memory.
class _Host extends StatefulWidget {
  const _Host({required this.items});

  final List<ShoppingItemModel> items;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late List<ShoppingItemModel> _items = widget.items;

  @override
  Widget build(BuildContext context) => ShoppingModeView(
    listId: perfListId,
    title: perfListName,
    items: _items,
    onToggle: (item, checked) async => setState(() {
      _items = [
        for (final i in _items)
          i.id == item.id
              ? i.copyWith(isChecked: checked, checkedAt: DateTime.now())
              : i,
      ];
    }),
    onAdd: () {},
    onEdit: (_) {},
    onFinish: () async {},
    onClose: () {},
  );
}

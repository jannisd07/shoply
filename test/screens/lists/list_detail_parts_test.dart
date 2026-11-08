import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/localization/app_translations.dart';
import 'package:shoply/data/models/custom_category.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_category_section.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_detail_data.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_detail_menu.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_detail_parts.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_drag_controller.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_item_tile.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/item_row.dart';

import '../../layout/layout_matrix.dart';

final _at = DateTime(2026, 1, 1);

String _en(String key, [Map<String, String>? params]) =>
    AppTranslations.get(key, 'en', params: params);

ShoppingItemModel _item(
  String name, {
  double quantity = 1,
  String? unit,
  bool checked = false,
  double? price,
  String category = 'other',
  int? order,
}) => ShoppingItemModel(
  id: name,
  listId: 'l1',
  name: name,
  quantity: quantity,
  unit: unit,
  category: category,
  categoryId: category,
  isChecked: checked,
  price: price,
  orderIndex: order,
  createdAt: _at,
  updatedAt: _at,
);

const _longTitle =
    'Wocheneinkauf für die ganze Wohngemeinschaft mit Grillabend am Samstag';

void main() {
  group('quantity', () {
    test('pieces, units and decimals in the app language', () {
      expect(formatItemQuantity(_item('a', quantity: 2)), '2 St.');
      expect(formatItemQuantity(_item('a', quantity: 1.5, unit: 'l')), '1,5 l');
      expect(formatItemQuantity(_item('a', quantity: 500, unit: 'g')), '500 g');
      expect(formatItemQuantity(_item('a', unit: 'bunch')), '1 Bund');
      expect(formatItemQuantity(_item('a', quantity: 3, unit: 'Stk')), '3 St.');
      expect(
        formatItemQuantity(
          _item('a', quantity: 2, unit: 'pcs'),
          languageCode: 'en',
        ),
        '2 pcs',
      );
      expect(
        formatItemQuantity(
          _item('a', quantity: 1.5, unit: 'kg'),
          languageCode: 'en',
        ),
        '1.5 kg',
      );
      // Free text from older rows stays as typed.
      expect(
        formatItemQuantity(_item('a', quantity: 2, unit: 'Beutel')),
        '2 Beutel',
      );
    });
  });

  group('sum of saved prices', () {
    test('only open items with a price; pieces count, measures once', () {
      expect(listOpenPriceTotal([_item('a')]), isNull);
      final total = listOpenPriceTotal([
        _item('a', quantity: 3, price: 0.99),
        _item('b', quantity: 2, unit: 'l', price: 1.29),
        _item('c', price: 5, checked: true),
        _item('d'),
      ]);
      expect(total, closeTo(4.26, 0.001));
    });

    test('"≈ 23,80 €" in German, "≈ €23.80" in English', () {
      // intl keeps amount and sign together with a no-break space.
      expect(formatListTotal(23.8, 'de'), '≈ 23,80\u00A0€');
      expect(formatListTotal(23.8, 'en'), '≈ €23.80');
    });
  });

  group('aisles', () {
    test('saved order first, unknown own category falls back to other', () {
      final groups = groupItemsByCategory(
        [
          _item('Milch', category: 'dairy'),
          _item('Brot', category: 'bakery'),
          _item('Seife', category: 'custom_gone'),
          _item('Äpfel', category: 'fruits_vegetables'),
        ],
        customCategories: const <CustomCategory>[],
        categoryOrder: const ['bakery', 'dairy'],
        languageCode: 'de',
      );
      // Aisles not in the saved order follow in the order they first
      // appear.
      expect(groups.map((g) => g.id), [
        'bakery',
        'dairy',
        'other',
        'fruits_vegetables',
      ]);
    });

    test('rows sorted by their order index', () {
      final groups = groupItemsByCategory(
        [
          _item('B', category: 'dairy', order: 2),
          _item('A', category: 'dairy', order: 1),
        ],
        customCategories: const [],
        categoryOrder: const [],
        languageCode: 'de',
      );
      expect(groups.single.items.map((i) => i.name), ['A', 'B']);
    });
  });

  group('menu entries', () {
    List<String> labels(
      BuildContext context, {
      bool hasOpen = true,
      bool hasDone = true,
      bool offers = true,
      bool hidden = false,
      bool? owner = true,
    }) => [
      for (final entry in listDetailMenuEntries(
        context,
        hasOpen: hasOpen,
        hasDone: hasDone,
        offersAvailable: offers,
        offersHidden: hidden,
        isOwner: owner,
        onSelected: (_) {},
      ))
        if (entry is AvoMenuItem) entry.label,
    ];

    testWidgets('entries without meaning are left out', (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        layoutHarness(
          const LayoutCase(width: 390, scale: 1),
          Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(labels(context), [
        _en('list_detail_menu_shop'),
        _en('list_detail_menu_checkout'),
        _en('list_detail_share'),
        _en('list_detail_menu_info'),
        _en('list_detail_menu_rename'),
        _en('list_detail_menu_order'),
        _en('list_detail_menu_hide_offers'),
        _en('list_detail_menu_import'),
        _en('list_detail_menu_delete'),
      ]);
      final reduced = labels(
        context,
        hasOpen: false,
        hasDone: false,
        offers: false,
        owner: false,
      );
      expect(reduced, isNot(contains(_en('list_detail_menu_shop'))));
      expect(reduced, isNot(contains(_en('list_detail_menu_checkout'))));
      expect(reduced, isNot(contains(_en('list_detail_menu_hide_offers'))));
      expect(reduced.last, _en('list_detail_menu_leave'));
      expect(
        labels(context, hidden: true),
        contains(_en('list_detail_menu_show_offers')),
      );
      expect(
        labels(context, owner: null),
        isNot(contains(_en('list_detail_menu_delete'))),
      );
    });

    testWidgets('choosing an entry reports its action', (tester) async {
      tester.view.physicalSize = const Size(390 * 3, kLayoutHeight * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final chosen = <ListDetailMenuAction>[];
      await tester.pumpWidget(
        layoutHarness(
          const LayoutCase(width: 390, scale: 1),
          Builder(
            builder: (context) => Align(
              alignment: Alignment.topRight,
              child: CupertinoButton(
                onPressed: () => showAvoMenu(
                  context,
                  anchorRect: const Rect.fromLTWH(330, 60, 44, 44),
                  items: listDetailMenuEntries(
                    context,
                    hasOpen: true,
                    hasDone: false,
                    offersAvailable: false,
                    offersHidden: false,
                    isOwner: true,
                    onSelected: chosen.add,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_en('list_detail_menu_order')));
      await tester.pumpAndSettle();
      expect(chosen, [ListDetailMenuAction.storeOrder]);
    });
  });

  group('Erledigt', () {
    testWidgets('collapsed: one row with the names; tap expands', (
      tester,
    ) async {
      final changes = <bool>[];
      await tester.pumpWidget(
        layoutHarness(
          const LayoutCase(width: 390, scale: 1),
          ListDoneSection(
            items: [
              _item('Eier', checked: true),
              _item('Kaffee', checked: true),
            ],
            expanded: false,
            onExpandedChanged: changes.add,
            rowBuilder: (item) => Text(item.name),
          ),
        ),
      );
      expect(find.text('DONE'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Eier, Kaffee'), findsOneWidget);
      await tester.tap(find.text('Eier, Kaffee'));
      await tester.tap(find.text('DONE'));
      expect(changes, [true, true]);
    });

    testWidgets('expanded: the rows', (tester) async {
      await tester.pumpWidget(
        layoutHarness(
          const LayoutCase(width: 390, scale: 1),
          ListDoneSection(
            items: [_item('Eier', checked: true)],
            expanded: true,
            onExpandedChanged: (_) {},
            rowBuilder: (item) => Text('row ${item.name}'),
          ),
        ),
      );
      expect(find.text('row Eier'), findsOneWidget);
      expect(find.text('Eier'), findsNothing);
    });

    testWidgets('nothing without done items', (tester) async {
      await tester.pumpWidget(
        layoutHarness(
          const LayoutCase(width: 390, scale: 1),
          ListDoneSection(
            items: const [],
            expanded: false,
            onExpandedChanged: (_) {},
            rowBuilder: (item) => const SizedBox(),
          ),
        ),
      );
      expect(find.text('DONE'), findsNothing);
    });
  });

  group('header and toolbar', () {
    testWidgets('no cart without onShop; inline title when given', (
      tester,
    ) async {
      await tester.pumpWidget(
        layoutHarness(
          const LayoutCase(width: 390, scale: 1),
          ListDetailToolbar(
            onBack: () {},
            onShare: () {},
            onMore: () {},
            moreKey: GlobalKey(),
            title: 'Wocheneinkauf',
          ),
        ),
      );
      expect(find.text('Wocheneinkauf'), findsOneWidget);
      expect(find.bySemanticsLabel(_en('list_detail_shop')), findsNothing);
    });

    testWidgets('header: progress and members as one share target', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        ProviderScope(
          child: layoutHarness(
            const LayoutCase(width: 390, scale: 1),
            ListDetailHeader(
              listId: 'l1',
              title: 'Wocheneinkauf',
              total: 12,
              done: 8,
              members: const ['Lena', 'Max'],
              onMembersTap: () => taps++,
            ),
          ),
        ),
      );
      expect(
        find.text(_en('common_progress', {'done': '8', 'total': '12'})),
        findsOneWidget,
      );
      await tester.tap(find.text('L'));
      expect(taps, 1);
    });

    testWidgets('header without items: no progress', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: layoutHarness(
            const LayoutCase(width: 390, scale: 1),
            const ListDetailHeader(
              listId: 'l1',
              title: 'Neu',
              total: 0,
              done: 0,
            ),
          ),
        ),
      );
      expect(find.textContaining(' of '), findsNothing);
    });
  });

  group('rename', () {
    testWidgets('returns the trimmed name, null on cancel', (tester) async {
      String? result = 'unset';
      await tester.pumpWidget(
        layoutHarness(
          const LayoutCase(width: 390, scale: 1),
          Builder(
            builder: (context) => CupertinoButton(
              onPressed: () async {
                result = await showCupertinoDialog<String>(
                  context: context,
                  builder: (_) =>
                      const RenameListDialog(initialName: 'Wocheneinkauf'),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(CupertinoTextField), '  Grillen  ');
      await tester.tap(find.text(_en('save')));
      await tester.pumpAndSettle();
      expect(result, 'Grillen');

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_en('cancel')));
      await tester.pumpAndSettle();
      expect(result, isNull);
    });
  });

  group('drag controller', () {
    testWidgets('scrolls down while the finger is near the bottom edge', (
      tester,
    ) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      late ListDragController drag;
      late BuildContext context;
      await tester.pumpWidget(
        layoutHarness(
          const LayoutCase(width: 390, scale: 1),
          _TickerHost(
            onReady: (vsync, c) {
              drag = ListDragController(scroll, vsync);
              context = c;
            },
            child: ListView(
              controller: scroll,
              children: [for (var i = 0; i < 80; i++) Text('row $i')],
            ),
          ),
        ),
      );
      drag.startDrag('dairy');
      expect(drag.draggedFromCategory, 'dairy');
      drag.handleDragUpdate(context, kLayoutHeight - 150);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 200));
      expect(scroll.offset, greaterThan(0));
      final reached = scroll.offset;
      drag.endDrag();
      await tester.pump(const Duration(milliseconds: 200));
      expect(scroll.offset, reached);
      expect(drag.draggedFromCategory, isNull);
      drag.dispose();
    });
  });

  testWidgets('item subtitle: quantity, note and diet warning', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      layoutHarness(
        const LayoutCase(width: 390, scale: 1),
        Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    final item = ShoppingItemModel(
      id: 'x',
      listId: 'l1',
      name: 'Feta',
      quantity: 200,
      unit: 'g',
      notes: 'griechisch',
      isDietWarning: true,
      createdAt: _at,
      updatedAt: _at,
    );
    expect(
      itemSubtitle(context, item),
      '200 g · griechisch · ${_en('list_detail_diet_warning')}',
    );
  });

  layoutMatrix(
    'ListDetailHeader long title, members, large numbers',
    (context) => const ProviderScope(
      child: ListDetailHeader(
        listId: 'l1',
        title: _longTitle,
        total: 130,
        done: 128,
        members: ['Lena', 'Max', 'Mia', 'Tom'],
      ),
    ),
    checkTapTargets: true,
  );

  layoutMatrix(
    'ListDetailToolbar with cart and inline title',
    (context) => ListDetailToolbar(
      onBack: () {},
      onShare: () {},
      onMore: () {},
      onShop: () {},
      moreKey: GlobalKey(),
      title: _longTitle,
    ),
    checkTapTargets: true,
  );

  layoutMatrix(
    'ListDoneSection collapsed with long names',
    (context) => ListDoneSection(
      items: [
        for (final name in [
          'Laktosefreie Bio-Vollmilch 3,8 %',
          'Olivenöl extra vergine',
          'Eier aus Freilandhaltung',
          'Kaffee',
        ])
          _item(name, checked: true),
      ],
      expanded: false,
      onExpandedChanged: (_) {},
      rowBuilder: (item) => const SizedBox(),
    ),
    checkTapTargets: true,
  );

  layoutMatrix(
    'ListDoneSection expanded with item rows',
    (context) => ListDoneSection(
      items: [
        _item('Laktosefreie Bio-Vollmilch 3,8 % für den Kaffee', checked: true),
        _item('Kaffee', checked: true),
      ],
      expanded: true,
      onExpandedChanged: (_) {},
      withThumbs: false,
      rowBuilder: (item) => ItemRow(
        title: item.name,
        subtitle: '1 St.',
        checked: true,
        onToggle: (_) {},
        onTap: () {},
      ),
    ),
    scrollable: true,
  );
}

/// Gives a test a [TickerProvider] and a context under the harness.
class _TickerHost extends StatefulWidget {
  const _TickerHost({required this.onReady, required this.child});

  final void Function(TickerProvider vsync, BuildContext context) onReady;
  final Widget child;

  @override
  State<_TickerHost> createState() => _TickerHostState();
}

class _TickerHostState extends State<_TickerHost>
    with SingleTickerProviderStateMixin {
  bool _ready = false;

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      _ready = true;
      widget.onReady(this, context);
    }
    return SizedBox(height: kLayoutHeight, child: widget.child);
  }
}

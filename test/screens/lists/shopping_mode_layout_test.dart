import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/presentation/screens/lists/widgets/shopping_mode_bars.dart';
import 'package:shoply/presentation/screens/lists/widgets/shopping_mode_header.dart';
import 'package:shoply/presentation/screens/lists/widgets/shopping_mode_view.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';

import '../../layout/layout_matrix.dart';

final _at = DateTime(2026, 11, 7, 10, 42);

ShoppingItemModel _item(
  String name,
  String category, {
  bool checked = false,
  double quantity = 1,
  String? unit,
  String? notes,
}) => ShoppingItemModel(
  id: name,
  listId: 'l1',
  name: name,
  categoryId: category,
  quantity: quantity,
  unit: unit,
  notes: notes,
  isChecked: checked,
  checkedAt: checked ? _at : null,
  createdAt: _at,
  updatedAt: _at,
);

/// Konzept 11 §0.3: Wocheneinkauf at Lidl, 11 open, 2 done.
final _week = [
  _item('Bananen', 'fruits_vegetables'),
  _item('Gurken', 'fruits_vegetables', quantity: 2),
  _item('Tomaten', 'fruits_vegetables', quantity: 500, unit: 'g'),
  _item('Vollkornbrot', 'bakery'),
  _item('Milch', 'dairy', quantity: 2),
  _item('Butter', 'dairy'),
  _item('Feta', 'dairy', quantity: 200, unit: 'g'),
  _item('Hähnchenbrust', 'meat_fish', quantity: 400, unit: 'g'),
  _item('Mehl', 'staples', quantity: 1, unit: 'kg'),
  _item('Spaghetti', 'staples', quantity: 2),
  _item('Mineralwasser', 'beverages', quantity: 6, notes: 'still'),
  _item('Eier', 'dairy', checked: true),
  _item('Joghurt', 'dairy', checked: true),
];

Widget _view(
  List<ShoppingItemModel>? items, {
  List<String> companions = const [],
  bool offline = false,
  bool showImages = true,
}) => ProviderScope(
  child: SizedBox.expand(
    child: ShoppingModeView(
      listId: 'l1',
      title: 'Wocheneinkauf',
      items: items,
      companions: companions,
      offline: offline,
      showImages: showImages,
      onToggle: (_, _) async {},
      onAdd: () {},
      onEdit: (_) {},
      onFinish: () async {},
      onClose: () {},
    ),
  ),
);

/// Fewer cases for the extra states: the extremes and dark mode.
final _edgeCases = [
  const LayoutCase(width: 320, scale: 1),
  const LayoutCase(width: 320, scale: 3.1),
  const LayoutCase(width: 440, scale: 2),
  const LayoutCase(width: 390, scale: 1, brightness: Brightness.dark),
  const LayoutCase(
    width: 320,
    scale: 3.1,
    bold: true,
    brightness: Brightness.dark,
  ),
];

void main() {
  layoutMatrix(
    'ShoppingModeView',
    (context) => _view(_week, companions: const ['Lena']),
    checkTapTargets: true,
  );

  layoutMatrix(
    'ShoppingModeView offline, images off',
    (context) => _view(_week, offline: true, showImages: false),
    cases: _edgeCases,
  );

  layoutMatrix(
    'ShoppingModeView all in the cart',
    (context) => _view([
      for (final i in _week)
        i.isChecked ? i : i.copyWith(isChecked: true, checkedAt: _at),
    ]),
    cases: _edgeCases,
  );

  layoutMatrix(
    'ShoppingModeView empty',
    (context) => _view(const []),
    cases: _edgeCases,
  );

  layoutMatrix(
    'ShoppingModeView loading',
    (context) => _view(null),
    cases: _edgeCases,
  );

  layoutMatrix(
    'ShoppingPresenceLine, three people',
    (context) => const Padding(
      padding: EdgeInsets.all(16),
      child: ShoppingPresenceLine(names: ['Lena', 'Max', 'Tom']),
    ),
  );

  Future<void> pumpBar(WidgetTester tester, double scale) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      layoutHarness(
        LayoutCase(width: 390, scale: scale),
        ShoppingBottomBar(onAdd: () {}, onFinish: () {}),
      ),
    );
  }

  testWidgets('finish: full label, "Finish" from AX1, only the mark from AX3', (
    tester,
  ) async {
    await pumpBar(tester, 1);
    expect(find.text('Finish shopping'), findsOneWidget);

    await pumpBar(tester, 1.6);
    expect(find.text('Finish'), findsOneWidget);
    expect(find.bySemanticsLabel('Finish shopping'), findsOneWidget);

    await pumpBar(tester, 2.4);
    expect(find.byType(AppButton), findsNothing);
    expect(find.text('Finish'), findsNothing);
    expect(find.bySemanticsLabel('Finish shopping'), findsOneWidget);
  });

  testWidgets('the screen-on capsule keeps only its clock from AX1', (
    tester,
  ) async {
    await tester.pumpWidget(
      layoutHarness(
        const LayoutCase(width: 390, scale: 1.6),
        const Center(child: ScreenOnChip()),
      ),
    );
    expect(find.text('Screen stays on'), findsNothing);
    expect(
      find.bySemanticsLabel('The screen stays on while you shop'),
      findsOneWidget,
    );
  });

  testWidgets('a slot that draws nothing leaves no gap', (tester) async {
    await tester.pumpWidget(
      layoutHarness(
        const LayoutCase(width: 390, scale: 1),
        const Align(
          alignment: Alignment.topLeft,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShoppingSlotPadding(
                padding: EdgeInsets.all(14),
                child: SizedBox.shrink(),
              ),
              ShoppingSlotPadding(
                padding: EdgeInsets.all(14),
                child: SizedBox(key: ValueKey('box'), width: 10, height: 10),
              ),
            ],
          ),
        ),
      ),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('box'))),
      const Offset(14, 14),
    );
    expect(tester.getSize(find.byType(ShoppingSlotPadding).first), Size.zero);
  });
}

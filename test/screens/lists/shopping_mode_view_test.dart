import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/presentation/screens/lists/widgets/shopping_mode_view.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';

import '../../layout/layout_matrix.dart';

final _at = DateTime(2026, 11, 7, 10, 42);

ShoppingItemModel _item(
  String name, {
  String category = 'fruits_vegetables',
  bool checked = false,
  double quantity = 1,
}) => ShoppingItemModel(
  id: name,
  listId: 'l1',
  name: name,
  categoryId: category,
  quantity: quantity,
  isChecked: checked,
  checkedAt: checked ? _at : null,
  createdAt: _at,
  updatedAt: _at,
);

final _week = [
  _item('Bananen'),
  _item('Gurken', quantity: 2),
  _item('Milch', category: 'dairy'),
  _item('Eier', category: 'dairy', checked: true),
];

class _Host extends StatefulWidget {
  const _Host({
    required this.items,
    this.fail = false,
    this.companions = const [],
    this.offline = false,
    this.loadFailed = false,
  });

  final List<ShoppingItemModel>? items;
  final bool fail;
  final List<String> companions;
  final bool offline;
  final bool loadFailed;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late List<ShoppingItemModel>? items = widget.items;
  final saved = <String>[];
  final edits = <String>[];
  int adds = 0;
  int finishes = 0;
  int closes = 0;
  int retries = 0;

  void set(String id, bool checked) => setState(() {
    items = [
      for (final i in items!)
        i.id == id ? i.copyWith(isChecked: checked, checkedAt: _at) : i,
    ];
  });

  @override
  Widget build(BuildContext context) => ShoppingModeView(
    listId: 'l1',
    title: 'Wocheneinkauf',
    items: items,
    companions: widget.companions,
    offline: widget.offline,
    loadFailed: widget.loadFailed,
    onToggle: (item, checked) async {
      saved.add('${item.id}:$checked');
      if (widget.fail) throw Exception('offline');
      set(item.id, checked);
    },
    onAdd: () => adds++,
    onEdit: (item) => edits.add(item.id),
    onFinish: () async => finishes++,
    onClose: () => closes++,
    onRetry: () => retries++,
  );
}

Future<_HostState> _pump(
  WidgetTester tester,
  _Host host, {
  bool reduceMotion = false,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: layoutHarness(
        LayoutCase(width: 390, scale: 1, reduceMotion: reduceMotion),
        AvoToastHost(child: host),
      ),
    ),
  );
  await tester.pump();
  return tester.state<_HostState>(find.byType(_Host));
}

/// Lets the undo toast and every motion finish.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 11));
  await tester.pumpAndSettle();
}

/// The progress sentence VoiceOver reads ("2 of 4 done").
Finder _progress(String label) => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.label == label,
);

Finder _finish() => find.byWidgetPredicate(
  (w) => w is AppButton && w.label == 'Finish shopping',
);

void main() {
  setUp(
    () =>
        SharedPreferences.setMockInitialValues({'show_article_images': false}),
  );

  testWidgets('title, progress, aisles with open counts, cart collapsed', (
    tester,
  ) async {
    await _pump(tester, _Host(items: _week));
    expect(find.text('Wocheneinkauf'), findsOneWidget);
    expect(_progress('1 of 4 done'), findsOneWidget);
    expect(find.text('FRUITS & VEGETABLES'), findsOneWidget);
    expect(find.text('DAIRY PRODUCTS'), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // two open in fruits
    expect(find.text('2 pcs'), findsOneWidget);
    expect(find.text('IN THE CART'), findsOneWidget);
    expect(find.text('Eier'), findsNothing);

    await tester.tap(find.text('IN THE CART'));
    await tester.pumpAndSettle();
    expect(find.text('Eier'), findsOneWidget);
  });

  testWidgets('a checked row stays struck through, then moves to the cart', (
    tester,
  ) async {
    final host = await _pump(tester, _Host(items: _week));
    await tester.tap(find.text('Bananen'));
    await tester.pump();
    expect(host.saved, ['Bananen:true']);
    expect(find.text('Bananen'), findsOneWidget);
    expect(find.text('Checked off: Bananen'), findsOneWidget);
    expect(_progress('2 of 4 done'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.text('Bananen'), findsNothing);

    await tester.tap(find.text('IN THE CART'));
    await tester.pumpAndSettle();
    expect(find.text('Bananen'), findsOneWidget);
    await _settle(tester);
  });

  testWidgets('undo from the toast puts the item back', (tester) async {
    final host = await _pump(tester, _Host(items: _week));
    await tester.tap(find.text('Bananen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500)); // toast in place
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(host.saved, ['Bananen:true', 'Bananen:false']);
    expect(host.items!.first.isChecked, isFalse);
    expect(find.text('Bananen'), findsOneWidget);
    await _settle(tester);
  });

  testWidgets('the last open item plays the success haptic', (tester) async {
    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add('${call.arguments}');
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await _pump(
      tester,
      _Host(items: [_item('Bananen'), _item('Eier', checked: true)]),
    );
    await tester.tap(find.text('Bananen'));
    await tester.pump();
    expect(haptics, contains('HapticFeedbackType.lightImpact'));
    expect(haptics, contains('HapticFeedbackType.mediumImpact'));
    await _settle(tester);
  });

  testWidgets('a failed save rolls back and offers to try again', (
    tester,
  ) async {
    final host = await _pump(tester, _Host(items: _week, fail: true));
    await tester.tap(find.text('Bananen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500)); // toast in place
    expect(find.text('Bananen wasn\'t saved.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(host.items!.first.isChecked, isFalse);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(host.saved, ['Bananen:true', 'Bananen:true']);
    await _settle(tester);
    expect(find.text('Bananen'), findsOneWidget);
  });

  testWidgets('checked by someone else: "just checked off", then the cart', (
    tester,
  ) async {
    final host = await _pump(tester, _Host(items: _week));
    host.set('Milch', true);
    await tester.pump();
    expect(find.text('Milch'), findsOneWidget);
    expect(find.text('just checked off'), findsOneWidget);
    expect(find.text('Checked off: Milch'), findsNothing); // no own toast

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Milch'), findsNothing);
    expect(_progress('2 of 4 done'), findsOneWidget);
  });

  testWidgets('finish is dimmed until something is checked', (tester) async {
    final host = await _pump(
      tester,
      _Host(items: [_item('Bananen'), _item('Gurken')]),
    );
    for (final b in tester.widgetList<AppButton>(_finish())) {
      expect(b.onPressed, isNull);
    }
    await tester.tap(find.text('Bananen'));
    await tester.pumpAndSettle();
    for (final b in tester.widgetList<AppButton>(_finish())) {
      expect(b.onPressed, isNotNull);
    }
    await tester.tap(_finish().hitTestable());
    await tester.pump();
    expect(host.finishes, 1);
    await _settle(tester);
  });

  testWidgets('everything in the cart: done state, finish stays', (
    tester,
  ) async {
    await _pump(tester, _Host(items: [_item('Bananen', checked: true)]));
    expect(find.text('Everything\'s in the cart.'), findsOneWidget);
    expect(find.text('FRUITS & VEGETABLES'), findsNothing);
    expect(
      tester.widget<AppButton>(_finish().hitTestable()).onPressed,
      isNotNull,
    );
  });

  testWidgets('empty list: empty state that adds an item', (tester) async {
    final host = await _pump(tester, const _Host(items: []));
    expect(find.text('Nothing left to get.'), findsOneWidget);
    await tester.tap(find.text('Add item'));
    expect(host.adds, 1);
    await tester.tap(find.bySemanticsLabel('Add item').hitTestable().last);
    expect(host.adds, 2);
  });

  testWidgets('presence, offline and back', (tester) async {
    final host = await _pump(
      tester,
      _Host(items: _week, companions: const ['Lena'], offline: true),
    );
    expect(find.text('Lena is shopping with you'), findsOneWidget);
    expect(
      find.text('Offline. Checking off works again once you\'re back online.'),
      findsOneWidget,
    );
    // The top row has an invisible twin for the layout: count the real one.
    expect(find.text('Screen stays on').hitTestable(), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Back').hitTestable());
    expect(host.closes, 1);
  });

  testWidgets('no local copy yet: calm placeholder; failed: try again', (
    tester,
  ) async {
    await _pump(tester, const _Host(items: null));
    expect(find.text('FRUITS & VEGETABLES'), findsNothing);
    expect(find.text('Try again'), findsNothing);

    final host = await _pump(
      tester,
      const _Host(items: null, loadFailed: true),
    );
    await tester.tap(find.text('Try again'));
    expect(host.retries, 1);
  });

  testWidgets('long press opens the item', (tester) async {
    final host = await _pump(tester, _Host(items: _week));
    await tester.longPress(find.text('Gurken'));
    expect(host.edits, ['Gurken']);
    expect(host.saved, isEmpty);
  });

  testWidgets('Reduce Motion: a checked row waits until 1 s without input', (
    tester,
  ) async {
    await _pump(tester, _Host(items: _week), reduceMotion: true);
    await tester.tap(find.text('Bananen'));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Bananen'), findsOneWidget);

    // Touching the list starts the second over.
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Wocheneinkauf')),
    );
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Bananen'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Bananen'), findsNothing);
    await _settle(tester);
  });
}

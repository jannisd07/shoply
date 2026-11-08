import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/core/localization/app_translations.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/repositories/item_repository.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/data/services/offline_cache_service.dart';
import 'package:shoply/data/services/tip_service.dart';
import 'package:shoply/presentation/screens/lists/list_detail_screen.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_detail_data.dart';
import 'package:shoply/presentation/screens/onboarding/onboarding_steps.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/item_row.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';
import 'package:shoply/presentation/widgets/tips/tip_row.dart';
import 'package:shoply/presentation/widgets/tips/tip_slot.dart';

import '../layout/layout_matrix.dart';

const _listId = 'l1';
final _today = DateTime(2026, 11, 8, 10);

String _en(String key, [Map<String, String>? params]) =>
    AppTranslations.get(key, 'en', params: params);

ShoppingItemModel _item(String id, String name, {double quantity = 1}) =>
    ShoppingItemModel(
      id: id,
      listId: _listId,
      name: name,
      quantity: quantity,
      category: 'dairy',
      categoryId: 'dairy',
      createdAt: _today,
      updatedAt: _today,
    );

class _FakeRepository extends Fake implements ItemRepository {}

/// Items from the test; adding puts the item into the state.
class _FakeItems extends ItemsNotifier {
  _FakeItems(List<ShoppingItemModel> start)
    : super(_FakeRepository(), _listId) {
    state = AsyncData(start);
  }

  @override
  Future<void> loadItems() async {}

  @override
  Future<void> addItem({
    required String name,
    double quantity = 1.0,
    String? unit,
    String? category,
    String? notes,
    bool isDietWarning = false,
    String? barcode,
    double? price,
    String? priceCurrency,
    String? priceRetailer,
    String? priceUnit,
    double? priceOldValue,
    bool autoParse = true,
  }) async {
    state = AsyncData([
      ...?state.valueOrNull,
      _item('n${state.valueOrNull?.length ?? 0}', name, quantity: quantity),
    ]);
  }
}

class _Actions extends ListDetailActions {
  final calls = <String>[];

  @override
  Future<void> openShopping(BuildContext context, String listId) async =>
      calls.add('shopping');

  @override
  Future<void> refreshLists(WidgetRef ref) async {}
}

ShoppingListModel _list({required bool shared}) => ShoppingListModel(
  id: _listId,
  name: 'Lidl',
  ownerId: 'u1',
  isShared: shared,
  createdAt: _today,
  updatedAt: _today,
);

Future<TipService> _tips({Map<String, Object> stored = const {}}) async {
  SharedPreferences.setMockInitialValues(stored);
  final prefs = await SharedPreferences.getInstance();
  return TipService(clock: () => _today)..attach(prefs);
}

Future<(_FakeItems, _Actions)> _pump(
  WidgetTester tester, {
  required TipService tips,
  OnboardingArrival? arrival,
  List<ShoppingItemModel> items = const [],
  bool shared = false,
  String? name = 'Lena Berg',
}) async {
  await loadLayoutFonts();
  tester.view.physicalSize = const Size(390 * 3, kLayoutHeight * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final notifier = _FakeItems(items);
  final actions = _Actions();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tipServiceProvider.overrideWithValue(tips),
        itemsNotifierProvider.overrideWith((ref, id) => notifier),
        listDetailListProvider.overrideWith((ref, id) => _list(shared: shared)),
        listDetailMembersProvider.overrideWith((ref, id) async => const []),
        authUserIdProvider.overrideWithValue('u1'),
        currentUserProvider.overrideWith((ref) async => null),
        cachedUserProfileProvider.overrideWithValue(
          CachedUserProfile(
            userId: 'u1',
            displayName: name,
            onboardingCompleted: true,
          ),
        ),
        isOfflineProvider.overrideWithValue(false),
        offersAvailableProvider.overrideWithValue(false),
        moduleEnabledProvider.overrideWith((ref, module) => true),
        listDetailActionsProvider.overrideWithValue(actions),
      ],
      child: layoutHarness(
        const LayoutCase(width: 390, scale: 1),
        ListDetailScreen(listId: _listId, listName: 'Lidl', arrival: arrival),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return (notifier, actions);
}

bool _fieldFocused(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus;

/// Lets the toast run out.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 11));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('new: add field focused, T1 in "Für heute"', (tester) async {
    final tips = await _tips();
    await _pump(tester, tips: tips, arrival: OnboardingArrival.created);
    await tester.pump();
    expect(_fieldFocused(tester), isTrue);
    expect(find.text('FOR TODAY'), findsOneWidget);
    expect(find.text(_en('tip_t1')), findsOneWidget);
    expect(tips.active, TipId.quantity);
  });

  testWidgets('new: "2 Milch" finishes T1 and the row goes', (tester) async {
    final tips = await _tips();
    await _pump(tester, tips: tips, arrival: OnboardingArrival.created);
    await tester.enterText(find.byType(EditableText), '2 Milch');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.widgetWithText(ItemRow, 'Milch'), findsOneWidget);
    expect(find.text(_en('tip_t1')), findsNothing);
    expect(tips.isFinished(TipId.quantity), isTrue);
    await _settle(tester);
  });

  testWidgets('joined: T5, no keyboard', (tester) async {
    final tips = await _tips();
    await _pump(
      tester,
      tips: tips,
      arrival: OnboardingArrival.joined,
      shared: true,
      items: [for (var i = 0; i < 12; i++) _item('i$i', 'Artikel $i')],
    );
    await tester.pump();
    expect(_fieldFocused(tester), isFalse);
    expect(find.text(_en('tip_t5')), findsOneWidget);
    expect(find.text(_en('tip_t1')), findsNothing);
  });

  testWidgets('existing: one status with the first name, no tip, no keyboard', (
    tester,
  ) async {
    final tips = await _tips();
    await _pump(
      tester,
      tips: tips,
      arrival: OnboardingArrival.existing,
      items: [_item('a', 'Milch'), _item('b', 'Brot'), _item('c', 'Eier')],
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text(_en('tip_arrival_existing', {'name': 'Lena'})),
      findsOneWidget,
    );
    expect(_fieldFocused(tester), isFalse);
    expect(find.byType(TipRow), findsNothing);
    // T1–T7 count as shown for an account that was set up.
    expect(tips.isFinished(TipId.shoppingMode), isTrue);
    expect(tips.isFinished(TipId.voice), isFalse);
    await _settle(tester);
  });

  testWidgets('existing without a name: the plain status', (tester) async {
    final tips = await _tips();
    await _pump(
      tester,
      tips: tips,
      arrival: OnboardingArrival.existing,
      name: 'lena@example.com',
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(_en('tip_arrival_existing_anonymous')), findsOneWidget);
    await _settle(tester);
  });

  testWidgets('an arrival acts once per run', (tester) async {
    final tips = await _tips();
    await _pump(tester, tips: tips, arrival: OnboardingArrival.existing);
    await _settle(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await _pump(tester, tips: tips, arrival: OnboardingArrival.existing);
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text(_en('tip_arrival_existing', {'name': 'Lena'})),
      findsNothing,
    );
  });

  testWidgets('no arrival: T2 with 3 open items; the cart counts as shopping', (
    tester,
  ) async {
    final tips = await _tips();
    final (_, actions) = await _pump(
      tester,
      tips: tips,
      items: [_item('a', 'Milch'), _item('b', 'Brot'), _item('c', 'Eier')],
    );
    expect(find.text(_en('tip_t2')), findsOneWidget);
    expect(_fieldFocused(tester), isFalse);
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is AvoIcon && identical(w.icon, AvoIcons.cart),
      ),
    );
    await tester.pump();
    expect(actions.calls, ['shopping']);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(tips.isFinished(TipId.shoppingMode), isTrue);
    expect(find.text(_en('tip_t2')), findsNothing);
  });

  testWidgets('tips not attached (other tests, before start): nothing', (
    tester,
  ) async {
    await _pump(
      tester,
      tips: TipService(),
      arrival: OnboardingArrival.created,
      items: [_item('a', 'Milch'), _item('b', 'Brot'), _item('c', 'Eier')],
    );
    expect(find.byType(TipRow), findsNothing);
    expect(find.text('FOR TODAY'), findsNothing);
  });
}

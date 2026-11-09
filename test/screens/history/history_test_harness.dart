import 'dart:async';

// Fakes and a router for the W11 history screens (V4–V8, Home V9–V12): no
// Supabase, a fixed clock (Mon, 9 Nov 2026, 12:00), German.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/core/services/shared_preferences_provider.dart';
import 'package:shoply/data/models/expense_split.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/repositories/item_repository.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/data/services/expense_split_service.dart';
import 'package:shoply/data/services/shopping_history_service.dart';
import 'package:shoply/data/services/trip_history_cache.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/expense_split_provider.dart';
import 'package:shoply/presentation/state/history_view_provider.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/state/lists_provider.dart';
import 'package:shoply/presentation/state/shopping_history_provider.dart';
import 'package:shoply/presentation/state/trip_history_provider.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';
import 'package:shoply/routes/app_branch.dart';
import 'package:shoply/routes/areas/history_routes.dart';
import 'package:shoply/routes/route_paths.dart';

import '../../data/services/expense_split_service_test.dart'
    show FakeSplitBackend;
import '../../data/services/shopping_history_service_test.dart'
    show FakeTripBackend;
import '../offers/offer_test_harness.dart' show RecordingItemsNotifier;

final DateTime histNow = DateTime(2026, 11, 9, 12);

ShoppingHistory histTrip(
  String id,
  DateTime at, {
  String user = 'me',
  String? by,
  String? byName,
  String list = 'l1',
  String listName = 'Wocheneinkauf',
  double? cost,
  String? chain = 'lidl',
  int items = 3,
  List<ShoppingHistoryItem>? lines,
}) => ShoppingHistory(
  id: id,
  userId: user,
  listId: list,
  listName: listName,
  totalItems: items,
  completedAt: at,
  totalCost: cost,
  storeChainId: chain,
  completedBy: by ?? user,
  completedByName: byName,
  paidByUserId: by ?? user,
  items:
      lines ??
      [
        ShoppingHistoryItem(id: '$id-1', historyId: id, name: 'Milch', quantity: 2),
        ShoppingHistoryItem(id: '$id-2', historyId: id, name: 'Brot'),
      ],
);

OpenShare histShare(
  String id, {
  String trip = 't1',
  String? user = 'lena',
  String name = 'Lena',
  String? payer = 'me',
  String? payerName = 'Jannis',
  int cents = 2140,
  bool paid = false,
}) => OpenShare(
  splitId: id,
  historyId: trip,
  userId: user,
  participantName: name,
  amountCents: cents,
  isPaid: paid,
  paidAt: paid ? histNow : null,
  listId: 'l1',
  listName: 'Wocheneinkauf',
  completedAt: histNow.subtract(const Duration(hours: 2)),
  paidByUserId: payer,
  paidByName: payerName,
  storeChainId: 'lidl',
);

ExpenseSplit histSplit(
  String id, {
  String? user,
  required String name,
  required int cents,
  bool paid = false,
  int position = 0,
  String mode = 'equal',
}) => ExpenseSplit(
  id: id,
  historyId: 't1',
  userId: user,
  participantName: name,
  amount: cents / 100,
  isPaid: paid,
  paidAt: paid ? histNow : null,
  createdAt: histNow,
  updatedAt: histNow,
  splitMode: mode,
  position: position,
);

ShoppingListModel histList(String id, String name, {bool shared = true}) => ShoppingListModel(
  id: id,
  name: name,
  ownerId: 'me',
  isShared: shared,
  sortMode: 'category',
  createdAt: histNow,
  updatedAt: histNow,
);

/// Lists without a server.
class FakeLists extends StateNotifier<AsyncValue<List<ShoppingListModel>>>
    implements ListsNotifier {
  FakeLists(List<ShoppingListModel> lists) : super(AsyncData(lists));

  @override
  Future<void> loadLists() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records `addItems` (V5 "Alle wieder auf die Liste").
class FakeItemRepo implements ItemRepository {
  final added = <(String, List<NewItem>)>[];

  @override
  Future<AddItemsResult> addItems(String listId, List<NewItem> items) async {
    added.add((listId, items));
    return const AddItemsResult(token: 'tok', items: []);
  }

  @override
  Future<void> undoAddItems(String token) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The history as the screens read it.
class HistoryWorld {
  HistoryWorld({
    required this.prefs,
    this.trips = const [],
    this.shares = const [],
    this.splits = const {},
    this.lists = const [],
    this.open = const [],
    this.splitModule = true,
    this.offline = false,
    this.savings = false,
    this.synced = true,
    this.failRefresh = false,
    this.membersOfList = const [
      SplitMember(userId: 'me', name: 'Jannis'),
      SplitMember(userId: 'lena', name: 'Lena'),
    ],
  });

  final SharedPreferences prefs;
  final List<ShoppingHistory> trips;
  final List<OpenShare> shares;
  final Map<String, List<ExpenseSplit>> splits;
  final List<ShoppingListModel> lists;
  final List<ShoppingItemModel> open;
  final bool splitModule;
  final bool offline;
  final bool savings;

  /// False: no answer yet (first load without cache).
  final bool synced;
  final bool failRefresh;
  final List<SplitMember> membersOfList;

  late final FakeTripBackend tripBackend = synced
      ? FakeTripBackend()
      : _SilentBackend();
  final splitBackend = FakeSplitBackend();
  final repo = FakeItemRepo();

  Future<List<Override>> overrides() async {
    final cache = TripHistoryCache(prefs);
    await cache.writeTrips('me', trips);
    await cache.writeShares('me', shares);
    tripBackend.trips = [...trips];
    splitBackend.openRows = [for (final s in shares) s.toJson()];
    if (failRefresh) tripBackend.fetchError = Exception('offline');
    return [
      sharedPreferencesProvider.overrideWith((ref) => prefs),
      authUserIdProvider.overrideWithValue('me'),
      historyClockProvider.overrideWithValue(() => histNow),
      tripHistoryCacheProvider.overrideWithValue(synced ? cache : null),
      shoppingHistoryServiceProvider.overrideWithValue(
        ShoppingHistoryService(backend: tripBackend),
      ),
      expenseSplitServiceProvider.overrideWithValue(
        ExpenseSplitService.withBackend(splitBackend),
      ),
      tripHistoryProvider.overrideWith(
        (ref) => TripHistoryController(
          service: ShoppingHistoryService(backend: tripBackend),
          userId: 'me',
          cache: synced ? cache : null,
          now: () => histNow,
        ),
      ),
      openSharesProvider.overrideWith(
        (ref) => OpenSharesController(
          service: ExpenseSplitService.withBackend(splitBackend),
          userId: 'me',
          cache: cache,
        ),
      ),
      tripSplitsProvider.overrideWith((ref, id) async => splits[id] ?? const []),
      splitMembersProvider.overrideWith((ref, id) => membersOfList),
      splitCandidateMembersProvider.overrideWith((ref, id) async => const []),
      moduleEnabledProvider.overrideWith(
        (ref, m) => m == AppModule.costSplit ? splitModule : true,
      ),
      isOfflineProvider.overrideWithValue(offline),
      historySavingsVisibleProvider.overrideWith((ref, id) => savings),
      listsNotifierProvider.overrideWith((ref) => FakeLists(lists)),
      itemsNotifierProvider.overrideWith((ref, id) => RecordingItemsNotifier(open)),
      itemRepositoryProvider.overrideWithValue(repo),
    ];
  }
}

/// The history routes in a Listen-like shell, opened at [location].
Future<GoRouter> pumpHistory(
  WidgetTester tester,
  String location,
  List<Override> overrides, {
  Locale locale = const Locale('de'),
}) async {
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: location,
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Text('Start')),
      GoRoute(path: RoutePaths.lists, builder: (_, _) => const Text('Listen')),
      GoRoute(
        path: RoutePaths.history,
        builder: buildHistoryRoot,
        routes: historyChildRoutes,
      ),
      ...historyBranchRoutes[AppBranch.lists]!,
      ...historyRootRoutes,
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: overrides,
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => AvoToastHost(child: child!),
        locale: locale,
        supportedLocales: const [Locale('de'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(platform: TargetPlatform.iOS),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

/// A server that never answers (the very first open without a cache).
class _SilentBackend extends FakeTripBackend {
  @override
  Future<List<ShoppingHistory>> fetchTrips({int? limit, DateTime? before}) =>
      Completer<List<ShoppingHistory>>().future;
}

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/core/services/shared_preferences_provider.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/data/services/shopping_history_service.dart';
import 'package:shoply/presentation/providers/offer_display_prefs_provider.dart';
import 'package:shoply/presentation/providers/store_choice_provider.dart';
import 'package:shoply/presentation/screens/history/checkout/checkout_data.dart';
import 'package:shoply/presentation/screens/history/checkout/checkout_flow.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/state/trip_history_provider.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';
import 'package:shoply/routes/areas/history_routes.dart';
import 'package:shoply/routes/areas/offers_routes.dart';

import '../../data/services/shopping_history_service_test.dart'
    show FakeTripBackend;
import '../offers/offer_test_harness.dart'
    show RecordingItemsNotifier, testItem, testListId;

/// Two in the cart, one stays on the list.
List<ShoppingItemModel> checkoutItems({int checked = 2}) => [
  for (var i = 0; i < checked; i++)
    testItem('c$i', i == 0 ? 'Milch' : 'Brot $i', checked: true),
  testItem('o1', 'Gurken'),
];

/// Everything V1 reads, without network or location.
List<Override> checkoutOverrides({
  required FakeTripBackend backend,
  required SharedPreferences prefs,
  List<ShoppingItemModel>? items,
  String? preselected = 'lidl',
  String? here,
  List<SplitMember> members = const [
    SplitMember(userId: 'me', name: 'Jannis'),
  ],
  bool splitModule = true,
  bool offline = false,
  int? savingsAtLidl = 320,
  CheckoutLocationAccess hint = CheckoutLocationAccess.none,
  RecordingItemsNotifier? notifier,
}) => [
  sharedPreferencesProvider.overrideWith((ref) => prefs),
  authUserIdProvider.overrideWithValue('me'),
  itemsNotifierProvider.overrideWith(
    (ref, id) => notifier ?? RecordingItemsNotifier(items ?? checkoutItems()),
  ),
  checkoutListNameProvider.overrideWith((ref, id) async => 'Wocheneinkauf'),
  checkoutPreselectionProvider.overrideWith(
    (ref, id) => preselected == null
        ? null
        : CheckoutPreselection(preselected, 'list'),
  ),
  checkoutStoreHereProvider.overrideWith((ref) async => here),
  checkoutLocationHintProvider.overrideWith((ref) async => hint),
  listStoreHistoryProvider.overrideWith((ref, id) async => const []),
  favoriteStoresProvider.overrideWithValue(const ['rewe']),
  storeDetectionOnProvider.overrideWithValue(true),
  splitMembersProvider.overrideWith((ref, id) => members),
  moduleEnabledProvider.overrideWith(
    (ref, module) => module == AppModule.costSplit ? splitModule : true,
  ),
  isOfflineProvider.overrideWithValue(offline),
  checkoutSavingsCentsProvider.overrideWith(
    (ref, key) => key.chainId == 'lidl' ? savingsAtLidl : null,
  ),
  tripHistoryProvider.overrideWith(
    (ref) => TripHistoryController(
      service: ShoppingHistoryService(backend: backend),
      userId: 'me',
    ),
  ),
];

/// What the launcher's [openCheckoutFlow] call returned.
abstract final class CheckoutLaunch {
  static bool? result;
}

/// A list stand-in at `/` with a button "open" that runs [openCheckoutFlow],
/// plus the history and store routes of Teil B, in German.
Future<GoRouter> pumpCheckout(
  WidgetTester tester, {
  required List<Override> overrides,
  Locale locale = const Locale('de'),
}) async {
  CheckoutLaunch.result = null;
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () async => CheckoutLaunch.result =
                    await openCheckoutFlow(context, testListId),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const Scaffold(body: Text('Verlauf')),
      ),
      GoRoute(
        path: '/lists',
        builder: (context, state) => const Scaffold(body: Text('Listen')),
      ),
      ...historyRootRoutes,
      ...offersRootRoutes,
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

/// Opens V1 from the launcher.
Future<void> openV1(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

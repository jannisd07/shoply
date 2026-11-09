// Layout matrix (A11) for the whole `HomeScreen`, fed through provider
// overrides, no Supabase. States: content, no lists yet, lists loading (name
// from this device), lists failed, every module off.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/models/user_model.dart';
import 'package:shoply/data/services/offline_cache_service.dart';
import 'package:shoply/data/services/tip_service.dart';
import 'package:shoply/presentation/screens/home/home_screen.dart';
import 'package:shoply/presentation/screens/home/widgets/home_avo_card.dart';
import 'package:shoply/presentation/screens/home/widgets/home_for_you.dart';
import 'package:shoply/presentation/screens/home/widgets/home_header.dart';
import 'package:shoply/presentation/screens/home/widgets/home_top_lists.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/lists_provider.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';
import 'package:shoply/presentation/widgets/tips/tip_slot.dart';

import '../../layout/layout_matrix.dart';

final _now = DateTime(2026, 11, 9, 10);

ShoppingListModel _list(
  String id, {
  required String name,
  int items = 12,
  int open = 4,
  DateTime? used,
  bool shared = false,
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
  backgroundType: 'color',
  backgroundValue: '#FF9F0A',
);

final _lists = [
  _list('a', name: 'WG Küche', open: 7, used: DateTime(2026, 11, 8)),
  _list(
    'b',
    name: 'Wocheneinkauf fürs lange Wochenende bei den Großeltern',
    used: DateTime(2026, 11, 9),
    shared: true,
  ),
  _list('c', name: 'Grillabend Samstag', open: 0, used: DateTime(2026, 11, 5)),
  _list('d', name: 'Drogerie', open: 1, used: DateTime(2026, 10, 1)),
];

/// The lists notifier without a server, in any state.
class _Lists extends StateNotifier<AsyncValue<List<ShoppingListModel>>>
    implements ListsNotifier {
  _Lists(super.state);

  int loads = 0;

  @override
  Future<void> loadLists() async => loads++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

late TipService _tips;

Widget _home(
  AsyncValue<List<ShoppingListModel>> lists, {
  String? serverName = 'Maximiliane-Sophie Brandt',
  String? cachedName,
  Set<AppModule> modules = const {
    AppModule.avo,
    AppModule.offers,
    AppModule.mealPlan,
  },
  _Lists? notifier,
}) => ProviderScope(
  overrides: [
    authUserIdProvider.overrideWithValue(null),
    currentUserProvider.overrideWith(
      (ref) async => serverName == null
          ? null
          : UserModel(
              id: 'u1',
              email: 'm@beispiel.de',
              displayName: serverName,
              createdAt: _now,
              updatedAt: _now,
            ),
    ),
    cachedUserProfileProvider.overrideWithValue(
      cachedName == null
          ? null
          : CachedUserProfile(
              userId: 'u1',
              displayName: cachedName,
              onboardingCompleted: true,
            ),
    ),
    listsNotifierProvider.overrideWith((ref) => notifier ?? _Lists(lists)),
    moduleEnabledProvider.overrideWith((ref, m) => modules.contains(m)),
    offersAvailableProvider.overrideWithValue(
      modules.contains(AppModule.offers),
    ),
    // Teil B's calorie sections have their own tests.
    homeCaloriesHasContentProvider.overrideWithValue(false),
    homeWaterHasContentProvider.overrideWithValue(false),
    tipServiceProvider.overrideWithValue(_tips),
  ],
  child: const SizedBox.expand(child: HomeScreen()),
);

/// The extremes and dark mode for the extra states.
const _stateCases = [
  LayoutCase(width: 320, scale: 1),
  LayoutCase(width: 320, scale: 3.1),
  LayoutCase(width: 390, scale: 1),
  LayoutCase(width: 440, scale: 2),
  LayoutCase(width: 390, scale: 1, brightness: Brightness.dark),
  LayoutCase(width: 390, scale: 1, highContrast: true),
];

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    _tips = TipService(clock: () => _now)..attach(prefs);
  });

  layoutMatrix(
    'HomeScreen Inhalt',
    (context) => _home(AsyncValue.data(_lists)),
  );

  layoutMatrix(
    'HomeScreen noch keine Listen',
    (context) => _home(const AsyncValue.data([])),
    cases: _stateCases,
  );

  layoutMatrix(
    'HomeScreen lädt, Name vom Gerät',
    (context) => _home(
      const AsyncValue.loading(),
      serverName: null,
      cachedName: 'Maximiliane',
    ),
    cases: _stateCases,
  );

  layoutMatrix(
    'HomeScreen Listen fehlgeschlagen, ohne Namen',
    (context) => _home(
      AsyncValue.error(Exception('offline'), StackTrace.empty),
      serverName: null,
    ),
    cases: _stateCases,
  );

  layoutMatrix(
    'HomeScreen alle Module aus',
    (context) => _home(AsyncValue.data(_lists), modules: const {}),
    cases: _stateCases,
  );

  layoutMatrix(
    'HomeScreen tap targets',
    (context) => _home(AsyncValue.data(_lists)),
    cases: const [
      LayoutCase(width: 390, scale: 1),
      LayoutCase(width: 320, scale: 3.1),
    ],
    checkTapTargets: true,
  );

  group('HomeScreen states', () {
    Future<void> pump(WidgetTester tester, Widget child) async {
      tester.view.physicalSize = const Size(390 * 3, kLayoutHeight * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        layoutHarness(const LayoutCase(width: 390, scale: 1), child),
      );
      await tester.pump(const Duration(milliseconds: 600));
    }

    testWidgets('content: greeting, Avo, "Weiter einkaufen", top lists', (
      tester,
    ) async {
      await pump(tester, _home(AsyncValue.data(_lists)));
      expect(find.byType(HomeHeader), findsOneWidget);
      expect(find.byType(HomeAvoCard), findsOneWidget);
      expect(find.byType(ContinueShoppingTile), findsOneWidget);
      expect(find.byType(HomeTopLists), findsOneWidget);
    });

    testWidgets('no lists: no "Weiter einkaufen", no top lists', (
      tester,
    ) async {
      await pump(tester, _home(const AsyncValue.data([])));
      expect(find.byType(HomeHeader), findsOneWidget);
      expect(find.byType(ContinueShoppingTile), findsNothing);
      expect(find.byType(HomeTopLists), findsNothing);
    });

    testWidgets('Avo off: no Avo card', (tester) async {
      await pump(
        tester,
        _home(AsyncValue.data(_lists), modules: const {AppModule.offers}),
      );
      expect(find.byType(HomeAvoCard), findsNothing);
      expect(find.byType(HomeTopLists), findsOneWidget);
    });

    testWidgets('loading: the name saved on this device greets at once', (
      tester,
    ) async {
      await pump(
        tester,
        _home(
          const AsyncValue.loading(),
          serverName: null,
          cachedName: 'Maximiliane',
        ),
      );
      final header = tester.widget<HomeHeader>(find.byType(HomeHeader));
      expect(header.firstName, 'Maximiliane');
    });

    testWidgets('pull to refresh loads the lists again', (tester) async {
      final notifier = _Lists(AsyncValue.data(_lists));
      await pump(tester, _home(AsyncValue.data(_lists), notifier: notifier));
      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 400),
        1200,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(notifier.loads, 1);
      await tester.pumpAndSettle();
    });
  });
}

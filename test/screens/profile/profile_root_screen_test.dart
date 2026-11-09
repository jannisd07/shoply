import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/services/subscription_service.dart';
import 'package:shoply/presentation/screens/profile/account/account_backend.dart'
    show SignInMethod;
import 'package:shoply/presentation/screens/profile/profile_root_data.dart';
import 'package:shoply/presentation/screens/profile/profile_root_screen.dart';
import 'package:shoply/presentation/widgets/design/empty_state.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';
import 'package:shoply/routes/areas/profile_routes.dart';
import 'package:shoply/routes/route_paths.dart';

import '../../layout/layout_matrix.dart';

const _bPages = [
  RoutePaths.settingsOffers,
  RoutePaths.settingsHealth,
  RoutePaths.settingsPlan,
  RoutePaths.settingsAvo,
  RoutePaths.settingsSiri,
  RoutePaths.settingsWidgets,
];

/// Teil A's routes alone (no Teil-B settings page).
final Set<String> _aRoutes = {
  for (final r in collectRoutePatterns(profileBranchRoutes))
    if (!_bPages.any((b) => r == b || r.startsWith('$b/'))) r,
  RoutePaths.pro,
};

/// With Teil B's pages mounted.
final Set<String> _withB = {
  ..._aRoutes,
  RoutePaths.settingsOffers,
  RoutePaths.settingsOffersRegion,
  RoutePaths.settingsOffersMarkets,
  RoutePaths.settingsHealth,
  RoutePaths.settingsPlan,
  RoutePaths.settingsAvo,
  RoutePaths.settingsSiri,
  RoutePaths.settingsWidgets,
};

/// The sample world of Konzept 18 §2.
ProfileRootData _data({
  ProfileIdentity identity = const ProfileIdentity(
    name: 'Jannis',
    email: 'jannis.d@beispiel.de',
    signInMethod: SignInMethod.apple,
  ),
  ProRowStatus pro = ProRowStatus.trialAvailable,
  Set<AppModule> modules = const {
    AppModule.offers,
    AppModule.avo,
    AppModule.costSplit,
  },
  bool killSwitch = false,
  NotificationRowState? notifications = NotificationRowState.on,
  bool offline = false,
  Set<String>? routes,
  String? version = '1.1.4 (31)',
  String? favorites,
  List<String> diet = const ['vegetarian'],
  int allergies = 1,
}) => ProfileRootData(
  identity: identity,
  pro: pro,
  enabledModules: modules,
  killSwitch: killSwitch,
  regionLabel: '79098 Freiburg im Breisgau',
  favoritesLabel: favorites,
  dietIds: diet,
  allergyCount: allergies,
  notifications: notifications,
  languageCode: 'de',
  version: version,
  offline: offline,
  routes: routes ?? _aRoutes,
);

/// Shows the location a push reached.
class _Probe extends StatelessWidget {
  const _Probe(this.location);

  final String location;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFFFFFFF),
    child: Center(child: Text('at $location')),
  );
}

GoRoute _probe(String path, {List<RouteBase> routes = const []}) => GoRoute(
  path: path,
  builder: (context, state) => _Probe(state.uri.toString()),
  routes: routes,
);

/// The root at /profile with probe pages for every place it opens.
GoRouter _router() => GoRouter(
  initialLocation: RoutePaths.profile,
  routes: [
    GoRoute(
      path: RoutePaths.profile,
      builder: (context, state) => const ProfileRootScreen(),
    ),
    GoRoute(
      path: RoutePaths.settings,
      builder: (context, state) => const ProfileRootScreen(),
      routes: [
        for (final p in [
          'profile',
          'modules',
          'diet',
          'personal',
          'lists',
          'notifications',
          'appearance',
          'language',
          'help',
          'offers',
          'offers/region',
          'health',
          'avo',
        ])
          _probe(p),
        _probe('legal', routes: [_probe('sources')]),
        _probe('account', routes: [_probe('delete')]),
      ],
    ),
    _probe(RoutePaths.pro),
  ],
);

/// The location on top: a pushed page's own uri (go_router 13 keeps the
/// base uri on the match list after a push).
String _location(GoRouter router) {
  final config = router.routerDelegate.currentConfiguration;
  final last = config.last;
  return last is ImperativeRouteMatch
      ? last.matches.uri.toString()
      : config.uri.toString();
}

Future<void> _pump(
  WidgetTester tester,
  ProfileRootData data, {
  GoRouter? router,
  List<Override> extra = const [],
  double scale = 1,
}) async {
  await loadLayoutFonts();
  tester.view.physicalSize = const Size(390 * 3, kLayoutHeight * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final config = router ?? _router();
  addTearDown(config.dispose);
  await tester.pumpWidget(
    ProviderScope(
      // A new scope and app per pump, also when a test pumps twice.
      key: UniqueKey(),
      overrides: [profileRootDataProvider.overrideWithValue(data), ...extra],
      child: MediaQuery(
        data: MediaQueryData(
          size: const Size(390, kLayoutHeight),
          devicePixelRatio: 3,
          textScaler: TextScaler.linear(scale),
          padding: const EdgeInsets.only(top: 47, bottom: 34),
          viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
        ),
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            platform: TargetPlatform.iOS,
            fontFamily: 'CupertinoSystemText',
          ),
          routerConfig: config,
          builder: (context, child) => AvoDesignScope(child: child!),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// Settles a push or pop (Cupertino transition).
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) => tester
    .scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);

Widget _body(BuildContext context, ProfileRootData data, {String query = ''}) =>
    ProfileRootBody(data: data, query: query, onOpen: (_) {});

void main() {
  test('Pro row: a used trial offers all benefits instead', () {
    const used = ProSubscriptionDetails(status: 'expired', trialEndsAt: null);
    final usedTrial = ProSubscriptionDetails(
      status: 'inactive',
      trialEndsAt: DateTime(2026, 10, 1),
    );
    const fresh = ProSubscriptionDetails(status: 'inactive');
    expect(
      ProRowStatus.ofDetails(SubscriptionStatus.notSubscribed, null),
      ProRowStatus.trialAvailable,
    );
    expect(
      ProRowStatus.ofDetails(SubscriptionStatus.notSubscribed, fresh),
      ProRowStatus.trialAvailable,
    );
    expect(
      ProRowStatus.ofDetails(SubscriptionStatus.notSubscribed, usedTrial),
      ProRowStatus.subscribe,
    );
    expect(
      ProRowStatus.ofDetails(SubscriptionStatus.notSubscribed, used),
      ProRowStatus.subscribe,
    );
    expect(
      ProRowStatus.ofDetails(SubscriptionStatus.subscribed, usedTrial),
      ProRowStatus.active,
    );
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('title, search, person, Avo Pro and the sections of today', (
    tester,
  ) async {
    await _pump(tester, _data());
    // The harness runs in English.
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Search settings'), findsOneWidget);
    expect(find.text('Jannis'), findsOneWidget);
    // The address may break after "@" and ".".
    expect(find.textContaining('beispiel'), findsOneWidget);
    expect(find.text('Avo Pro'), findsOneWidget);
    expect(find.text('Try free for 14 days'), findsOneWidget);
    expect(find.text('APP'), findsOneWidget);
    // Offers, avo and split costs are on; the meal plan is not released.
    expect(find.text('3 on'), findsOneWidget);
    // No Teil-B page exists yet: no offers row, no Module and iPhone section.
    expect(find.text('Prices & offers'), findsNothing);
    expect(find.text('MODULES'), findsNothing);
    expect(find.text('IPHONE'), findsNothing);
    expect(find.text('FOR YOU'), findsOneWidget);
    expect(find.text('Vegetarian · 1 allergy'), findsOneWidget);
    expect(find.text('Personal details'), findsOneWidget);
    expect(find.text('Lists'), findsOneWidget);
    await _scrollTo(tester, find.text('Avo · Version 1.1.4 (31)'));
    expect(find.text('GENERAL'), findsOneWidget);
    expect(find.text('On'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Deutsch'), findsOneWidget);
    expect(find.text('HELP AND LEGAL'), findsOneWidget);
    expect(find.text('Help'), findsOneWidget);
    expect(find.text('Legal'), findsOneWidget);
    expect(find.text('ACCOUNT'), findsOneWidget);
    expect(find.text('Apple'), findsOneWidget);
    // No counters, no premium card, no sign-out button.
    expect(find.textContaining('Sign out'), findsNothing);
  });

  testWidgets("Teil B's rows appear once their routes exist", (tester) async {
    await _pump(
      tester,
      _data(
        routes: _withB,
        modules: const {AppModule.offers, AppModule.avo, AppModule.calories},
      ),
    );
    expect(find.text('Prices & offers'), findsOneWidget);
    expect(find.text('79098 Freiburg im Breisgau'), findsOneWidget);
    expect(find.text('MODULES'), findsOneWidget);
    expect(find.text('Calories & health'), findsOneWidget);
    expect(find.text('Avo'), findsOneWidget);
    // The meal plan module is not released.
    expect(find.text('Meal plan'), findsNothing);
    await _scrollTo(tester, find.text('Widgets'));
    expect(find.text('IPHONE'), findsOneWidget);
    expect(find.text('Siri & Shortcuts'), findsOneWidget);
  });

  testWidgets('offers module off: "Off"; kill switch: "Stores" without value', (
    tester,
  ) async {
    await _pump(tester, _data(routes: _withB, modules: const {AppModule.avo}));
    expect(find.text('Prices & offers'), findsOneWidget);
    expect(find.text('Off'), findsOneWidget);
    expect(find.text('MODULES'), findsOneWidget);

    await _pump(tester, _data(routes: _withB, killSwitch: true));
    expect(find.text('Prices & offers'), findsNothing);
    expect(find.text('Stores'), findsOneWidget);
    expect(find.text('79098 Freiburg im Breisgau'), findsNothing);
  });

  testWidgets('favourite markets win over the region (D2), also as Märkte', (
    tester,
  ) async {
    await _pump(tester, _data(routes: _withB, favorites: 'Lidl, REWE'));
    expect(find.text('Lidl, REWE'), findsOneWidget);
    expect(find.text('79098 Freiburg im Breisgau'), findsNothing);
    await _pump(
      tester,
      _data(routes: _withB, favorites: 'Lidl, REWE', killSwitch: true),
    );
    expect(find.text('Stores'), findsOneWidget);
    expect(find.text('Lidl, REWE'), findsOneWidget);
  });

  testWidgets('Avo Pro line follows the subscription', (tester) async {
    await _pump(tester, _data(pro: ProRowStatus.active));
    expect(find.text('Active'), findsOneWidget);
    await _pump(tester, _data(pro: ProRowStatus.pending));
    expect(find.text('Waiting for approval'), findsOneWidget);
    await _pump(tester, _data(pro: ProRowStatus.subscribe));
    expect(find.text('See all benefits'), findsOneWidget);
    await _pump(tester, _data(pro: ProRowStatus.unknown));
    expect(find.text('Avo Pro'), findsOneWidget);
    expect(find.text('Try free for 14 days'), findsNothing);
  });

  testWidgets('notifications forbidden in iOS', (tester) async {
    await _pump(
      tester,
      _data(notifications: NotificationRowState.blockedInIos),
    );
    await _scrollTo(tester, find.text('Off in iOS'));
    expect(find.text('Off in iOS'), findsOneWidget);
  });

  testWidgets('without a name: "Set your name"; with nothing: retry', (
    tester,
  ) async {
    await _pump(
      tester,
      _data(identity: const ProfileIdentity(email: 'jannis.d@beispiel.de')),
    );
    expect(find.text('Set your name'), findsOneWidget);
    expect(find.text('Profile not loaded'), findsNothing);

    await _pump(tester, _data(identity: const ProfileIdentity()));
    expect(find.text('Profile not loaded'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    // Still loading: no error.
    await _pump(tester, _data(identity: const ProfileIdentity(loading: true)));
    expect(find.text('Profile not loaded'), findsNothing);
  });

  testWidgets('offline shows the status row under the title', (tester) async {
    await _pump(tester, _data(offline: true));
    expect(find.byType(StatusRow), findsOneWidget);
    expect(find.textContaining('Offline.'), findsOneWidget);
  });

  testWidgets('without a version the footer still names the app', (
    tester,
  ) async {
    await _pump(tester, _data(version: null));
    await _scrollTo(tester, find.text('Avo'));
    expect(find.text('Avo'), findsOneWidget);
  });

  testWidgets('sets Avo\'s screen context to the profile', (tester) async {
    final container = ProviderContainer(
      overrides: [profileRootDataProvider.overrideWithValue(_data())],
    );
    addTearDown(container.dispose);
    await loadLayoutFonts();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: layoutHarness(
          const LayoutCase(width: 390, scale: 1),
          const ProfileRootScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(
      container.read(avoScreenContextProvider),
      const AvoScreenContext(screen: 'profile'),
    );
  });

  group('navigation', () {
    testWidgets('rows push their page in the tab, Back returns', (
      tester,
    ) async {
      final router = _router();
      await _pump(tester, _data(), router: router);
      await tester.tap(find.text('Diet & allergies'));
      await _settle(tester);
      expect(_location(router), RoutePaths.settingsDiet);
      expect(find.text('at ${RoutePaths.settingsDiet}'), findsOneWidget);
      router.pop();
      await _settle(tester);
      expect(_location(router), RoutePaths.profile);

      await tester.tap(find.text('Jannis'));
      await _settle(tester);
      expect(_location(router), RoutePaths.settingsProfile);
      router.pop();
      await _settle(tester);

      await tester.tap(find.text('Avo Pro'));
      await _settle(tester);
      expect(_location(router), RoutePaths.pro);
    });

    testWidgets('a search hit opens the page; the text stays for Back', (
      tester,
    ) async {
      final router = _router();
      await _pump(tester, _data(), router: router);
      await tester.enterText(find.byType(EditableText), 'dunkel');
      await tester.pump();
      expect(find.text('SETTINGS'), findsOneWidget);
      expect(find.text('Appearance'), findsWidgets);
      // The sections give way to the hits.
      expect(find.text('FOR YOU'), findsNothing);
      await tester.tap(find.text('Appearance').first);
      await _settle(tester);
      expect(_location(router), startsWith(RoutePaths.settingsAppearance));
      router.pop();
      await _settle(tester);
      expect(find.text('dunkel'), findsOneWidget);
      expect(find.text('SETTINGS'), findsOneWidget);
    });

    testWidgets('a deep location pushes the whole path', (tester) async {
      final router = _router();
      await _pump(tester, _data(), router: router);
      final context = tester.element(find.byType(ProfileRootBody));
      final done = pushSettingsLocation(
        context,
        '${RoutePaths.settingsAccountDelete}?row=delete.summary',
      );
      await _settle(tester);
      await _settle(tester);
      expect(
        _location(router),
        '${RoutePaths.settingsAccountDelete}?row=delete.summary',
      );
      router.pop();
      await _settle(tester);
      expect(_location(router), RoutePaths.settingsAccount);
      await done;
      router.pop();
      await _settle(tester);
      expect(_location(router), RoutePaths.profile);
    });

    testWidgets('a subpage hit pushes its page first (Back walks the path)', (
      tester,
    ) async {
      final router = _router();
      await _pump(tester, _data(routes: _withB), router: router);
      await tester.enterText(find.byType(EditableText), 'Postleitzahl');
      await tester.pump();
      await tester.tap(find.text('Region'));
      await _settle(tester);
      await _settle(tester);
      expect(_location(router), RoutePaths.settingsOffersRegion);
      router.pop();
      await _settle(tester);
      expect(_location(router), RoutePaths.settingsOffers);
    });

    testWidgets('no hit: empty state that opens the iOS Settings', (
      tester,
    ) async {
      var opened = 0;
      await _pump(
        tester,
        _data(),
        extra: [
          openSystemSettingsProvider.overrideWithValue(() async => opened++),
        ],
      );
      await tester.enterText(find.byType(EditableText), 'xyzzy');
      await tester.pump();
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('No setting for “xyzzy”.'), findsOneWidget);
      await tester.tap(find.text('Open iOS Settings'));
      await tester.pump();
      expect(opened, 1);
    });

    testWidgets('kill switch: offers words find nothing', (tester) async {
      await _pump(tester, _data(routes: _withB, killSwitch: true));
      await tester.enterText(find.byType(EditableText), 'Prospekt');
      await tester.pump();
      expect(find.byType(EmptyState), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'PLZ');
      await tester.pump();
      expect(find.text('Region'), findsOneWidget);
      expect(find.text('Stores'), findsOneWidget);
    });

    testWidgets('the person row reads as one button', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _data());
      expect(
        find.bySemanticsLabel('Jannis, jannis.d@beispiel.de'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  layoutMatrix(
    'ProfileRootBody',
    (context) => _body(
      context,
      _data(
        routes: _withB,
        modules: const {AppModule.offers, AppModule.avo, AppModule.calories},
        notifications: NotificationRowState.blockedInIos,
        offline: true,
      ),
    ),
    scrollable: true,
  );
  layoutMatrix(
    'ProfileRootBody (long name and e-mail, no photo)',
    (context) => _body(
      context,
      _data(
        identity: const ProfileIdentity(
          name: 'Maximiliane Hoffmann-Schwarzenberger',
          email: 'maximiliane.hoffmann-schwarzenberger@beispiel-familie.de',
          signInMethod: SignInMethod.email,
        ),
        pro: ProRowStatus.pending,
        diet: const ['vegetarian', 'halal', 'low_carb'],
        allergies: 3,
      ),
    ),
    scrollable: true,
  );
  layoutMatrix(
    'ProfileRootBody (search hits)',
    (context) => _body(context, _data(routes: _withB), query: 'a'),
    scrollable: true,
  );
  layoutMatrix(
    'ProfileRootBody (no hits)',
    (context) => _body(context, _data(), query: 'Kontrastregler'),
    scrollable: true,
  );
  layoutMatrix(
    'ProfileRootBody (not loaded, no name)',
    (context) => Column(
      children: [
        _body(context, _data(identity: const ProfileIdentity())),
        _body(
          context,
          _data(identity: const ProfileIdentity(email: 'jannis.d@beispiel.de')),
        ),
      ],
    ),
    scrollable: true,
    cases: const [
      LayoutCase(width: 320, scale: 1),
      LayoutCase(width: 320, scale: 3.1, bold: true),
      LayoutCase(width: 390, scale: 2),
      LayoutCase(width: 390, scale: 1, brightness: Brightness.dark),
    ],
  );
}

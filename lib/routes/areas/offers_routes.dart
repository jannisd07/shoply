import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/screens/offers/favorite_markets_screen.dart';
import 'package:shoply/presentation/screens/offers/list_offers_screen.dart';
import 'package:shoply/presentation/screens/offers/offer_detail_screen.dart';
import 'package:shoply/presentation/screens/offers/offer_paths.dart';
import 'package:shoply/presentation/screens/offers/recipe_offers_screen.dart';
import 'package:shoply/presentation/screens/offers/region_screen.dart';
import 'package:shoply/presentation/screens/offers/store_picker_screen.dart';
import 'package:shoply/presentation/screens/offers/weekly_offers_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/offers_settings_screen.dart';
import 'package:shoply/presentation/screens/system/b_settings_route.dart';
import 'package:shoply/routes/app_branch.dart';
import 'package:shoply/routes/module_gate.dart';
import 'package:shoply/routes/route_error_screen.dart';

// Angebote (Teil B). Same contract as avo_routes.dart.

/// The screen at RoutePaths.offers ("Angebote der Woche", S10, pushed in
/// the Listen tab): `filter=regulars` opens "Oft gekauft", `q=` fills the
/// search. A's module gate wraps it; the kill switch shows the error page.
Widget buildOffersRoot(BuildContext context, GoRouterState state) {
  final query = state.uri.queryParameters;
  return _OffersGate(
    child: WeeklyOffersScreen(
      regulars: query['filter'] == 'regulars',
      query: query['q'],
    ),
  );
}

/// Children of the area root, with paths relative to it. They open in the
/// root's navigator; add `parentNavigatorKey: rootNavigatorKey` to open one
/// full screen above the tab bar.
final List<RouteBase> offersChildRoutes = [
  // "Angebote bei {Markt}" (S9), in the Listen tab; back leads to where it
  // was pushed from (the list), not to `/offers`.
  GoRoute(
    path: offerListChildPattern,
    builder: (context, state) => _OffersGate(
      child: ListOffersScreen(listId: state.pathParameters['listId'] ?? ''),
    ),
  ),
];

/// Further roots inside a tab, with absolute paths (see RoutePaths for the
/// prefixes reserved for Teil B). Teil A places them in that tab's branch.
final Map<AppBranch, List<RouteBase>> offersBranchRoutes = {};

/// Full-screen roots above the tab bar, with absolute paths (`angebote.md`
/// 1.2, type V): they open over whichever tab or full screen asked and come
/// back there. `/offers/offer/:offerId` still matches here although the
/// shell owns `/offers`: GoRouter tries the next top-level route when no
/// child of `/offers` takes the rest of the path. Unnamed, so A's route
/// snapshot (`test/routes/app_routes_test.dart`) stays as it is; open them
/// with the helpers in `offer_paths.dart`.
final List<RouteBase> offersRootRoutes = [
  GoRoute(
    path: offerDetailPattern,
    builder: (context, state) {
      final query = state.uri.queryParameters;
      final mode = query['mode'];
      return _OffersGate(
        child: OfferDetailScreen(
          offerId: int.tryParse(state.pathParameters['offerId'] ?? '') ?? -1,
          listId: query['list'],
          itemId: query['item'],
          mode: OfferDetailMode.values.where((m) => m.name == mode).firstOrNull,
          name: query['name'],
        ),
      );
    },
  ),
  // "Angebote für {Rezept}" (S15); the recipe detail hands the recipe over.
  GoRoute(
    path: offerRecipePattern,
    builder: (context, state) {
      final query = state.uri.queryParameters;
      final listId = query['list'];
      if (listId == null || listId.isEmpty) return const RouteErrorScreen();
      final extra = state.extra;
      return _OffersGate(
        child: RecipeOffersScreen(
          recipeId: state.pathParameters['recipeId'] ?? '',
          listId: listId,
          recipe: extra is Recipe ? extra : null,
          servings: int.tryParse(query['servings'] ?? ''),
        ),
      );
    },
  ),
  // Core ("Markt pro Liste"): open with the module off and the kill switch
  // on too.
  GoRoute(
    path: storeRegionPath,
    builder: (context, state) => const RegionScreen(fullScreen: true),
  ),
  GoRoute(
    path: storePickerPath,
    builder: (context, state) {
      final query = state.uri.queryParameters;
      final from = query['from'];
      return StorePickerScreen(
        listId: query['list'],
        from:
            StorePickerOrigin.values.where((o) => o.name == from).firstOrNull ??
            StorePickerOrigin.chip,
      );
    },
  ),
];

/// Settings pages, with paths relative to RoutePaths.settings (e.g. 'offers').
/// They open in the Profil tab. Not gated: "Preise & Angebote" changes its
/// content with the module and the kill switch (S12), region and favourite
/// markets are core.
final List<RouteBase> offersSettingsRoutes = [
  bSettingsRoute(
    'offers',
    (_) => const OffersSettingsScreen(),
    routes: [
      bSettingsRoute('region', (_) => const RegionScreen()),
      bSettingsRoute('markets', (_) => const FavoriteMarketsScreen()),
    ],
  ),
];

/// The guard of an offers route (`angebote.md` 1.3).
///
/// Opened while offers are off: the kill switch shows A's error page without
/// the word "Angebot", a switched-off module asks first (A's [ModuleGate]).
/// Once the screen was shown, a later flip (kill switch, or the module
/// turned off on another device) closes it silently: a plain background,
/// then back to where the person came from, no dialog, no error page.
class _OffersGate extends ConsumerStatefulWidget {
  const _OffersGate({required this.child});

  final Widget child;

  @override
  ConsumerState<_OffersGate> createState() => _OffersGateState();
}

class _OffersGateState extends ConsumerState<_OffersGate> {
  bool _shown = false;
  bool _closing = false;

  void _closeSilently() {
    if (_closing) return;
    _closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      final navigator = Navigator.of(context);
      // A menu above the screen goes first, then the screen itself.
      if (route != null && !route.isCurrent && route.isActive) {
        navigator.popUntil((r) => r == route);
      }
      if (context.canPop()) context.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final remote = ref.watch(offersRemoteEnabledProvider);
    final module = ref.watch(moduleEnabledProvider(AppModule.offers));
    if (_shown) {
      if (!_closing && remote && module) return widget.child;
      _closeSilently();
      return ColoredBox(color: context.colors.background);
    }
    if (!remote) return const RouteErrorScreen();
    if (!module) {
      return ModuleGate(module: AppModule.offers, child: widget.child);
    }
    _shown = true;
    return widget.child;
  }
}

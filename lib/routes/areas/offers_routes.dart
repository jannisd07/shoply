import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/screens/home/weekly_deals_screen.dart';
import 'package:shoply/presentation/screens/offers/offer_detail_screen.dart';
import 'package:shoply/presentation/screens/offers/offer_paths.dart';
import 'package:shoply/presentation/screens/offers/store_picker_screen.dart';
import 'package:shoply/routes/app_branch.dart';
import 'package:shoply/routes/module_gate.dart';
import 'package:shoply/routes/route_error_screen.dart';

// Angebote (Teil B). Same contract as avo_routes.dart.

/// The screen at RoutePaths.offers ("Angebote der Woche"; full screen until
/// S2, then in the Listen tab).
Widget buildOffersRoot(BuildContext context, GoRouterState state) =>
    const WeeklyDealsScreen();

/// Children of the area root, with paths relative to it. They open in the
/// root's navigator; add `parentNavigatorKey: rootNavigatorKey` to open one
/// full screen above the tab bar.
final List<RouteBase> offersChildRoutes = [];

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
  // Core ("Markt pro Liste"): open with the module off and the kill switch
  // on too.
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
/// They open in the Profil tab.
final List<RouteBase> offersSettingsRoutes = [];

/// The guard of an offers route (`angebote.md` 1.3): the kill switch shows
/// A's error page without the word "Angebot", a switched-off module asks
/// first (A's [ModuleGate]).
class _OffersGate extends ConsumerWidget {
  const _OffersGate({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(offersRemoteEnabledProvider)) {
      return const RouteErrorScreen();
    }
    return ModuleGate(module: AppModule.offers, child: child);
  }
}

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/presentation/screens/avo/avo_hand_over.dart';
import 'package:shoply/presentation/screens/avo/avo_settings_screen.dart';
import 'package:shoply/presentation/screens/avo/avo_tab_screen.dart';
import 'package:shoply/presentation/screens/system/b_settings_route.dart';
import 'package:shoply/routes/app_branch.dart';

// Avo (Teil B). The contract for all Teil-B route files is the same: a root
// builder (if the area has a root screen) and four lists. Teil A places them;
// Teil B only edits this file. See docs/redesign/status-A.md, "Routen".

/// Root of the Avo tab at RoutePaths.avo. A URL's `?prompt=` or `?q=`
/// (deep links like `shoply://avo?q=`) only fills the composer and never
/// sends, so another app or a web page cannot make Avo act. In-app callers
/// that want Avo to answer at once use `openAvoWithQuestion`, which hands the
/// question over as `extra` ([AvoAsk]); Avo sends it exactly once.
Widget buildAvoRoot(BuildContext context, GoRouterState state) {
  final query = state.uri.queryParameters;
  final extra = state.extra;
  return AvoTabScreen(
    prompt: query['prompt'] ?? query['q'],
    ask: extra is AvoAsk ? extra : null,
  );
}

/// Children of the area root, with paths relative to it. They open in the
/// root's navigator; add `parentNavigatorKey: rootNavigatorKey` to open one
/// full screen above the tab bar.
final List<RouteBase> avoChildRoutes = [];

/// Further roots inside a tab, with absolute paths (see RoutePaths for the
/// prefixes reserved for Teil B). Teil A places them in that tab's branch.
final Map<AppBranch, List<RouteBase>> avoBranchRoutes = {};

/// Full-screen roots above the tab bar, with absolute paths.
final List<RouteBase> avoRootRoutes = [];

/// Settings pages, with paths relative to RoutePaths.settings (e.g. 'avo').
/// They open in the Profil tab; `?row=` highlights a row (settings search).
final List<RouteBase> avoSettingsRoutes = [
  bSettingsRoute(
    'avo',
    (row) => AvoSettingsScreen(highlightRowId: row),
    module: AppModule.avo,
  ),
];

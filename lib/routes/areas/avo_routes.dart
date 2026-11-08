import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/presentation/screens/avo/avo_tab_screen.dart';
import 'package:shoply/routes/app_branch.dart';

// Avo (Teil B). The contract for all Teil-B route files is the same: a root
// builder (if the area has a root screen) and four lists. Teil A places them;
// Teil B only edits this file. See docs/redesign/status-A.md, "Routen".

/// Root of the Avo tab at RoutePaths.avo. `?q=` hands a question over
/// (the "Frag Avo …" field on Home); Avo sends it exactly once. `?prompt=`
/// (deep links `shoply://avo?prompt=`) only fills the composer and never
/// sends, so another app or a web page cannot make Avo act.
Widget buildAvoRoot(BuildContext context, GoRouterState state) => AvoTabScreen(
      initialQuestion: state.uri.queryParameters['q'],
      prompt: state.uri.queryParameters['prompt'],
    );

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
/// They open in the Profil tab.
final List<RouteBase> avoSettingsRoutes = [];

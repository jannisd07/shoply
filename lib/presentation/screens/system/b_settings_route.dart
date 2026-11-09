import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/presentation/widgets/design/row_highlight.dart';
import 'package:shoply/routes/module_gate.dart';

/// The row a settings search hit asks to highlight (`?row=<rowId>`).
String? settingsRowOf(GoRouterState state) {
  final row = state.uri.queryParameters['row']?.trim();
  return row == null || row.isEmpty ? null : row;
}

/// One of Teil B's settings pages at [path] (relative to its parent, as in
/// Teil A's `profile_routes.dart`): the screen gets the row from `?row=`
/// and sits in a [RowHighlightScope] with it. With [module] the page is
/// behind [ModuleGate] (opened while the module is off: the centred alert).
GoRoute bSettingsRoute(
  String path,
  Widget Function(String? rowId) screen, {
  AppModule? module,
  List<RouteBase> routes = const [],
}) => GoRoute(
  path: path,
  builder: (context, state) {
    final row = settingsRowOf(state);
    final page = RowHighlightScope(rowId: row, child: screen(row));
    final gate = module;
    return gate == null ? page : ModuleGate(module: gate, child: page);
  },
  routes: routes,
);

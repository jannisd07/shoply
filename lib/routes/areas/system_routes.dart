import 'package:go_router/go_router.dart';

import 'package:shoply/presentation/screens/system/b_settings_route.dart';
import 'package:shoply/presentation/screens/system/siri_settings_screen.dart';
import 'package:shoply/presentation/screens/system/widgets_settings_screen.dart';

// System (Teil B): Siri & Kurzbefehle, Widgets and the other pages about
// how Avo reaches the system. Same contract as avo_routes.dart; Teil A
// mounts the list, Teil B only edits this file.

/// Settings pages, with paths relative to RoutePaths.settings (e.g. 'siri').
/// They open in the Profil tab; `?row=` highlights a row (settings search).
/// Core pages, not behind a module.
final List<RouteBase> systemSettingsRoutes = [
  bSettingsRoute('siri', (row) => SiriSettingsScreen(highlightRowId: row)),
  bSettingsRoute(
    'widgets',
    (row) => WidgetsSettingsScreen(highlightRowId: row),
  ),
];

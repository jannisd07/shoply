import 'package:go_router/go_router.dart';

// System (Teil B): Siri & Kurzbefehle, Widgets and the other pages about
// how Avo reaches the system. Same contract as avo_routes.dart; Teil A
// mounts the list, Teil B only edits this file.

/// Settings pages, with paths relative to RoutePaths.settings (e.g. 'siri').
/// They open in the Profil tab; `?row=` highlights a row (settings search).
/// Core pages, not behind a module.
final List<RouteBase> systemSettingsRoutes = [];

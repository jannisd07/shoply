import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/presentation/screens/profile/account/account_screen.dart';
import 'package:shoply/presentation/screens/profile/account/delete_account_screen.dart';
import 'package:shoply/presentation/screens/profile/account/profile_edit_screen.dart';
import 'package:shoply/presentation/screens/profile/profile_root_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/appearance_settings_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/diet_settings_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/help_settings_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/language_settings_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/legal_settings_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/lists_settings_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/modules_settings_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/notifications_settings_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/personal_settings_screen.dart';
import 'package:shoply/presentation/widgets/design/row_highlight.dart';
import 'package:shoply/routes/areas/avo_routes.dart';
import 'package:shoply/routes/areas/calories_routes.dart';
import 'package:shoply/routes/areas/history_routes.dart';
import 'package:shoply/routes/areas/offers_routes.dart';
import 'package:shoply/routes/areas/plan_routes.dart';
import 'package:shoply/routes/route_error_screen.dart';
import 'package:shoply/routes/route_paths.dart';

/// The row a search hit asks to highlight (`?row=<rowId>`, E18-14).
String? _rowOf(GoRouterState state) {
  final row = state.uri.queryParameters['row']?.trim();
  return row == null || row.isEmpty ? null : row;
}

/// A settings page at [path] (relative to its parent): the screen gets the
/// row from `?row=` and sits in a [RowHighlightScope] with it.
GoRoute _page(
  String path,
  Widget Function(String? rowId) screen, {
  List<RouteBase> routes = const [],
}) => GoRoute(
  path: path,
  builder: (context, state) {
    final row = _rowOf(state);
    return RowHighlightScope(rowId: row, child: screen(row));
  },
  routes: routes,
);

/// Teil A's settings pages, relative to RoutePaths.settings (Konzept 18
/// E18-11). Unnamed, like Teil B's, so the route snapshot keeps its names.
final List<RouteBase> profileSettingsRoutes = [
  _page('profile', (row) => ProfileEditScreen(highlightRowId: row)),
  _page('modules', (row) => ModulesSettingsScreen(highlightRowId: row)),
  _page('diet', (row) => DietSettingsScreen(highlightRowId: row)),
  _page('personal', (row) => PersonalSettingsScreen(highlightRowId: row)),
  _page('lists', (row) => ListsSettingsScreen(highlightRowId: row)),
  _page(
    'notifications',
    (row) => NotificationsSettingsScreen(highlightRowId: row),
  ),
  _page('appearance', (row) => AppearanceSettingsScreen(highlightRowId: row)),
  _page('language', (row) => LanguageSettingsScreen(highlightRowId: row)),
  _page('help', (row) => HelpSettingsScreen(highlightRowId: row)),
  _page(
    'legal',
    (row) => LegalSettingsScreen(highlightRowId: row),
    routes: [
      _page('sources', (row) => DataSourcesScreen(highlightRowId: row)),
      // `privacy`, `imprint`, `terms`, `licenses`; anything else is the
      // error page.
      GoRoute(
        path: ':doc',
        builder: (context, state) {
          final document = LegalDocument.fromId(state.pathParameters['doc']);
          if (document == null) return const RouteErrorScreen();
          return RowHighlightScope(
            rowId: _rowOf(state),
            child: LegalDocumentScreen(document: document),
          );
        },
      ),
    ],
  ),
  _page(
    'account',
    (row) => AccountScreen(highlightRowId: row),
    routes: [
      _page('delete', (row) => DeleteAccountScreen(highlightRowId: row)),
    ],
  ),
];

/// Routes of the Profil tab branch (Teil A). `/profile` is the tab root,
/// `/settings` shows the same page (Konzept 18 §3, D2: Profil is a tab);
/// every settings page is a push in this tab, at most three levels deep.
/// Teil B's pages (`offers`, `health`, `plan`, `avo`, …) are mounted here
/// too; the profile root shows their rows once they exist.
final List<RouteBase> profileBranchRoutes = [
  GoRoute(
    path: RoutePaths.profile,
    name: 'profile',
    pageBuilder: (context, state) =>
        NoTransitionPage(key: state.pageKey, child: const ProfileRootScreen()),
  ),
  GoRoute(
    path: RoutePaths.settings,
    name: 'settings',
    pageBuilder: (context, state) =>
        NoTransitionPage(key: state.pageKey, child: const ProfileRootScreen()),
    routes: [
      ...profileSettingsRoutes,
      ...offersSettingsRoutes,
      ...avoSettingsRoutes,
      ...planSettingsRoutes,
      ...caloriesSettingsRoutes,
      ...historySettingsRoutes,
    ],
  ),
];

/// Profile routes outside the tab bar (Teil A).
///
/// `/diet-preferences` (old links, the Rezepte tip, the diet hint) is an
/// alias of `/settings/diet`: the same page, opened full screen over the tab
/// that asked, so Back returns there instead of jumping to the Profil tab.
final List<RouteBase> profileRoutes = [
  GoRoute(
    path: RoutePaths.dietPreferences,
    name: 'diet-preferences',
    builder: (context, state) {
      final row = _rowOf(state);
      return RowHighlightScope(
        rowId: row,
        child: DietSettingsScreen(highlightRowId: row),
      );
    },
  ),
];

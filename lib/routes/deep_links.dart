import 'package:shoply/routes/route_paths.dart';

/// The one place that turns a `shoply://` link into an app path (Teil A).
///
/// Widgets, Siri, controls and notifications (Teil B) open links like
/// `shoply://plan?day=2026-11-11` or `shoply://avo/voice`; the router's
/// redirect passes every custom-scheme URI through here. Links that trigger
/// an action instead of a screen (`add-item`, `create-list`) are handled by
/// `DeepLinkService` and land on Home. Unknown links land on Home too.
String mapCustomSchemeLink(Uri uri) {
  final host = uri.host;
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  String withQuery(String path) => uri.hasQuery ? '$path?${uri.query}' : path;
  String rest() => segments.isEmpty ? '' : '/${segments.join('/')}';

  switch (host) {
    // Shared content (ids required).
    case 'recipe':
    case 'list':
    case 'invite':
    case 'author':
      return segments.isEmpty ? RoutePaths.home : '/$host/${segments.first}';

    // Lists: overview, one list (optionally ?focus=add), shopping mode.
    case 'lists':
      return withQuery('${RoutePaths.lists}${rest()}');
    case 'shopping':
      final listId = uri.queryParameters['list'];
      return listId == null || listId.isEmpty
          ? RoutePaths.lists
          : '${RoutePaths.lists}/$listId/shopping';

    // Recipes: saved, search (?q=), one recipe.
    case 'recipes':
      if (segments.isNotEmpty && segments.first == 'search') {
        final q = uri.queryParameters['q'];
        return q == null ? RoutePaths.recipes : '${RoutePaths.recipes}?q=$q';
      }
      return withQuery('${RoutePaths.recipes}${rest()}');

    // Teil B areas and the rest of the app, path kept as is.
    case 'plan':
    case 'calories':
    case 'avo':
    case 'offers':
    case 'history':
    case 'splits':
    case 'settings':
    case 'pro':
    case 'profile':
    case 'home':
      return withQuery('/$host${rest()}');

    default:
      return RoutePaths.home;
  }
}

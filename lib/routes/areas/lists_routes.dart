import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/presentation/screens/lists/list_activities_screen.dart';
import 'package:shoply/presentation/screens/lists/list_detail_screen.dart';
import 'package:shoply/routes/route_paths.dart';

/// Lists (Teil A): one list full screen, its activities, and the shared-list
/// deep links.
final List<RouteBase> listsRoutes = [
  GoRoute(
    path: '${RoutePaths.lists}/:listId',
    name: 'list-detail',
    pageBuilder: (context, state) {
      final listId = state.pathParameters['listId']!;
      final listName = state.uri.queryParameters['name'] ?? 'Shopping List';
      return CupertinoPage(
        key: state.pageKey,
        child: ListDetailScreen(listId: listId, listName: listName),
      );
    },
    routes: [
      GoRoute(
        path: 'activities',
        name: 'list-activities',
        builder: (context, state) {
          final listId = state.pathParameters['listId']!;
          final listName = state.uri.queryParameters['name'] ?? 'Shopping List';
          return ListActivitiesScreen(listId: listId, listName: listName);
        },
      ),
    ],
  ),
  // Shared-list and invite deep links are aliases of /lists/:listId.
  // Logged-out users are sent to sign in first (top-level redirect).
  GoRoute(
    path: '/list/:listId',
    name: 'shared-list',
    redirect: (context, state) => sharedListTarget(state),
  ),
  GoRoute(
    path: '/invite/:listId',
    name: 'list-invite',
    redirect: (context, state) => sharedListTarget(state),
  ),
];

/// Maps `/list/:id` and `/invite/:id` onto the canonical `/lists/:id` route.
String sharedListTarget(GoRouterState state) {
  final listId = state.pathParameters['listId'] ?? state.uri.pathSegments.last;
  final listName = state.uri.queryParameters['name'] ?? 'Shared List';
  return RoutePaths.list(listId, name: listName);
}

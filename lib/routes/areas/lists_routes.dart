import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/presentation/screens/lists/all_lists_screen.dart';
import 'package:shoply/presentation/screens/lists/list_activities_screen.dart';
import 'package:shoply/presentation/screens/lists/list_detail_screen.dart';
import 'package:shoply/routes/route_paths.dart';

/// Routes of the Listen tab branch (Teil A): the overview and, below it, one
/// list and its activities (D2: the tab bar stays visible on a list).
final List<RouteBase> listsBranchRoutes = [
  GoRoute(
    path: RoutePaths.lists,
    name: 'lists',
    pageBuilder: (context, state) =>
        NoTransitionPage(key: state.pageKey, child: const AllListsScreen()),
    routes: [
      GoRoute(
        path: ':listId',
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
              final listName =
                  state.uri.queryParameters['name'] ?? 'Shopping List';
              return ListActivitiesScreen(listId: listId, listName: listName);
            },
          ),
        ],
      ),
    ],
  ),
];

/// Shared-list and invite deep links (Teil A), aliases of `/lists/:listId`.
/// Logged-out users are sent to sign in first (top-level redirect).
final List<RouteBase> listsRoutes = [
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

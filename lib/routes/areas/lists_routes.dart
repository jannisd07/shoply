import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/screens/lists/all_lists_screen.dart';
import 'package:shoply/presentation/screens/lists/list_activities_screen.dart';
import 'package:shoply/presentation/screens/lists/list_detail_screen.dart';
import 'package:shoply/presentation/screens/lists/shopping_mode_screen.dart';
import 'package:shoply/routes/app_branch.dart';
import 'package:shoply/routes/route_paths.dart';

/// Routes of the Listen tab branch (Teil A): the overview and, below it, one
/// list, its activities and its shopping mode (D2: the tab bar stays visible
/// on a list; the shopping mode opens above it).
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
          // `RoutePaths.shopping(listId)`: full screen on the root navigator,
          // pushed like a page (Reduce Motion: a short cross-fade).
          GoRoute(
            path: 'shopping',
            name: 'list-shopping',
            parentNavigatorKey: rootNavigatorKey,
            pageBuilder: (context, state) =>
                shoppingModePage(state, reduceMotion: context.reduceMotion),
          ),
        ],
      ),
    ],
  ),
];

/// The page of the shopping mode route: an iOS push, or a cross-fade with
/// Reduce Motion.
Page<void> shoppingModePage(GoRouterState state, {required bool reduceMotion}) {
  final child = ShoppingModeScreen(listId: state.pathParameters['listId']!);
  if (!reduceMotion) {
    return CupertinoPage<void>(key: state.pageKey, child: child);
  }
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: AvoMotion.fadeReduced,
    reverseTransitionDuration: AvoMotion.fadeReduced,
    transitionsBuilder: (context, animation, secondary, child) =>
        FadeTransition(opacity: animation, child: child),
    child: child,
  );
}

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

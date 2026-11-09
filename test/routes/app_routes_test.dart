import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/routes/app_branch.dart';
import 'package:shoply/routes/app_router.dart';
import 'package:shoply/routes/route_paths.dart';

/// Collects `name -> full path` for every named GoRoute, depth first.
Map<String, String> _collect(List<RouteBase> routes, [String parent = '']) {
  final out = <String, String>{};
  for (final r in routes) {
    if (r is GoRoute) {
      final full = r.path.startsWith('/')
          ? r.path
          : (parent == '/' ? '/${r.path}' : '$parent/${r.path}');
      if (r.name != null) out[r.name!] = full;
      out.addAll(_collect(r.routes, full));
    } else if (r is StatefulShellRoute) {
      for (final b in r.branches) {
        out.addAll(_collect(b.routes, parent));
      }
    } else if (r is ShellRouteBase) {
      out.addAll(_collect(r.routes, parent));
    }
  }
  return out;
}

void main() {
  test('A1 split keeps every route name and path', () {
    // Snapshot of lib/routes/app_router.dart before the split (07.11.2026),
    // plus the new mount points for Teil B (plan, settings, offers, history).
    const expected = {
      'onboarding': '/onboarding',
      'welcome': '/welcome',
      'login': '/login',
      'signup': '/signup',
      'reset-password': '/reset-password',
      'name-prompt': '/name-prompt',
      // New in A7: invitations by share code (Konzept 17 §5.1).
      'join-code': '/join/:code',
      'home': '/home',
      'recipes': '/recipes',
      'add-recipe': '/recipes/add',
      'recipe-drafts': '/recipes/drafts',
      'saved-recipes': '/recipes/saved',
      'my-recipes': '/recipes/my',
      'creators': '/recipes/creators',
      'popular-recipes': '/recipes/popular',
      'all-recipes': '/recipes/all',
      'category-recipes': '/recipes/category/:categoryId',
      'recipe-detail': '/recipes/:recipeId',
      'calories': '/calories',
      'profile': '/profile',
      'avo-chat': '/avo',
      'list-detail': '/lists/:listId',
      'list-activities': '/lists/:listId/activities',
      // New in A5: shopping mode above the tab bar.
      'list-shopping': '/lists/:listId/shopping',
      'author-profile': '/author/:authorId',
      'diet-preferences': '/diet-preferences',
      'shared-recipe': '/recipe/:recipeId',
      'shared-list': '/list/:listId',
      'list-invite': '/invite/:listId',
      // New in A1: where Teil B's routes are mounted.
      'plan': '/plan',
      'settings': '/settings',
      'offers': '/offers',
      'history': '/history',
      // New in A2: Listen tab root and the paywall path for Teil B.
      'lists': '/lists',
      'pro': '/pro',
      // Debug builds only (tests run in debug): the component gallery.
      'debug-components': '/debug/components',
    };
    expect(_collect(buildAppRoutes()), expected);
  });

  test('D2 tabs: Home, Listen, Avo, Rezepte, Profil', () {
    final shell = buildAppRoutes().whereType<StatefulShellRoute>().single;
    final roots = [
      for (final b in shell.branches) (b.routes.first as GoRoute).path,
    ];
    expect(roots, [
      RoutePaths.home,
      RoutePaths.lists,
      RoutePaths.avo,
      RoutePaths.recipes,
      RoutePaths.profile,
    ]);
    expect(shell.branches.length, AppBranch.values.length);
  });

  test('Kalorien pushes in Home, a list and Angebote/Verlauf in Listen, '
      'settings in Profil, plan in Rezepte', () {
    final shell = buildAppRoutes().whereType<StatefulShellRoute>().single;
    Iterable<String> paths(AppBranch b) =>
        shell.branches[b.index].routes.whereType<GoRoute>().map((r) => r.path);
    expect(paths(AppBranch.home), contains(RoutePaths.calories));
    expect(
      paths(AppBranch.lists),
      containsAll([RoutePaths.lists, RoutePaths.offers, RoutePaths.history]),
    );
    expect(paths(AppBranch.profile), contains(RoutePaths.settings));
    expect(paths(AppBranch.recipes), contains(RoutePaths.plan));
    final lists = shell.branches[AppBranch.lists.index].routes.first as GoRoute;
    expect((lists.routes.single as GoRoute).path, ':listId');
  });

  test(
    'RoutePaths.list builds the same link as the old shared-list target',
    () {
      expect(
        RoutePaths.list('abc', name: 'Shared List'),
        '/lists/abc?name=Shared+List',
      );
      expect(RoutePaths.list('abc'), '/lists/abc');
    },
  );
}

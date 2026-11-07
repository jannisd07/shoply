import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
    };
    expect(_collect(buildAppRoutes()), expected);
  });

  test('tab order stays Home, Rezepte, Kalorien, Profil until S2', () {
    final shell = buildAppRoutes().whereType<StatefulShellRoute>().single;
    final roots = [
      for (final b in shell.branches) (b.routes.first as GoRoute).path,
    ];
    // Settings and the plan segment stay in their tabs.
    final profile = shell.branches[3].routes.whereType<GoRoute>();
    expect(profile.map((r) => r.path), contains(RoutePaths.settings));
    final recipes = shell.branches[1].routes.whereType<GoRoute>();
    expect(recipes.map((r) => r.path), contains(RoutePaths.plan));
    expect(roots, [
      RoutePaths.home,
      RoutePaths.recipes,
      RoutePaths.calories,
      RoutePaths.profile,
    ]);
  });

  test('RoutePaths.list builds the same link as the old shared-list target',
      () {
    expect(RoutePaths.list('abc', name: 'Shared List'),
        '/lists/abc?name=Shared+List');
    expect(RoutePaths.list('abc'), '/lists/abc');
  });
}

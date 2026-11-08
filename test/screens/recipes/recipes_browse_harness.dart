import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/screens/recipes/all_recipes_screen.dart';
import 'package:shoply/presentation/screens/recipes/category_recipes_screen.dart';
import 'package:shoply/presentation/screens/recipes/recipes_home_data.dart';
import 'package:shoply/presentation/screens/recipes/recipes_screen.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_browse_state.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/recipes_provider.dart';
import 'package:shoply/presentation/state/saved_recipes_provider.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';

import '../../layout/layout_matrix.dart';

/// Provider overrides for the browse screens: local catalogue [seed], the
/// server's answer [fresh] (null: never answers), profile, list, modules.
List<Override> browseOverrides({
  List<Recipe>? seed,
  List<Recipe>? fresh,
  bool freshFails = false,
  RecipeDietProfile profile = RecipeDietProfile.none,
  bool offline = false,
  bool planOn = false,
  bool caloriesOn = false,
  List<Set<String>> listItems = const [],
  RecipeHighlights? highlights,
}) => [
  recipeCatalogueSeedProvider.overrideWithValue(seed),
  recipesProvider.overrideWith((ref) {
    if (freshFails) return Future<List<Recipe>>.error(Exception('offline'));
    if (fresh == null) return Completer<List<Recipe>>().future;
    return Future.value(fresh);
  }),
  recipeDietProfileProvider.overrideWithValue(profile),
  recipeDietProfileKnownProvider.overrideWithValue(true),
  recipeListItemStemsProvider.overrideWithValue(listItems),
  recipeHighlightsLoaderProvider.overrideWithValue(() async => highlights),
  isOfflineProvider.overrideWithValue(offline),
  authUserIdProvider.overrideWithValue('u1'),
  isRecipeSavedProvider.overrideWith((ref, id) => false),
  moduleEnabledProvider.overrideWith(
    (ref, module) => switch (module) {
      AppModule.mealPlan => planOn,
      AppModule.calories => caloriesOn,
      _ => false,
    },
  ),
];

/// Shows where a push went.
class BrowseProbe extends StatelessWidget {
  const BrowseProbe(this.location, {super.key});

  final String location;

  @override
  Widget build(BuildContext context) => Center(child: Text('at $location'));
}

/// The browse screens in a small router: the real screens for the tab,
/// category and "Alle" pages, a [BrowseProbe] for everything else.
GoRouter browseRouter({String initial = '/recipes'}) => GoRouter(
  initialLocation: initial,
  routes: [
    GoRoute(
      path: '/recipes',
      builder: (context, state) => RecipesScreen(
        initialQuery: state.uri.queryParameters['q'],
        initialSegment: state.uri.queryParameters['segment'] == 'plan'
            ? RecipesSegment.plan
            : null,
      ),
      routes: [
        GoRoute(
          path: 'popular',
          builder: (context, state) =>
              const AllRecipesScreen(popularOnly: true),
        ),
        GoRoute(
          path: 'all',
          builder: (context, state) => AllRecipesScreen(
            initialFilter: RecipeListFilter.byId(
              state.uri.queryParameters['filter'],
            ),
            initialSort: RecipeSort.byId(state.uri.queryParameters['sort']),
          ),
        ),
        GoRoute(
          path: 'category/:id',
          builder: (context, state) => CategoryRecipesScreen(
            categoryId: state.pathParameters['id']!,
            initialFilter: RecipeListFilter.byId(
              state.uri.queryParameters['filter'],
            ),
            initialSort: RecipeSort.byId(state.uri.queryParameters['sort']),
          ),
        ),
        GoRoute(
          path: ':rest',
          builder: (context, state) => BrowseProbe(state.uri.toString()),
        ),
      ],
    ),
    GoRoute(
      path: '/author/:id',
      builder: (context, state) => BrowseProbe(state.uri.toString()),
    ),
    GoRoute(
      path: '/diet-preferences',
      builder: (context, state) => BrowseProbe(state.uri.toString()),
    ),
  ],
);

/// Pumps [router] at 390 pt like the app (design scope, toast host).
Future<void> pumpBrowse(
  WidgetTester tester,
  List<Override> overrides, {
  GoRouter? router,
  ProviderContainer? container,
  double scale = 1,
}) async {
  await loadLayoutFonts();
  tester.view.physicalSize = const Size(390 * 3, kLayoutHeight * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final config = router ?? browseRouter();
  final app = MediaQuery(
    data: MediaQueryData(
      size: const Size(390, kLayoutHeight),
      devicePixelRatio: 3,
      textScaler: TextScaler.linear(scale),
      padding: const EdgeInsets.only(top: 47, bottom: 34),
      viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
    ),
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        platform: TargetPlatform.iOS,
        fontFamily: 'CupertinoSystemText',
      ),
      routerConfig: config,
      builder: (context, child) =>
          AvoDesignScope(child: AvoToastHost(child: child!)),
    ),
  );
  await tester.pumpWidget(
    container == null
        ? ProviderScope(overrides: overrides, child: app)
        : UncontrolledProviderScope(container: container, child: app),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// Where [router] is now.
String browseLocation(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

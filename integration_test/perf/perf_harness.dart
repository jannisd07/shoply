import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'package:shoply/core/design/avo_design_scope.dart';
import 'package:shoply/core/localization/app_localizations.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/core/theme/app_theme.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/repositories/item_repository.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/data/services/open_food_facts_service.dart';
import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/providers/article_image_settings_provider.dart';
import 'package:shoply/presentation/providers/offer_display_prefs_provider.dart';
import 'package:shoply/presentation/providers/price_comparison_provider.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_detail_data.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_maybe_also.dart';
import 'package:shoply/presentation/screens/profile/settings/data/list_preferences.dart';
import 'package:shoply/presentation/screens/recipes/recipes_home_data.dart';
import 'package:shoply/presentation/screens/recipes/recipes_screen.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_browse_state.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/state/recipes_provider.dart';
import 'package:shoply/presentation/state/saved_recipes_provider.dart';
import 'package:shoply/presentation/widgets/article_image.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';

/// Shared setup of the frame measurements (Konzept 20 §5.1, §7.7): real
/// A widgets fed with test data through provider overrides, no Supabase.
/// Photos come from a small HTTP server on 127.0.0.1 that serves the
/// bundled `assets/avo/` pictures, so the real image path
/// (`CachedNetworkImage`, decode, cache) runs without the internet.

/// The list every scenario shows.
const String perfListId = 'perf-list';
const String perfListName = 'Wocheneinkauf';

final DateTime _at = DateTime(2026, 11, 9, 10);

/// Budget of §5.1 for S1, S2 and S5 (iPhone 13 Pro, 120 Hz).
const double perfTargetP90Millis = 8.3;
const double perfLimitWorstMillis = 16;

// ------------------------------------------------------------------ binding

/// The integration binding with every frame drawn, as in the app (not only
/// the frames the test pumps).
IntegrationTestWidgetsFlutterBinding perfBinding() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  return binding;
}

/// Runs [action] under `watchPerformance`; the summary lands in the report
/// under [reportKey] (written by `test_driver/perf_driver.dart`). Without
/// the integration binding (a plain widget test run of the harness) it
/// just runs [action].
Future<void> measure(String reportKey, Future<void> Function() action) async {
  final binding = WidgetsBinding.instance;
  if (binding is IntegrationTestWidgetsFlutterBinding) {
    await binding.watchPerformance(action, reportKey: reportKey);
  } else {
    await action();
  }
}

/// Lets [duration] pass while frames keep coming (live: real time).
Future<void> idle(WidgetTester tester, Duration duration) =>
    tester.pump(duration);

/// Empties the decoded-image cache, so photos decode again.
void coldImageCache() {
  PaintingBinding.instance.imageCache
    ..clear()
    ..clearLiveImages();
}

/// The vertical scroll view of the screen (its outermost `Scrollable`).
Finder mainScrollable() => find
    .descendant(
      of: find.byType(CustomScrollView).first,
      matching: find.byType(Scrollable),
    )
    .first;

/// [times] flings up or down on [scrollable], each followed by
/// [settle] for the momentum to run out.
Future<void> flingSeries(
  WidgetTester tester,
  Finder scrollable, {
  required bool down,
  int times = 3,
  double distance = 600,
  double speed = 3000,
  Duration settle = const Duration(milliseconds: 1600),
}) async {
  for (var i = 0; i < times; i++) {
    await tester.fling(
      scrollable,
      Offset(0, down ? -distance : distance),
      speed,
      warnIfMissed: false,
    );
    await idle(tester, settle);
  }
}

// ------------------------------------------------------------------ images

/// Serves the `assets/avo/` pictures over HTTP on 127.0.0.1, one URL per
/// item or recipe. Every run gets its own query token, so the disk cache
/// of `CachedNetworkImage` is cold at the start of each run.
class PerfImageServer {
  PerfImageServer._(this._server, this._pictures)
    : _run = DateTime.now().microsecondsSinceEpoch;

  static const List<String> _assets = [
    'assets/avo/avo_waving.png',
    'assets/avo/avo_excited.png',
    'assets/avo/avo_thinking.png',
    'assets/avo/avo_celebrating.png',
  ];

  final HttpServer _server;
  final List<Uint8List> _pictures;
  final int _run;

  /// Starts the server (call in `setUpAll`, outside the test's clock).
  static Future<PerfImageServer> start() async {
    final pictures = [
      for (final a in _assets) (await rootBundle.load(a)).buffer.asUint8List(),
    ];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final images = PerfImageServer._(server, pictures);
    server.listen(images._answer);
    return images;
  }

  void _answer(HttpRequest request) {
    final name = request.uri.pathSegments.isEmpty
        ? ''
        : request.uri.pathSegments.last;
    final n = int.tryParse(name.split('.').first) ?? 0;
    request.response
      ..headers.contentType = ContentType('image', 'png')
      ..add(_pictures[n % _pictures.length]);
    unawaited(request.response.close());
  }

  /// The photo URL of picture [n].
  String url(int n) => 'http://127.0.0.1:${_server.port}/img/$n.png?run=$_run';

  Future<void> close() => _server.close(force: true);
}

// ------------------------------------------------------------------ app

/// The app's root around [home] or [router]: German, the D2 design scope,
/// a `ScaffoldMessenger` and the toast host like `app.dart`, on the real
/// screen of the device (no MediaQuery override).
Widget perfApp({
  required List<Override> overrides,
  Widget? home,
  GoRouter? router,
}) {
  assert((home == null) != (router == null), 'home or router');
  Widget wrap(BuildContext context, Widget? child) => AvoDesignScope(
    child: ScaffoldMessenger(child: AvoToastHost(child: child!)),
  );
  const delegates = [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];
  final theme = AppTheme.of(Brightness.light);
  const locale = Locale('de');
  return ProviderScope(
    overrides: overrides,
    child: router == null
        ? MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: delegates,
            builder: wrap,
            home: home,
          )
        : MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: theme,
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: delegates,
            builder: wrap,
            routerConfig: router,
          ),
  );
}

/// Article images on, every item photo from [images], no offers.
List<Override> articleImageOverrides(PerfImageServer images) => [
  showArticleImagesProvider.overrideWith(
    (ref) => ShowArticleImagesNotifier(null, known: true),
  ),
  offPhotoLookupProvider.overrideWithValue(
    (barcode) async => OffProductPhoto(
      barcode: barcode,
      smallUrl: images.url(int.parse(barcode.substring(9))),
    ),
  ),
  offerSurfaceVisibleProvider.overrideWith((ref, key) => false),
  itemOfferProvider.overrideWith((ref, key) => null),
];

// ------------------------------------------------------------------ items

/// The eight aisles of "Wocheneinkauf" with their items (60 in all).
const Map<String, List<String>> _aisles = {
  'fruits_vegetables': [
    'Bananen',
    'Äpfel',
    'Tomaten',
    'Gurken',
    'Paprika',
    'Zwiebeln',
    'Karotten',
    'Avocados',
    'Zitronen',
    'Spinat',
  ],
  'bakery': [
    'Vollkornbrot',
    'Brötchen',
    'Croissants',
    'Laugenbrezeln',
    'Toast',
    'Knäckebrot',
  ],
  'meat_fish': [
    'Hähnchenbrust',
    'Hackfleisch',
    'Lachs',
    'Thunfisch',
    'Salami',
    'Kochschinken',
    'Garnelen',
  ],
  'staples': [
    'Spaghetti',
    'Reis',
    'Mehl',
    'Zucker',
    'Haferflocken',
    'Rote Linsen',
    'Olivenöl',
    'Passierte Tomaten',
    'Kichererbsen',
  ],
  'snacks': [
    'Schokolade',
    'Chips',
    'Nüsse',
    'Kekse',
    'Müsliriegel',
    'Gummibärchen',
  ],
  'beverages': [
    'Mineralwasser',
    'Orangensaft',
    'Kaffee',
    'Tee',
    'Apfelschorle',
    'Hafermilch',
  ],
  'dairy': [
    'Milch',
    'Butter',
    'Joghurt',
    'Feta',
    'Gouda',
    'Sahne',
    'Eier',
    'Quark',
    'Mozzarella',
  ],
  'frozen': [
    'Erbsen',
    'Pizza',
    'Spinat tiefgekühlt',
    'Beeren',
    'Pommes',
    'Eis',
    'Fischstäbchen',
  ],
};

ShoppingItemModel _item(
  int n,
  String name,
  String category, {
  bool checked = false,
}) => ShoppingItemModel(
  id: 'i$n',
  listId: perfListId,
  name: name,
  categoryId: category,
  category: category,
  quantity: n % 4 == 0 ? 2 : 1,
  unit: n % 7 == 0 ? 'kg' : null,
  price: n % 3 == 0 ? 0.99 + n / 10 : null,
  notes: n % 9 == 0 ? 'Bio, wenn es gibt' : null,
  // EAN-13 shape: "400000000" + four digits; those pick the photo.
  barcode: '400000000${n.toString().padLeft(4, '0')}',
  orderIndex: n,
  isChecked: checked,
  checkedAt: checked ? _at : null,
  createdAt: _at,
  updatedAt: _at,
);

/// "Wocheneinkauf": 60 items in 8 aisles, each with a photo; every tenth
/// one is already checked (so "Erledigt" has rows too).
List<ShoppingItemModel> weeklyShopItems() {
  var n = 0;
  return [
    for (final aisle in _aisles.entries)
      for (final name in aisle.value)
        _item(n++, name, aisle.key, checked: n % 10 == 0),
  ];
}

/// The shopping mode: 20 open items in 5 aisles.
List<ShoppingItemModel> shoppingModeItems() {
  var n = 0;
  final picks = <String, int>{
    'fruits_vegetables': 6,
    'bakery': 3,
    'meat_fish': 3,
    'staples': 4,
    'dairy': 4,
  };
  return [
    for (final e in picks.entries)
      for (final name in _aisles[e.key]!.take(e.value)) _item(n++, name, e.key),
  ];
}

class _NoRepository extends Fake implements ItemRepository {}

/// Items of the list screen: start with [items], apply checks locally,
/// never load or listen to the server.
class PerfItemsNotifier extends ItemsNotifier {
  PerfItemsNotifier(List<ShoppingItemModel> items)
    : super(_NoRepository(), perfListId) {
    state = AsyncData(items);
  }

  List<ShoppingItemModel> get _current => state.valueOrNull ?? const [];

  @override
  Future<void> loadItems() async {}

  @override
  void startRealtime() {}

  @override
  void stopRealtime() {}

  @override
  Future<void> toggleItemChecked(String itemId, bool isChecked) async {
    state = AsyncData([
      for (final i in _current)
        i.id == itemId ? i.copyWith(isChecked: isChecked, checkedAt: _at) : i,
    ]);
  }
}

/// Opens nothing: the measurements never navigate.
class _NoActions extends ListDetailActions {
  const _NoActions();
}

/// Overrides for `ListDetailScreen` with "Wocheneinkauf" (S1).
List<Override> listScreenOverrides(PerfImageServer images) => [
  ...articleImageOverrides(images),
  itemsNotifierProvider.overrideWith(
    (ref, id) => PerfItemsNotifier(weeklyShopItems()),
  ),
  itemRepositoryProvider.overrideWithValue(_NoRepository()),
  listDetailListProvider.overrideWith(
    (ref, id) => ShoppingListModel(
      id: perfListId,
      name: perfListName,
      ownerId: 'u1',
      isShared: true,
      createdAt: _at,
      updatedAt: _at,
    ),
  ),
  listDetailMembersProvider.overrideWith((ref, id) async => const ['Lena']),
  authUserIdProvider.overrideWithValue('u1'),
  currentUserProvider.overrideWith((ref) async => null),
  isOfflineProvider.overrideWithValue(false),
  offersAvailableProvider.overrideWithValue(false),
  listDetailActionsProvider.overrideWithValue(const _NoActions()),
  maybeAlsoSourceProvider.overrideWithValue(const []),
  listPreferencesProvider.overrideWith(
    (ref) =>
        ListPreferencesNotifier(null)
          ..state = const ListPreferences(sharePresence: false),
  ),
];

// ------------------------------------------------------------------ recipes

const List<(String, String, List<String>)> _dishes = [
  ('Shakshuka mit Feta', 'vegetarian', ['Tomaten', 'Eier', 'Feta']),
  ('Rotes Linsen-Dal', 'vegan', ['Rote Linsen', 'Kokosmilch', 'Spinat']),
  ('Avocado-Pasta', 'vegetarian', ['Spaghetti', 'Avocado', 'Zitrone']),
  ('Erdnuss-Satay', 'asian', ['Hähnchenbrust', 'Erdnussbutter']),
  ('Ofengemüse mit Feta', 'vegetarian', ['Paprika', 'Zucchini', 'Feta']),
  ('Kürbis-Risotto', 'vegetarian', ['Reis', 'Kürbis', 'Parmesan']),
  ('Zitronen-Hähnchen', 'healthy', ['Hähnchenbrust', 'Zitronen']),
  ('Chili sin Carne', 'vegan', ['Kidneybohnen', 'Mais', 'Tomaten']),
  ('Lachs mit Ofenkartoffeln', 'healthy', ['Lachs', 'Kartoffeln']),
  ('Gemüsecurry', 'vegan', ['Kokosmilch', 'Brokkoli', 'Reis']),
  ('Spaghetti Bolognese', 'italian', ['Spaghetti', 'Hackfleisch']),
  ('Griechischer Salat', 'vegetarian', ['Gurken', 'Tomaten', 'Feta']),
  ('Pfannkuchen', 'vegetarian', ['Mehl', 'Milch', 'Eier']),
  ('Falafel-Bowl', 'vegan', ['Kichererbsen', 'Gurken', 'Reis']),
  ('Pizza Margherita', 'italian', ['Mehl', 'Tomaten', 'Mozzarella']),
  ('Tomatensuppe', 'vegan', ['Tomaten', 'Zwiebeln']),
  ('Thai-Nudeln', 'asian', ['Reisnudeln', 'Erdnüsse', 'Limette']),
  ('Käsespätzle', 'vegetarian', ['Mehl', 'Eier', 'Bergkäse']),
  ('Hummus mit Fladenbrot', 'vegan', ['Kichererbsen', 'Tahin']),
  ('Gefüllte Paprika', 'healthy', ['Paprika', 'Hackfleisch', 'Reis']),
  ('Overnight Oats', 'vegetarian', ['Haferflocken', 'Joghurt', 'Beeren']),
  ('Minestrone', 'vegan', ['Karotten', 'Bohnen', 'Nudeln']),
  ('Teriyaki-Lachs', 'asian', ['Lachs', 'Sojasauce', 'Reis']),
  ('Linsensalat', 'vegan', ['Rote Linsen', 'Paprika', 'Zitronen']),
];

/// 24 recipes with photos (author avatars too), enough for every section
/// of the tab (hero, "Beliebt diese Woche", "Neu", from 8 on).
List<Recipe> perfRecipes(PerfImageServer images) => [
  for (var i = 0; i < _dishes.length; i++)
    Recipe(
      id: 'r$i',
      name: _dishes[i].$1,
      description: '',
      imageUrl: images.url(100 + i),
      prepTimeMinutes: 10 + i % 3 * 5,
      cookTimeMinutes: 10 + i % 4 * 10,
      defaultServings: 2,
      ingredients: [
        for (final name in _dishes[i].$3)
          Ingredient(name: name, amount: 1, unit: ''),
      ],
      instructions: const ['Vorbereiten', 'Kochen', 'Anrichten'],
      authorId: 'a${i % 4}',
      authorName: const [
        'Mara Köhler',
        'Deniz Aydın',
        'Jonas Weber',
        'Lena Roth',
      ][i % 4],
      authorAvatarUrl: images.url(200 + i % 4),
      createdAt: _at.subtract(Duration(days: i * 2)),
      averageRating: 4 + (i % 10) / 10,
      ratingCount: 10 + i * 7,
      viewCount: 100 + i * 13,
      labels: [_dishes[i].$2],
    ),
];

/// Overrides for `RecipesScreen` with [recipes] (local and from the
/// server), the list's items for "Passt zu deiner Liste", plan and
/// calories off.
List<Override> recipesTabOverrides(List<Recipe> recipes) => [
  recipeCatalogueSeedProvider.overrideWithValue(recipes),
  recipesProvider.overrideWith((ref) async => recipes),
  recipeDietProfileProvider.overrideWithValue(RecipeDietProfile.none),
  recipeDietProfileKnownProvider.overrideWithValue(true),
  recipeListItemStemsProvider.overrideWithValue([
    nameStems('Tomaten'),
    nameStems('Feta'),
    nameStems('Eier'),
  ]),
  recipeHighlightsLoaderProvider.overrideWithValue(
    () async => RecipeHighlights(
      popularIds: [for (final r in recipes.take(8)) r.id],
      weekId: recipes[3].id,
    ),
  ),
  isOfflineProvider.overrideWithValue(false),
  authUserIdProvider.overrideWithValue('u1'),
  isRecipeSavedProvider.overrideWith((ref, id) => false),
  moduleEnabledProvider.overrideWith((ref, module) => false),
];

/// The tab in a small router; every push lands on a blank page.
GoRouter recipesTabRouter() => GoRouter(
  initialLocation: '/recipes',
  routes: [
    GoRoute(
      path: '/recipes',
      builder: (context, state) => const RecipesScreen(),
      routes: [
        GoRoute(
          path: ':rest',
          builder: (context, state) => const SizedBox.shrink(),
        ),
      ],
    ),
    GoRoute(
      path: '/:rest',
      builder: (context, state) => const SizedBox.shrink(),
    ),
  ],
);

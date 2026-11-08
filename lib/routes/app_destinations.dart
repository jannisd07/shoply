import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/routes/deep_links.dart';
import 'package:shoply/routes/route_paths.dart';

/// Destination ids that Avo's answer cards, notifications and widgets use to
/// open a place in the app without knowing its route (Teil A, S2b).
///
/// | Id | Opens |
/// |---|---|
/// | `home`, `lists`, `avo`, `recipes`, `profile` | the tab |
/// | `list:<listId>` | one list |
/// | `list:<listId>:add` | one list with the add field focused |
/// | `shopping:<listId>` | shopping mode of a list |
/// | `recipe:<recipeId>` | one recipe |
/// | `recipes:saved` | saved recipes |
/// | `plan` | Wochenplan segment in the Rezepte tab |
/// | `calories`, `offers`, `history` | the Teil B area |
/// | `settings`, `settings:<page>` | settings (`settings:offers` …) |
/// | `pro`, `pro:<feature>` | the paywall |
///
/// A path (`/lists/l1`) or a `shoply://` link is accepted as well.
abstract final class AppDestinations {
  static const home = 'home';
  static const lists = 'lists';
  static const avo = 'avo';
  static const recipes = 'recipes';
  static const profile = 'profile';
  static const plan = 'plan';
  static const calories = 'calories';
  static const offers = 'offers';
  static const history = 'history';
  static const settings = 'settings';
  static const pro = 'pro';
  static const savedRecipes = 'recipes:saved';

  static String list(String listId, {bool focusAdd = false}) =>
      focusAdd ? 'list:$listId:add' : 'list:$listId';
  static String shopping(String listId) => 'shopping:$listId';
  static String recipe(String recipeId) => 'recipe:$recipeId';
  static String settingsPage(String page) => 'settings:$page';
  static String proFeature(String feature) => 'pro:$feature';
}

/// The app path for a destination [id], or `null` if the id is unknown or
/// misses its argument.
String? appDestinationPath(String id) {
  final trimmed = id.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.startsWith('/')) return trimmed;
  if (trimmed.startsWith('shoply://')) {
    final uri = Uri.tryParse(trimmed);
    return uri == null ? null : mapCustomSchemeLink(uri);
  }

  final parts = trimmed.split(':');
  final kind = parts.first;
  final arg = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;
  final extra = parts.length > 2 ? parts[2] : null;

  switch (kind) {
    case AppDestinations.home:
      return RoutePaths.home;
    case AppDestinations.lists:
      return RoutePaths.lists;
    case AppDestinations.avo:
      return RoutePaths.avo;
    case AppDestinations.recipes:
      if (arg == 'saved') return '${RoutePaths.recipes}/saved';
      return RoutePaths.recipes;
    case AppDestinations.profile:
      return RoutePaths.profile;
    case AppDestinations.plan:
      return RoutePaths.recipesPlanSegment;
    case AppDestinations.calories:
      return RoutePaths.calories;
    case AppDestinations.offers:
      return RoutePaths.offers;
    case AppDestinations.history:
      return RoutePaths.history;
    case AppDestinations.settings:
      return arg == null
          ? RoutePaths.settings
          : '${RoutePaths.settings}/$arg';
    case AppDestinations.pro:
      return arg == null ? RoutePaths.pro : RoutePaths.proFor(arg);
    case 'list':
      if (arg == null) return null;
      final path = '${RoutePaths.lists}/$arg';
      return extra == 'add' ? '$path?focus=add' : path;
    case 'shopping':
      return arg == null ? null : '${RoutePaths.lists}/$arg/shopping';
    case 'recipe':
      return arg == null ? null : RoutePaths.recipe(arg);
    default:
      return null;
  }
}

/// Opens the destination [id] (see [AppDestinations]). Tab destinations
/// switch the tab and keep its stack; the paywall opens on top so it can be
/// closed again. Returns `false` and does nothing for an unknown id.
bool openAppDestination(BuildContext context, String id) {
  final path = appDestinationPath(id);
  if (path == null) return false;
  if (path == RoutePaths.pro || path.startsWith('${RoutePaths.pro}?')) {
    context.push(path);
  } else {
    context.go(path);
  }
  return true;
}

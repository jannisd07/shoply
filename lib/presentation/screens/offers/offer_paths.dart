/// Paths of the offer and market screens below Teil B's roots `/offers` and
/// `/stores` (`angebote.md` 1.2). Open them with `context.push`.
library;

import 'package:shoply/routes/route_paths.dart';

/// "Markt wählen" (S2), full screen above the tab bar.
const String storePickerPath = RoutePaths.storesPick;

/// Where "Markt wählen" was opened from (`from=`).
enum StorePickerOrigin { chip, checkout, newList, info }

/// `/stores/pick?list=…&from=…`. With [listId] the screen saves the choice
/// itself and shows the undo toast; without it, it only returns the choice.
String storePickerLocation({
  String? listId,
  StorePickerOrigin from = StorePickerOrigin.chip,
}) => Uri(
  path: storePickerPath,
  queryParameters: {if (listId != null) 'list': listId, 'from': from.name},
).toString();

/// The offer detail (S5) pattern, full screen above the tab bar.
const String offerDetailPattern = RoutePaths.offersOfferPattern;

/// What the main action of the offer detail does (`mode=`).
enum OfferDetailMode {
  /// "Preis übernehmen" for the item the offer belongs to.
  take,

  /// "Auf die Liste".
  add,
}

/// `/offers/offer/:offerId?list=…&item=…&mode=…&name=…`. [name] is the item
/// name "Auf die Liste" uses ("Milch" as typed, not the product name).
String offerDetailLocation(
  int offerId, {
  String? listId,
  String? itemId,
  OfferDetailMode? mode,
  String? name,
}) => Uri(
  path: '${RoutePaths.offers}/offer/$offerId',
  queryParameters: {
    if (listId != null) 'list': listId,
    if (itemId != null) 'item': itemId,
    if (mode != null) 'mode': mode.name,
    if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
  },
).toString();

/// "Angebote der Woche" (S10), the root in the Listen tab. [regulars] opens
/// the segment "Oft gekauft" (`filter=regulars`), [query] fills the search
/// (`q=`, from Avo).
String weeklyOffersLocation({bool regulars = false, String? query}) => Uri(
  path: RoutePaths.offers,
  queryParameters: {
    if (regulars) 'filter': 'regulars',
    if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
  },
).toString().replaceFirst(RegExp(r'\?$'), '');

/// "Angebote bei {Markt}" (S9), a child of `/offers` in the Listen tab.
const String offerListChildPattern = 'list/:listId';

/// `/offers/list/:listId`.
String offerListLocation(String listId) =>
    '${RoutePaths.offers}/list/${Uri.encodeComponent(listId)}';

/// "Angebote für {Rezept}" (S15), full screen above the tab bar.
const String offerRecipePattern = RoutePaths.offersRecipePattern;

/// `/offers/recipe/:recipeId?list=…&servings=…`.
String offerRecipeLocation(
  String recipeId, {
  required String listId,
  int? servings,
}) => Uri(
  path: '${RoutePaths.offers}/recipe/${Uri.encodeComponent(recipeId)}',
  queryParameters: {
    'list': listId,
    if (servings != null) 'servings': '$servings',
  },
).toString();

/// Region (S11) full screen above the tab bar (core).
const String storeRegionPath = RoutePaths.storesRegion;

/// Where the region screen was opened from (`from=`).
enum RegionOrigin { list, offers, panel, avo }

/// `/stores/region?from=…`; returns `true` when a region was saved.
String storeRegionLocation({RegionOrigin from = RegionOrigin.list}) =>
    '$storeRegionPath?from=${from.name}';

/// "Preise & Angebote" (S12) in the Profil tab.
const String offersSettingsPath = RoutePaths.settingsOffers;

/// Region (S11) inside the Profil tab.
const String offersSettingsRegionPath = RoutePaths.settingsOffersRegion;

/// "Lieblingsmärkte" (S13) inside the Profil tab.
const String offersSettingsMarketsPath = RoutePaths.settingsOffersMarkets;

/// Paths of the offer and market screens below Teil B's roots `/offers` and
/// `/stores` (`angebote.md` 1.2). Open them with `context.push`.
library;

import 'package:shoply/routes/route_paths.dart';

/// "Markt wählen" (S2), full screen above the tab bar.
const String storePickerPath = '${RoutePaths.stores}/pick';

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
const String offerDetailPattern = '${RoutePaths.offers}/offer/:offerId';

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

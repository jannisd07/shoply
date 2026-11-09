/// Paths of the history area (verlauf-kosten.md §1.2). Open them with
/// `context.push`, never `go`.
library;

import 'package:shoply/routes/route_paths.dart';

/// V1 "Einkauf abschließen", full screen above the tab bar.
const String checkoutPattern = '${RoutePaths.checkout}/:listId';

/// Where V1 was opened from (`source=`, analytics only).
enum CheckoutSource { shoppingMode, menu, avo }

/// `/checkout/:listId?source=…`.
String checkoutLocation(String listId, {CheckoutSource? source}) => Uri(
  path: '${RoutePaths.checkout}/${Uri.encodeComponent(listId)}',
  queryParameters: {
    if (source != null)
      'source': switch (source) {
        CheckoutSource.shoppingMode => 'shopping_mode',
        CheckoutSource.menu => 'menu',
        CheckoutSource.avo => 'avo',
      },
  },
).toString().replaceFirst(RegExp(r'\?$'), '');

/// V5 "Einkauf-Detail": `/history/:tripId` (child of the history root).
String historyTripLocation(String tripId) =>
    '${RoutePaths.history}/${Uri.encodeComponent(tripId)}';

/// V7 "Kosten teilen", relative to the history root (`historyChildRoutes`,
/// with `parentNavigatorKey: rootNavigatorKey`). Slice W11 registers the
/// screen under this path; V1 offers "Kosten teilen" once it exists.
const String historySplitChildPath = ':tripId/split';

/// `/history/:tripId/split?amount=<Cent>&from=checkout`.
String historySplitLocation(
  String tripId, {
  int? amountCents,
  bool fromCheckout = false,
}) => Uri(
  path: '${RoutePaths.history}/${Uri.encodeComponent(tripId)}/split',
  queryParameters: {
    if (amountCents != null) 'amount': '$amountCents',
    if (fromCheckout) 'from': 'checkout',
  },
).toString().replaceFirst(RegExp(r'\?$'), '');

/// V2 "Markt für diesen Einkauf": the store picker in mode `trip`. It only
/// returns the choice (`pop(StoreChoice)`); [listId] fills "Deine Märkte"
/// with the list's markets, [selected] shows the check mark.
String storePickTripLocation({String? listId, String? selected}) => Uri(
  path: RoutePaths.storesPick,
  queryParameters: {
    'mode': 'trip',
    'listId': ?listId,
    'selected': ?selected,
  },
).toString();

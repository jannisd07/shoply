import 'package:flutter/foundation.dart' show immutable;

import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/models/shopping_item_model.dart';

/// Where the market of a trip came from (`shopping_history.store_source`).
enum TripStoreSource {
  /// The market of the list ("Markt dieser Liste").
  list,

  /// The same market twice in a row on this list ("Wie beim letzten Mal").
  learned,

  /// Found from the person's location ("REWE (hier)").
  location,

  /// Picked by the person (a chip or "Anderer Markt …").
  user,
}

/// What "Einkauf speichern" (V1) sends.
@immutable
class CheckoutRequest {
  const CheckoutRequest({
    required this.listId,
    required this.listName,
    required this.checkedItems,
    this.chainId,
    this.storeSource,
    this.totalCostCents,
    this.splitPlanned = false,
    this.notifyUserIds = const [],
    this.actorName,
  });

  final String listId;
  final String listName;

  /// The checked items as the app shows them; the server re-reads them.
  final List<ShoppingItemModel> checkedItems;

  /// `StoreChainDirectory` id of the market, or null ("Ohne Markt").
  final String? chainId;
  final TripStoreSource? storeSource;

  /// What the person typed, in cents; null without an amount (never from
  /// offer prices, Bug 7).
  final int? totalCostCents;

  /// "Kosten teilen" was on in V1.
  final bool splitPlanned;

  /// Members who get "{name} hat bei {store} eingekauft" after the undo
  /// window (never the person who finished, V14).
  final List<String> notifyUserIds;

  /// The finishing person's name for that push; null: "Ein Mitglied".
  final String? actorName;
}

/// The outcome of [ShoppingHistoryService.completeTrip].
sealed class CheckoutResult {
  const CheckoutResult();
}

/// The trip is in the history.
final class CheckoutSaved extends CheckoutResult {
  const CheckoutSaved({
    required this.trip,
    this.undoToken,
    this.legacy = false,
    this.restoreItems = const [],
  });

  /// The new history entry (with item snapshots).
  final ShoppingHistory trip;

  /// For `undo_shopping_trip`; null on the fallback path (see [legacy]).
  final String? undoToken;

  /// Saved with today's inserts because the server functions are missing
  /// (migration `b_trip_checkout` not applied yet). Undo then deletes the
  /// trip and puts the items back as new rows.
  final bool legacy;

  /// The removed list items, for the fallback undo.
  final List<ShoppingItemModel> restoreItems;
}

/// A member finished the list a moment earlier; nothing was saved.
final class CheckoutAlreadyCompleted extends CheckoutResult {
  const CheckoutAlreadyCompleted({this.tripId, this.byName});

  /// Their trip, for "Zum Verlauf".
  final String? tripId;

  /// "Lena"; null when unknown ("Ein Mitglied").
  final String? byName;
}

/// The list was deleted while V1 was open.
final class CheckoutListGone extends CheckoutResult {
  const CheckoutListGone();
}

/// Nothing is checked any more (someone took it back).
final class CheckoutNothingChecked extends CheckoutResult {
  const CheckoutNothingChecked();
}

/// Not saved yet: offline, slow or failed. The trip shows in the history
/// with the sync mark (or "Nicht gespeichert" after a failure); the items
/// stay checked on the list until the server confirms.
final class CheckoutPending extends CheckoutResult {
  const CheckoutPending({required this.localTripId, this.failed = false});

  /// Id of the local entry (`local-…`) for retry and undo.
  final String localTripId;

  /// True after a failed attempt ("Nicht gespeichert", tap retries).
  final bool failed;
}

/// The outcome of [ShoppingHistoryService.undoTrip].
enum UndoTripResult {
  /// The trip is gone and the items are checked again.
  undone,

  /// The server refused: a member split the trip meanwhile, or the window
  /// is over ("Widerrufen hat nicht geklappt.").
  refused,

  /// The network or server failed.
  failed,
}

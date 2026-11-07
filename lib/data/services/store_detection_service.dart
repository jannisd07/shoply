/// Decides which supermarket chain a shopping list belongs to (Kap. 12,
/// "Markt pro Liste"). Pure logic: the provider in
/// `presentation/providers/store_for_list_provider.dart` gathers the signals.
library;

/// Where a list's market came from. The StoreChip shows a confirmed guess as
/// "Lidl" and an unconfirmed one as "Lidl?" ("Ist das deine Lidl-Liste?").
enum StoreSource { user, learned, name, location, privateLabel }

class StoreGuess {
  const StoreGuess(this.chainId, this.source, {required this.confirmed});

  /// Chain id from `StoreChainDirectory`, e.g. `lidl`, `rewe`, `aldi-sued`.
  final String chainId;
  final StoreSource source;

  /// False means "only a suggestion": the app asks before it filters offers.
  final bool confirmed;

  @override
  bool operator ==(Object other) =>
      other is StoreGuess &&
      other.chainId == chainId &&
      other.source == source &&
      other.confirmed == confirmed;

  @override
  int get hashCode => Object.hash(chainId, source, confirmed);

  @override
  String toString() => 'StoreGuess($chainId, $source, confirmed: $confirmed)';
}

/// The market of one list, from all signals; null when nothing points
/// anywhere.
///
/// - [explicitChainId]: the person picked the market. Always wins.
/// - [nameChainId]: matched from the list name ("Lidl Wocheneinkauf").
/// - [recentTripChains]: chains of this list's last completed purchases,
///   newest first (from the shopping history).
/// - [nearbyChainId]: the store within 250 m right now. Only ever a
///   suggestion, never confirmed on its own.
/// - [privateLabelHits]: chain id -> number of open items that are that
///   chain's own brands ("Milbona" -> lidl). A weak signal.
StoreGuess? resolveStoreForList({
  String? explicitChainId,
  String? nameChainId,
  List<String> recentTripChains = const [],
  String? nearbyChainId,
  Map<String, int> privateLabelHits = const {},
}) {
  // TODO(human): decide how the remaining signals combine when there is no
  // explicit choice. Placeholder until then: only the explicit choice counts.
  if (explicitChainId != null) {
    return StoreGuess(explicitChainId, StoreSource.user, confirmed: true);
  }
  return null;
}

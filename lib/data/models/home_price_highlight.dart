/// Home-screen "this list is cheaper at X than Y" highlight (Feature 8):
/// surfaces Feature 1's price-comparison work proactively instead of only
/// being reachable by opening a list and tapping its summary bar.
class HomePriceHighlight {
  final String listId;
  final String listName;
  final String cheaperRetailerName;
  final String pricierRetailerName;
  final double cheaperTotal;
  final double savings;
  final int matchedItemCount;
  final int totalItemCount;

  /// The exact (list, items, zip) signature this highlight was computed
  /// from — reused as both the cache key and the dismiss key, so dismissing
  /// this specific claim doesn't also suppress a genuinely new one later.
  final String signature;

  const HomePriceHighlight({
    required this.listId,
    required this.listName,
    required this.cheaperRetailerName,
    required this.pricierRetailerName,
    required this.cheaperTotal,
    required this.savings,
    required this.matchedItemCount,
    required this.totalItemCount,
    required this.signature,
  });

  Map<String, dynamic> toJson() => {
        'listId': listId,
        'listName': listName,
        'cheaperRetailerName': cheaperRetailerName,
        'pricierRetailerName': pricierRetailerName,
        'cheaperTotal': cheaperTotal,
        'savings': savings,
        'matchedItemCount': matchedItemCount,
        'totalItemCount': totalItemCount,
        'signature': signature,
      };

  static HomePriceHighlight? fromJson(Map<String, dynamic> json) {
    try {
      return HomePriceHighlight(
        listId: json['listId'] as String,
        listName: json['listName'] as String,
        cheaperRetailerName: json['cheaperRetailerName'] as String,
        pricierRetailerName: json['pricierRetailerName'] as String,
        cheaperTotal: (json['cheaperTotal'] as num).toDouble(),
        savings: (json['savings'] as num).toDouble(),
        matchedItemCount: json['matchedItemCount'] as int,
        totalItemCount: json['totalItemCount'] as int,
        signature: json['signature'] as String,
      );
    } catch (_) {
      return null;
    }
  }
}

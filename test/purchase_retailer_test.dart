// "Where do I usually buy this?" — the tally that answers it.
//
// The home-screen offer flyer leans on this: it only makes sense to say
// "Bananen sind bei REWE im Angebot" if REWE is actually where the user buys
// bananas. A wrong preferred retailer would put the wrong store in front of
// them, so the merge rule is pinned down here.
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/services/purchase_tracking_service.dart';

void main() {
  test('first purchase with a retailer sets the preference', () {
    final r = PurchaseTrackingService.mergeRetailer(const {}, 'REWE');
    expect(r.counts, {'REWE': 1});
    expect(r.preferred, 'REWE');
  });

  test('purchases without a retailer leave the tally untouched', () {
    final r = PurchaseTrackingService.mergeRetailer({'REWE': 3}, null);
    expect(r.counts, {'REWE': 3});
    expect(r.preferred, 'REWE');
  });

  test('blank retailer names are ignored', () {
    final r = PurchaseTrackingService.mergeRetailer({'REWE': 2}, '   ');
    expect(r.counts, {'REWE': 2});
  });

  test('the most frequent retailer wins, not the most recent', () {
    var counts = {'REWE': 5, 'Lidl': 1};
    final r = PurchaseTrackingService.mergeRetailer(counts, 'Lidl');
    expect(r.counts, {'REWE': 5, 'Lidl': 2});
    expect(r.preferred, 'REWE');
  });

  test('the preference shifts once another store overtakes', () {
    final r = PurchaseTrackingService.mergeRetailer({'REWE': 2, 'Lidl': 2}, 'Lidl');
    expect(r.preferred, 'Lidl');
  });

  test('ties resolve alphabetically so the answer is stable', () {
    // Without a deterministic tie-break the shown store would flip between
    // runs depending on map order.
    final a = PurchaseTrackingService.mergeRetailer({'Lidl': 1}, 'Aldi');
    final b = PurchaseTrackingService.mergeRetailer({'Aldi': 1}, 'Lidl');
    expect(a.preferred, 'Aldi');
    expect(b.preferred, a.preferred);
  });

  test('no data at all yields no preference', () {
    final r = PurchaseTrackingService.mergeRetailer(const {}, null);
    expect(r.counts, isEmpty);
    expect(r.preferred, isNull);
  });

  test('the original tally is not mutated', () {
    final original = {'REWE': 1};
    PurchaseTrackingService.mergeRetailer(original, 'Lidl');
    expect(original, {'REWE': 1});
  });
}

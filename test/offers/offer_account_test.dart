// Offer choices belong to one account (angebote.md 3.4, "der Zustand liegt im
// Konto"): what user A hides, declines or switches off on this device is not
// there for user B after a sign-out, and comes back when A signs in again.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/presentation/providers/list_offer_prefs_provider.dart';
import 'package:shoply/presentation/providers/offer_display_prefs_provider.dart';
import 'package:shoply/presentation/providers/offer_lookup_provider.dart';

final _account = StateProvider<String?>((ref) => 'user-a');

StoreOffer _offer() => StoreOffer(
  id: 7,
  productName: 'Milch',
  brandName: null,
  description: '',
  price: 0.99,
  oldPrice: null,
  unitShortName: null,
  retailerName: 'Lidl',
  retailerUniqueName: 'lidl',
  categoryName: null,
  validFrom: null,
  validTo: null,
);

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        offerAccountIdProvider.overrideWith((ref) => ref.watch(_account)),
        offerClockProvider.overrideWithValue(() => DateTime(2026, 11, 10)),
      ],
    );
    addTearDown(c.dispose);
    // Keep the account-scoped providers alive like the screens do.
    c.listen(hiddenOfferListsProvider, (_, __) {});
    c.listen(offerDisplayPrefsProvider, (_, __) {});
    return c;
  }

  test('A hides, declines and switches off; B sees none of it', () async {
    final c = container();
    await _settle();

    await c.read(hiddenOfferListsProvider.notifier).setHidden('list-1', true);
    final prefs = c.read(offerDisplayPrefsProvider.notifier);
    await prefs.decline('item-1', 7, DateTime(2026, 11, 14));
    await prefs.setSurface(OfferSurface.listSavings, false);
    await prefs.setSummaryHiddenThisWeek('list-1', true);
    await prefs.dontAskStore('list-1', 'lidl');
    c.read(offerCacheProvider).remember(_offer());

    expect(c.read(offersHiddenForListProvider('list-1')), isTrue);
    expect(
      c.read(offerDisplayPrefsProvider)!.isOn(OfferSurface.listSavings),
      isFalse,
    );

    // Sign-out, then user B on the same device.
    c.read(_account.notifier).state = null;
    await _settle();
    expect(c.read(offersHiddenForListProvider('list-1')), isFalse);
    expect(
      c.read(offerCacheProvider).byId(7),
      isNull,
      reason: 'the session offers go with the account',
    );
    c.read(_account.notifier).state = 'user-b';
    await _settle();
    await _settle();
    final b = c.read(offerDisplayPrefsProvider)!;
    expect(c.read(offersHiddenForListProvider('list-1')), isFalse);
    expect(b.isOn(OfferSurface.listSavings), isTrue);
    expect(b.isDeclined('item-1', 7, DateTime(2026, 11, 10)), isFalse);
    expect(b.summaryHiddenWeek, isEmpty);
    expect(b.dontAskStore, isEmpty);

    // A again: everything is back.
    c.read(_account.notifier).state = 'user-a';
    await _settle();
    await _settle();
    final a = c.read(offerDisplayPrefsProvider)!;
    expect(c.read(offersHiddenForListProvider('list-1')), isTrue);
    expect(a.isOn(OfferSurface.listSavings), isFalse);
    expect(a.isDeclined('item-1', 7, DateTime(2026, 11, 10)), isTrue);
    expect(a.dontAskStore, {'list-1': 'lidl'});
  });

  test('stored per account; signed out nothing is stored', () async {
    final c = container();
    await _settle();
    await c.read(hiddenOfferListsProvider.notifier).setHidden('list-1', true);
    await c
        .read(offerDisplayPrefsProvider.notifier)
        .setSurface(OfferSurface.itemOffers, false);
    final store = await SharedPreferences.getInstance();
    expect(store.getStringList(hiddenOfferListsKeyFor('user-a')), ['list-1']);
    expect(
      store.getString(offerDisplayPrefsKeyFor('user-a')),
      contains('itemOffers'),
    );

    c.read(_account.notifier).state = null;
    await _settle();
    await c.read(hiddenOfferListsProvider.notifier).setHidden('list-2', true);
    expect(
      c.read(offersHiddenForListProvider('list-2')),
      isTrue,
      reason: 'kept for the session',
    );
    expect(
      store.getKeys().where((k) => k.contains('list-2') || k.endsWith(':')),
      isEmpty,
    );
    expect(store.getStringList(hiddenOfferListsPrefsKey), isNull);
  });

  test('the device-wide hidden lists go to the first account once', () async {
    SharedPreferences.setMockInitialValues({
      hiddenOfferListsPrefsKey: ['old-list'],
    });
    final c = container();
    await _settle();
    await _settle();
    expect(c.read(offersHiddenForListProvider('old-list')), isTrue);
    final store = await SharedPreferences.getInstance();
    expect(store.getStringList(hiddenOfferListsKeyFor('user-a')), ['old-list']);
    expect(store.getStringList(hiddenOfferListsPrefsKey), isNull);

    c.read(_account.notifier).state = 'user-b';
    await _settle();
    await _settle();
    expect(
      c.read(offersHiddenForListProvider('old-list')),
      isFalse,
      reason: 'moved once, not shared',
    );
  });

  test(
    'a device-wide display choice from a development build is dropped',
    () async {
      SharedPreferences.setMockInitialValues({
        offerDisplayPrefsKey: '{"off":["itemOffers"]}',
      });
      final c = container();
      await _settle();
      await _settle();
      expect(
        c.read(offerDisplayPrefsProvider)!.isOn(OfferSurface.itemOffers),
        isTrue,
      );
      final store = await SharedPreferences.getInstance();
      expect(store.getString(offerDisplayPrefsKey), isNull);
    },
  );
}

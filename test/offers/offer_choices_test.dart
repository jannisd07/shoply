// The choices and data behind S9-S14 (angebote.md): favourite markets in
// their order (also from the onboarding before an account exists), "Markt
// automatisch erkennen", "Nicht interessiert", the "Postleitzahl festlegen"
// snooze, "Oft gekauft" and the lists of "Angebote der Woche".
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/data/models/item_purchase_stats.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/data/services/offer_price_service.dart';
import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/providers/list_offer_prefs_provider.dart';
import 'package:shoply/presentation/providers/offer_display_prefs_provider.dart';
import 'package:shoply/presentation/providers/price_comparison_provider.dart';
import 'package:shoply/presentation/providers/region_provider.dart';
import 'package:shoply/presentation/providers/weekly_offers_provider.dart';

import '../screens/offers/offer_test_harness.dart';

final _now = DateTime(2026, 11, 10, 12);
final _account = StateProvider<String?>((ref) => 'user-a');

Future<void> _settle() => Future<void>.delayed(Duration.zero);

ItemPurchaseStats _stats(
  String name, {
  int count = 4,
  double? every = 7,
  int daysAgo = 7,
  String? retailer = 'Lidl',
}) => ItemPurchaseStats(
  id: name,
  userId: 'user-a',
  itemName: name,
  purchaseCount: count,
  firstPurchase: _now.subtract(const Duration(days: 60)),
  lastPurchase: DateTime.now().subtract(Duration(days: daysAgo)),
  purchaseDates: const [],
  averageDaysBetween: every,
  preferredRetailer: retailer,
  createdAt: _now,
  updatedAt: _now,
);

/// Answers every search with [offers] of the asked market; counts them.
class _Source extends Fake implements OfferPriceService {
  _Source(this.offers);

  final Map<String, StoreOffer> offers;
  final asked = <(String, String?)>[];

  @override
  Future<List<StoreOffer>?> trySearchOffers(
    String query, {
    required String zipCode,
    String? chainId,
    int limit = 30,
  }) async {
    asked.add((query, chainId));
    final offer = offers[query.toLowerCase()];
    if (offer == null || (chainId != null && !offer.isFromChain(chainId))) {
      return const [];
    }
    return [offer];
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  ProviderContainer prefs({String? account = 'user-a'}) {
    final c = ProviderContainer(
      overrides: [
        offerAccountIdProvider.overrideWith(
          (ref) => account == null ? null : ref.watch(_account),
        ),
        offerClockProvider.overrideWithValue(() => _now),
      ],
    );
    addTearDown(c.dispose);
    c.listen(offerDisplayPrefsProvider, (_, __) {});
    return c;
  }

  group('favourite markets', () {
    test('add at the end, move, remove; saved for the account', () async {
      final c = prefs();
      await _settle();
      final n = c.read(offerDisplayPrefsProvider.notifier);
      await n.toggleFavorite('lidl');
      await n.toggleFavorite('rewe');
      await n.toggleFavorite('edeka');
      expect(c.read(favoriteStoresProvider), ['lidl', 'rewe', 'edeka']);
      await n.moveFavorite('edeka', -2);
      expect(c.read(favoriteStoresProvider), ['edeka', 'lidl', 'rewe']);
      await n.moveFavorite('rewe', 5);
      expect(c.read(favoriteStoresProvider), ['edeka', 'lidl', 'rewe']);
      await n.toggleFavorite('lidl');
      expect(c.read(favoriteStoresProvider), ['edeka', 'rewe']);
      final saved = (await SharedPreferences.getInstance()).getString(
        offerDisplayPrefsKeyFor('user-a'),
      );
      expect(jsonDecode(saved!)['favorites'], ['edeka', 'rewe']);
    });

    test(
      'picked in the onboarding: the first account takes them over',
      () async {
        final out = prefs(account: null);
        await _settle();
        await out.read(offerDisplayPrefsProvider.notifier).setFavorites([
          'lidl',
          'rewe',
          'lidl',
        ]);
        final device = await SharedPreferences.getInstance();
        expect(device.getStringList(pendingFavoriteStoresKey), [
          'lidl',
          'rewe',
        ]);
        expect(
          device.getString(offerDisplayPrefsKeyFor('user-a')),
          isNull,
          reason: 'nothing else is stored signed out',
        );

        final c = prefs();
        await _settle();
        await _settle();
        expect(c.read(favoriteStoresProvider), ['lidl', 'rewe']);
        expect(device.getStringList(pendingFavoriteStoresKey), isNull);
      },
    );

    test('an account with its own favourites keeps them', () async {
      SharedPreferences.setMockInitialValues({
        pendingFavoriteStoresKey: ['penny'],
        offerDisplayPrefsKeyFor('user-a'): jsonEncode({
          'favorites': <String>[],
        }),
      });
      final c = prefs();
      await _settle();
      await _settle();
      expect(c.read(favoriteStoresProvider), isEmpty, reason: 'chose none');
      final device = await SharedPreferences.getInstance();
      expect(device.getStringList(pendingFavoriteStoresKey), isNull);
    });
  });

  test('"Markt automatisch erkennen" is on until switched off', () async {
    final c = prefs();
    expect(c.read(storeDetectionOnProvider), isTrue);
    await _settle();
    await c.read(offerDisplayPrefsProvider.notifier).setDetectStore(false);
    expect(c.read(storeDetectionOnProvider), isFalse);
  });

  test('"Nicht interessiert": until the offer ends, at most 7 days', () async {
    final c = prefs();
    await _settle();
    final n = c.read(offerDisplayPrefsProvider.notifier);
    final soon = await n.notInterested(1, _now.add(const Duration(days: 2)));
    expect(soon, _now.add(const Duration(days: 2)));
    final later = await n.notInterested(2, _now.add(const Duration(days: 30)));
    expect(later, _now.add(const Duration(days: 7)));
    final p = c.read(offerDisplayPrefsProvider)!;
    expect(p.isNotInterested(1, _now), isTrue);
    expect(p.isNotInterested(1, _now.add(const Duration(days: 3))), isFalse);
    await n.undoNotInterested(2);
    expect(
      c.read(offerDisplayPrefsProvider)!.isNotInterested(2, _now),
      isFalse,
    );
  });

  test('"Postleitzahl festlegen" closed: 7 days quiet', () async {
    final c = prefs();
    await _settle();
    expect(
      c.read(offerDisplayPrefsProvider)!.postcodeHintAllowed(_now),
      isTrue,
    );
    await c.read(offerDisplayPrefsProvider.notifier).snoozePostcodeHint();
    final p = c.read(offerDisplayPrefsProvider)!;
    expect(p.postcodeHintAllowed(_now.add(const Duration(days: 6))), isFalse);
    expect(p.postcodeHintAllowed(_now.add(const Duration(days: 7))), isTrue);
  });

  group('"Oft gekauft"', () {
    ProviderContainer regulars(
      _Source source, {
      List<ItemPurchaseStats> stats = const [],
      Set<String> open = const {},
      bool remote = true,
      Region? region = testRegion,
      List<String> favorites = const [],
      void Function()? onStats,
    }) {
      SharedPreferences.setMockInitialValues({
        offerDisplayPrefsKeyFor('user-a'): jsonEncode({'favorites': favorites}),
      });
      final c = ProviderContainer(
        overrides: [
          offersRemoteEnabledProvider.overrideWithValue(remote),
          offersAvailableProvider.overrideWithValue(remote),
          offerAccountIdProvider.overrideWithValue('user-a'),
          regionProvider.overrideWithValue(region),
          offerPriceServiceProvider.overrideWithValue(source),
          offerPurchaseStatsProvider.overrideWith((ref) async {
            onStats?.call();
            return stats;
          }),
          offerOpenItemNamesProvider.overrideWith((ref) async => open),
        ],
      );
      addTearDown(c.dispose);
      c.listen(offerDisplayPrefsProvider, (_, __) {});
      return c;
    }

    test(
      'at the usual market, else the first favourite; open items not',
      () async {
        final source = _Source({
          'milch': testOffer(id: 1),
          'kaffee': testOffer(id: 2, product: 'Kaffee', retailer: 'rewe'),
          'brot': testOffer(id: 3, product: 'Brot'),
        });
        final c = regulars(
          source,
          favorites: const ['rewe'],
          stats: [
            _stats('milch'),
            _stats('kaffee', retailer: null),
            _stats('brot'),
            _stats('einmal', count: 1),
          ],
          open: {'brot'},
        );
        await _settle();
        final result = await c.read(regularOffersProvider.future);
        expect(result.hasStats, isTrue);
        // Equally due: by name, never by price.
        expect([for (final r in result.offers) r.name], ['Kaffee', 'Milch']);
        expect(source.asked, [('kaffee', 'rewe'), ('milch', 'lidl')]);
        expect(result.offers.last.averageDays, 7);
      },
    );

    test(
      'nothing read or asked without region, or with the kill switch',
      () async {
        for (final (remote, region) in [(true, null), (false, testRegion)]) {
          var read = 0;
          final source = _Source({'milch': testOffer()});
          final c = regulars(
            source,
            stats: [_stats('milch')],
            remote: remote,
            region: region,
            onStats: () => read++,
          );
          await _settle();
          final result = await c.read(regularOffersProvider.future);
          expect(result.offers, isEmpty);
          expect(read, 0);
          expect(source.asked, isEmpty);
        }
      },
    );

    test('no regulars yet: "Nach ein paar Einkäufen …"', () async {
      final c = regulars(_Source({}), stats: [_stats('milch', count: 1)]);
      await _settle();
      expect((await c.read(regularOffersProvider.future)).hasStats, isFalse);
    });
  });

  group('"Deine Listen"', () {
    test(
      'the list\'s offers in its order; hidden lists and declined out',
      () async {
        final milk = testItem('a', 'Milch');
        final bread = testItem('b', 'Brot');
        final c = ProviderContainer(
          overrides: [
            ...offersOn(),
            offerDealListIdsProvider.overrideWith((ref) => [testListId]),
            offerDealItemsProvider.overrideWith(
              (ref, ids) async => [bread, milk],
            ),
            listOfferSyncProvider.overrideWith(
              (ref) => _FixedSync(
                testSnapshot({
                  'Milch': testOffer(id: 1),
                  'Brot': testOffer(id: 2),
                }),
              ),
            ),
          ],
        );
        addTearDown(c.dispose);
        c.listen(hiddenOfferListsProvider, (_, __) {});
        c.listen(offerDisplayPrefsProvider, (_, __) {});
        c.listen(weeklyListSectionsProvider, (_, __) {});
        await _settle();
        await _settle();
        final sections = await c.read(weeklyListSectionsProvider.future);
        expect(sections.single.listName, 'Wocheneinkauf');
        expect(
          [for (final e in sections.single.entries) e.item.name],
          ['Brot', 'Milch'],
        );

        await c
            .read(offerDisplayPrefsProvider.notifier)
            .decline('b', 2, DateTime(2099));
        final declined = await c.read(weeklyListSectionsProvider.future);
        expect(
          [for (final e in declined.single.entries) e.item.name],
          ['Milch'],
        );

        await c
            .read(hiddenOfferListsProvider.notifier)
            .setHidden(testListId, true);
        expect(await c.read(weeklyListSectionsProvider.future), isEmpty);
      },
    );
  });

  test('a snapshot takes an offer put on from S9 without a request', () async {
    final sync = ListOfferSync(_Source({}));
    final snapshot = testSnapshot({'Milch': testOffer(id: 1)});
    SharedPreferences.setMockInitialValues({
      'offers_list_snapshot_v1:$testListId': jsonEncode(snapshot.toJson()),
    });
    await sync.attach(
      listId: testListId,
      chainId: 'lidl',
      name: 'Haferflocken',
      offer: testOffer(id: 9, product: 'Haferflocken'),
    );
    final cached = await sync.cached(testListId);
    expect(cached!.offerFor('haferflocken')?.id, 9);
    expect(cached.offerFor('Milch')?.id, 1);
  });
}

class _FixedSync extends ListOfferSync {
  _FixedSync(this.snapshot) : super(_Source({}));

  final ListOfferSnapshot snapshot;

  @override
  Future<ListOfferSnapshot> sync({
    required String listId,
    required String chainId,
    required String zip,
    required List<String> itemNames,
    bool force = false,
  }) async => snapshot;
}

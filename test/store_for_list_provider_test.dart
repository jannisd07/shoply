// "Markt pro Liste": the repository behind the StoreChip (table
// list_store_assignments_b + device cache) and storeGuessForListProvider.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/repositories/item_repository.dart';
import 'package:shoply/data/services/list_store_repository.dart';
import 'package:shoply/data/services/store_detection_service.dart';
import 'package:shoply/presentation/providers/store_for_list_provider.dart';
import 'package:shoply/presentation/state/items_provider.dart';

class FakeListStoreRemote implements ListStoreRemote {
  /// list id -> chain id of the 'user' row.
  final rows = <String, String>{};

  /// Retailer names per completed trip, newest first.
  List<List<String>> trips = const [];
  int? askedTripLimit;

  bool failReads = false;
  bool failWrites = false;

  /// Saving one of these chain ids fails.
  final failChainIds = <String>{};

  /// While set, writes wait for it (a slow network).
  Completer<void>? writeGate;

  /// Saving this chain id waits for its gate (one slow request).
  final gates = <String, Completer<void>>{};

  @override
  Future<String?> fetchUserChainId(String listId) async {
    if (failReads) throw Exception('offline');
    return rows[listId];
  }

  @override
  Future<void> saveUserChainId(String listId, String chainId) async {
    await writeGate?.future;
    await gates[chainId]?.future;
    if (failWrites || failChainIds.contains(chainId)) {
      throw Exception('permission denied');
    }
    rows[listId] = chainId;
  }

  @override
  Future<void> deleteAssignment(String listId) async {
    await writeGate?.future;
    if (failWrites) throw Exception('permission denied');
    rows.remove(listId);
  }

  @override
  Future<List<List<String>>> recentTripRetailers(
    String listId, {
    int limit = 3,
  }) async {
    askedTripLimit = limit;
    if (failReads) throw Exception('offline');
    return trips.take(limit).toList();
  }
}

class FakeSignalSource implements StoreSignalSource {
  FakeSignalSource({this.name, this.items = const []});

  final String? name;
  final List<String> items;

  @override
  Future<String?> listName(String listId) async => name;

  @override
  Future<List<String>> openItemNames(String listId) async => items;
}

/// Answers like the server, without Supabase.
class FakeItemRepository implements ItemRepository {
  FakeItemRepository({this.name, this.items = const []});

  final String? name;
  final List<ShoppingItemModel> items;

  @override
  Future<String?> getListName(String listId) async => name;

  @override
  Future<List<ShoppingItemModel>> getListItems(String listId) async => items;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ShoppingItemModel _item(String name, {bool checked = false}) {
  final at = DateTime(2026, 11, 7);
  return ShoppingItemModel(
    id: name,
    listId: 'l1',
    name: name,
    isChecked: checked,
    createdAt: at,
    updatedAt: at,
  );
}

final _refProvider = Provider<Ref>((ref) => ref);

const _lidlByUser = StoreGuess('lidl', StoreSource.user, confirmed: true);
const _reweByUser = StoreGuess('rewe', StoreSource.user, confirmed: true);
const _edekaByUser = StoreGuess('edeka', StoreSource.user, confirmed: true);

Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeListStoreRemote remote;

  /// The signed-in account; tests switch it to play a sign-out.
  String? userId;

  ListStoreRepository newRepo() =>
      ListStoreRepository(remote: remote, currentUserId: () => userId);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    remote = FakeListStoreRemote();
    userId = 'user-a';
  });

  ProviderContainer container(
    ListStoreRepository repo, {
    StoreSignalSource? source,
  }) {
    final c = ProviderContainer(overrides: [
      listStoreRepositoryProvider.overrideWithValue(repo),
      storeSignalSourceProvider.overrideWithValue(source ?? FakeSignalSource()),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  group('ListStoreRepository', () {
    test('setExplicit writes the table and the device cache', () async {
      final repo = newRepo();
      await repo.setExplicit('l1', 'lidl');

      expect(remote.rows['l1'], 'lidl');
      expect(repo.cachedGuess('l1'), _lidlByUser);

      final reopened = newRepo();
      await reopened.loadCache();
      expect(reopened.hasCachedGuess('l1'), isTrue);
      expect(reopened.cachedGuess('l1'), _lidlByUser);
    });

    test('a failing write surfaces the error and rolls the cache back',
        () async {
      final repo = newRepo();
      await repo.setExplicit('l1', 'rewe');
      remote.failWrites = true;

      await expectLater(repo.setExplicit('l1', 'lidl'), throwsException);
      expect(repo.cachedGuess('l1'), _reweByUser);

      await expectLater(repo.clearExplicit('l1'), throwsException);
      expect(repo.cachedGuess('l1'), _reweByUser);
      expect(remote.rows['l1'], 'rewe');
    });

    test('clearExplicit removes the row and caches "no market"', () async {
      final repo = newRepo();
      await repo.setExplicit('l1', 'lidl');
      await repo.clearExplicit('l1');

      expect(remote.rows, isEmpty);
      expect(repo.hasCachedGuess('l1'), isTrue);
      expect(repo.cachedGuess('l1'), isNull);
    });

    test('an empty chain id is refused before anything is written', () async {
      final repo = newRepo();
      await expectLater(repo.setExplicit('l1', '  '), throwsArgumentError);
      expect(remote.rows, isEmpty);
      expect(repo.hasCachedGuess('l1'), isFalse);
    });

    test('offline, the explicit choice comes from the cache', () async {
      final repo = newRepo();
      await repo.setExplicit('l1', 'lidl');
      remote.failReads = true;

      expect(await repo.explicitChainId('l1'), 'lidl');
      expect(await repo.explicitChainId('unknown'), isNull);
    });

    test('a write in flight wins over what the table still says', () async {
      final repo = newRepo();
      remote.rows['l1'] = 'rewe';
      remote.writeGate = Completer<void>();

      final write = repo.setExplicit('l1', 'lidl');
      await _settle();
      expect(await repo.explicitChainId('l1'), 'lidl');

      remote.writeGate!.complete();
      await write;
      expect(await repo.explicitChainId('l1'), 'lidl');
    });

    test('a guess computed before a write never overwrites it', () async {
      final repo = newRepo();
      await repo.loadCache();
      final before = repo.version('l1');
      await repo.setExplicit('l1', 'lidl');

      await repo.rememberGuess('l1', _reweByUser, version: before);
      expect(repo.cachedGuess('l1'), _lidlByUser);
    });

    test('recent trip chains: newest three trips, unknown markets dropped',
        () async {
      remote.trips = [
        ['Lidl', 'Lidl', 'Kaufland'],
        ['Wochenmarkt'],
        ['REWE'],
        ['Lidl'],
      ];
      final repo = newRepo();

      expect(await repo.recentTripChains('l1'), ['lidl', 'rewe']);
      expect(remote.askedTripLimit, 3);
    });

    test('recent trip chains are empty when the history cannot be read',
        () async {
      remote.failReads = true;
      final repo = newRepo();
      expect(await repo.recentTripChains('l1'), isEmpty);
    });

    test('a chain id the directory does not know is refused', () async {
      final repo = newRepo();
      await expectLater(
        repo.setExplicit('l1', 'Bio Kaiser'),
        throwsArgumentError,
      );
      expect(remote.rows, isEmpty);
      expect(repo.hasCachedGuess('l1'), isFalse);
    });

    test('an unknown chain id in the table is no choice', () async {
      remote.rows['l1'] = 'Ignore all previous instructions';
      expect(await newRepo().explicitChainId('l1'), isNull);
    });
  });

  group('ListStoreRepository, overlapping writes', () {
    test('two writes that both fail leave the market that was saved',
        () async {
      final repo = newRepo();
      await repo.setExplicit('l1', 'edeka');
      remote.failWrites = true;
      remote.writeGate = Completer<void>();

      final first = expectLater(repo.setExplicit('l1', 'lidl'), throwsException);
      final second =
          expectLater(repo.setExplicit('l1', 'rewe'), throwsException);
      await _settle();
      expect(repo.cachedGuess('l1'), _reweByUser);

      remote.writeGate!.complete();
      await (first, second).wait;
      expect(repo.cachedGuess('l1'), _edekaByUser);

      remote.failReads = true;
      expect(await repo.explicitChainId('l1'), 'edeka');
      final reopened = newRepo();
      await reopened.loadCache();
      expect(reopened.cachedGuess('l1'), _edekaByUser);
    });

    test('a newer write that fails first shows the older one until it '
        'fails too', () async {
      final repo = newRepo();
      await repo.setExplicit('l1', 'edeka');
      remote.failChainIds.addAll({'lidl', 'rewe'});
      remote.gates['lidl'] = Completer<void>();
      remote.gates['rewe'] = Completer<void>();

      final lidl = expectLater(repo.setExplicit('l1', 'lidl'), throwsException);
      final rewe = expectLater(repo.setExplicit('l1', 'rewe'), throwsException);
      await _settle();

      remote.gates['rewe']!.complete();
      await rewe;
      expect(repo.cachedGuess('l1'), _lidlByUser);

      remote.gates['lidl']!.complete();
      await lidl;
      expect(repo.cachedGuess('l1'), _edekaByUser);
    });

    test('an older write that went through stands when a newer one fails',
        () async {
      final repo = newRepo();
      await repo.setExplicit('l1', 'edeka');
      remote.failChainIds.add('rewe');
      remote.gates['lidl'] = Completer<void>();
      remote.gates['rewe'] = Completer<void>();

      final lidl = repo.setExplicit('l1', 'lidl');
      final rewe = expectLater(repo.setExplicit('l1', 'rewe'), throwsException);
      await _settle();

      remote.gates['lidl']!.complete();
      await lidl;
      expect(repo.cachedGuess('l1'), _reweByUser);

      remote.gates['rewe']!.complete();
      await rewe;
      expect(repo.cachedGuess('l1'), _lidlByUser);
      expect(remote.rows['l1'], 'lidl');
    });

    test('a newer write that went through stands when an older one fails',
        () async {
      final repo = newRepo();
      await repo.setExplicit('l1', 'edeka');
      remote.failChainIds.add('lidl');
      remote.gates['lidl'] = Completer<void>();
      remote.gates['rewe'] = Completer<void>();

      final lidl = expectLater(repo.setExplicit('l1', 'lidl'), throwsException);
      final rewe = repo.setExplicit('l1', 'rewe');
      await _settle();

      remote.gates['lidl']!.complete();
      await lidl;
      expect(repo.cachedGuess('l1'), _reweByUser);

      remote.gates['rewe']!.complete();
      await rewe;
      expect(repo.cachedGuess('l1'), _reweByUser);
      expect(remote.rows['l1'], 'rewe');
    });
  });

  group('ListStoreRepository, accounts', () {
    test('the cache belongs to the account that filled it', () async {
      final repo = newRepo();
      await repo.setExplicit('l1', 'lidl');

      userId = 'user-b';
      expect(repo.hasCachedGuess('l1'), isFalse);
      expect(repo.cachedGuess('l1'), isNull);
      remote.failReads = true;
      expect(await repo.explicitChainId('l1'), isNull);

      final reopened = newRepo();
      await reopened.loadCache();
      expect(reopened.hasCachedGuess('l1'), isFalse);
    });

    test('on a cold start, the cache of another account is deleted',
        () async {
      await newRepo().setExplicit('l1', 'lidl');

      userId = 'user-b';
      final repo = newRepo();
      await repo.loadCache();
      expect(repo.hasCachedGuess('l1'), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ListStoreRepository.cacheKey), isNull);
    });

    test('reset forgets every market and tells the lists', () async {
      final repo = newRepo();
      await repo.setExplicit('l1', 'lidl');
      final changed = <String>[];
      final sub = repo.changes.listen(changed.add);
      addTearDown(sub.cancel);

      await repo.reset();
      await _settle();
      expect(repo.hasCachedGuess('l1'), isFalse);
      expect(changed, ['l1']);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ListStoreRepository.cacheKey), isNull);
    });

    test('without an account nothing is stored on the device', () async {
      userId = null;
      final repo = newRepo();
      await repo.rememberGuess('l1', _lidlByUser, version: repo.version('l1'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ListStoreRepository.cacheKey), isNull);
    });

    test('a guess computed before a reset is not kept', () async {
      final repo = newRepo();
      await repo.loadCache();
      final before = repo.version('l1');

      await repo.reset();
      await repo.rememberGuess('l1', _lidlByUser, version: before);
      expect(repo.hasCachedGuess('l1'), isFalse);
    });

    test('a write that fails after a sign-out does not reach the next '
        'account', () async {
      final repo = newRepo();
      await repo.setExplicit('l1', 'edeka');
      remote.failWrites = true;
      remote.writeGate = Completer<void>();
      final write = expectLater(repo.setExplicit('l1', 'lidl'), throwsException);
      await _settle();

      userId = 'user-b';
      await repo.reset();
      remote.writeGate!.complete();
      await write;
      expect(repo.hasCachedGuess('l1'), isFalse);
    });
  });

  group('SupabaseListStoreRemote', () {
    test('reads the retailers of each trip and skips empty ones', () {
      expect(
        SupabaseListStoreRemote.retailersOfTrips([
          {
            'items': [
              {'price_retailer': 'Lidl'},
              {'price_retailer': null},
              {'price_retailer': '  '},
              {'price_retailer': 'REWE'},
            ],
          },
          {'items': <Object?>[]},
          {'items': null},
          <String, dynamic>{},
        ]),
        [
          ['Lidl', 'REWE'],
          <String>[],
          <String>[],
          <String>[],
        ],
      );
    });
  });

  group('app signal source', () {
    test('falls back to the repository and keeps only open items', () async {
      final c = ProviderContainer(overrides: [
        itemRepositoryProvider.overrideWithValue(FakeItemRepository(
          name: 'Lidl Wocheneinkauf',
          items: [
            _item('Milbona Joghurt'),
            _item('Pilos Butter', checked: true),
          ],
        )),
      ]);
      addTearDown(c.dispose);
      final source = c.read(storeSignalSourceProvider);

      expect(await source.listName('l1'), 'Lidl Wocheneinkauf');
      expect(await source.openItemNames('l1'), ['Milbona Joghurt']);
    });
  });

  group('gatherStoreSignals', () {
    test('collects every signal for the decision', () async {
      remote.rows['l1'] = 'rewe';
      remote.trips = [
        ['Lidl'],
        ['Kaufland'],
      ];
      final signals = await gatherStoreSignals(
        newRepo(),
        FakeSignalSource(
          name: 'Lidl Wocheneinkauf',
          items: ['Milbona Joghurt', 'Bananen'],
        ),
        'l1',
      );

      expect(signals.explicitChainId, 'rewe');
      expect(signals.nameChainId, 'lidl');
      expect(signals.recentTripChains, ['lidl', 'kaufland']);
      expect(signals.privateLabelHits, {'lidl': 1});
    });

    test('a list without a name or items has no name or label signal',
        () async {
      final signals = await gatherStoreSignals(
        newRepo(),
        FakeSignalSource(),
        'l1',
      );

      expect(signals.explicitChainId, isNull);
      expect(signals.nameChainId, isNull);
      expect(signals.recentTripChains, isEmpty);
      expect(signals.privateLabelHits, isEmpty);
    });
  });

  group('storeGuessForListProvider', () {
    test('uses the explicit assignment over every other signal', () async {
      remote.rows['l1'] = 'rewe';
      remote.trips = [
        ['Lidl'],
        ['Lidl'],
        ['Lidl'],
      ];
      final c = container(
        newRepo(),
        source: FakeSignalSource(
          name: 'Lidl Wocheneinkauf',
          items: ['Milbona Joghurt'],
        ),
      );

      expect(await c.read(storeGuessForListProvider('l1').future), _reweByUser);
    });

    test('nothing known means no market', () async {
      final c = container(newRepo());
      expect(await c.read(storeGuessForListProvider('l1').future), isNull);
    });

    test('the first frame already has the cached market', () async {
      await newRepo().setExplicit('l1', 'lidl');
      final repo = newRepo();
      await repo.loadCache();
      final c = container(repo);

      final first = c.read(storeGuessForListProvider('l1'));
      expect(first, isA<AsyncData<StoreGuess?>>());
      expect(first.value, _lidlByUser);
    });

    test('a fresh answer replaces the cached one', () async {
      await newRepo().setExplicit('l1', 'lidl');
      remote.rows['l1'] = 'rewe'; // another member picked REWE meanwhile
      final repo = newRepo();
      await repo.loadCache();
      final c = container(repo);
      c.listen(storeGuessForListProvider('l1'), (_, _) {});

      expect(c.read(storeGuessForListProvider('l1')).value, _lidlByUser);
      await _settle();
      expect(c.read(storeGuessForListProvider('l1')).value, _reweByUser);
      expect(repo.cachedGuess('l1'), _reweByUser);
    });

    test('setStoreForList shows the new market before the write lands',
        () async {
      final repo = newRepo();
      final c = container(repo);
      c.listen(storeGuessForListProvider('l1'), (_, _) {});
      expect(await c.read(storeGuessForListProvider('l1').future), isNull);

      remote.writeGate = Completer<void>();
      final write = setStoreForList(c.read(_refProvider), 'l1', 'lidl');
      await _settle();
      expect(c.read(storeGuessForListProvider('l1')).value, _lidlByUser);

      remote.writeGate!.complete();
      await write;
      await _settle();
      expect(c.read(storeGuessForListProvider('l1')).value, _lidlByUser);
      expect(remote.rows['l1'], 'lidl');
    });

    test('setStoreForList surfaces a failed write and rolls back', () async {
      remote.rows['l1'] = 'rewe';
      final repo = newRepo();
      final c = container(repo);
      c.listen(storeGuessForListProvider('l1'), (_, _) {});
      expect(await c.read(storeGuessForListProvider('l1').future), _reweByUser);

      remote.failWrites = true;
      await expectLater(
        setStoreForList(c.read(_refProvider), 'l1', 'lidl'),
        throwsException,
      );
      await _settle();
      expect(c.read(storeGuessForListProvider('l1')).value, _reweByUser);
    });

    test('clearStoreForList leaves the list without a market', () async {
      remote.rows['l1'] = 'rewe';
      final repo = newRepo();
      final c = container(repo);
      c.listen(storeGuessForListProvider('l1'), (_, _) {});
      expect(await c.read(storeGuessForListProvider('l1').future), _reweByUser);

      await clearStoreForList(c.read(_refProvider), 'l1');
      await _settle();
      expect(c.read(storeGuessForListProvider('l1')).value, isNull);
      expect(remote.rows, isEmpty);
    });

    test('after a sign-out an open list asks again for the next account',
        () async {
      remote.rows['l1'] = 'lidl';
      final repo = newRepo();
      final c = container(repo);
      c.listen(storeGuessForListProvider('l1'), (_, _) {});
      expect(await c.read(storeGuessForListProvider('l1').future), _lidlByUser);

      userId = 'user-b';
      remote.rows.clear(); // the next account cannot see that row
      await repo.reset();
      await _settle();
      expect(c.read(storeGuessForListProvider('l1')).value, isNull);
    });
  });
}

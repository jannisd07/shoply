import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/services/offline_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final list = ShoppingListModel(
    id: 'l1',
    name: 'Wocheneinkauf',
    ownerId: 'u1',
    createdAt: DateTime(2026, 11, 8),
    updatedAt: DateTime(2026, 11, 8),
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('cached lists belong to the account that saved them', () async {
    final cache = OfflineCacheService.instance;
    await cache.cacheLists([list], userId: 'u1');

    final own = await cache.getCachedLists(userId: 'u1');
    expect(own?.single.name, 'Wocheneinkauf');
    expect(await cache.getCachedLists(userId: 'u2'), isNull);
    // Callers without an account (offline fallback) still get them.
    expect(await cache.getCachedLists(), isNotNull);
  });

  test('lists cached without an account are not shown to one', () async {
    final cache = OfflineCacheService.instance;
    await cache.cacheLists([list]);
    expect(await cache.getCachedLists(userId: 'u1'), isNull);
  });

  test('sync read for the first frame, only for the own account', () async {
    final cache = OfflineCacheService.instance;
    cache.attachPreferences(await SharedPreferences.getInstance());
    await cache.cacheLists([list], userId: 'u1');
    expect(cache.getCachedListsSync(userId: 'u1')?.single.id, 'l1');
    expect(cache.getCachedListsSync(userId: 'u2'), isNull);

    await cache.cacheUserProfile(userId: 'u1', displayName: 'Jannis');
    expect(cache.getCachedUserProfileSync('u1')?.displayName, 'Jannis');
    expect(cache.getCachedUserProfileSync('u2'), isNull);
  });
}

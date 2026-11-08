// The AI part of the recommendations. Free users have 5 `recommend` calls a
// day, so Claude is asked at most once per list every few minutes, a real
// "nothing to add" is remembered, and a failure is not. What the user reads
// (reasons, starter items) follows the app language, and nothing from one
// account outlives its sign-out.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/data/models/item_purchase_stats.dart';
import 'package:shoply/data/models/recommendation_item.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/services/ai_categorization_service.dart';
import 'package:shoply/data/services/claude_service.dart';
import 'package:shoply/data/services/ml_recommendation_service.dart';
import 'package:shoply/data/services/purchase_tracking_service.dart';
import 'package:shoply/data/services/shopping_history_service.dart';
import 'package:shoply/data/services/smart_categorization_service.dart';

ItemPurchaseStats _stat(String name, {int count = 4, int daysAgo = 7, double every = 7}) {
  final now = DateTime.now();
  return ItemPurchaseStats(
    id: name,
    userId: 'u1',
    itemName: name,
    purchaseCount: count,
    firstPurchase: now.subtract(const Duration(days: 30)),
    lastPurchase: now.subtract(Duration(days: daysAgo)),
    purchaseDates: [now.subtract(Duration(days: daysAgo))],
    averageDaysBetween: every,
    createdAt: now,
    updatedAt: now,
  );
}

class _Stats implements PurchaseTrackingService {
  _Stats({this.empty = false, this.extra = const []});

  final bool empty;
  final List<ItemPurchaseStats> extra;

  @override
  Future<List<ItemPurchaseStats>> getAllStats() async =>
      empty ? [] : [_stat('Kaffee'), ...extra];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoHistory implements ShoppingHistoryService {
  @override
  Future<List<ShoppingHistory>> getRecentHistory({int limit = 5}) async => [];

  @override
  Future<List<ShoppingHistory>> getHistoryForList(String listId) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ShoppingItemModel _item(String name) => ShoppingItemModel(
      id: name,
      listId: 'l1',
      name: name,
      createdAt: DateTime(2026, 11, 7),
      updatedAt: DateTime(2026, 11, 7),
    );

http.Response _suggest(List<String> names) => http.Response(
      jsonEncode({
        'result': {
          'items': [
            for (final name in names) {'name': name}
          ]
        },
      }),
      200,
    );

/// A recommendation service over [client]; [locale] is read on every call.
MLRecommendationService _service(
  http.Client client, {
  String Function()? locale,
  Stream<void>? signedOut,
  bool noStats = false,
  List<ItemPurchaseStats> stats = const [],
}) =>
    MLRecommendationService(
      trackingService: _Stats(empty: noStats, extra: stats),
      historyService: _NoHistory(),
      geminiService: AiCategorizationService.forTesting(
        claude: ClaudeService(
          httpClientFactory: () => client,
          accessToken: () async => 'jwt',
          locale: locale ?? () => 'de',
          endpoint: Uri.parse('https://project.test/functions/v1/ai'),
          anonKey: 'anon',
        ),
        local: SmartCategorizationService.forTesting(currentUserId: () => 'u1'),
        signedOut: signedOut,
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a failed Claude call is asked again on the next run', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      if (calls == 1) {
        return http.Response(jsonEncode({'code': 'provider_error'}), 502);
      }
      return _suggest(['Parmesan']);
    });
    final service = _service(client);
    final items = [_item('Spaghetti Retry'), _item('Tomaten Retry')];

    await service.getRecommendations(currentListItems: items);
    await service.getRecommendations(currentListItems: items);
    await service.getRecommendations(currentListItems: items);

    expect(calls, 2, reason: 'one failure, one success, then the cache');
  });

  test('one list asks Claude at most once in ten minutes', () async {
    var calls = 0;
    final service = _service(MockClient((request) async {
      calls++;
      return _suggest(['Parmesan']);
    }));

    // Every added item changes the set of names.
    await service.getRecommendations(
        currentListItems: [_item('Pasta')], listId: 'l1');
    await service.getRecommendations(
        currentListItems: [_item('Pasta'), _item('Brot')], listId: 'l1');
    await service.getRecommendations(
        currentListItems: [_item('Pasta'), _item('Brot'), _item('Wein')],
        listId: 'l1');
    expect(calls, 1);

    await service.getRecommendations(
        currentListItems: [_item('Pasta')], listId: 'l2');
    expect(calls, 2, reason: 'another list asks for itself');
  });

  test('the suggestions are reused while the list is throttled', () async {
    // Parmesan is bought often, so it is shown; Claude's suggestion adds
    // its reason on top.
    final service = _service(
      MockClient((request) async => _suggest(['Parmesan'])),
      stats: [_stat('Parmesan', count: 20, daysAgo: 1, every: 1)],
    );
    String? reasonFor(List<RecommendationItem> result) =>
        result.where((r) => r.itemName == 'Parmesan').firstOrNull?.reason;

    final first = await service.getRecommendations(
        currentListItems: [_item('Pasta')], listId: 'l1');
    final second = await service.getRecommendations(
        currentListItems: [_item('Pasta'), _item('Brot')], listId: 'l1');

    expect(reasonFor(first), contains('Ergänzt deine Liste'));
    expect(reasonFor(second), contains('Ergänzt deine Liste'));
  });

  test('a real empty answer is remembered', () async {
    var calls = 0;
    final service = _service(MockClient((request) async {
      calls++;
      return _suggest([]);
    }));
    final items = [_item('Zorbelwix')];

    await service.getRecommendations(currentListItems: items);
    await service.getRecommendations(currentListItems: items);

    expect(calls, 1);
  });

  test('another app language asks again', () async {
    var calls = 0;
    var locale = 'de';
    final service = _service(
      MockClient((request) async {
        calls++;
        return _suggest(['Parmesan']);
      }),
      locale: () => locale,
    );
    final items = [_item('Pasta')];

    await service.getRecommendations(currentListItems: items, listId: 'l1');
    locale = 'en';
    await service.getRecommendations(currentListItems: items, listId: 'l1');

    expect(calls, 2);
  });

  test('signing out forgets the suggestions', () async {
    final signedOut = StreamController<void>.broadcast();
    addTearDown(signedOut.close);
    var calls = 0;
    final service = _service(
      MockClient((request) async {
        calls++;
        return _suggest(['Parmesan']);
      }),
      signedOut: signedOut.stream,
    );
    final items = [_item('Pasta')];

    await service.getRecommendations(currentListItems: items, listId: 'l1');
    signedOut.add(null);
    await Future<void>.delayed(Duration.zero);
    await service.getRecommendations(currentListItems: items, listId: 'l1');

    expect(calls, 2);
  });

  group('the text follows the app language', () {
    test('German', () async {
      final service =
          _service(MockClient((_) async => _suggest([])), noStats: true);

      final starter = await service.getRecommendations(currentListItems: []);

      expect(starter.first.itemName, 'Milch');
      expect(starter.first.reason, 'Beliebtes Produkt');
    });

    test('English', () async {
      final service = _service(
        MockClient((_) async => _suggest([])),
        locale: () => 'en',
        noStats: true,
      );

      final starter = await service.getRecommendations(currentListItems: []);

      expect(starter.first.itemName, 'Milk');
      expect(starter.first.reason, 'Popular item');
      expect(starter.map((r) => r.itemName), isNot(contains('Milch')));
    });

    test('English reasons for scored items', () async {
      final service = _service(
        MockClient((_) async => _suggest(['Parmesan'])),
        locale: () => 'en',
      );

      final result = await service.getRecommendations(
        currentListItems: [_item('Pasta')],
        listId: 'l1',
      );

      expect(result, isNotEmpty);
      for (final recommendation in result) {
        expect(
          recommendation.reason,
          isNot(matches(RegExp(r'[äöüÄÖÜß]|\bOft\b|Empfohlen|Wieder|Passt'))),
        );
      }
    });

    test('a starter item already on the list is left out', () async {
      final service = _service(
        MockClient((_) async => _suggest([])),
        locale: () => 'en',
        noStats: true,
      );

      final starter = await service.getRecommendations(
        currentListItems: [_item('milk')],
      );

      expect(starter.map((r) => r.itemName), isNot(contains('Milk')));
    });
  });
}

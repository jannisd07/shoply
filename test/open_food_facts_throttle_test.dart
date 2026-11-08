// B4 / OFF compliance: Open Food Facts allows 10 searches and 15 product
// reads per minute and IP, and asks every client to name itself
// (`AppName/Version (ContactEmail)`). Both limits are sliding windows here,
// tested with a fake clock.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/data/services/open_food_facts_service.dart';
import 'package:shoply/data/services/open_prices_service.dart';

void main() {
  final t0 = DateTime(2026, 11, 8, 12);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SlidingWindowRateLimiter', () {
    test('lets 10 through in 60 s and blocks the 11th', () {
      var now = t0;
      final limiter = SlidingWindowRateLimiter(
        maxEvents: 10,
        window: const Duration(seconds: 60),
        clock: () => now,
      );
      for (var i = 0; i < 10; i++) {
        expect(limiter.tryAcquire(), isTrue, reason: 'request ${i + 1}');
        now = now.add(const Duration(seconds: 1));
      }
      expect(limiter.tryAcquire(), isFalse);
      expect(limiter.timeUntilFree(), const Duration(seconds: 50));

      now = t0.add(const Duration(seconds: 60));
      expect(limiter.tryAcquire(), isTrue, reason: 'the first one left');
      expect(limiter.tryAcquire(), isFalse, reason: 'the second is still in');
    });

    test('keepFree leaves slots for other callers', () {
      final limiter = SlidingWindowRateLimiter(
        maxEvents: 15,
        window: const Duration(seconds: 60),
        clock: () => t0,
      );
      for (var i = 0; i < 12; i++) {
        expect(limiter.tryAcquire(keepFree: 3), isTrue);
      }
      expect(limiter.tryAcquire(keepFree: 3), isFalse);
      expect(limiter.timeUntilFree(keepFree: 3), const Duration(seconds: 60));
      expect(limiter.tryAcquire(), isTrue);
      expect(
        limiter.timeUntilFree(keepFree: 3),
        const Duration(seconds: 60),
        reason: 'two have to leave before a background slot is free',
      );
    });

    test('timeUntilFree counts from the oldest events', () {
      var now = t0;
      final limiter = SlidingWindowRateLimiter(
        maxEvents: 15,
        window: const Duration(seconds: 60),
        clock: () => now,
      );
      for (var i = 0; i < 13; i++) {
        limiter.tryAcquire();
        now = now.add(const Duration(seconds: 1));
      }
      // Events at 0..12 s, now 13 s: background (12 slots) needs the
      // events at 0 and 1 s gone, so 61 s - 13 s.
      expect(limiter.timeUntilFree(keepFree: 3), const Duration(seconds: 48));
      expect(limiter.timeUntilFree(), Duration.zero);
    });
  });

  group('OpenFoodFactsService', () {
    late DateTime now;
    late List<http.Request> requests;
    late List<DateTime> sentAt;
    late OpenFoodFactsService service;
    // What OFF really answers for an unknown barcode (checked live).
    final notFoundBody = jsonEncode({
      'status': 0,
      'status_verbose': 'product not found',
    });
    var productStatus = 404;
    var productBody = notFoundBody;

    OpenFoodFactsService build({Future<void> Function(Duration)? delay}) =>
        OpenFoodFactsService.forTesting(
          client: MockClient((request) async {
            requests.add(request);
            sentAt.add(now);
            if (request.url.host == 'search.openfoodfacts.org') {
              return http.Response(jsonEncode({'hits': []}), 200);
            }
            return http.Response(productBody, productStatus);
          }),
          limits: OffRateLimits(clock: () => now),
          delay: delay ?? (d) async => now = now.add(d),
        );

    /// At most [max] requests in any 60 s.
    void expectWithinLimit(int max) {
      for (final at in sentAt) {
        final inWindow = sentAt.where(
          (t) =>
              !t.isAfter(at) && at.difference(t) < const Duration(minutes: 1),
        );
        expect(inWindow.length, lessThanOrEqualTo(max), reason: '$at');
      }
    }

    setUp(() {
      now = t0;
      requests = [];
      sentAt = [];
      productStatus = 404;
      productBody = notFoundBody;
      service = build();
    });

    test('the 11th search within 60 s never reaches the network', () async {
      for (var i = 0; i < 10; i++) {
        await service.search('milch $i');
        now = now.add(const Duration(seconds: 1));
      }
      expect(requests, hasLength(10));

      // It waits for a free slot (the person sees the search loading)
      // instead of answering "no products found".
      final waiting = service.search('milch 11');
      expect(requests, hasLength(10));
      await waiting;
      expect(requests, hasLength(11));
      expect(sentAt.last, t0.add(const Duration(seconds: 60)));
      expectWithinLimit(10);
    });

    test(
      'a search that only has to wait briefly goes out after the wait',
      () async {
        for (var i = 0; i < 10; i++) {
          await service.search('milch $i');
        }
        now = t0.add(const Duration(seconds: 58));
        await service.search('milch 11');
        expect(requests, hasLength(11));
        expect(now.isAfter(t0.add(const Duration(seconds: 59))), isTrue);
      },
    );

    test('a waiting search is dropped once a newer one starts', () async {
      for (var i = 0; i < 10; i++) {
        await service.search('milch $i');
      }
      now = t0.add(const Duration(seconds: 58));
      final older = service.search('hafer');
      final newer = service.search('haferflocken');
      expect(await older, isEmpty);
      await newer;
      expect(requests, hasLength(11));
      expect(requests.last.url.queryParameters['q'], 'haferflocken');
    });

    test(
      'the 16th product read within 60 s never reaches the network',
      () async {
        for (var i = 0; i < 15; i++) {
          await service.lookupBarcode(
            '40000000000${i.toString().padLeft(2, '0')}',
          );
          now = now.add(const Duration(seconds: 1));
        }
        expect(requests, hasLength(15));

        // It waits for the window instead of answering "barcode not found".
        productStatus = 200;
        productBody = jsonEncode({
          'status': 1,
          'product': {'product_name': 'Haferdrink'},
        });
        final product = await service.lookupBarcode('4000000000099');
        expect(product?.name, 'Haferdrink');
        expect(requests, hasLength(16));
        expect(sentAt.last, t0.add(const Duration(seconds: 60)));
        expectWithinLimit(15);
      },
    );

    test('photo lookups keep 3 product reads for the person', () async {
      for (var i = 0; i < 12; i++) {
        await service.productPhoto(
          '40000000000${i.toString().padLeft(2, '0')}',
        );
      }
      expect(requests, hasLength(12));

      // The 13th is skipped and says when to ask again.
      await expectLater(
        service.productPhoto('4000000000012'),
        throwsA(
          isA<OffRateLimited>().having(
            (e) => e.retryAfter,
            'retryAfter',
            const Duration(seconds: 60),
          ),
        ),
      );
      expect(requests, hasLength(12));

      await service.lookupBarcode('4000000000099');
      expect(requests, hasLength(13));
    });

    test('names the app with version and contact in the User-Agent', () async {
      await service.search('milch');
      await service.lookupBarcode('4000000000001');
      final version = RegExp(
        r'^version:\s*([0-9.]+)',
        multiLine: true,
      ).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1);
      expect(offUserAgent, 'Avo/$version (kontakt@example.invalid)');
      for (final r in requests) {
        expect(r.headers['User-Agent'], offUserAgent);
      }
    });

    test('photo lookup reads the front photos and caches the answer', () async {
      productStatus = 200;
      productBody = jsonEncode({
        'status': 1,
        'product': {
          'code': '4000000000001',
          'image_front_small_url':
              'https://images.openfoodfacts.org/images/products/400/front_de.3.200.jpg',
          'image_front_url':
              'https://images.openfoodfacts.org/images/products/400/front_de.3.400.jpg',
        },
      });
      final photo = await service.productPhoto('4000000000001');
      expect(photo, isNotNull);
      expect(photo!.urlFor(44), endsWith('.200.jpg'));
      expect(photo.urlFor(88), endsWith('.400.jpg'));
      expect(
        photo.productPage.toString(),
        'https://world.openfoodfacts.org/product/4000000000001',
      );

      await service.productPhoto('4000000000001');
      expect(requests, hasLength(1));

      final fresh = build();
      expect(await fresh.productPhoto('4000000000001'), isNotNull);
      expect(requests, hasLength(1), reason: 'saved on the device');
    });

    test(
      'photo lookup caches "no photo" and asks nothing for bad codes',
      () async {
        expect(await service.productPhoto('4000000000001'), isNull);
        expect(await service.productPhoto('4000000000001'), isNull);
        expect(await service.productPhoto('abc'), isNull);
        expect(await service.productPhoto('123'), isNull);
        expect(requests, hasLength(1));

        expect(await build().productPhoto('4000000000001'), isNull);
        expect(requests, hasLength(1), reason: 'saved on the device');
      },
    );

    test('photo lookup caches a found product without a photo', () async {
      productStatus = 200;
      productBody = jsonEncode({
        'status': 1,
        'product': {'code': '4000000000001'},
      });
      expect(await service.productPhoto('4000000000001'), isNull);
      expect(await build().productPhoto('4000000000001'), isNull);
      expect(requests, hasLength(1));
    });

    test('photo lookup does not cache server errors', () async {
      for (final status in [429, 500, 503]) {
        productStatus = status;
        productBody = 'busy';
        expect(await service.productPhoto('4000000000001'), isNull);
      }
      expect(requests, hasLength(3));
    });

    test('photo lookup ignores photos outside Open Food Facts', () async {
      productStatus = 200;
      productBody = jsonEncode({
        'status': 1,
        'product': {
          'image_front_small_url': 'https://mg2de.b-cdn.net/offer/1.jpg',
        },
      });
      expect(await service.productPhoto('4000000000001'), isNull);
    });
  });

  group('OpenPricesService', () {
    test('uses the same User-Agent and the shared search limit, '
        'leaving 3 searches for the person', () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response(jsonEncode({'hits': [], 'items': []}), 200);
      });

      await http.runWithClient(
        () => OpenPricesService.instance.lookupByName('olivenoel'),
        () => client,
      );
      expect(requests, hasLength(1));
      expect(requests.single.headers['user-agent'], offUserAgent);

      // 7 of 10 in use: background lookups stop, the person's search not.
      for (var i = 0; i < 6; i++) {
        expect(OffRateLimits.shared.search.tryAcquire(), isTrue);
      }
      await http.runWithClient(
        () => OpenPricesService.instance.lookupByName('rapsoel'),
        () => client,
      );
      expect(requests, hasLength(1), reason: 'background reserve reached');
      for (var i = 0; i < 3; i++) {
        expect(OffRateLimits.shared.search.tryAcquire(), isTrue);
      }
    });
  });
}

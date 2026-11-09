// A8: Teil B's in-memory caches are emptied on sign-out, the region starts
// again for another account, and Avo answers "Lösch mein Konto" with a row
// to the page instead of acting.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/data/services/avo_assistant_service.dart';
import 'package:shoply/data/services/meal_photo_storage_service.dart';
import 'package:shoply/data/services/offer_price_service.dart';
import 'package:shoply/presentation/providers/list_offer_prefs_provider.dart';
import 'package:shoply/presentation/providers/region_provider.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_result_card.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_setting_sections.dart';
import 'package:shoply/routes/route_paths.dart';

import '../../screens/offers/offer_test_harness.dart' show FakeRegionLookup;

class _Bucket implements MealPhotoBucket {
  var signs = 0;

  @override
  Future<String> createSignedUrl(String path, Duration expiresIn) async {
    signs++;
    return 'https://example.test/$path?sig=$signs';
  }

  @override
  Future<void> remove(List<String> paths) async {}

  @override
  Future<void> upload(
    String path,
    Uint8List bytes, {
    required String contentType,
  }) async {}
}

class _CountingLookup extends FakeRegionLookup {
  _CountingLookup(super.region);

  var reads = 0;

  @override
  Future<Region?> getRegion({
    bool allowPermissionPrompt = false,
    bool forceRefresh = false,
  }) {
    reads++;
    return super.getRegion(
      allowPermissionPrompt: allowPermissionPrompt,
      forceRefresh: forceRefresh,
    );
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('offer searches are asked again after clearSessionCache', () async {
    var searches = 0;
    final service = OfferPriceService.forTesting(
      MockClient((request) async {
        if (request.url.host == 'www.marktguru.de') {
          return http.Response(
            '<script type="application/json">'
            '{"config":{"apiKey":"a1","clientKey":"c1"}}</script>',
            200,
          );
        }
        searches++;
        return http.Response('{"results":[]}', 200);
      }),
      requestGap: Duration.zero,
    );
    await service.trySearchOffers('Milch', zipCode: '89077');
    await service.trySearchOffers('Milch', zipCode: '89077');
    expect(searches, 1);
    service.clearSessionCache();
    await service.trySearchOffers('Milch', zipCode: '89077');
    expect(searches, 2);
  });

  test('signed photo URLs are signed again after clearSignedUrls', () async {
    final bucket = _Bucket();
    final service = MealPhotoStorageService(bucket: bucket);
    const path = 'u1/a.jpg';
    await service.signedUrl(path);
    await service.signedUrl(path);
    expect(bucket.signs, 1);
    service.clearSignedUrls();
    await service.signedUrl(path);
    expect(bucket.signs, 2);
  });

  test('the region is read again for another account', () async {
    final lookup = _CountingLookup(
      const Region(zip: '79098', source: RegionSource.manual),
    );
    final account = StateProvider<String?>((ref) => 'u1');
    final container = ProviderContainer(
      overrides: [
        regionLookupProvider.overrideWithValue(lookup),
        offerAccountIdProvider.overrideWith((ref) => ref.watch(account)),
      ],
    );
    addTearDown(container.dispose);
    container.listen(regionProvider, (_, __) {});
    await pumpEventQueue();
    expect(container.read(regionProvider)?.zip, '79098');
    expect(lookup.reads, 1);

    lookup.region = null;
    container.read(account.notifier).state = null;
    await pumpEventQueue();
    expect(lookup.reads, 2);
    expect(container.read(regionProvider), isNull);
  });

  group('show_settings_link', () {
    test('adds a row for the page and changes nothing', () {
      final payloads = <AvoWidgetPayload>[];
      final result = AvoAssistantService.toolSettingsLink({
        'page': 'account_delete',
      }, payloads);
      expect(result['shown'], isTrue);
      expect(payloads.single.kind, AvoPayloadKind.settingsLink);
      expect(payloads.single.settingsLink, AvoSettingsLink.accountDelete);
      expect(payloads.single.isDoneChange, isFalse);
    });

    test('an unknown page is an error without a row', () {
      final payloads = <AvoWidgetPayload>[];
      final result = AvoAssistantService.toolSettingsLink({
        'page': 'delete_now',
      }, payloads);
      expect(result['error'], isNotNull);
      expect(payloads, isEmpty);
    });

    for (final (page, route, title, note) in [
      (
        AvoSettingsLink.accountDelete,
        RoutePaths.settingsAccountDelete,
        'Konto löschen',
        'Das machst du selbst unter Konto.',
      ),
      (
        AvoSettingsLink.account,
        RoutePaths.settingsAccount,
        'Konto',
        'Abmelden, E-Mail und Passwort änderst du selbst unter Konto.',
      ),
    ]) {
      testWidgets('"$title" opens $route', (tester) async {
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => Scaffold(
                body: Builder(
                  builder: (context) => AvoResultCard(
                    sections: [avoSettingsLinkSection(context, page)],
                  ),
                ),
              ),
            ),
            GoRoute(
              path: route,
              builder: (context, state) => const Text('target page'),
            ),
          ],
        );
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp.router(
              routerConfig: router,
              locale: const Locale('de'),
              supportedLocales: const [Locale('de'), Locale('en')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(title), findsOneWidget);
        expect(find.text(note), findsOneWidget);
        await tester.tap(find.text('Öffnen'));
        await tester.pumpAndSettle();
        expect(find.text('target page'), findsOneWidget);
      });
    }
  });
}

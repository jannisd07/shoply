// Guards the offer lookup once the bundled fallback keys are gone.
//
// Without a usable key pair the service must stay silent: no request to the
// offers API, a null result ("don't know", so nothing is cached or shown),
// and no second download of the marktguru homepage while the cooldown runs.
// Otherwise every keystroke in the add field would hit marktguru.de.
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/services/offer_price_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('no extractable keys: null result and no offers request', () async {
    final hosts = <String>[];
    final service = OfferPriceService.forTesting(
      MockClient((request) async {
        hosts.add(request.url.host);
        return http.Response('<html>no config here</html>', 200);
      }),
    );

    final result = await service.trySearchOffers('Milch', zipCode: '89077');

    expect(result, isNull);
    expect(hosts, ['www.marktguru.de']);
  });

  test('failed extraction is not retried during the cooldown', () async {
    var homepageLoads = 0;
    final service = OfferPriceService.forTesting(
      MockClient((request) async {
        if (request.url.host == 'www.marktguru.de') homepageLoads++;
        return http.Response('', 500);
      }),
    );

    await service.trySearchOffers('Milch', zipCode: '89077');
    await service.trySearchOffers('Butter', zipCode: '89077');

    expect(homepageLoads, 1);
  });

  test('extracted keys are sent with the offers request', () async {
    final apiKeys = <String?>[];
    final service = OfferPriceService.forTesting(
      MockClient((request) async {
        if (request.url.host == 'www.marktguru.de') {
          return http.Response(
            '<script type="application/json">'
            '{"config":{"apiKey":"a1","clientKey":"c1"}}</script>',
            200,
          );
        }
        apiKeys.add(request.headers['x-apikey']);
        return http.Response('{"results":[]}', 200);
      }),
    );

    final result = await service.trySearchOffers('Milch', zipCode: '89077');

    expect(result, isEmpty);
    expect(apiKeys, ['a1']);
  });
}

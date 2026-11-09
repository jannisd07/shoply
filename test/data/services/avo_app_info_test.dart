// A9-4: what Avo knows about Avo Pro comes from the paywall's catalogue
// (ProFeatures.all), with no fixed price and nothing that is free.
import 'package:flutter_test/flutter_test.dart';

import 'package:shoply/data/services/avo_assistant_service.dart';
import 'package:shoply/data/services/subscription_service.dart';
import 'package:shoply/presentation/widgets/design/pro_gate.dart';

void main() {
  group('avoProContents', () {
    for (final lang in ['de', 'en']) {
      test('one entry per Pro feature, in paywall order ($lang)', () {
        final contents = avoProContents(lang);
        expect(contents, hasLength(ProFeatures.all.length));
        for (final entry in contents) {
          expect(entry['title'], isNotEmpty);
          expect(entry['detail'], isNotEmpty);
          // Translated, not the raw key.
          expect(entry['title'], isNot(startsWith('pro_feat_')));
        }
      });

      test('names no price and nothing that stays free ($lang)', () {
        final text = avoProContents(
          lang,
        ).map((e) => '${e['title']} ${e['detail']}').join(' ').toLowerCase();
        expect(text, isNot(contains('€')));
        expect(text, isNot(contains(r'$')));
        for (final free in [
          'kategorie',
          'categor',
          'alle rezepte',
          'all recipes',
          'nährwert',
          'nutrition',
          'theme',
          'sync',
          'angebot',
          'offer',
        ]) {
          expect(text, isNot(contains(free)), reason: free);
        }
      });
    }

    test('German titles are the paywall titles', () {
      expect(avoProContents('de').map((e) => e['title']), [
        'Mehr von Avo',
        'Avo plant deine Woche',
        'Kochmodus',
        'Statistiken',
      ]);
    });
  });

  test('a store price is named by its plan, never by the store title', () {
    expect(avoProPrice(SubscriptionProducts.yearlyId, '29,99 €'), {
      'plan': 'yearly',
      'price': '29,99 €',
    });
    expect(avoProPrice(SubscriptionProducts.monthlyId, '2,99 €'), {
      'plan': 'monthly',
      'price': '2,99 €',
    });
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:shoply/data/services/trip_money_format.dart';
import 'package:shoply/data/services/trip_split_math.dart';

void main() {
  group('parseAmountCents (verlauf-kosten.md 3.3, Bug 14)', () {
    int? de(String s) => parseAmountCents(s).cents;
    int? en(String s) => parseAmountCents(s, languageCode: 'en').cents;

    test('reads every common notation', () {
      expect(de('42,8'), 4280);
      expect(de('42,80'), 4280);
      expect(de('42.80'), 4280);
      expect(de('1.234,56'), 123456);
      expect(de('1234,5'), 123450);
      expect(de('1,234.56'), 123456);
      expect(de('12'), 1200);
      expect(de('€ 12,00'), 1200);
      expect(de('0,99'), 99);
      expect(de(',5'), 50);
    });

    test('a lone separator before three digits groups thousands', () {
      expect(de('1.234'), 123400);
      expect(en('1,234'), 123400);
      expect(de('12.345'), 1234500);
      expect(parseAmountCents('1.234.567').isInvalid, isTrue, reason: 'cap');
    });

    test('empty is no amount, never an error', () {
      expect(parseAmountCents('').isEmpty, isTrue);
      expect(parseAmountCents('   ').isEmpty, isTrue);
      expect(parseAmountCents('').isInvalid, isFalse);
    });

    test('nonsense is invalid, never silently 0', () {
      for (final text in ['abc', '-3', '4,567', '1.2.3', '12,3,4', '1,23.4']) {
        final input = parseAmountCents(text);
        expect(input.isInvalid, isTrue, reason: text);
        expect(input.cents, isNull, reason: text);
      }
    });

    test('refuses more than 100.000 €', () {
      expect(parseAmountCents('100000').cents, maxTripAmountCents);
      expect(parseAmountCents('100000,01').isInvalid, isTrue);
    });
  });

  group('equalShareCents', () {
    test('10,00 € by 3 is 3,34 + 3,33 + 3,33 (rest cent first)', () {
      expect(equalShareCents(1000, 3), [334, 333, 333]);
    });

    test('always adds up to the cent', () {
      for (final total in [0, 1, 99, 1001, 4280, 99999]) {
        for (var n = 1; n <= 7; n++) {
          final shares = equalShareCents(total, n);
          expect(shares, hasLength(n));
          expect(sharesAddUp(total, shares), isTrue, reason: '$total / $n');
          expect(shares.first - shares.last, lessThanOrEqualTo(1));
        }
      }
    });

    test('several rest cents go to the first positions', () {
      expect(equalShareCents(1002, 4), [251, 251, 250, 250]);
    });

    test('nobody gets nothing', () {
      expect(equalShareCents(1000, 0), isEmpty);
    });
  });

  group('money format', () {
    test('German "42,80 €" with a no-break space, English "€42.80"', () {
      expect(formatEuroCents(4280, 'de'), '42,80 €');
      expect(formatEuroCents(4280, 'en'), '€42.80');
      expect(formatEuroCents(142800, 'de'), '1.428,00 €');
    });

    test('VoiceOver reads euros and cents', () {
      expect(spokenEuroCents(320, 'de'), '3,20 Euro');
      expect(spokenEuroCents(320, 'en'), '3 euros 20');
      expect(spokenEuroCents(100, 'en'), '1 euro');
    });

    test('cents and euros round-trip without float noise', () {
      expect(eurosToCents(0.1 + 0.2), 30);
      expect(centsToEuros(334), 3.34);
    });
  });
}

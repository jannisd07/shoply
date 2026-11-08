import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/utils/item_quantity.dart';

void main() {
  String? de(double q, [String? unit]) =>
      formatQuantity(q, unit, languageCode: 'de');
  String? en(double q, [String? unit]) =>
      formatQuantity(q, unit, languageCode: 'en');

  test('a single piece without unit has no second line', () {
    expect(de(1), isNull);
    expect(de(1, 'pcs'), isNull);
    expect(de(1, 'Stk.'), isNull);
    expect(en(1, ''), isNull);
  });

  test('pieces, units and decimals in the app language', () {
    expect(de(2), '2 St.');
    expect(de(3, 'Stk'), '3 St.');
    expect(en(2, 'pcs'), '2 pcs');
    expect(de(1.5, 'l'), '1,5 L');
    expect(en(1.5, 'kg'), '1.5 kg');
    expect(de(500, 'g'), '500 g');
    expect(de(1, 'bunch'), '1 Bund');
    expect(de(1, 'bottle'), '1 Fl.');
    expect(en(1, 'bottle'), '1 btl.');
  });

  test('free text from older rows stays as typed', () {
    expect(de(2, 'Beutel'), '2 Beutel');
    expect(de(1, 'Tetrapack'), '1 Tetrapack');
  });

  test('piece units are recognised in any spelling', () {
    expect(isPieceUnit(null), isTrue);
    expect(isPieceUnit(' Stück '), isTrue);
    expect(isPieceUnit('g'), isFalse);
  });
}

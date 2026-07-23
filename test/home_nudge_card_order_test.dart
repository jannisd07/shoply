import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/presentation/screens/home/home_nudge_card_order.dart';

void main() {
  group('orderedHomeNudgeCards', () {
    test('no priorities selected keeps the original fixed order', () {
      expect(orderedHomeNudgeCards({}), kDefaultHomeNudgeCardOrder);
    });

    test('a priority with no mapped card keeps the original order', () {
      expect(
        orderedHomeNudgeCards({'discover_recipes'}),
        kDefaultHomeNudgeCardOrder,
      );
    });

    test('a single matched priority floats its card to the front', () {
      expect(
        orderedHomeNudgeCards({'save_money'}),
        [
          HomeNudgeCardKind.priceComparison,
          HomeNudgeCardKind.split,
          HomeNudgeCardKind.avoRestock,
          HomeNudgeCardKind.calorieRecipe,
        ],
      );
    });

    test('multiple matched priorities preserve default relative order '
        'among themselves and among the rest', () {
      // calorieRecipe and priceComparison are selected; default order has
      // them after split/avoRestock, so they should surface first, in
      // their original relative order, followed by the unselected two.
      expect(
        orderedHomeNudgeCards({'eat_healthier', 'save_money'}),
        [
          HomeNudgeCardKind.calorieRecipe,
          HomeNudgeCardKind.priceComparison,
          HomeNudgeCardKind.split,
          HomeNudgeCardKind.avoRestock,
        ],
      );
    });

    test('every priority selected reduces to the default order', () {
      expect(
        orderedHomeNudgeCards({
          'save_money',
          'share_lists',
          'eat_healthier',
          'discover_recipes',
          'stay_organized',
        }),
        kDefaultHomeNudgeCardOrder,
      );
    });

    test('unknown priority ids are ignored, not thrown on', () {
      expect(
        orderedHomeNudgeCards({'some_future_priority'}),
        kDefaultHomeNudgeCardOrder,
      );
    });
  });
}

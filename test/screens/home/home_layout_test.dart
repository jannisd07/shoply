import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/presentation/screens/home/home_layout.dart';

void main() {
  const everything = HomeLayoutInput(
    avo: true,
    offers: true,
    calories: true,
    mealPlan: true,
    savingsHint: true,
    month: true,
    spending: true,
    savingsGoal: true,
    caloriesToday: true,
    continueShopping: true,
    restock: true,
    offersTile: true,
    water: true,
    lists: true,
    recentTrips: true,
    cookToday: true,
    tip: true,
  );

  test('everything on: exactly the D2 "Für dich" order', () {
    expect(homeSections(everything), [
      HomeSection.avoCard,
      HomeSection.month,
      HomeSection.spending,
      HomeSection.savingsGoal,
      HomeSection.calories,
      HomeSection.forYou,
      HomeSection.topLists,
      HomeSection.recentTrips,
      HomeSection.cookToday,
      HomeSection.tip,
    ]);
    expect(homeTiles(everything), HomeTile.values);
  });

  test('a brand-new account sees the Avo card only', () {
    expect(homeSections(const HomeLayoutInput()), [HomeSection.avoCard]);
  });

  test('offers module off: no savings goal, no offers tile', () {
    const i = HomeLayoutInput(
      offers: false,
      savingsHint: true,
      savingsGoal: true,
      offersTile: true,
      restock: true,
    );
    expect(homeSections(i), isNot(contains(HomeSection.savingsGoal)));
    expect(homeTiles(i), [HomeTile.restock]);
  });

  test('Avo module off: the savings hint stands on its own', () {
    const i = HomeLayoutInput(avo: false, savingsHint: true);
    expect(homeSections(i), [HomeSection.savingsHint]);
    expect(
      homeSections(
        const HomeLayoutInput(avo: false, offers: false, savingsHint: true),
      ),
      isEmpty,
    );
  });

  test('calories and meal plan follow their modules', () {
    const off = HomeLayoutInput(
      caloriesToday: true,
      water: true,
      cookToday: true,
    );
    expect(homeSections(off), [HomeSection.avoCard]);
    expect(homeTiles(off), isEmpty);
    const on = HomeLayoutInput(
      calories: true,
      mealPlan: true,
      caloriesToday: true,
      water: true,
      cookToday: true,
    );
    expect(homeSections(on), [
      HomeSection.avoCard,
      HomeSection.calories,
      HomeSection.forYou,
      HomeSection.cookToday,
    ]);
  });

  test('no tiles: no "Für dich" heading', () {
    expect(homeSections(const HomeLayoutInput(lists: true)), [
      HomeSection.avoCard,
      HomeSection.topLists,
    ]);
  });

  test('gaps follow D2', () {
    expect(homeSectionGap(null, HomeSection.avoCard), 40);
    expect(homeSectionGap(HomeSection.avoCard, HomeSection.month), 24);
    expect(homeSectionGap(HomeSection.month, HomeSection.spending), 12);
    expect(homeSectionGap(HomeSection.spending, HomeSection.savingsGoal), 12);
    expect(homeSectionGap(HomeSection.savingsGoal, HomeSection.calories), 24);
    expect(homeSectionGap(HomeSection.cookToday, HomeSection.tip), 12);
    expect(homeSectionGap(HomeSection.topLists, HomeSection.tip), 24);
    expect(homeSectionGap(HomeSection.tip, HomeSection.proHint), 12);
    expect(homeSectionGap(HomeSection.topLists, HomeSection.proHint), 24);
  });

  test('the Pro offer comes last, only when Home decided for it', () {
    expect(homeSections(everything), isNot(contains(HomeSection.proHint)));
    const withHint = HomeLayoutInput(lists: true, proHint: true);
    expect(homeSections(withHint), [
      HomeSection.avoCard,
      HomeSection.topLists,
      HomeSection.proHint,
    ]);
  });
}

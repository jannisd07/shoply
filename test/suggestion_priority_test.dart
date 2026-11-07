// Ranking of restock suggestions.
//
// The rule the user asked for: things bought occasionally should still be
// suggested — they must not need three purchases to qualify — but the things
// bought often come first. Sorting on overdue ratio alone got this backwards,
// because a twice-bought oddity with a shaky average looks wildly overdue.
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/services/avo_nudge_service.dart';

double priority({
  required int count,
  required double avgDays,
  required double ratio,
}) =>
    AvoNudgeService.suggestionPriority(
      purchaseCount: count,
      averageDaysBetween: avgDays,
      overdueRatio: ratio,
    );

void main() {
  group('habit strength', () {
    test('grows with the number of purchases', () {
      final two = AvoNudgeService.habitStrength(
          purchaseCount: 2, averageDaysBetween: 7);
      final twenty = AvoNudgeService.habitStrength(
          purchaseCount: 20, averageDaysBetween: 7);
      expect(twenty, greaterThan(two));
    });

    test('saturates, so early purchases matter most', () {
      double h(int n) =>
          AvoNudgeService.habitStrength(purchaseCount: n, averageDaysBetween: 7);
      expect(h(6) - h(2), greaterThan(h(30) - h(20)));
    });

    test('a tight cadence counts as more of a habit', () {
      final weekly = AvoNudgeService.habitStrength(
          purchaseCount: 5, averageDaysBetween: 7);
      final rare = AvoNudgeService.habitStrength(
          purchaseCount: 5, averageDaysBetween: 55);
      expect(weekly, greaterThan(rare));
    });

    test('never reaches zero, so occasional buys stay eligible', () {
      final minimal = AvoNudgeService.habitStrength(
          purchaseCount: 2, averageDaysBetween: 60);
      expect(minimal, greaterThan(0));
    });

    test('stays within 0..1', () {
      expect(
        AvoNudgeService.habitStrength(purchaseCount: 500, averageDaysBetween: 1),
        lessThanOrEqualTo(1.0),
      );
    });
  });

  group('suggestion priority', () {
    test('a weekly staple outranks a barely-known item that looks overdue',
        () {
      final staple = priority(count: 20, avgDays: 7, ratio: 1.1);
      final oddity = priority(count: 2, avgDays: 45, ratio: 1.8);
      expect(staple, greaterThan(oddity));
    });

    test('an occasional buy still scores above zero', () {
      expect(priority(count: 2, avgDays: 45, ratio: 1.2), greaterThan(0));
    });

    test('among equals, the more overdue one wins', () {
      final a = priority(count: 8, avgDays: 7, ratio: 1.6);
      final b = priority(count: 8, avgDays: 7, ratio: 1.0);
      expect(a, greaterThan(b));
    });

    test('urgency saturates so a stale outlier cannot dominate forever', () {
      final twiceOverdue = priority(count: 8, avgDays: 7, ratio: 2.0);
      final wildlyOverdue = priority(count: 8, avgDays: 7, ratio: 12.0);
      expect(wildlyOverdue, equals(twiceOverdue));
    });

    test('not yet due scores below due', () {
      final notDue = priority(count: 8, avgDays: 7, ratio: 0.5);
      final due = priority(count: 8, avgDays: 7, ratio: 1.0);
      expect(notDue, lessThan(due));
    });
  });
}

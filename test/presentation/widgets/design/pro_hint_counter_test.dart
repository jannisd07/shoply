import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/presentation/widgets/design/pro_hint_counter.dart';

void main() {
  const hint = ProHintCounter.trialOffer;
  late SharedPreferences prefs;
  late DateTime now;
  ProHintCounter counter() => ProHintCounter(prefs, clock: () => now);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    now = DateTime(2026, 11, 9, 10);
  });

  test('nothing before the first finished trip', () {
    expect(counter().canShow(hint, visitStart: now), isFalse);
  });

  test('not on the visit of the trip, on the next one', () {
    final visit = now;
    now = now.add(const Duration(minutes: 5));
    counter().noteAha();
    expect(counter().canShow(hint, visitStart: visit), isFalse);
    expect(
      counter().canShow(hint, visitStart: now.add(const Duration(seconds: 1))),
      isTrue,
    );
  });

  test('stays for the day once shown, then waits a week', () {
    counter().noteAha();
    final later = now.add(const Duration(hours: 1));
    counter().markShown(hint);
    now = later;
    expect(counter().canShow(hint, visitStart: later), isTrue);
    now = DateTime(2026, 11, 10, 9);
    expect(counter().canShow(hint, visitStart: now), isFalse);
    now = DateTime(2026, 11, 15, 9);
    expect(counter().canShow(hint, visitStart: now), isFalse);
    now = DateTime(2026, 11, 16, 9);
    expect(counter().canShow(hint, visitStart: now), isTrue);
  });

  test('one Pro hint a day overall', () {
    counter().noteAha();
    now = now.add(const Duration(hours: 1));
    counter().markShown('other');
    expect(counter().canShow(hint, visitStart: now), isFalse);
  });

  test('"Nicht mehr zeigen" is final', () {
    counter().noteAha();
    now = now.add(const Duration(hours: 1));
    counter().hide(hint);
    expect(counter().isHidden(hint), isTrue);
    now = DateTime(2027, 1, 1);
    expect(counter().canShow(hint, visitStart: now), isFalse);
  });

  test('only the first aha counts', () {
    counter().noteAha();
    final first = counter().ahaAt;
    now = now.add(const Duration(days: 3));
    counter().noteAha();
    expect(counter().ahaAt, first);
  });

  test('lives under an account-bound key', () {
    counter().noteAha();
    expect(prefs.getKeys(), {ProHintCounter.key});
  });

  testWidgets('a visit never shows the hint on the first visit (app start), '
      'then on the next one; it goes when room runs out', (tester) async {
    counter().noteAha();
    now = now.add(const Duration(hours: 1));
    final visit = ProHintVisit(hint, clock: () => now);
    final results = <bool>[];
    Future<void> pump({required bool on, bool allowed = true}) =>
        tester.pumpWidget(
          TickerMode(
            enabled: on,
            child: Builder(
              builder: (context) {
                results.add(
                  visit.resolve(
                    context,
                    counter(),
                    ready: true,
                    allowed: allowed,
                  ),
                );
                return const SizedBox();
              },
            ),
          ),
        );
    await pump(on: true);
    expect(results.last, isFalse);
    await pump(on: false);
    await pump(on: true);
    expect(results.last, isTrue);
    await pump(on: true, allowed: false);
    expect(results.last, isFalse);
  });
}

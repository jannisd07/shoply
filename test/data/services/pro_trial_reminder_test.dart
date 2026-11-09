// A9b-1: the local reminder on day 12 of the Avo Pro trial.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/data/services/notification_service.dart';

void main() {
  final service = NotificationService.instance;
  late List<(int, String, String, DateTime)> planned;
  late List<int> cancelled;

  setUp(() {
    SharedPreferences.setMockInitialValues({'language': 'de'});
    planned = [];
    cancelled = [];
    service.debugHasPermission = () async => true;
    service.debugCancel = (id) async => cancelled.add(id);
    service.debugSchedule = (id, title, body, at) async =>
        planned.add((id, title, body, at));
  });

  tearDown(() {
    service.debugHasPermission = null;
    service.debugSchedule = null;
    service.debugCancel = null;
  });

  group('when', () {
    DateTime? time(DateTime end, DateTime now) =>
        NotificationService.proTrialReminderTime(end, now);

    test('10:00 local on the day 48 h before the end', () {
      expect(
        time(DateTime(2026, 11, 23, 9, 30), DateTime(2026, 11, 9)),
        DateTime(2026, 11, 21, 10),
      );
    });

    test('a trial ending at night still reminds at daytime', () {
      expect(
        time(DateTime(2026, 11, 23, 3, 15), DateTime(2026, 11, 9)),
        DateTime(2026, 11, 21, 10),
      );
      expect(
        time(DateTime(2026, 11, 23, 23, 50), DateTime(2026, 11, 9)),
        DateTime(2026, 11, 21, 10),
      );
    });

    test('10:00 of that day already passed: nothing', () {
      expect(
        time(DateTime(2026, 11, 23, 9, 30), DateTime(2026, 11, 21, 10, 1)),
        isNull,
      );
    });

    test('a trial ending tomorrow: nothing', () {
      expect(time(DateTime(2026, 11, 10, 9), DateTime(2026, 11, 9, 8)), isNull);
    });
  });

  test('the sentence in German and English with the price passed in', () {
    expect(
      NotificationService.proTrialReminderBody('de', '29,99 €'),
      'Deine Avo Pro-Testphase endet übermorgen. Danach 29,99 € pro Jahr.',
    );
    expect(
      NotificationService.proTrialReminderBody('en', r'$29.99'),
      r'Your Avo Pro trial ends the day after tomorrow. After that it is $29.99 a year.',
    );
  });

  test('the tap opens shoply://pro', () {
    final data = NotificationService.payloadData(
      NotificationService.proTrialReminderPayload,
    );
    expect(data, {'type': 'pro_trial_reminder', 'link': 'shoply://pro'});
  });

  test('planned with the fixed id, the brand as title, true', () async {
    final end = DateTime.now().add(const Duration(days: 14));
    final ok = await service.scheduleProTrialReminder(
      end,
      yearlyPrice: '29,99 €',
    );
    expect(ok, isTrue);
    expect(planned, hasLength(1));
    final (id, title, body, at) = planned.single;
    expect(id, NotificationService.proTrialReminderId);
    expect(title, 'Avo Pro');
    expect(body, contains('29,99 €'));
    expect(at, NotificationService.proTrialReminderTime(end, DateTime.now()));
    expect(at.hour, 10);
    expect(cancelled, [
      NotificationService.proTrialReminderId,
    ], reason: 'an older reminder is replaced');
  });

  test('without permission: false and nothing planned', () async {
    service.debugHasPermission = () async => false;
    final ok = await service.scheduleProTrialReminder(
      DateTime.now().add(const Duration(days: 14)),
      yearlyPrice: '29,99 €',
    );
    expect(ok, isFalse);
    expect(planned, isEmpty);
    expect(cancelled, [NotificationService.proTrialReminderId]);
  });

  test('notifications switched off in the app: false', () async {
    SharedPreferences.setMockInitialValues({'notif_master_enabled': false});
    final ok = await service.scheduleProTrialReminder(
      DateTime.now().add(const Duration(days: 14)),
      yearlyPrice: '29,99 €',
    );
    expect(ok, isFalse);
    expect(planned, isEmpty);
    expect(cancelled, [NotificationService.proTrialReminderId]);
  });

  test('a trial ending tomorrow plans nothing', () async {
    final ok = await service.scheduleProTrialReminder(
      DateTime.now().add(const Duration(days: 1)),
      yearlyPrice: '29,99 €',
    );
    expect(ok, isFalse);
    expect(planned, isEmpty);
    expect(cancelled, [NotificationService.proTrialReminderId]);
  });
}

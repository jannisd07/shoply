// A9b-1: the local reminder on day 12 of the Avo Pro trial.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/data/services/notification_service.dart';

void main() {
  final service = NotificationService.instance;
  late List<(int, String, String, DateTime)> planned;

  setUp(() {
    SharedPreferences.setMockInitialValues({'language': 'de'});
    planned = [];
    service.debugHasPermission = () async => true;
    service.debugSchedule = (id, title, body, at) async =>
        planned.add((id, title, body, at));
  });

  tearDown(() {
    service.debugHasPermission = null;
    service.debugSchedule = null;
  });

  test('the reminder comes two days before the trial ends', () {
    final end = DateTime(2026, 11, 23, 9, 30);
    expect(
      NotificationService.proTrialReminderTime(end, DateTime(2026, 11, 9)),
      DateTime(2026, 11, 21, 9, 30),
    );
  });

  test('nothing when that day has passed', () {
    final end = DateTime(2026, 11, 10, 9);
    expect(
      NotificationService.proTrialReminderTime(end, DateTime(2026, 11, 9)),
      isNull,
    );
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
    expect(at, end.subtract(const Duration(days: 2)));
  });

  test('without permission: false and nothing planned', () async {
    service.debugHasPermission = () async => false;
    final ok = await service.scheduleProTrialReminder(
      DateTime.now().add(const Duration(days: 14)),
      yearlyPrice: '29,99 €',
    );
    expect(ok, isFalse);
    expect(planned, isEmpty);
  });

  test('notifications switched off in the app: false', () async {
    SharedPreferences.setMockInitialValues({'notif_master_enabled': false});
    final ok = await service.scheduleProTrialReminder(
      DateTime.now().add(const Duration(days: 14)),
      yearlyPrice: '29,99 €',
    );
    expect(ok, isFalse);
    expect(planned, isEmpty);
  });

  test('a trial ending tomorrow plans nothing', () async {
    final ok = await service.scheduleProTrialReminder(
      DateTime.now().add(const Duration(days: 1)),
      yearlyPrice: '29,99 €',
    );
    expect(ok, isFalse);
    expect(planned, isEmpty);
  });
}

// A8: Avo's reminders fire at the times chosen in Einstellungen ›
// Mitteilungen (and › Kalorien & Gesundheit) instead of fixed 9:00 / 18:00,
// and "Ideen fürs Abendessen" has its own switch.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/data/services/mascot_notification_service.dart';
import 'package:shoply/presentation/screens/profile/settings/data/notification_settings.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the keys are the ones Einstellungen › Mitteilungen writes', () {
    expect(
      MascotNotificationService.restockTimeKey,
      NotificationTimeSlot.restock.prefsKey,
    );
    expect(
      MascotNotificationService.dinnerTimeKey,
      NotificationTimeSlot.dinnerIdeas.prefsKey,
    );
    expect(
      MascotNotificationService.dinnerIdeasKey,
      NotificationSetting.dinnerIdeas.prefsKey,
    );
    expect(
      MascotNotificationService.defaultRestockTime,
      (
        hour: NotificationTimeSlot.restock.defaultHour,
        minute: NotificationTimeSlot.restock.defaultMinute,
      ),
    );
    expect(
      MascotNotificationService.defaultDinnerTime,
      (
        hour: NotificationTimeSlot.dinnerIdeas.defaultHour,
        minute: NotificationTimeSlot.dinnerIdeas.defaultMinute,
      ),
    );
  });

  test('parseReminderTime reads "H:MM" and falls back on anything else', () {
    const fallback = (hour: 9, minute: 0);
    expect(MascotNotificationService.parseReminderTime('7:30', fallback), (
      hour: 7,
      minute: 30,
    ));
    expect(MascotNotificationService.parseReminderTime('18:05', fallback), (
      hour: 18,
      minute: 5,
    ));
    for (final bad in [null, '', '24:00', '9:60', 'neun', '9', '9:0:0']) {
      expect(
        MascotNotificationService.parseReminderTime(bad, fallback),
        fallback,
        reason: '$bad',
      );
    }
  });

  test('restock fires the next day, dinner ideas today, at the chosen '
      'minute', () {
    final now = DateTime(2026, 11, 9, 20, 15);
    const time = (hour: 7, minute: 45);
    expect(
      MascotNotificationService.restockMoment(now, time),
      DateTime(2026, 11, 10, 7, 45),
    );
    expect(
      MascotNotificationService.dinnerMoment(now, (hour: 19, minute: 30)),
      DateTime(2026, 11, 9, 19, 30),
    );
    // Month end rolls over.
    expect(
      MascotNotificationService.restockMoment(DateTime(2026, 11, 30, 8), time),
      DateTime(2026, 12, 1, 7, 45),
    );
  });

  test('without a choice the times are 9:00 and 18:00', () async {
    final service = MascotNotificationService.forTesting();
    expect(await service.restockTime(), (hour: 9, minute: 0));
    expect(await service.dinnerTime(), (hour: 18, minute: 0));
    expect(await service.dinnerIdeasEnabled(), isTrue);
  });

  test('stored choices win', () async {
    SharedPreferences.setMockInitialValues({
      'setp_notif_time_restock': '7:30',
      'setp_notif_time_dinner': '19:15',
      'notif_dinner_ideas': false,
    });
    final service = MascotNotificationService.forTesting();
    expect(await service.restockTime(), (hour: 7, minute: 30));
    expect(await service.dinnerTime(), (hour: 19, minute: 15));
    expect(await service.dinnerIdeasEnabled(), isFalse);
  });

  test('a broken stored time falls back to the default', () async {
    SharedPreferences.setMockInitialValues({
      'setp_notif_time_restock': 'morgens',
    });
    final service = MascotNotificationService.forTesting();
    expect(await service.restockTime(), (hour: 9, minute: 0));
  });
}

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/presentation/screens/profile/settings/data/notification_settings.dart';
import 'package:shoply/presentation/screens/profile/settings/notifications_settings_screen.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';

import '../../../layout/layout_matrix.dart';
import 'settings_test_helpers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('every switch has a storage key and a default', () {
    expect(
      NotificationSetting.values.map((s) => s.prefsKey).toSet(),
      hasLength(NotificationSetting.values.length),
    );
    expect(NotificationSetting.newRecipes.defaultOn, isFalse);
    expect(NotificationSetting.planReminder.defaultOn, isFalse);
    expect(NotificationSetting.shoppingStarted.defaultOn, isTrue);
    expect(NotificationSetting.restock.prefsKey, 'notif_avo_nudges');
  });

  layoutMatrix(
    'NotificationsSettingsScreen',
    (_) => scoped(const NotificationsSettingsScreen()),
  );

  layoutMatrix(
    'NotificationsSettingsScreen, iOS says no',
    (_) => scoped(
      const NotificationsSettingsScreen(),
      overrides: settingsOverrides(
        permission: FakePermissionBackend(NotificationPermissionState.denied),
        modules: FakeModuleStore(exampleModules(calories: true)),
      ),
    ),
  );

  testWidgets('allowed: no status row, all categories from the local state', (
    tester,
  ) async {
    await pumpSettings(
      tester,
      const NotificationsSettingsScreen(),
      height: 2200,
    );
    expect(find.byType(StatusRow), findsNothing);
    expect(find.text('Allow notifications'), findsNothing);
    expect(find.text('Notifications from Avo'), findsOneWidget);
    expect(find.text('Someone is shopping'), findsOneWidget);
    expect(find.text('Restock reminder'), findsOneWidget);
    expect(find.text('9:00 AM'), findsOneWidget);
    expect(find.text('Ratings and likes'), findsOneWidget);
    // Modules: cost split on, calories off, the plan unreleased.
    expect(find.text('Open amounts'), findsOneWidget);
    expect(find.text('Dinner ideas'), findsNothing);
    expect(find.text('Remind me about next week'), findsNothing);
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
  });

  testWidgets('not asked yet: "Allow notifications" asks iOS', (tester) async {
    final permission = FakePermissionBackend(
      NotificationPermissionState.notAsked,
      afterRequest: NotificationPermissionState.allowed,
    );
    await pumpSettings(
      tester,
      const NotificationsSettingsScreen(),
      overrides: settingsOverrides(permission: permission),
      height: 2200,
    );
    await tester.tap(find.text('Allow notifications'));
    await settle(tester);
    expect(permission.requests, 1);
    expect(find.text('Allow notifications'), findsNothing);
  });

  testWidgets('denied: the status row opens the iOS settings', (tester) async {
    final actions = FakeExternalActions();
    await pumpSettings(
      tester,
      const NotificationsSettingsScreen(),
      overrides: settingsOverrides(
        actions: actions,
        permission: FakePermissionBackend(NotificationPermissionState.denied),
      ),
      height: 2200,
    );
    expect(find.byType(StatusRow), findsOneWidget);
    await tester.tap(find.text('Allow in Settings'));
    await tester.pump();
    expect(actions.appSettings, 1);
    // The switches stay usable.
    await tester.tap(find.text('Cooking timer'));
    await tester.pump();
  });

  testWidgets('the main switch off folds the categories away', (tester) async {
    final backend = FakeNotificationBackend();
    await pumpSettings(
      tester,
      const NotificationsSettingsScreen(),
      overrides: settingsOverrides(notifications: backend),
      height: 2200,
    );
    await tester.tap(find.text('Notifications from Avo'));
    await settle(tester);
    expect(backend.master, isFalse);
    expect(find.text('Someone is shopping'), findsNothing);
    await tester.tap(find.text('Notifications from Avo'));
    await settle(tester);
    expect(find.text('Someone is shopping'), findsOneWidget);
  });

  testWidgets('a category switch is stored', (tester) async {
    final backend = FakeNotificationBackend();
    await pumpSettings(
      tester,
      const NotificationsSettingsScreen(),
      overrides: settingsOverrides(notifications: backend),
      height: 2200,
    );
    await tester.tap(find.text('New recipes from creators you follow'));
    await settle(tester);
    expect(backend.values[NotificationSetting.newRecipes], isTrue);
    await tester.tap(find.text('Restock reminder'));
    await settle(tester);
    expect(backend.values[NotificationSetting.restock], isFalse);
    expect(find.text('9:00 AM'), findsNothing);
  });

  testWidgets('the restock time is chosen on a wheel in the row', (
    tester,
  ) async {
    final backend = FakeNotificationBackend();
    await pumpSettings(
      tester,
      const NotificationsSettingsScreen(),
      overrides: settingsOverrides(notifications: backend),
      height: 2200,
      locale: const Locale('de'),
    );
    expect(find.text('9:00'), findsOneWidget);
    await tester.tap(find.text('Uhrzeit'));
    await tester.pumpAndSettle();
    final hours = find.byType(CupertinoPicker).first;
    await tester.drag(hours, const Offset(0, -90));
    await tester.pumpAndSettle();
    final time = backend.times[NotificationTimeSlot.restock];
    expect(time, isNotNull);
    expect(time!.hour, greaterThan(9));
    expect(find.text('${time.hour}:00'), findsOneWidget);
  });

  testWidgets('calories on: "Dinner ideas" with its time', (tester) async {
    await pumpSettings(
      tester,
      const NotificationsSettingsScreen(),
      overrides: settingsOverrides(
        modules: FakeModuleStore(exampleModules(calories: true)),
      ),
      height: 2200,
    );
    expect(find.text('Dinner ideas'), findsOneWidget);
    expect(find.text('6:00 PM'), findsOneWidget);
  });
}

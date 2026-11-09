// "Kalorien & Gesundheit" in the settings (S23, `/settings/health`): goals,
// the dinner-ideas reminder with its time, permission and master switch.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/data/models/nutrition_goal.dart';
import 'package:shoply/presentation/screens/calories/calories_settings_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/data/notification_settings.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';
import 'package:shoply/presentation/widgets/design/picker_row.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';

import '../../layout/layout_matrix.dart';
import '../profile/settings/settings_test_helpers.dart';

final _goal = NutritionGoal(
  userId: 'u1',
  dailyCalorieTarget: 2000,
  createdAt: DateTime(2026, 11, 1),
  updatedAt: DateTime(2026, 11, 1),
);

List<Override> _overrides({
  CalorieGoalState goal = const CalorieGoalState(CalorieGoalStatus.none),
  FakeNotificationBackend? notifications,
  FakePermissionBackend? permission,
  FakeExternalActions? actions,
}) => [
  ...settingsOverrides(
    notifications: notifications,
    permission: permission,
    actions: actions,
    modules: FakeModuleStore(exampleModules(calories: true)),
  ),
  calorieGoalStateProvider.overrideWith((ref) => goal),
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('goal value, the reminder on by default with its time', (
    tester,
  ) async {
    await pumpSettings(
      tester,
      const CaloriesSettingsScreen(),
      overrides: _overrides(
        goal: CalorieGoalState(CalorieGoalStatus.set, _goal),
      ),
    );
    expect(find.text('Calories & Health'), findsOneWidget);
    expect(find.text('Goals'), findsOneWidget);
    expect(find.text('2,000 kcal'), findsOneWidget);
    expect(find.text('Dinner ideas'), findsOneWidget);
    expect(
      find.text("Daily at 6:00 PM if there's budget left"),
      findsOneWidget,
    );
    expect(tester.widget<ToggleRow>(find.byType(ToggleRow)).value, isTrue);
    expect(find.byType(PickerRow), findsOneWidget);
    expect(find.byType(StatusRow), findsNothing);
  });

  testWidgets('without a goal the row says so', (tester) async {
    await pumpSettings(
      tester,
      const CaloriesSettingsScreen(),
      overrides: _overrides(),
    );
    expect(find.text('Not set'), findsOneWidget);
  });

  testWidgets('the switch and the time are the ones of Mitteilungen', (
    tester,
  ) async {
    final backend = FakeNotificationBackend();
    final container = await pumpSettings(
      tester,
      const CaloriesSettingsScreen(),
      overrides: _overrides(notifications: backend),
    );
    await tester.tap(find.text('Time'));
    await settle(tester);
    expect(tester.widget<PickerRow>(find.byType(PickerRow)).expanded, isTrue);

    await tester.tap(find.text('Dinner ideas'));
    await settle(tester);
    expect(backend.values[NotificationSetting.dinnerIdeas], isFalse);
    expect(find.byType(PickerRow), findsNothing);

    await container
        .read(notificationSettingsProvider.notifier)
        .setTime(NotificationTimeSlot.dinnerIdeas, const ReminderTime(19, 30));
    await container
        .read(notificationSettingsProvider.notifier)
        .setEnabled(NotificationSetting.dinnerIdeas, true);
    await settle(tester);
    expect(
      find.text("Daily at 7:30 PM if there's budget left"),
      findsOneWidget,
    );
  });

  testWidgets('switching on asks for the permission only then', (tester) async {
    final permission = FakePermissionBackend(
      NotificationPermissionState.notAsked,
      afterRequest: NotificationPermissionState.allowed,
    );
    final backend = FakeNotificationBackend()
      ..values[NotificationSetting.dinnerIdeas] = false;
    await pumpSettings(
      tester,
      const CaloriesSettingsScreen(),
      overrides: _overrides(notifications: backend, permission: permission),
    );
    expect(permission.requests, 0);
    await tester.tap(find.text('Dinner ideas'));
    await settle(tester);
    expect(permission.requests, 1);
    expect(backend.values[NotificationSetting.dinnerIdeas], isTrue);
  });

  testWidgets('notifications denied in iOS: status, the switch stays off', (
    tester,
  ) async {
    final actions = FakeExternalActions();
    await pumpSettings(
      tester,
      const CaloriesSettingsScreen(),
      overrides: _overrides(
        permission: FakePermissionBackend(NotificationPermissionState.denied),
        actions: actions,
      ),
    );
    expect(find.text('Notifications are off in iOS.'), findsOneWidget);
    final toggle = tester.widget<ToggleRow>(find.byType(ToggleRow));
    expect(toggle.value, isFalse);
    expect(toggle.enabled, isFalse);
    expect(find.byType(PickerRow), findsNothing);
    await tester.tap(find.text('Settings'));
    await settle(tester);
    expect(actions.appSettings, 1);
  });

  testWidgets('Avo notifications off: status with a way to Mitteilungen', (
    tester,
  ) async {
    await pumpSettings(
      tester,
      const CaloriesSettingsScreen(),
      overrides: _overrides(
        notifications: FakeNotificationBackend(master: false),
      ),
    );
    expect(find.text('Notifications from Avo are off.'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(tester.widget<ToggleRow>(find.byType(ToggleRow)).enabled, isFalse);
  });

  testWidgets('"Goals" opens /settings/health/goals', (tester) async {
    await loadLayoutFonts();
    final router = GoRouter(
      initialLocation: '/settings/health',
      routes: [
        GoRoute(
          path: '/settings/health',
          builder: (context, state) => const CaloriesSettingsScreen(),
        ),
        GoRoute(
          path: '/settings/health/goals',
          builder: (context, state) => const Text('goals page'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Goals'));
    await settle(tester);
    expect(find.text('goals page'), findsOneWidget);
  });
}

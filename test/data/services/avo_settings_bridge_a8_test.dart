// A8 keys of AvoSettingsBridge (Konzept 18 §5, a8-stand.md "Von Teil B"):
// lists, recipes, start list, notifications and their times, modules; no
// accent colour any more (K-06).
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/services/avo_settings_bridge.dart';
import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/screens/lists/widgets/all_lists_data.dart';
import 'package:shoply/presentation/screens/profile/settings/data/list_preferences.dart';
import 'package:shoply/presentation/screens/profile/settings/data/notification_settings.dart';
import 'package:shoply/presentation/screens/profile/settings/data/profile_settings.dart';

import '../../screens/profile/settings/settings_test_helpers.dart';

ShoppingListModel _list(String id, String name) => ShoppingListModel(
  id: id,
  name: name,
  ownerId: 'u1',
  createdAt: DateTime(2026, 10, 1),
  updatedAt: DateTime(2026, 11, 7),
);

Future<(AvoSettingsBridge, ProviderContainer)> _bridge(
  WidgetTester tester, {
  FakeNotificationBackend? notifications,
  FakeModuleStore? modules,
  bool killSwitch = false,
}) async {
  late WidgetRef captured;
  final container = await pumpSettings(
    tester,
    Consumer(
      builder: (context, ref, _) {
        captured = ref;
        return const SizedBox.shrink();
      },
    ),
    overrides: [
      ...settingsOverrides(
        notifications: notifications,
        modules: modules,
        killSwitch: killSwitch,
        lists: [_list('w', 'Wocheneinkauf'), _list('g', 'Grillabend')],
      ),
      offersKillSwitchOffProvider.overrideWithValue(killSwitch),
    ],
  );
  return (AvoSettingsBridge(captured), container);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the A8 keys are supported, accent_color is gone', () {
    final keys = AvoSettingsBridge.supportedKeys;
    for (final key in [
      'recipes_auto_adapt',
      'show_item_images',
      'suggestions_enabled',
      'start_list',
      'keep_screen_on',
      'share_presence',
      'notif_dinner_ideas',
      'notif_time_restock',
      'notif_time_dinner',
      'module_calories',
      'module_cost_split',
    ]) {
      expect(keys, contains(key), reason: key);
    }
    expect(keys, isNot(contains('accent_color')));
    // Unreleased modules have no key.
    expect(keys, isNot(contains('module_meal_plan')));
    expect(
      AvoSettingsBridge.notificationKeys.values.toSet(),
      NotificationSetting.values.toSet(),
    );
  });

  testWidgets('accent_color is an unknown setting', (tester) async {
    final (bridge, _) = await _bridge(tester);
    final r = await bridge.update('accent_color', '#1F7A3A');
    expect(r.success, isFalse);
    expect(r.error, contains('Unknown setting'));
  });

  testWidgets('list switches write listPreferencesProvider', (tester) async {
    final (bridge, container) = await _bridge(tester);
    final r = await bridge.update('show_item_images', false);
    expect(r.success, isTrue);
    expect(r.oldValue, 'on');
    expect(r.newValue, 'off');
    expect(r.labelKey, 'avo_setkey_show_item_images');
    await bridge.update('suggestions_enabled', 'aus');
    await bridge.update('keep_screen_on', 'false');
    await bridge.update('share_presence', 0);
    final prefs = container.read(listPreferencesProvider);
    expect(prefs.showItemImages, isFalse);
    expect(prefs.suggestions, isFalse);
    expect(prefs.keepScreenOn, isFalse);
    expect(prefs.sharePresence, isFalse);
    final bad = await bridge.update('keep_screen_on', 'vielleicht');
    expect(bad.success, isFalse);
  });

  testWidgets('recipes_auto_adapt writes recipeAutoAdaptProvider', (
    tester,
  ) async {
    final (bridge, container) = await _bridge(tester);
    await bridge.update('recipes_auto_adapt', false);
    expect(container.read(recipeAutoAdaptProvider), isFalse);
  });

  testWidgets('start_list pins a list by name and back to the last one', (
    tester,
  ) async {
    final (bridge, container) = await _bridge(tester);
    final r = await bridge.update('start_list', 'grillabend');
    expect(r.success, isTrue);
    expect(r.newValue, 'Grillabend');
    expect(container.read(pinnedListProvider).listId, 'g');
    final back = await bridge.update('start_list', 'last');
    expect(back.oldValue, 'Grillabend');
    expect(container.read(pinnedListProvider).listId, isNull);
    final missing = await bridge.update('start_list', 'Party');
    expect(missing.success, isFalse);
    expect(missing.error, contains('Wocheneinkauf'));
  });

  testWidgets('notification switches and times go through '
      'notificationSettingsProvider', (tester) async {
    final backend = FakeNotificationBackend();
    final (bridge, container) = await _bridge(tester, notifications: backend);
    await bridge.update('notif_dinner_ideas', false);
    expect(backend.values[NotificationSetting.dinnerIdeas], isFalse);
    expect(
      container
          .read(notificationSettingsProvider)
          .isOn(NotificationSetting.dinnerIdeas),
      isFalse,
    );
    final time = await bridge.update('notif_time_dinner', '19:30');
    expect(time.oldValue, '18:00');
    expect(time.newValue, '19:30');
    expect(
      backend.times[NotificationTimeSlot.dinnerIdeas],
      const ReminderTime(19, 30),
    );
    final bad = await bridge.update('notif_time_restock', '25:00');
    expect(bad.success, isFalse);
  });

  testWidgets('module keys switch the module', (tester) async {
    final store = FakeModuleStore(exampleModules());
    final (bridge, container) = await _bridge(tester, modules: store);
    final r = await bridge.update('module_calories', true);
    expect(r.success, isTrue);
    expect(container.read(moduleEnabledProvider(AppModule.calories)), isTrue);
    expect(store.local?['calories'], isTrue);
  });

  testWidgets('module_offers fails while the kill switch is on', (
    tester,
  ) async {
    final (bridge, container) = await _bridge(tester, killSwitch: true);
    final r = await bridge.update('module_offers', false);
    expect(r.success, isFalse);
    expect(container.read(moduleEnabledProvider(AppModule.offers)), isTrue);
  });

  testWidgets('module_offers works without the kill switch', (tester) async {
    final (bridge, container) = await _bridge(tester);
    final r = await bridge.update('module_offers', false);
    expect(r.success, isTrue);
    expect(container.read(moduleEnabledProvider(AppModule.offers)), isFalse);
  });

  testWidgets('currentValue reads what update wrote, so undo can tell a '
      'value the person changed since', (tester) async {
    final (bridge, _) = await _bridge(tester);
    for (final (key, value) in [
      ('show_item_images', 'off'),
      ('keep_screen_on', 'on'),
      ('notif_dinner_ideas', 'off'),
      ('notif_time_dinner', '19:15'),
      ('start_list', 'Grillabend'),
      ('module_calories', 'off'),
    ]) {
      final result = await bridge.update(key, value);
      expect(result.success, isTrue, reason: key);
      expect(AvoSettingsBridge.isA8Key(key), isTrue, reason: key);
      expect(bridge.currentValue(key), result.newValue, reason: key);
    }
    // "Widerrufen" of the start list goes back to the last used list.
    final back = await bridge.update('start_list', 'last used list');
    expect(back.success, isTrue);
    expect(bridge.currentValue('start_list'), 'last used list');
    expect(AvoSettingsBridge.isA8Key('theme_mode'), isFalse);
    expect(bridge.currentValue('theme_mode'), isNull);
  });
}

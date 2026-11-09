import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/models/user_model.dart';
import 'package:shoply/data/services/mascot_notification_service.dart';
import 'package:shoply/data/services/notification_preferences_service.dart';
import 'package:shoply/data/services/user_location_service.dart';
import 'package:shoply/data/services/user_service.dart';
import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/screens/lists/widgets/all_lists_data.dart';
import 'package:shoply/presentation/screens/profile/settings/data/list_preferences.dart';
import 'package:shoply/presentation/screens/profile/settings/data/notification_settings.dart';
import 'package:shoply/presentation/screens/profile/settings/data/profile_settings.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/language_provider.dart';
import 'package:shoply/presentation/state/theme_provider.dart';

/// Result of a single setting change, used for UI confirmation cards.
class SettingChangeResult {
  final bool success;
  final String key;
  final String displayName;
  final String? oldValue;
  final String newValue;
  final String? error;

  /// Translation key of the setting's name on the answer card; null shows
  /// [displayName] (the English name the model reads).
  final String? labelKey;

  const SettingChangeResult({
    required this.success,
    required this.key,
    required this.displayName,
    required this.newValue,
    this.oldValue,
    this.error,
    this.labelKey,
  });

  Map<String, Object?> toJson() => {
        'success': success,
        'key': key,
        'display_name': displayName,
        'old_value': oldValue,
        'new_value': newValue,
        if (error != null) 'error': error,
      };
}

/// Thin wrapper that lets Avo's tool layer read and mutate every
/// user-configurable setting in the app.
///
/// Takes a Riverpod [Ref] so writes flow through StateNotifiers and
/// trigger UI rebuilds immediately.
class AvoSettingsBridge {
  final WidgetRef ref;
  AvoSettingsBridge(this.ref);

  /// Switches of Einstellungen › Mitteilungen, by key (`notif_<name>`).
  static const notificationKeys = <String, NotificationSetting>{
    'notif_shopping_started': NotificationSetting.shoppingStarted,
    'notif_list_changes': NotificationSetting.listChanges,
    'notif_shopping_completed': NotificationSetting.shoppingCompleted,
    'notif_invitations': NotificationSetting.invitations,
    'notif_restock': NotificationSetting.restock,
    'notif_cooking_timer': NotificationSetting.cookingTimer,
    'notif_plan_reminder': NotificationSetting.planReminder,
    'notif_dinner_ideas': NotificationSetting.dinnerIdeas,
    'notif_cost_split_open': NotificationSetting.costSplitOpen,
    'notif_recipe_likes': NotificationSetting.recipeLikes,
    'notif_recipe_comments': NotificationSetting.recipeComments,
    'notif_new_recipes': NotificationSetting.newRecipes,
  };

  /// Reminder times ("H:MM") of Einstellungen › Mitteilungen.
  static const notificationTimeKeys = <String, NotificationTimeSlot>{
    'notif_time_restock': NotificationTimeSlot.restock,
    'notif_time_dinner': NotificationTimeSlot.dinnerIdeas,
  };

  /// Switches of Einstellungen › Listen and Ernährung (A8, Konzept 18 §5).
  static const _flagKeys = <String>[
    'recipes_auto_adapt',
    'show_item_images',
    'suggestions_enabled',
    'keep_screen_on',
    'share_presence',
  ];

  /// `module_<id>` for every released module (`module_calories`, …); the
  /// same switch as Einstellungen › Module and the `set_module` tool.
  static String moduleKey(AppModule module) => 'module_${module.storageKey}';

  /// Supported setting keys. The `update_setting` tool schema
  /// (`supabase/functions/_shared/avo_tools.ts`, `SETTING_KEYS`) offers all
  /// of them except the module keys, which Avo switches with `set_module`.
  static final supportedKeys = <String>[
    'theme_mode',
    'language',
    'notifications',
    'display_name',
    'diet_add',
    'diet_remove',
    'allergies_add',
    'allergies_remove',
    'age',
    'gender',
    'height_cm',
    'zip_code',
    ..._flagKeys,
    'start_list',
    ...notificationKeys.keys,
    ...notificationTimeKeys.keys,
    for (final m in AppModule.values)
      if (m.released) moduleKey(m),
  ];

  /// Apply a settings change. Returns a structured result suitable for
  /// both the LLM function response and a confirmation widget.
  Future<SettingChangeResult> update(String key, Object? value) async {
    try {
      switch (key) {
        case 'theme_mode':
          return await _setThemeMode(value);
        case 'language':
          return await _setLanguage(value);
        case 'notifications':
          return await _setNotifications(value);
        case 'zip_code':
        case 'zip':
        case 'plz':
          return await _setZipCode(value);
        case 'display_name':
        case 'name':
          return await _updateUserField(
            key: 'display_name',
            displayName: 'Name',
            newValue: value?.toString() ?? '',
            apply: (u, v) => u.copyWith(displayName: v),
            readCurrent: (u) => u.displayName,
          );
        case 'diet_add':
        case 'diet_remove':
          return await _changeListEntry(
            key: key,
            displayName: 'Diet preferences',
            entry: value,
            add: key == 'diet_add',
            apply: (u, list) => u.copyWith(dietPreferences: list),
            readCurrent: (u) => u.dietPreferences,
          );
        case 'allergies_add':
        case 'allergies_remove':
          return await _changeListEntry(
            key: key,
            displayName: 'Allergies',
            entry: value,
            add: key == 'allergies_add',
            apply: (u, list) => u.copyWith(allergies: list),
            readCurrent: (u) => u.allergies,
          );
        case 'age':
          final age = value is int ? value : int.tryParse('$value');
          if (age == null || age < 1 || age > 120) {
            return SettingChangeResult(
              success: false,
              key: key,
              displayName: 'Age',
              newValue: '$value',
              error: 'Age must be between 1 and 120',
            );
          }
          return await _updateUserField(
            key: 'age',
            displayName: 'Age',
            newValue: '$age',
            apply: (u, v) => u.copyWith(age: int.parse(v)),
            readCurrent: (u) => u.age?.toString(),
          );
        case 'gender':
          final g = value?.toString().toLowerCase();
          const valid = {'male', 'female', 'other', 'prefer_not_to_say'};
          if (g == null || !valid.contains(g)) {
            return SettingChangeResult(
              success: false,
              key: key,
              displayName: 'Gender',
              newValue: '$value',
              error: 'Gender must be one of: ${valid.join(', ')}',
            );
          }
          return await _updateUserField(
            key: 'gender',
            displayName: 'Gender',
            newValue: g,
            apply: (u, v) => u.copyWith(gender: v),
            readCurrent: (u) => u.gender,
          );
        case 'height':
        case 'height_cm':
          final h = value is num ? value.toDouble() : double.tryParse('$value');
          if (h == null || h < 50 || h > 300) {
            return SettingChangeResult(
              success: false,
              key: key,
              displayName: 'Height',
              newValue: '$value',
              error: 'Height must be between 50 and 300 cm',
            );
          }
          return await _updateUserField(
            key: 'height',
            displayName: 'Height',
            newValue: '${h.round()} cm',
            apply: (u, v) => u.copyWith(height: double.parse(v.split(' ').first)),
            readCurrent: (u) =>
                u.height == null ? null : '${u.height!.round()} cm',
          );
        case 'recipes_auto_adapt':
          return await _setFlag(
            key: key,
            displayName: 'Adapt recipes automatically',
            value: value,
            current: ref.read(recipeAutoAdaptProvider),
            write: (on) => ref.read(recipeAutoAdaptProvider.notifier).set(on),
          );
        case 'show_item_images':
          return await _setListPreference(
            key,
            'Item images',
            value,
            read: (p) => p.showItemImages,
            apply: (p, on) => p.copyWith(showItemImages: on),
          );
        case 'suggestions_enabled':
          return await _setListPreference(
            key,
            'Suggestions at the end of a list',
            value,
            read: (p) => p.suggestions,
            apply: (p, on) => p.copyWith(suggestions: on),
          );
        case 'keep_screen_on':
          return await _setListPreference(
            key,
            'Keep the screen on while shopping',
            value,
            read: (p) => p.keepScreenOn,
            apply: (p, on) => p.copyWith(keepScreenOn: on),
          );
        case 'share_presence':
          return await _setListPreference(
            key,
            'Show others that I am shopping',
            value,
            read: (p) => p.sharePresence,
            apply: (p, on) => p.copyWith(sharePresence: on),
          );
        case 'start_list':
          return await _setStartList(value);
        default:
          final setting = notificationKeys[key];
          if (setting != null) return await _setNotification(key, setting, value);
          final slot = notificationTimeKeys[key];
          if (slot != null) return await _setNotificationTime(key, slot, value);
          final module = _moduleOfKey(key);
          if (module != null) return await _setModule(key, module, value);
          return SettingChangeResult(
            success: false,
            key: key,
            displayName: key,
            newValue: '$value',
            error:
                'Unknown setting "$key". Supported: ${supportedKeys.join(', ')}',
          );
      }
    } catch (e) {
      return SettingChangeResult(
        success: false,
        key: key,
        displayName: key,
        newValue: '$value',
        error: e.toString(),
      );
    }
  }

  // ── Individual handlers ─────────────────────────────────────────────

  Future<SettingChangeResult> _setThemeMode(Object? value) async {
    final v = value?.toString().toLowerCase().trim();
    ThemeMode? mode;
    switch (v) {
      case 'light':
        mode = ThemeMode.light;
        break;
      case 'dark':
        mode = ThemeMode.dark;
        break;
      case 'system':
      case 'auto':
        mode = ThemeMode.system;
        break;
    }
    if (mode == null) {
      return SettingChangeResult(
        success: false,
        key: 'theme_mode',
        displayName: 'Theme',
        newValue: '$value',
        error: 'Theme must be "light", "dark", or "system"',
      );
    }
    final current = ref.read(themeModeProvider);
    await ref.read(themeModeProvider.notifier).setThemeMode(mode);
    return SettingChangeResult(
      success: true,
      key: 'theme_mode',
      displayName: 'Theme',
      oldValue: _themeModeLabel(current),
      newValue: _themeModeLabel(mode),
    );
  }

  Future<SettingChangeResult> _setLanguage(Object? value) async {
    final v = value?.toString().toLowerCase().trim();
    if (v != 'en' && v != 'de' && v != 'system') {
      return SettingChangeResult(
        success: false,
        key: 'language',
        displayName: 'Language',
        newValue: '$value',
        error: 'Language must be "en", "de", or "system"',
      );
    }
    final current = ref.read(languageProvider.notifier).savedSetting;
    await ref.read(languageProvider.notifier).setLanguage(v!);
    return SettingChangeResult(
      success: true,
      key: 'language',
      displayName: 'Language',
      oldValue: _languageLabel(current),
      newValue: _languageLabel(v),
    );
  }

  Future<SettingChangeResult> _setNotifications(Object? value) async {
    final enabled = _parseBool(value);
    if (enabled == null) {
      return SettingChangeResult(
        success: false,
        key: 'notifications',
        displayName: 'Notifications',
        newValue: '$value',
        error: 'Notifications must be true or false',
      );
    }
    final result = await _updateUserField(
      key: 'notifications',
      displayName: 'Notifications',
      newValue: enabled ? 'on' : 'off',
      apply: (u, v) => u.copyWith(notificationEnabled: v == 'on'),
      readCurrent: (u) => u.notificationEnabled ? 'on' : 'off',
    );
    if (result.success) {
      // The DB row is already updated; mirror the enforced local gate
      // (SharedPreferences cache + FCM token) and Avo's scheduled reminder.
      await NotificationPreferencesService.instance
          .applyMasterChangedRemotely(enabled);
      await MascotNotificationService.instance
          .rearmRestockReminder(force: true);
      await MascotNotificationService.instance
          .rearmDinnerIdeasReminder(force: true);
    }
    return result;
  }

    Future<SettingChangeResult> _setZipCode(Object? value) async {
    final zip = value?.toString().trim() ?? '';
    // Empty clears the manual override; otherwise a 4-5 digit PLZ
    // (Germany uses 5, Austria 4 — same data the offer search expects).
    if (zip.isNotEmpty && !RegExp(r'^\d{4,5}$').hasMatch(zip)) {
      return SettingChangeResult(
        success: false,
        key: 'zip_code',
        displayName: 'Zip code',
        newValue: zip,
        error: 'Zip code must be 4-5 digits (or empty to clear it)',
      );
    }
    final current = await UserLocationService.instance.getManualZipCode();
    // regionProvider follows UserLocationService.changes on its own.
    await UserLocationService.instance.setManualZipCode(zip);
    return SettingChangeResult(
      success: true,
      key: 'zip_code',
      displayName: 'Zip code',
      oldValue: current ?? 'none',
      newValue: zip.isEmpty ? 'none' : zip,
    );
  }

  Future<SettingChangeResult> _updateUserField({
    required String key,
    required String displayName,
    required String newValue,
    required UserModel Function(UserModel user, String value) apply,
    required String? Function(UserModel user) readCurrent,
  }) async {
    final user = await ref.read(currentUserProvider.future);
    if (user == null) {
      return SettingChangeResult(
        success: false,
        key: key,
        displayName: displayName,
        newValue: newValue,
        error: 'Not signed in',
      );
    }
    final oldValue = readCurrent(user);
    final updated = apply(user, newValue);
    await UserService().updateUserProfile(updated);
    // Force the profile provider to refetch so UI rebuilds.
    ref.invalidate(currentUserProvider);
    return SettingChangeResult(
      success: true,
      key: key,
      displayName: displayName,
      oldValue: oldValue,
      newValue: newValue,
    );
  }

  /// Adds or removes one entry of a list setting (allergies, diet), never
  /// the whole list: one wrong word from Avo can't wipe someone's allergies.
  Future<SettingChangeResult> _changeListEntry({
    required String key,
    required String displayName,
    required Object? entry,
    required bool add,
    required UserModel Function(UserModel user, List<String> list) apply,
    required List<String> Function(UserModel user) readCurrent,
  }) async {
    final value = entry?.toString().trim() ?? '';
    if (value.isEmpty) {
      return SettingChangeResult(
        success: false,
        key: key,
        displayName: displayName,
        newValue: '',
        error: 'value must name one entry',
      );
    }
    final user = await ref.read(currentUserProvider.future);
    if (user == null) {
      return SettingChangeResult(
        success: false,
        key: key,
        displayName: displayName,
        newValue: value,
        error: 'Not signed in',
      );
    }
    final current = readCurrent(user);
    bool same(String a) => a.trim().toLowerCase() == value.toLowerCase();
    final next = add
        ? (current.any(same) ? current : [...current, value])
        : current.where((e) => !same(e)).toList();
    if (!add && next.length == current.length) {
      return SettingChangeResult(
        success: false,
        key: key,
        displayName: displayName,
        newValue: value,
        error: '"$value" is not in the list',
      );
    }
    await UserService().updateUserProfile(apply(user, next));
    ref.invalidate(currentUserProvider);
    return SettingChangeResult(
      success: true,
      key: key,
      displayName: displayName,
      oldValue: current.isEmpty ? 'none' : current.join(', '),
      newValue: next.isEmpty ? 'none' : next.join(', '),
    );
  }

  // ── A8 keys: lists, recipes, notifications, modules ───────────────

  /// The card's name of [key] (`avo_setkey_<key>`).
  static String labelKeyOf(String key) => 'avo_setkey_$key';

  SettingChangeResult _invalidBool(String key, String displayName, Object? v) =>
      SettingChangeResult(
        success: false,
        key: key,
        displayName: displayName,
        newValue: '$v',
        error: '$key must be true or false',
      );

  Future<SettingChangeResult> _setFlag({
    required String key,
    required String displayName,
    required Object? value,
    required bool current,
    required Future<void> Function(bool on) write,
  }) async {
    final on = _parseBool(value);
    if (on == null) return _invalidBool(key, displayName, value);
    await write(on);
    return SettingChangeResult(
      success: true,
      key: key,
      displayName: displayName,
      oldValue: _onOff(current),
      newValue: _onOff(on),
      labelKey: labelKeyOf(key),
    );
  }

  Future<SettingChangeResult> _setListPreference(
    String key,
    String displayName,
    Object? value, {
    required bool Function(ListPreferences p) read,
    required ListPreferences Function(ListPreferences p, bool on) apply,
  }) {
    final prefs = ref.read(listPreferencesProvider);
    return _setFlag(
      key: key,
      displayName: displayName,
      value: value,
      current: read(prefs),
      write: (on) => ref
          .read(listPreferencesProvider.notifier)
          .update(apply(ref.read(listPreferencesProvider), on)),
    );
  }

  /// "Liste beim Start": a list by name or id, or the last used one
  /// (`last`, empty).
  Future<SettingChangeResult> _setStartList(Object? value) async {
    const key = 'start_list';
    const displayName = 'List at start';
    final wanted = value?.toString().trim() ?? '';
    final lists = ref.read(allListsSourceProvider).valueOrNull ?? const [];
    final pinnedId = ref.read(pinnedListProvider).listId;
    String nameOf(String? id) =>
        lists.where((l) => l.id == id).firstOrNull?.name ?? 'last used list';
    final last = wanted.isEmpty ||
        const {'last', 'last used list', 'zuletzt', 'none', 'null'}.contains(wanted.toLowerCase());
    final match = last
        ? null
        : lists
              .where(
                (l) =>
                    l.id == wanted ||
                    l.name.trim().toLowerCase() == wanted.toLowerCase(),
              )
              .firstOrNull;
    if (!last && match == null) {
      return SettingChangeResult(
        success: false,
        key: key,
        displayName: displayName,
        newValue: wanted,
        error: 'No list "$wanted". Lists: '
            '${lists.map((l) => l.name).join(', ')}; or "last" for the list '
            'used last',
      );
    }
    final old = pinnedId == null ? 'last used list' : nameOf(pinnedId);
    await ref.read(pinnedListProvider.notifier).pin(match?.id);
    return SettingChangeResult(
      success: true,
      key: key,
      displayName: displayName,
      oldValue: old,
      newValue: match?.name ?? 'last used list',
      labelKey: labelKeyOf(key),
    );
  }

  Future<SettingChangeResult> _setNotification(
    String key,
    NotificationSetting setting,
    Object? value,
  ) {
    final state = ref.read(notificationSettingsProvider);
    return _setFlag(
      key: key,
      displayName: 'Notifications: ${setting.name}',
      value: value,
      current: state.isOn(setting),
      write: (on) => ref
          .read(notificationSettingsProvider.notifier)
          .setEnabled(setting, on),
    );
  }

  Future<SettingChangeResult> _setNotificationTime(
    String key,
    NotificationTimeSlot slot,
    Object? value,
  ) async {
    final displayName = 'Reminder time: ${slot.name}';
    final time = ReminderTime.parse(value?.toString().trim());
    if (time == null) {
      return SettingChangeResult(
        success: false,
        key: key,
        displayName: displayName,
        newValue: '$value',
        error: '$key must be a time like "18:30"',
      );
    }
    final current = ref.read(notificationSettingsProvider).timeOf(slot);
    await ref.read(notificationSettingsProvider.notifier).setTime(slot, time);
    return SettingChangeResult(
      success: true,
      key: key,
      displayName: displayName,
      oldValue: current.storage,
      newValue: time.storage,
      labelKey: labelKeyOf(key),
    );
  }

  static AppModule? _moduleOfKey(String key) {
    for (final m in AppModule.values) {
      if (moduleKey(m) == key) return m;
    }
    return null;
  }

  Future<SettingChangeResult> _setModule(
    String key,
    AppModule module,
    Object? value,
  ) async {
    final displayName = 'Module ${module.storageKey}';
    final killSwitch =
        module == AppModule.offers && ref.read(offersKillSwitchOffProvider);
    if (!module.released || killSwitch) {
      return SettingChangeResult(
        success: false,
        key: key,
        displayName: displayName,
        newValue: '$value',
        error: 'This module is not available',
      );
    }
    return _setFlag(
      key: key,
      displayName: displayName,
      value: value,
      current: ref.read(moduleEnabledProvider(module)),
      write: (on) =>
          ref.read(appModulesProvider.notifier).setEnabled(module, on),
    );
  }

  static String _onOff(bool on) => on ? 'on' : 'off';

  // ── Helpers ─────────────────────────────────────────────────────────

  static bool? _parseBool(Object? v) {
    if (v is bool) return v;
    final s = v?.toString().toLowerCase().trim();
    const yes = {'true', 'on', 'yes', 'enable', 'enabled', '1', 'an', 'ja'};
    const no = {'false', 'off', 'no', 'disable', 'disabled', '0', 'aus', 'nein'};
    if (yes.contains(s)) return true;
    if (no.contains(s)) return false;
    return null;
  }

  static String _themeModeLabel(ThemeMode m) => switch (m) {
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
        ThemeMode.system => 'System',
      };

  static String _languageLabel(String code) => switch (code) {
        'en' => 'English',
        'de' => 'German',
        'system' => 'System',
        _ => code,
      };
}

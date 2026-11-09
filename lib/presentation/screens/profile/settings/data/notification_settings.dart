import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/data/services/mascot_notification_service.dart';
import 'package:shoply/data/services/notification_permission_service.dart';
import 'package:shoply/data/services/notification_preferences_service.dart';
import 'package:shoply/data/services/notification_service.dart';
import 'package:shoply/presentation/state/auth_provider.dart';

/// One switch of Einstellungen › Mitteilungen (Konzept 18 §5.5, K18-06).
///
/// Every switch is a [NotificationCategory]: the app checks it wherever it
/// shows or plans a notification ([NotificationPreferencesService]). Pushes
/// the server sends while the app is closed still need the account copy
/// (`user_notification_prefs`). A switch without a category would be stored
/// under its own `key`.
enum NotificationSetting {
  /// "Jemand kauft ein" (`shopping_started`).
  shoppingStarted(category: NotificationCategory.shoppingStarted),

  /// "Änderungen an Listen", bundled (K-39).
  listChanges(category: NotificationCategory.listActivity),

  /// "Einkauf abgeschlossen".
  shoppingCompleted(category: NotificationCategory.shoppingCompleted),

  /// "Einladungen und neue Mitglieder".
  invitations(category: NotificationCategory.listInvitations),

  /// "Nachkauf-Erinnerung" (Avo's restock reminder).
  restock(category: NotificationCategory.avoNudges),

  /// "Kochtimer" (time-sensitive).
  cookingTimer(category: NotificationCategory.cookingTimer),

  /// Wochenplan: "An die nächste Woche erinnern" (default off).
  planReminder(category: NotificationCategory.planReminder),

  /// Kalorien: "Ideen fürs Abendessen".
  dinnerIdeas(category: NotificationCategory.dinnerIdeas),

  /// Kosten teilen: "Offene Beträge".
  costSplitOpen(category: NotificationCategory.costSplitOpen),

  /// "Bewertungen und Likes".
  recipeLikes(category: NotificationCategory.recipeLikes),

  /// "Kommentare".
  recipeComments(category: NotificationCategory.recipeComments),

  /// "Neue Rezepte von Erstellern, denen du folgst" (default off).
  newRecipes(category: NotificationCategory.newRecipes);

  const NotificationSetting({this.category, String? key, bool? defaultOn})
    : _key = key,
      _defaultOn = defaultOn;

  /// The enforced category behind this switch, if there is one.
  final NotificationCategory? category;
  final String? _key;
  final bool? _defaultOn;

  /// Device storage key (the category's key for enforced categories).
  String get prefsKey => category?.prefsKey ?? _key!;

  /// Value when nothing is stored.
  bool get defaultOn => category?.defaultValue ?? _defaultOn ?? true;
}

/// A time a reminder fires at (Konzept 18 §5.5 "Uhrzeiten wählbar").
enum NotificationTimeSlot {
  /// Nachkauf-Erinnerung, 9:00.
  restock('setp_notif_time_restock', 9, 0),

  /// Kalorien "Ideen fürs Abendessen", 18:00.
  dinnerIdeas('setp_notif_time_dinner', 18, 0);

  const NotificationTimeSlot(
    this.prefsKey,
    this.defaultHour,
    this.defaultMinute,
  );

  /// Device storage key ("9:00").
  final String prefsKey;
  final int defaultHour;
  final int defaultMinute;
}

/// A time of day without Material's `TimeOfDay`.
@immutable
class ReminderTime {
  /// Creates a time.
  const ReminderTime(this.hour, this.minute);

  final int hour;
  final int minute;

  /// "9:00".
  String get storage => '$hour:${minute.toString().padLeft(2, '0')}';

  static ReminderTime? parse(String? raw) {
    final parts = raw?.split(':');
    if (parts == null || parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return ReminderTime(h, m);
  }

  @override
  bool operator ==(Object other) =>
      other is ReminderTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);
}

/// What Einstellungen › Mitteilungen shows.
@immutable
class NotificationSettings {
  /// Creates the state.
  const NotificationSettings({
    this.master = true,
    this.values = const {},
    this.times = const {},
    this.loaded = false,
  });

  /// "Mitteilungen von Avo", for the whole account.
  final bool master;

  /// Stored switches; missing ones are [NotificationSetting.defaultOn].
  final Map<NotificationSetting, bool> values;

  /// Stored times; missing ones are the slot's default.
  final Map<NotificationTimeSlot, ReminderTime> times;

  /// The stored values have been read.
  final bool loaded;

  bool isOn(NotificationSetting s) => values[s] ?? s.defaultOn;

  ReminderTime timeOf(NotificationTimeSlot slot) =>
      times[slot] ?? ReminderTime(slot.defaultHour, slot.defaultMinute);

  NotificationSettings copyWith({
    bool? master,
    Map<NotificationSetting, bool>? values,
    Map<NotificationTimeSlot, ReminderTime>? times,
    bool? loaded,
  }) => NotificationSettings(
    master: master ?? this.master,
    values: values ?? this.values,
    times: times ?? this.times,
    loaded: loaded ?? this.loaded,
  );
}

/// Reads and writes the notification choices. Overridden in tests.
abstract interface class NotificationSettingsBackend {
  /// Everything stored on the device.
  Future<NotificationSettings> load();

  /// The account's master switch after a server read (another device, Avo);
  /// null when it could not be read.
  Future<bool?> refreshMaster();

  /// The master switch: account, local cache and push token.
  Future<void> setMaster(bool on);

  Future<void> setEnabled(NotificationSetting setting, bool on);

  Future<void> setTime(NotificationTimeSlot slot, ReminderTime time);
}

/// The app's services: [NotificationPreferencesService] for the master
/// switch and the enforced categories, the device store for the rest, and
/// Avo's reminders planned anew after every change.
class DefaultNotificationSettingsBackend
    implements NotificationSettingsBackend {
  /// Creates the backend.
  const DefaultNotificationSettingsBackend();

  NotificationPreferencesService get _prefs =>
      NotificationPreferencesService.instance;

  @override
  Future<NotificationSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final master = await _prefs.isMasterEnabled();
    final values = <NotificationSetting, bool>{
      for (final s in NotificationSetting.values)
        if (prefs.getBool(s.prefsKey) case final v?) s: v,
    };
    final times = <NotificationTimeSlot, ReminderTime>{
      for (final slot in NotificationTimeSlot.values)
        if (ReminderTime.parse(prefs.getString(slot.prefsKey)) case final t?)
          slot: t,
    };
    return NotificationSettings(
      master: master,
      values: values,
      times: times,
      loaded: true,
    );
  }

  @override
  Future<bool?> refreshMaster() async {
    await _prefs.syncFromRemote();
    return _prefs.isMasterEnabled();
  }

  void _rearm() {
    final reminders = MascotNotificationService.instance;
    unawaited(reminders.rearmRestockReminder(force: true));
    unawaited(reminders.rearmDinnerIdeasReminder(force: true));
  }

  @override
  Future<void> setMaster(bool on) async {
    await _prefs.setMasterEnabled(on);
    _rearm();
  }

  @override
  Future<void> setEnabled(NotificationSetting setting, bool on) async {
    final category = setting.category;
    if (category != null) {
      await _prefs.setCategoryEnabled(category, on);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(setting.prefsKey, on);
    }
    if (setting == NotificationSetting.restock ||
        setting == NotificationSetting.dinnerIdeas) {
      _rearm();
    }
  }

  @override
  Future<void> setTime(NotificationTimeSlot slot, ReminderTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(slot.prefsKey, time.storage);
    _rearm();
  }
}

/// Where the notification choices live.
final notificationSettingsBackendProvider =
    Provider<NotificationSettingsBackend>(
      (ref) => const DefaultNotificationSettingsBackend(),
    );

/// Shows the stored choices at once (no spinner); a later server read of the
/// master switch replaces it unless it was changed here meanwhile.
class NotificationSettingsNotifier extends StateNotifier<NotificationSettings> {
  NotificationSettingsNotifier(this._backend)
    : super(const NotificationSettings()) {
    unawaited(_load());
  }

  final NotificationSettingsBackend _backend;
  bool _masterChanged = false;
  final Set<NotificationSetting> _changed = {};
  final Set<NotificationTimeSlot> _timesChanged = {};

  Future<void> _load() async {
    try {
      final stored = await _backend.load();
      if (!mounted) return;
      state = stored.copyWith(
        master: _masterChanged ? state.master : stored.master,
        values: {...stored.values, for (final s in _changed) s: state.isOn(s)},
        times: {
          ...stored.times,
          for (final t in _timesChanged) t: state.timeOf(t),
        },
        loaded: true,
      );
      final remote = await _backend.refreshMaster();
      if (!mounted || remote == null || _masterChanged) return;
      if (remote != state.master) state = state.copyWith(master: remote);
    } catch (e) {
      debugPrint('⚠️ [SETTINGS] Reading notification settings failed: $e');
      if (mounted && !state.loaded) state = state.copyWith(loaded: true);
    }
  }

  Future<void> setMaster(bool on) async {
    _masterChanged = true;
    state = state.copyWith(master: on);
    try {
      await _backend.setMaster(on);
    } catch (e) {
      debugPrint('⚠️ [SETTINGS] Saving notifications failed: $e');
    }
  }

  Future<void> setEnabled(NotificationSetting setting, bool on) async {
    _changed.add(setting);
    state = state.copyWith(values: {...state.values, setting: on});
    try {
      await _backend.setEnabled(setting, on);
    } catch (e) {
      debugPrint('⚠️ [SETTINGS] Saving ${setting.name} failed: $e');
    }
  }

  Future<void> setTime(NotificationTimeSlot slot, ReminderTime time) async {
    _timesChanged.add(slot);
    state = state.copyWith(times: {...state.times, slot: time});
    try {
      await _backend.setTime(slot, time);
    } catch (e) {
      debugPrint('⚠️ [SETTINGS] Saving ${slot.name} time failed: $e');
    }
  }
}

/// Einstellungen › Mitteilungen of the signed-in person.
final notificationSettingsProvider =
    StateNotifierProvider<NotificationSettingsNotifier, NotificationSettings>((
      ref,
    ) {
      ref.watch(authUserIdProvider);
      return NotificationSettingsNotifier(
        ref.watch(notificationSettingsBackendProvider),
      );
    });

// ------------------------------------------------------------- permission

/// What iOS allows (Konzept 18 §5.5 "iOS-Status").
enum NotificationPermissionState {
  /// Not read yet.
  unknown,

  /// The system prompt was never shown.
  notAsked,

  /// The person said no, or switched notifications off in iOS.
  denied,

  /// Allowed.
  allowed,
}

/// Reads and asks for the notification permission. Overridden in tests.
abstract interface class NotificationPermissionBackend {
  Future<NotificationPermissionState> status();

  /// Shows the system prompt when it was never shown; true when allowed
  /// afterwards.
  Future<bool> request();
}

/// [NotificationService] and [NotificationPermissionService] (the one place
/// that shows the prompt).
class DefaultNotificationPermissionBackend
    implements NotificationPermissionBackend {
  /// Creates the backend.
  const DefaultNotificationPermissionBackend();

  bool get _supported => Platform.isIOS || Platform.isAndroid;

  @override
  Future<NotificationPermissionState> status() async {
    if (!_supported) return NotificationPermissionState.unknown;
    if (await NotificationService.instance.hasPermission()) {
      return NotificationPermissionState.allowed;
    }
    final prefs = await SharedPreferences.getInstance();
    final asked =
        prefs.getBool(NotificationPermissionService.promptedKey) ?? false;
    return asked
        ? NotificationPermissionState.denied
        : NotificationPermissionState.notAsked;
  }

  @override
  Future<bool> request() =>
      NotificationPermissionService.instance.requestIfUseful('settings');
}

/// Where the permission is read.
final notificationPermissionBackendProvider =
    Provider<NotificationPermissionBackend>(
      (ref) => const DefaultNotificationPermissionBackend(),
    );

/// The permission, read on start and again by [refresh] (opening the page,
/// coming back from the iOS settings).
class NotificationPermissionNotifier
    extends StateNotifier<NotificationPermissionState> {
  NotificationPermissionNotifier(this._backend)
    : super(NotificationPermissionState.unknown) {
    unawaited(refresh());
  }

  final NotificationPermissionBackend _backend;

  Future<void> refresh() async {
    try {
      final next = await _backend.status();
      if (mounted && next != state) state = next;
    } catch (e) {
      debugPrint('⚠️ [SETTINGS] Reading the permission failed: $e');
    }
  }

  /// "Mitteilungen erlauben": the system prompt, then the new state.
  Future<void> request() async {
    try {
      await _backend.request();
    } catch (e) {
      debugPrint('⚠️ [SETTINGS] Asking for notifications failed: $e');
    }
    await refresh();
  }
}

/// The notification permission of this device. The profile row ("In iOS
/// aus") can watch it too.
final notificationPermissionProvider =
    StateNotifierProvider<
      NotificationPermissionNotifier,
      NotificationPermissionState
    >(
      (ref) => NotificationPermissionNotifier(
        ref.watch(notificationPermissionBackendProvider),
      ),
    );

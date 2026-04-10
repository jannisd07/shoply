import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show WidgetRef;
import 'package:shoply/data/models/user_model.dart';
import 'package:shoply/data/services/user_service.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/language_provider.dart';
import 'package:shoply/presentation/state/theme_provider.dart';
import 'package:shoply/presentation/state/user_profile_provider.dart';

/// Result of a single setting change, used for UI confirmation cards.
class SettingChangeResult {
  final bool success;
  final String key;
  final String displayName;
  final String? oldValue;
  final String newValue;
  final String? error;

  const SettingChangeResult({
    required this.success,
    required this.key,
    required this.displayName,
    required this.newValue,
    this.oldValue,
    this.error,
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

  /// Supported setting keys. Kept in sync with the `update_setting` tool
  /// schema in AvoAssistantService.
  static const supportedKeys = <String>[
    'theme_mode',
    'accent_color',
    'language',
    'notifications',
    'display_name',
    'diet_preferences',
    'allergies',
    'age',
    'gender',
    'height',
  ];

  /// Apply a settings change. Returns a structured result suitable for
  /// both the LLM function response and a confirmation widget.
  Future<SettingChangeResult> update(String key, Object? value) async {
    try {
      switch (key) {
        case 'theme_mode':
          return await _setThemeMode(value);
        case 'accent_color':
          return await _setAccentColor(value);
        case 'language':
          return await _setLanguage(value);
        case 'notifications':
          return await _setNotifications(value);
        case 'display_name':
        case 'name':
          return await _updateUserField(
            key: 'display_name',
            displayName: 'Name',
            newValue: value?.toString() ?? '',
            apply: (u, v) => u.copyWith(displayName: v),
            readCurrent: (u) => u.displayName,
          );
        case 'diet_preferences':
        case 'diet':
          return await _setListField(
            key: 'diet_preferences',
            displayName: 'Diet preferences',
            value: value,
            apply: (u, list) => u.copyWith(dietPreferences: list),
            readCurrent: (u) => u.dietPreferences,
          );
        case 'allergies':
          return await _setListField(
            key: 'allergies',
            displayName: 'Allergies',
            value: value,
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
        default:
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

  Future<SettingChangeResult> _setAccentColor(Object? value) async {
    final hex = value?.toString().replaceAll('#', '').trim() ?? '';
    if (hex.length != 6) {
      return SettingChangeResult(
        success: false,
        key: 'accent_color',
        displayName: 'Accent color',
        newValue: '$value',
        error: 'Accent color must be a 6-character hex like "007AFF"',
      );
    }
    final colorValue = int.tryParse('FF$hex', radix: 16);
    if (colorValue == null) {
      return SettingChangeResult(
        success: false,
        key: 'accent_color',
        displayName: 'Accent color',
        newValue: '$value',
        error: 'Invalid hex color',
      );
    }
    final newColor = Color(colorValue);
    final current = ref.read(accentColorProvider);
    await ref.read(accentColorProvider.notifier).setAccentColor(newColor);
    return SettingChangeResult(
      success: true,
      key: 'accent_color',
      displayName: 'Accent color',
      oldValue: '#${current.value.toRadixString(16).substring(2).toUpperCase()}',
      newValue: '#${hex.toUpperCase()}',
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
    return await _updateUserField(
      key: 'notifications',
      displayName: 'Notifications',
      newValue: enabled ? 'on' : 'off',
      apply: (u, v) => u.copyWith(notificationEnabled: v == 'on'),
      readCurrent: (u) => u.notificationEnabled ? 'on' : 'off',
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
    ref.invalidate(userProfileProvider);
    return SettingChangeResult(
      success: true,
      key: key,
      displayName: displayName,
      oldValue: oldValue,
      newValue: newValue,
    );
  }

  Future<SettingChangeResult> _setListField({
    required String key,
    required String displayName,
    required Object? value,
    required UserModel Function(UserModel user, List<String> list) apply,
    required List<String> Function(UserModel user) readCurrent,
  }) async {
    final list = _parseStringList(value);
    if (list == null) {
      return SettingChangeResult(
        success: false,
        key: key,
        displayName: displayName,
        newValue: '$value',
        error: '$displayName must be a list of strings',
      );
    }
    final user = await ref.read(currentUserProvider.future);
    if (user == null) {
      return SettingChangeResult(
        success: false,
        key: key,
        displayName: displayName,
        newValue: list.join(', '),
        error: 'Not signed in',
      );
    }
    final oldList = readCurrent(user);
    final updated = apply(user, list);
    await UserService().updateUserProfile(updated);
    ref.invalidate(currentUserProvider);
    ref.invalidate(userProfileProvider);
    return SettingChangeResult(
      success: true,
      key: key,
      displayName: displayName,
      oldValue: oldList.isEmpty ? 'none' : oldList.join(', '),
      newValue: list.isEmpty ? 'none' : list.join(', '),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────

  static bool? _parseBool(Object? v) {
    if (v is bool) return v;
    final s = v?.toString().toLowerCase().trim();
    if (s == 'true' || s == 'on' || s == 'yes' || s == 'enable' ||
        s == 'enabled' || s == '1') return true;
    if (s == 'false' || s == 'off' || s == 'no' || s == 'disable' ||
        s == 'disabled' || s == '0') return false;
    return null;
  }

  static List<String>? _parseStringList(Object? v) {
    if (v == null) return [];
    if (v is List) return v.map((e) => e.toString()).toList();
    if (v is String) {
      if (v.trim().isEmpty) return [];
      return v.split(RegExp(r'[,;]')).map((e) => e.trim()).where((s) => s.isNotEmpty).toList();
    }
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

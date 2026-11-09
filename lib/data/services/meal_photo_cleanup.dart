import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Starts a delayed call; [Timer.new] in the app, a fake in tests.
typedef PhotoTimerFactory = Timer Function(Duration delay, void Function() run);

/// Deletes the photo of a deleted diary entry from the private bucket once
/// the undo window has passed ("Widerrufen" cancels it). Pending deletes are
/// kept on the device, so one due while the app was closed runs at the next
/// start ([resume]).
class MealPhotoCleanup {
  MealPhotoCleanup({
    required SharedPreferences prefs,
    required String userId,
    required Future<bool> Function(String path) delete,
    this.undoWindow = const Duration(seconds: 10),
    DateTime Function()? now,
    PhotoTimerFactory? timerFactory,
  })  : _prefs = prefs,
        _key = 'cal_photo_pending_deletes_v1_$userId',
        _delete = delete,
        _now = now ?? DateTime.now,
        _timerFactory = timerFactory ?? Timer.new {
    _load();
  }

  final SharedPreferences _prefs;
  final String _key;
  final Future<bool> Function(String path) _delete;

  /// The undo toast stands 4 s (10 s with VoiceOver).
  final Duration undoWindow;
  final DateTime Function() _now;
  final PhotoTimerFactory _timerFactory;
  final Map<String, DateTime> _pending = {};
  final Map<String, Timer> _timers = {};
  bool _disposed = false;

  /// Paths waiting for their delete.
  Set<String> get pending => _pending.keys.toSet();

  /// Deletes [path] once the undo window has passed.
  Future<void> schedule(String path) async {
    _pending[path] = _now().add(undoWindow);
    await _save();
    _arm(path, undoWindow);
  }

  /// "Widerrufen": the photo stays.
  Future<void> cancel(String path) async {
    _timers.remove(path)?.cancel();
    if (_pending.remove(path) != null) await _save();
  }

  /// Runs deletes that came due while the app was closed and re-arms the
  /// rest.
  Future<void> resume() async {
    final now = _now();
    for (final e in Map.of(_pending).entries) {
      final left = e.value.difference(now);
      if (left <= Duration.zero) {
        await _run(e.key);
      } else {
        _arm(e.key, left);
      }
    }
  }

  void _arm(String path, Duration delay) {
    _timers.remove(path)?.cancel();
    _timers[path] = _timerFactory(delay, () => unawaited(_run(path)));
  }

  Future<void> _run(String path) async {
    _timers.remove(path);
    if (_disposed || !_pending.containsKey(path)) return;
    // Kept for the next start when the delete fails (offline).
    if (await _delete(path)) {
      _pending.remove(path);
      await _save();
    }
  }

  void _load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return;
    try {
      final map = (jsonDecode(raw) as Map).cast<String, String>();
      _pending.addAll(map.map((k, v) => MapEntry(k, DateTime.parse(v))));
    } catch (e) {
      debugPrint('⚠️ [MEAL_PHOTO] Pending photo deletes unreadable: ${e.runtimeType}');
    }
  }

  Future<void> _save() => _prefs.setString(_key, jsonEncode(_pending.map((k, v) => MapEntry(k, v.toIso8601String()))));

  void dispose() {
    _disposed = true;
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
  }
}

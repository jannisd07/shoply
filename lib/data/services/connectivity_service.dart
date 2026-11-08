import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:shoply/core/config/env.dart';

/// Thin wrapper around [Connectivity] that exposes a simple online/offline
/// boolean stream. Used by the router and the offline banner so the rest of
/// the app never touches `connectivity_plus` directly.
///
/// The platform's "connected" is trusted. Its "none" is checked against a
/// real request first: `connectivity_plus` 5 on iOS reports none whenever the
/// network path uses an interface it does not know (seen on the iOS 27
/// simulator with working Wi-Fi), so the app showed "Offline" while every
/// request succeeded. While a check fails, it is repeated every
/// [retryEvery] until a request gets through or the platform reports a
/// connection.
class ConnectivityService {
  ConnectivityService({
    Future<ConnectivityResult> Function()? check,
    Stream<ConnectivityResult> Function()? changes,
    Future<bool> Function()? isReachable,
    this.retryEvery = const Duration(seconds: 20),
  }) : _check = check ?? Connectivity().checkConnectivity,
       _changes = changes ?? (() => Connectivity().onConnectivityChanged),
       _isReachable = isReachable ?? _backendAnswers;

  static final ConnectivityService instance = ConnectivityService();

  final Future<ConnectivityResult> Function() _check;
  final Stream<ConnectivityResult> Function() _changes;
  final Future<bool> Function() _isReachable;
  final Duration retryEvery;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  final _controller = StreamController<bool>.broadcast();
  Stream<bool> get onStatusChanged => _controller.stream;

  StreamSubscription<ConnectivityResult>? _sub;
  Timer? _retry;
  bool _initialized = false;

  /// Bumped on every platform report, so a slow check never overrides a
  /// newer report.
  int _generation = 0;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    ConnectivityResult initial;
    try {
      initial = await _check();
    } catch (_) {
      initial = ConnectivityResult.other;
    }
    await _apply(initial);
    _sub = _changes().listen(_apply);
  }

  Future<void> _apply(ConnectivityResult result) async {
    final generation = ++_generation;
    _retry?.cancel();
    if (result != ConnectivityResult.none) {
      _set(true);
      return;
    }
    final reachable = await _isReachable();
    if (generation != _generation) return;
    _set(reachable);
    if (!reachable) _scheduleRetry(generation);
  }

  void _scheduleRetry(int generation) {
    _retry = Timer.periodic(retryEvery, (timer) async {
      final reachable = await _isReachable();
      if (generation != _generation || !reachable) return;
      timer.cancel();
      _set(true);
    });
  }

  void _set(bool online) {
    if (online == _isOnline) return;
    _isOnline = online;
    if (!_controller.isClosed) _controller.add(online);
  }

  /// Any HTTP answer from Supabase, even an error status, means the network
  /// works; only a failed or timed-out request counts as offline.
  static Future<bool> _backendAnswers() async {
    try {
      await http
          .head(Uri.parse('${Env.supabaseUrl}/auth/v1/health'))
          .timeout(const Duration(seconds: 5));
      return true;
    } catch (e) {
      debugPrint('⚠️ [CONNECTIVITY] Backend not reachable: ${e.runtimeType}');
      return false;
    }
  }

  void dispose() {
    _retry?.cancel();
    _sub?.cancel();
    _controller.close();
  }
}

/// Emits `true` while the device has a network connection, `false` while
/// offline. The initial value reflects the current state at subscription time.
final connectivityProvider = StreamProvider<bool>((ref) async* {
  final svc = ConnectivityService.instance;
  await svc.initialize();
  yield svc.isOnline;
  yield* svc.onStatusChanged;
});

/// Convenience boolean – true when offline. Screens can watch this to show
/// offline UI without dealing with AsyncValue states (defaults to online on
/// loading/error so we never flash the banner unnecessarily).
final isOfflineProvider = Provider<bool>((ref) {
  final status = ref.watch(connectivityProvider);
  return status.maybeWhen(data: (online) => !online, orElse: () => false);
});

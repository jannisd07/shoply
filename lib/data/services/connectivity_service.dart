import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Thin wrapper around [Connectivity] that exposes a simple online/offline
/// boolean stream. Used by the router and the offline banner so the rest of
/// the app never touches `connectivity_plus` directly.
class ConnectivityService {
  static final ConnectivityService instance = ConnectivityService._();
  ConnectivityService._();

  final Connectivity _connectivity = Connectivity();

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  final _controller = StreamController<bool>.broadcast();
  Stream<bool> get onStatusChanged => _controller.stream;

  StreamSubscription<ConnectivityResult>? _sub;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final initial = await _connectivity.checkConnectivity();
      _isOnline = _online(initial);
    } catch (_) {
      _isOnline = true;
    }
    _sub = _connectivity.onConnectivityChanged.listen((result) {
      final next = _online(result);
      if (next != _isOnline) {
        _isOnline = next;
        _controller.add(next);
      }
    });
  }

  bool _online(ConnectivityResult result) => result != ConnectivityResult.none;

  void dispose() {
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

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/services/connectivity_service.dart';

/// The platform's "none" is checked against a real request before the app
/// shows "Offline" (connectivity_plus 5 reports none on the iOS 27 simulator
/// with working Wi-Fi).
void main() {
  late StreamController<ConnectivityResult> platform;
  late List<bool> reachableAnswers;
  late int checks;

  setUp(() {
    platform = StreamController<ConnectivityResult>.broadcast();
    reachableAnswers = [];
    checks = 0;
  });

  tearDown(() => platform.close());

  ConnectivityService service(
    ConnectivityResult initial, {
    Future<bool> Function()? isReachable,
  }) => ConnectivityService(
    check: () async => initial,
    changes: () => platform.stream,
    isReachable:
        isReachable ??
        () async {
          checks++;
          return reachableAnswers.isEmpty ? false : reachableAnswers.removeAt(0);
        },
    retryEvery: const Duration(milliseconds: 10),
  );

  test('trusts a connection the platform reports, without a request', () async {
    final svc = service(ConnectivityResult.wifi);
    await svc.initialize();

    expect(svc.isOnline, isTrue);
    expect(checks, 0);
    svc.dispose();
  });

  test('stays online when the platform says none but the backend answers', () async {
    reachableAnswers = [true];
    final svc = service(ConnectivityResult.none);
    await svc.initialize();

    expect(svc.isOnline, isTrue);
    expect(checks, 1);
    svc.dispose();
  });

  test('goes offline when the backend does not answer, and back once it does', () async {
    reachableAnswers = [false, false, true];
    final svc = service(ConnectivityResult.none);
    final events = <bool>[];
    svc.onStatusChanged.listen(events.add);

    await svc.initialize();
    expect(svc.isOnline, isFalse);

    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(svc.isOnline, isTrue);
    expect(events, [false, true]);
    final settled = checks;
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(checks, settled, reason: 'no more checks once online');
    svc.dispose();
  });

  test('a reported connection ends the offline state and its retries', () async {
    final svc = service(ConnectivityResult.wifi);
    final events = <bool>[];
    svc.onStatusChanged.listen(events.add);
    await svc.initialize();

    platform.add(ConnectivityResult.none);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(svc.isOnline, isFalse);

    platform.add(ConnectivityResult.wifi);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(svc.isOnline, isTrue);
    final settled = checks;
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(checks, settled, reason: 'retries stopped');
    expect(events, [false, true]);
    svc.dispose();
  });

  test('a slow check never overrides a newer platform report', () async {
    final slow = Completer<bool>();
    final svc = service(
      ConnectivityResult.wifi,
      isReachable: () => slow.future,
    );
    await svc.initialize();

    platform.add(ConnectivityResult.none);
    await Future<void>.delayed(Duration.zero);
    platform.add(ConnectivityResult.mobile);
    await Future<void>.delayed(Duration.zero);
    slow.complete(false);
    await Future<void>.delayed(const Duration(milliseconds: 5));

    expect(svc.isOnline, isTrue);
    svc.dispose();
  });
}

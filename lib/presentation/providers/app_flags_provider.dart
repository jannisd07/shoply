import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/services/app_flags_service.dart';

/// Override in tests.
final appFlagsServiceProvider = Provider<AppFlagsService>(
  (ref) => AppFlagsService.instance,
);

/// The remote flags (contract 3.2). Starts from [AppFlagsService.current],
/// loads the cache if nothing did yet, follows every refresh and refreshes
/// whenever the app comes back to the foreground (throttled to 30 min by the
/// service). Needs the Flutter binding (in tests:
/// `TestWidgetsFlutterBinding.ensureInitialized()`).
final appFlagsProvider = StateNotifierProvider<AppFlagsNotifier, AppFlags>(
  (ref) => AppFlagsNotifier(ref.watch(appFlagsServiceProvider)),
);

/// Remote kill switch for offers (`app_flags.offers_enabled`). Off until the
/// flags are known (cache or server): the offers source is called straight
/// from the device, so an unknown state must not let a request through.
final offersRemoteEnabledProvider = Provider<bool>(
  (ref) => ref.watch(
    appFlagsProvider.select(
      (f) => f.isKnown && f.isEnabled(AppFlagKeys.offersEnabled),
    ),
  ),
);

/// Whether the remote flags are real values (cache or server): until then
/// the offers kill switch reads "off" without being known to be off.
final offersFlagsKnownProvider = Provider<bool>(
  (ref) => ref.watch(appFlagsProvider.select((f) => f.isKnown)),
);

/// The offers kill switch is known and off (`app_flags.offers_enabled` is
/// false in real flags). Unknown flags are not "off" here: screens that
/// fetch nothing (the onboarding step) may show while the flags load,
/// because the kill switch is on by default (owner).
final offersKillSwitchOffProvider = Provider<bool>(
  (ref) =>
      ref.watch(offersFlagsKnownProvider) &&
      !ref.watch(offersRemoteEnabledProvider),
);

/// Remote kill switch for the Claude features (`app_flags.ai_enabled`). Off
/// until the cache was read, then on unless the flag says off. All AI calls
/// go through the `ai` edge function, which has to enforce the flag itself.
final aiRemoteEnabledProvider = Provider<bool>(
  (ref) => ref.watch(
    appFlagsProvider.select(
      (f) => f.isLoaded && f.isEnabled(AppFlagKeys.aiEnabled),
    ),
  ),
);

/// Whether any offers surface may show or fetch anything: the user's offers
/// module is on and the remote kill switch is known to be on.
final offersAvailableProvider = Provider<bool>(
  (ref) =>
      ref.watch(moduleEnabledProvider(AppModule.offers)) &&
      ref.watch(offersRemoteEnabledProvider),
);

class AppFlagsNotifier extends StateNotifier<AppFlags> {
  AppFlagsNotifier(AppFlagsService service) : super(service.current) {
    _subscription = service.changes.listen((flags) {
      if (mounted) state = flags;
    });
    _lifecycle = AppLifecycleListener(
      onResume: () => unawaited(service.refresh()),
    );
    // Picks up the cache when nothing loaded it yet (no-op otherwise).
    unawaited(service.loadCache());
  }

  late final StreamSubscription<AppFlags> _subscription;
  late final AppLifecycleListener _lifecycle;

  @override
  void dispose() {
    _lifecycle.dispose();
    _subscription.cancel();
    super.dispose();
  }
}

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/data/services/analytics_service.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/presentation/screens/main_scaffold.dart';
import 'package:shoply/presentation/widgets/design/gallery/component_gallery.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/services/shared_preferences_provider.dart';
import 'package:shoply/presentation/screens/onboarding/onboarding_prefs.dart';
import 'package:shoply/presentation/screens/onboarding/onboarding_steps.dart';
import 'package:shoply/routes/app_branch.dart';
import 'package:shoply/routes/areas/auth_routes.dart';
import 'package:shoply/routes/areas/avo_routes.dart';
import 'package:shoply/routes/areas/calories_routes.dart';
import 'package:shoply/routes/areas/history_routes.dart';
import 'package:shoply/routes/areas/home_routes.dart';
import 'package:shoply/routes/areas/lists_routes.dart';
import 'package:shoply/routes/areas/offers_routes.dart';
import 'package:shoply/routes/areas/paywall_routes.dart';
import 'package:shoply/routes/areas/plan_routes.dart';
import 'package:shoply/routes/areas/profile_routes.dart';
import 'package:shoply/routes/areas/recipes_routes.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/routes/deep_links.dart';
import 'package:shoply/routes/module_gate.dart';
import 'package:shoply/routes/route_error_screen.dart';
import 'package:shoply/routes/route_paths.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Forwards navigation events to the Firebase Analytics observer.
///
/// The router is built on the first frame, but [AnalyticsService.initialize]
/// (which creates the real observer) runs later in the background init. Reading
/// the observer lazily on every event means screen views are tracked as soon
/// as Firebase is ready instead of never.
class _LazyAnalyticsObserver extends NavigatorObserver {
  NavigatorObserver? get _target => AnalyticsService.instance.observer;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _target?.didPush(route, previousRoute);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _target?.didPop(route, previousRoute);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _target?.didRemove(route, previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _target?.didReplace(newRoute: newRoute, oldRoute: oldRoute);
}

/// What the redirect knows about the person and the device (Konzept 17
/// §1.3). Built from Supabase and [OnboardingPrefs]; tests pass fakes.
@immutable
class EntryState {
  const EntryState({
    required this.signedIn,
    this.deviceOnboarded = false,
    this.resumeStep,
    this.flowActive = false,
    this.passwordResetPending = false,
    this.pendingLink,
  });

  final bool signedIn;

  /// `onboarding_complete_v1`: the device knows the onboarding.
  final bool deviceOnboarded;

  /// `onb_step`: a run is open (before the account, or a new account that
  /// has not finished).
  final OnboardingStep? resumeStep;

  /// An [OnboardingFlow] is on screen and decides itself after a sign-in.
  final bool flowActive;

  /// The app was killed between the reset code and the new password.
  final bool passwordResetPending;

  /// A remembered private link (not expired).
  final PendingLink? pendingLink;
}

/// Routes the flow itself shows.
const Set<String> _entryRoutes = {
  RoutePaths.onboarding,
  RoutePaths.welcome,
  RoutePaths.login,
  RoutePaths.signup,
  RoutePaths.namePrompt,
};

/// The entry redirect (Konzept 17 §1.3, §4.4, §5.1, §5.5) for the matched
/// [location] of [uri]; null keeps it. [remember] gets a private link that
/// was opened without a session, [consumeLink] is called when a remembered
/// link is resumed.
///
/// - Rezept-Links (`/recipe/:id`) and `/reset-password` are always open.
/// - Without a session: private links are remembered and lead to
///   Willkommen (`/welcome` when the device knows the onboarding, else
///   `/onboarding`); `/login`, `/signup` stay; every other route leads
///   there too.
/// - With a session: a pending reset goes to `/reset-password`; an open run
///   goes back to `/onboarding`; the entry routes stay while the flow is on
///   screen and otherwise lead to Home; a remembered link opens once Home
///   or the lists tab is reached.
String? entryRedirect(
  Uri uri,
  String location,
  EntryState s, {
  void Function(String path)? remember,
  void Function()? consumeLink,
}) {
  if (location == RoutePaths.resetPassword) return null;
  if (location.startsWith('/recipe/')) return null;

  if (!s.signedIn) {
    final start = s.deviceOnboarded && s.resumeStep == null
        ? RoutePaths.welcome
        : RoutePaths.onboarding;
    if (isPrivateLink(location)) {
      remember?.call(uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path);
      return start;
    }
    switch (location) {
      case RoutePaths.onboarding:
        return start == RoutePaths.onboarding ? null : start;
      case RoutePaths.welcome:
        return s.resumeStep != null ? RoutePaths.onboarding : null;
      case RoutePaths.login:
      case RoutePaths.signup:
        return null;
      default:
        return start;
    }
  }

  if (s.passwordResetPending) return RoutePaths.resetPassword;
  final isEntry = _entryRoutes.contains(location);
  if (s.resumeStep != null) {
    return isEntry ? null : RoutePaths.onboarding;
  }
  if (isEntry) return s.flowActive ? null : RoutePaths.home;
  final link = s.pendingLink;
  if (link != null &&
      (location == RoutePaths.home || location == RoutePaths.lists)) {
    consumeLink?.call();
    return link.path;
  }
  return null;
}

/// The current [EntryState] (after [OnboardingPrefs.load]).
EntryState currentEntryState() {
  final prefs = OnboardingPrefs.instance;
  return EntryState(
    signedIn: SupabaseService.instance.currentUser != null,
    deviceOnboarded: prefs.deviceOnboarded,
    resumeStep: prefs.resumeStep,
    flowActive: OnboardingFlowPresence.active,
    passwordResetPending: prefs.passwordResetPending,
    pendingLink: prefs.pendingLink(),
  );
}

/// Helper class to refresh GoRouter when auth state changes. Only events
/// that change whether a user is signed in re-run the redirect; the hourly
/// tokenRefreshed and userUpdated events do not.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<AuthState> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((AuthState state) {
      if (_routingEvents.contains(state.event)) notifyListeners();
    });
  }

  static const _routingEvents = {
    AuthChangeEvent.initialSession,
    AuthChangeEvent.signedIn,
    AuthChangeEvent.signedOut,
    AuthChangeEvent.passwordRecovery,
  };

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Length of the arrival fade (close to `AvoMotion.morph`, 0.40 s).
const Duration _kArrivalDuration = Duration(milliseconds: 400);

final routerProvider = Provider<GoRouter>((ref) {
  final supabase = SupabaseService.instance;
  // main loads SharedPreferences before runApp: the first frame already
  // knows whether to show Willkommen or the app (Konzept 17 §3.1).
  final prefs = ref.read(sharedPreferencesProvider).valueOrNull;
  if (prefs != null) OnboardingPrefs.instance.attach(prefs);
  final signedIn = supabase.currentUser != null;
  final resume = OnboardingPrefs.instance.resumeStep;
  final initialLocation = signedIn
      ? (resume != null ? RoutePaths.onboarding : RoutePaths.home)
      : (OnboardingPrefs.instance.deviceOnboarded && resume == null
            ? RoutePaths.welcome
            : RoutePaths.onboarding);

  // Analytics screen tracking (iOS/Android only)
  final observers = <NavigatorObserver>[
    if (Platform.isIOS || Platform.isAndroid) _LazyAnalyticsObserver(),
  ];

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation,
    refreshListenable: GoRouterRefreshStream(supabase.authStateChanges),
    errorBuilder: (context, state) => const RouteErrorScreen(),
    observers: observers,
    routes: buildAppRoutes(),
    redirect: (context, state) async {
      final uri = state.uri;
      // Translate shoply:// links in one place (lib/routes/deep_links.dart).
      if (uri.scheme == 'shoply') return mapCustomSchemeLink(uri);
      await OnboardingPrefs.instance.load();
      return entryRedirect(
        uri,
        state.matchedLocation,
        currentEntryState(),
        remember: (path) => OnboardingPrefs.instance.rememberLink(path),
        consumeLink: () => OnboardingPrefs.instance.clearLink(),
      );
    },
  );
});

/// Routes Teil B wants inside [branch], from all B area files.
List<RouteBase> _bBranch(AppBranch branch) => [
  ...?avoBranchRoutes[branch],
  ...?caloriesBranchRoutes[branch],
  ...?planBranchRoutes[branch],
  ...?offersBranchRoutes[branch],
  ...?historyBranchRoutes[branch],
];

/// All routes of the app, assembled from the area files in `routes/areas/`.
///
/// The five D2 tabs (see [AppBranch]): Home, Listen, Avo, Rezepte, Profil.
/// StatefulShellRoute keeps each tab's state alive; [MainScaffold] shows the
/// floating tab bar. Kalorien is a push screen in the Home tab, Angebote and
/// Verlauf push in the Listen tab, the Wochenplan is a segment of Rezepte.
/// Routes outside the shell open full screen above the tab bar.
List<RouteBase> buildAppRoutes() => [
  ...authRoutes,
  StatefulShellRoute(
    // Entering the app from the onboarding or a sign-in fades in (Konzept 17
    // §3.12: the onboarding fades out, the list lies below; scale 0.98 to 1).
    pageBuilder: (context, state, navigationShell) => CustomTransitionPage(
      key: state.pageKey,
      transitionDuration: context.reduceMotion
          ? AvoMotion.fadeReduced
          : _kArrivalDuration,
      transitionsBuilder: (context, animation, secondary, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        final fade = FadeTransition(opacity: curved, child: child);
        if (context.reduceMotion) return fade;
        return ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
          child: fade,
        );
      },
      child: MainScaffold(
        navigationShell: navigationShell,
        location: state.fullPath ?? state.matchedLocation,
      ),
    ),
    navigatorContainerBuilder: (context, navigationShell, children) =>
        ShellBranchContainer(
          currentIndex: navigationShell.currentIndex,
          children: children,
        ),
    branches: [
      // 0 Home, with Kalorien as a push screen (Teil B, module "calories").
      StatefulShellBranch(
        routes: [
          ...homeBranchRoutes,
          GoRoute(
            path: RoutePaths.calories,
            name: 'calories',
            builder: (context, state) => ModuleGate(
              module: AppModule.calories,
              child: buildCaloriesRoot(context, state),
            ),
            routes: caloriesChildRoutes,
          ),
          ..._bBranch(AppBranch.home),
        ],
      ),
      // 1 Listen: overview, a list, Angebote and Verlauf (Teil B).
      StatefulShellBranch(
        routes: [
          ...listsBranchRoutes,
          GoRoute(
            path: RoutePaths.offers,
            name: 'offers',
            builder: (context, state) => ModuleGate(
              module: AppModule.offers,
              child: buildOffersRoot(context, state),
            ),
            routes: offersChildRoutes,
          ),
          GoRoute(
            path: RoutePaths.history,
            name: 'history',
            builder: buildHistoryRoot,
            routes: historyChildRoutes,
          ),
          ..._bBranch(AppBranch.lists),
        ],
      ),
      // 2 Avo (Teil B, module "avo"; the tab disappears when it is off).
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: RoutePaths.avo,
            name: 'avo-chat',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: ModuleGate(
                module: AppModule.avo,
                child: buildAvoRoot(context, state),
              ),
            ),
            routes: avoChildRoutes,
          ),
          ..._bBranch(AppBranch.avo),
        ],
      ),
      // 3 Rezepte (+ Wochenplan segment).
      StatefulShellBranch(
        routes: [...recipesBranchRoutes, ..._bBranch(AppBranch.recipes)],
      ),
      // 4 Profil (+ /settings pages of both parts).
      StatefulShellBranch(
        routes: [...profileBranchRoutes, ..._bBranch(AppBranch.profile)],
      ),
    ],
  ),
  // Full screen, above the tab bar.
  ...listsRoutes,
  ...recipesRoutes,
  ...profileRoutes,
  ...paywallRoutes,
  ...avoRootRoutes,
  ...caloriesRootRoutes,
  ...planRootRoutes,
  ...offersRootRoutes,
  ...historyRootRoutes,
  // Component gallery for comparing with D2; never in release builds.
  if (kDebugMode)
    GoRoute(
      path: RoutePaths.debugComponents,
      name: 'debug-components',
      builder: (context, state) => const ComponentGallery(),
    ),
];

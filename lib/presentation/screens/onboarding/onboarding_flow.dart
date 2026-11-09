import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/data/services/onboarding_answers_service.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/presentation/screens/auth/password_login_screen.dart';
import 'package:shoply/presentation/screens/auth/steps/account_step.dart';
import 'package:shoply/presentation/screens/auth/steps/code_step.dart';
import 'package:shoply/presentation/screens/auth/steps/email_step.dart';
import 'package:shoply/presentation/screens/auth/steps/name_step.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_info_actions.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_info_colors.dart';
import 'package:shoply/presentation/screens/onboarding/onboarding_controller.dart';
import 'package:shoply/presentation/screens/onboarding/onboarding_prefs.dart';
import 'package:shoply/presentation/screens/onboarding/onboarding_steps.dart';
import 'package:shoply/presentation/screens/onboarding/steps/account_check_step.dart';
import 'package:shoply/presentation/screens/onboarding/steps/diet_step.dart';
import 'package:shoply/presentation/screens/onboarding/steps/first_list_step.dart';
import 'package:shoply/presentation/screens/onboarding/steps/goal_step.dart';
import 'package:shoply/presentation/screens/onboarding/steps/join_step.dart';
import 'package:shoply/presentation/screens/onboarding/steps/modules_step.dart';
import 'package:shoply/presentation/screens/onboarding/steps/region_step.dart';
import 'package:shoply/presentation/screens/onboarding/steps/step_common.dart';
import 'package:shoply/presentation/screens/onboarding/steps/welcome_step.dart';
import 'package:shoply/routes/route_paths.dart';

export 'package:shoply/presentation/screens/onboarding/onboarding_controller.dart';

/// Where the flow was entered (Konzept 17 §1.3, §4).
enum OnboardingEntry {
  /// `/onboarding`: Willkommen, or the step a run stopped at.
  start,

  /// `/welcome`: Willkommen in the variant "Anmelden" (after signing out).
  welcomeBack,

  /// `/login`: Anmelden (§4.1), back leads to Willkommen.
  login,

  /// `/login?method=password` (§4.2), back leads to Anmelden.
  loginPassword,

  /// `/signup`: the e-mail step of a new account.
  signup,

  /// `/name-prompt`: Name for a signed-in account that is not set up.
  namePrompt,
}

/// Whether a session exists right now. Overridden in tests.
final onboardingSessionProvider = Provider<bool Function()>(
  (ref) =>
      () => SupabaseService.instance.currentUser != null,
);

/// The remembered private link (Konzept 17 §5.1). Overridden in tests.
final onboardingPendingLinkProvider = Provider<PendingLink? Function()>(
  (ref) =>
      () => OnboardingPrefs.instance.pendingLink(),
);

/// Creates the first list in the first palette colour (blue).
final onboardingCreateListProvider =
    Provider<Future<JoinedList> Function(String name)>((ref) {
      return (name) async {
        final list = await ref
            .read(listActionsProvider)
            .createList(name, colorHex: kListPalette.first.hex);
        return (id: list.id, name: list.name);
      };
    });

/// Joins a list by share code; null when no list has it.
final onboardingJoinProvider =
    Provider<Future<JoinedList?> Function(String code)>((ref) {
      return (code) async {
        final list = await ref.read(listActionsProvider).joinWithCode(code);
        return list == null ? null : (id: list.id, name: list.name);
      };
    });

/// Leaves the flow for [location]. Overridden in tests.
final onboardingExitProvider =
    Provider<void Function(BuildContext context, String location)>(
      (ref) =>
          (context, location) => GoRouter.of(context).go(location),
    );

/// What a page of the flow's own navigator shows.
enum _PageKind { welcome, step, email, code, password, check, join }

@immutable
class _FlowPage {
  const _FlowPage(this.kind, {this.email, this.failed = false}) : step = null;

  const _FlowPage.step(OnboardingStep this.step)
    : kind = _PageKind.step,
      email = null,
      failed = false;

  final _PageKind kind;
  final OnboardingStep? step;
  final String? email;
  final bool failed;

  /// The step this page saves as `onb_step`.
  OnboardingStep? get savedStep => switch (kind) {
    _PageKind.welcome => OnboardingStep.welcome,
    _PageKind.step => step,
    _PageKind.email ||
    _PageKind.code ||
    _PageKind.password => OnboardingStep.account,
    _PageKind.check || _PageKind.join => null,
  };

  /// The step whose progress the page shows.
  OnboardingStep? get progressStep => switch (kind) {
    _PageKind.step => step,
    _PageKind.email => OnboardingStep.email,
    _PageKind.code => OnboardingStep.code,
    _PageKind.join => OnboardingStep.firstList,
    _ => null,
  };
}

/// The first-start flow (Konzept 17 §1–3, §5): Willkommen, Module, Region
/// (Teil B), Konto with E-Mail and Code (Teil "Konto"), Name, Ernährung,
/// Dein Ziel, Erste Liste or Beitreten, then the list with `?arrival=`.
///
/// The steps live in their own [Navigator] (push from the right, back swipe
/// follows the finger; Reduce Motion: cross-fade). After the account there
/// is no way back to the steps before (§1.1). The answers sit in
/// [OnboardingController] and survive a killed app.
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key, this.entry = OnboardingEntry.start});

  final OnboardingEntry entry;

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  final _navKey = GlobalKey<NavigatorState>();
  late final List<_FlowPage> _initial;
  AccountStepMode? _initialMode;
  bool _resolving = false;
  bool _leaving = false;
  bool _busy = false;

  /// Teil B's region step mounted offstage for the check before the push.
  Widget? _probe;

  OnboardingController get _c =>
      ref.read(onboardingControllerProvider.notifier);
  OnboardingDraft get _s => ref.read(onboardingControllerProvider);
  NavigatorState? get _nav => _navKey.currentState;

  bool get _returning =>
      widget.entry == OnboardingEntry.welcomeBack ||
      OnboardingPrefs.instance.deviceOnboarded;

  @override
  void initState() {
    super.initState();
    OnboardingFlowPresence.enter();
    _initial = _initialPages();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final mode = _initialMode;
      if (mode != null) _c.setMode(mode);
      final step = _initial.last.savedStep;
      if (step != null) _c.enterStep(step);
    });
  }

  @override
  void dispose() {
    OnboardingFlowPresence.leave();
    super.dispose();
  }

  // ------------------------------------------------------- initial stack

  List<_FlowPage> _initialPages() {
    final s = _s;
    final signedIn = ref.read(onboardingSessionProvider)();
    final welcome = const _FlowPage(_PageKind.welcome);

    if (signedIn) {
      final step = s.step;
      final resumable =
          s.accountReady &&
          step != OnboardingStep.welcome &&
          !const {
            OnboardingStep.account,
            OnboardingStep.email,
            OnboardingStep.code,
          }.contains(step);
      if (resumable) return [_FlowPage.step(step)];
      return const [_FlowPage(_PageKind.check)];
    }

    switch (widget.entry) {
      case OnboardingEntry.login:
        _initialMode = AccountStepMode.login;
        return [welcome, const _FlowPage.step(OnboardingStep.account)];
      case OnboardingEntry.loginPassword:
        _initialMode = AccountStepMode.login;
        return [
          welcome,
          const _FlowPage.step(OnboardingStep.account),
          const _FlowPage(_PageKind.password),
        ];
      case OnboardingEntry.signup:
        _initialMode = AccountStepMode.signUp;
        return [
          welcome,
          const _FlowPage.step(OnboardingStep.account),
          const _FlowPage(_PageKind.email),
        ];
      case OnboardingEntry.start:
      case OnboardingEntry.welcomeBack:
      case OnboardingEntry.namePrompt:
        break;
    }

    // Resume before the account (§5.5): Willkommen, then the plan up to
    // the saved step. Without a session a later step resumes at Konto.
    final step = s.step;
    if (step == OnboardingStep.welcome) return [welcome];
    final plan = _c.plan;
    final accountIndex = plan.indexOf(OnboardingStep.account);
    var target =
        const {OnboardingStep.email, OnboardingStep.code}.contains(step)
        ? OnboardingStep.account
        : step;
    var index = plan.indexOf(target);
    if (index < 0 || index > accountIndex) {
      target = OnboardingStep.account;
      index = accountIndex;
    }
    return [
      welcome,
      for (final st in plan.sublist(0, index + 1)) _FlowPage.step(st),
    ];
  }

  // ---------------------------------------------------------------- routes

  Route<void> _route(_FlowPage page, {bool animated = true}) {
    final settings = RouteSettings(name: page.savedStep?.id);
    Widget builder(BuildContext context) =>
        _PageHost(page: page, builder: _buildPage);
    if (!animated || context.reduceMotion) {
      final duration = animated ? AvoMotion.fadeReduced : Duration.zero;
      return PageRouteBuilder<void>(
        settings: settings,
        transitionDuration: duration,
        reverseTransitionDuration: AvoMotion.fadeReduced,
        pageBuilder: (context, animation, secondary) => builder(context),
        transitionsBuilder: (context, animation, secondary, child) =>
            FadeTransition(opacity: animation, child: child),
      );
    }
    return CupertinoPageRoute<void>(settings: settings, builder: builder);
  }

  void _push(_FlowPage page) {
    final step = page.savedStep;
    if (step != null) _c.enterStep(step);
    _nav?.push(_route(page));
  }

  void _replace(_FlowPage page, {bool animated = true}) {
    final step = page.savedStep;
    if (step != null) _c.enterStep(step);
    _nav?.pushReplacement(_route(page, animated: animated));
  }

  /// No way back to what was before (after the account, §1.1).
  void _resetTo(_FlowPage page) {
    final step = page.savedStep;
    if (step != null) _c.enterStep(step);
    _nav?.pushAndRemoveUntil(_route(page), (_) => false);
  }

  void _pop() => _nav?.maybePop();

  void _goNext(OnboardingStep from) {
    final next = _c.nextAfter(from);
    if (next == null) return;
    _push(_FlowPage.step(next));
  }

  // ---------------------------------------------------------------- pages

  Widget _buildPage(BuildContext context, _FlowPage page, bool isFirst) {
    final back = isFirst ? null : _pop;
    final progressStep = page.progressStep;
    final progress = progressStep == null
        ? null
        : onboardingProgressLine(context, _c.progressOf(progressStep));
    final mode = _s.mode;

    switch (page.kind) {
      case _PageKind.welcome:
        return WelcomeStep(
          returning: _returning,
          invited:
              ref.read(onboardingPendingLinkProvider)()?.isInvitation ?? false,
          onStart: _onStart,
          onLogin: _onLogin,
        );
      case _PageKind.email:
        return EmailStep(
          mode: mode,
          onBack: back,
          progress: progress,
          onCodeSent: (email) => _push(_FlowPage(_PageKind.code, email: email)),
          onPassword: () => _push(const _FlowPage(_PageKind.password)),
        );
      case _PageKind.code:
        return CodeStep(
          mode: mode,
          email: page.email ?? '',
          onBack: back,
          progress: progress,
          onVerified: _handleSignedIn,
        );
      case _PageKind.password:
        return PasswordLoginScreen(onSignedIn: _handleSignedIn, onBack: back);
      case _PageKind.check:
        return AccountCheckStep(
          check: _resolve,
          failed: page.failed,
          autoStart: !page.failed,
        );
      case _PageKind.join:
        return _joinStep(progress: progress, onBack: back, existing: true);
      case _PageKind.step:
        break;
    }

    final step = page.step!;
    switch (step) {
      case OnboardingStep.welcome:
        return const SizedBox.shrink();
      case OnboardingStep.modules:
        return ModulesStep(
          progress: progress,
          onBack: back,
          onNext: () => _afterModules(),
          onSkip: () => _afterModules(skip: true),
        );
      case OnboardingStep.region:
        return RegionStep(
          progress: progress,
          onBack: back,
          onNext: () => _goNext(OnboardingStep.region),
          onUnavailable: _regionUnavailable,
        );
      case OnboardingStep.account:
        return AccountStep(
          mode: mode,
          progress: progress,
          onBack: back,
          onEmail: () => _push(const _FlowPage(_PageKind.email)),
          onSignedIn: _handleSignedIn,
          onPassword: mode == AccountStepMode.login
              ? () => _push(const _FlowPage(_PageKind.password))
              : null,
        );
      case OnboardingStep.email:
        return EmailStep(
          mode: mode,
          onBack: back,
          progress: progress,
          onCodeSent: (email) => _push(_FlowPage(_PageKind.code, email: email)),
          onPassword: () => _push(const _FlowPage(_PageKind.password)),
        );
      case OnboardingStep.code:
        // A code page needs the address; resume at Konto instead.
        return AccountStep(
          mode: mode,
          progress: progress,
          onBack: back,
          onEmail: () => _push(const _FlowPage(_PageKind.email)),
          onSignedIn: _handleSignedIn,
        );
      case OnboardingStep.name:
        return NameStep(
          progress: progress,
          onDone: () => _goNext(OnboardingStep.name),
          onSkip: () => _goNext(OnboardingStep.name),
        );
      case OnboardingStep.diet:
        return DietStep(
          progress: progress,
          onBack: back,
          onNext: () {
            _c.finishDiet();
            _goNext(OnboardingStep.diet);
          },
          onSkip: () {
            _c.finishDiet(skip: true);
            _goNext(OnboardingStep.diet);
          },
        );
      case OnboardingStep.goal:
        return GoalStep(
          progress: progress,
          onBack: back,
          onNext: () {
            _c.finishGoal();
            _goNext(OnboardingStep.goal);
          },
          onSkip: () {
            _c.finishGoal(skip: true);
            _goNext(OnboardingStep.goal);
          },
        );
      case OnboardingStep.firstList:
        final code = ref.read(onboardingPendingLinkProvider)()?.joinCode;
        if (code != null && !_s.joinDeclined) {
          return _joinStep(progress: progress, onBack: back, existing: false);
        }
        return FirstListStep(
          progress: progress,
          onBack: back,
          onCreate: _createList,
          onSkip: _skipList,
        );
    }
  }

  Widget _joinStep({
    required Widget? progress,
    required VoidCallback? onBack,
    required bool existing,
  }) {
    return JoinStep(
      progress: existing ? null : progress,
      onBack: existing ? null : onBack,
      join: () async {
        final code = ref.read(onboardingPendingLinkProvider)()?.joinCode;
        if (code == null) return null;
        return ref.read(onboardingJoinProvider)(code);
      },
      onJoined: (list) => _finish(
        RoutePaths.listArrival(
          list.id,
          OnboardingArrival.joined.id,
          name: list.name,
        ),
        complete: !existing,
      ),
      onDecline: () {
        unawaited(OnboardingPrefs.instance.clearLink());
        if (existing) {
          unawaited(_arriveExisting(skipLink: true));
          return;
        }
        _c.declineJoin();
        _replace(const _FlowPage.step(OnboardingStep.firstList));
      },
    );
  }

  // ------------------------------------------------------------- actions

  void _onStart() {
    if (_returning) {
      _c.startFresh(AccountStepMode.signUp);
    } else {
      _c.setMode(AccountStepMode.signUp);
    }
    _push(_FlowPage.step(_c.plan.first));
  }

  void _onLogin() {
    _c.setMode(AccountStepMode.login);
    _push(const _FlowPage.step(OnboardingStep.account));
  }

  Future<void> _afterModules({bool skip = false}) async {
    if (_busy) return;
    _busy = true;
    try {
      await _c.commitModules(skip: skip);
      if (_c.nextAfter(OnboardingStep.modules) == OnboardingStep.region) {
        // B's step may have nothing to show (kill switch, shell): then the
        // flow goes on without pushing it (A-O1).
        final hasContent = await probeOffersSetup((probe) {
          if (mounted) setState(() => _probe = probe);
        });
        if (!mounted) return;
        if (!hasContent) _c.markRegionHidden();
      }
      _goNext(OnboardingStep.modules);
    } finally {
      _busy = false;
    }
  }

  /// Resume case: B reported "nothing to show" while the region page was
  /// still invisible; it is replaced without an animation.
  void _regionUnavailable() {
    final next = _c.nextAfter(OnboardingStep.region);
    _c.markRegionHidden();
    if (next != null) _replace(_FlowPage.step(next), animated: false);
  }

  /// A session exists (Apple, Google, code or password). Stays on the
  /// account step until the account says new or set up (§3.5, Bug 8).
  void _handleSignedIn() {
    if (_resolving) return;
    unawaited(_resolveAndContinue());
  }

  Future<void> _resolveAndContinue() async {
    final ok = await _resolve();
    if (!ok && mounted) {
      _resetTo(const _FlowPage(_PageKind.check, failed: true));
    }
  }

  /// Asks the account and moves on; false when the server was unreachable.
  Future<bool> _resolve() async {
    if (_resolving) return true;
    _resolving = true;
    try {
      final status = await _c.resolveAccount();
      if (!mounted) return true;
      if (status == AccountSetupStatus.setUp) {
        await _arriveExisting();
      } else {
        final next = _c.nextAfter(OnboardingStep.account);
        if (next != null) _resetTo(_FlowPage.step(next));
      }
      return true;
    } catch (e) {
      debugPrint('⚠️ [Onboarding] Account check failed: $e');
      return false;
    } finally {
      _resolving = false;
    }
  }

  /// A set-up account: an invitation first, else the list of today (§5.3,
  /// §3.12 "Bestandskonto").
  Future<void> _arriveExisting({bool skipLink = false}) async {
    final link = skipLink ? null : ref.read(onboardingPendingLinkProvider)();
    if (link?.joinCode != null) {
      _resetTo(const _FlowPage(_PageKind.join));
      return;
    }
    if (link != null) {
      await OnboardingPrefs.instance.clearLink();
      _exit(link.path);
      return;
    }
    String? listId;
    try {
      listId = await ref.read(onboardingBackendProvider).lastListId();
    } catch (e) {
      debugPrint('⚠️ [Onboarding] No last list: $e');
    }
    if (!mounted) return;
    _exit(
      listId == null
          ? RoutePaths.lists
          : RoutePaths.listArrival(listId, OnboardingArrival.existing.id),
    );
  }

  Future<bool> _createList(String name) async {
    try {
      final list = await ref.read(onboardingCreateListProvider)(name);
      await _finish(
        RoutePaths.listArrival(
          list.id,
          OnboardingArrival.created.id,
          name: list.name,
        ),
      );
      return true;
    } catch (e) {
      debugPrint('⚠️ [Onboarding] Creating the first list failed: $e');
      return false;
    }
  }

  Future<void> _skipList() => _finish(RoutePaths.lists);

  /// Closes the run and opens [location]. A remembered private link that is
  /// no invitation (a list, an author) opens instead, above its tab (§1.3);
  /// an invitation was used by the join step.
  Future<void> _finish(String location, {bool complete = true}) async {
    if (_leaving) return;
    if (complete) await _c.complete();
    final link = ref.read(onboardingPendingLinkProvider)();
    var target = location;
    if (link != null) {
      await OnboardingPrefs.instance.clearLink();
      if (link.joinCode == null) target = link.path;
    }
    if (!mounted) return;
    _exit(target);
  }

  void _exit(String location) {
    if (_leaving) return;
    _leaving = true;
    ref.read(onboardingExitProvider)(context, location);
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _nav?.maybePop();
      },
      child: ColoredBox(
        color: context.colors.background,
        child: Stack(
          children: [
            Navigator(
              key: _navKey,
              onGenerateInitialRoutes: (navigator, initialRoute) => [
                for (final page in _initial) _route(page),
              ],
              observers: [_StepObserver(onVisible: _onVisible)],
            ),
            if (_probe != null) _probe!,
          ],
        ),
      ),
    );
  }

  void _onVisible(String? stepId) {
    final step = OnboardingStep.fromId(stepId);
    if (step == null) return;
    // Not while the navigator updates (it may be inside a build).
    scheduleMicrotask(() {
      if (mounted) _c.enterStep(step);
    });
  }
}

/// Builds a page with whether it is the first of the stack (no back
/// button there) and rebuilds it when the plan changes (progress).
class _PageHost extends ConsumerWidget {
  const _PageHost({required this.page, required this.builder});

  final _FlowPage page;
  final Widget Function(BuildContext context, _FlowPage page, bool isFirst)
  builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(
      onboardingControllerProvider.select(
        (s) => (s.mode, s.plannedModules, s.regionHidden, s.joinDeclined),
      ),
    );
    final isFirst = ModalRoute.of(context)?.isFirst ?? true;
    return builder(context, page, isFirst);
  }
}

/// Tells the flow which step is visible after a pop.
class _StepObserver extends NavigatorObserver {
  _StepObserver({required this.onVisible});

  final ValueChanged<String?> onVisible;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onVisible(previousRoute?.settings.name);
  }
}

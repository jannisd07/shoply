import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/data/services/recipe_service.dart';
import 'package:shoply/presentation/screens/recipes/widgets/cooking_mode_chrome.dart';
import 'package:shoply/presentation/screens/recipes/widgets/cooking_mode_logic.dart';
import 'package:shoply/presentation/screens/recipes/widgets/cooking_mode_overview.dart';
import 'package:shoply/presentation/screens/recipes/widgets/cooking_mode_pages.dart';
import 'package:shoply/presentation/screens/recipes/widgets/cooking_mode_progress.dart';
import 'package:shoply/presentation/screens/recipes/widgets/cooking_mode_theme.dart';
import 'package:shoply/presentation/screens/recipes/widgets/cooking_mode_timers.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/confirm_dialog.dart';
import 'package:shoply/presentation/widgets/design/glass_toolbar.dart';
import 'package:shoply/presentation/widgets/design/pro_gate.dart';
import 'package:shoply/presentation/widgets/design/progress.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';

export 'package:shoply/presentation/screens/recipes/widgets/cooking_mode_progress.dart'
    show CookingProgress, cookingProgressProvider;

/// A page spring has landed within half a point.
const Tolerance _pageTolerance = Tolerance(distance: 0.5, velocity: 10);

/// Reduce Motion: a horizontal flick faster than this (points per second)
/// turns the page.
const double _flickVelocity = 300;

/// The Pro id of the cooking mode ([ProGate.run]). Avo Pro since A9
/// (owner, 09.11.2026): the ingredients and step 1 stay free as a real
/// preview, every later step needs Pro (Konzept 18 §9.2).
const String kCookModeFeature = 'cook_mode';

/// Keeps the screen on while the cooking mode is in front.
abstract interface class CookingKeepAwake {
  Future<void> enable();
  Future<void> disable();
}

/// [CookingKeepAwake] through `wakelock_plus`; failures are logged, never
/// shown.
class WakelockCookingKeepAwake implements CookingKeepAwake {
  const WakelockCookingKeepAwake();

  @override
  Future<void> enable() => _guard(WakelockPlus.enable, 'on');

  @override
  Future<void> disable() => _guard(WakelockPlus.disable, 'off');

  static Future<void> _guard(Future<void> Function() call, String what) async {
    try {
      await call();
    } catch (e) {
      debugPrint('⚠️ [COOKING] Screen could not be kept $what: $e');
    }
  }
}

/// How the cooking mode keeps the screen on; overridden in tests.
final cookingKeepAwakeProvider = Provider<CookingKeepAwake>(
  (ref) => const WakelockCookingKeepAwake(),
);

/// Sends a rating from the "Fertig" page; overridden in tests.
final cookingRateRecipeProvider =
    Provider<Future<void> Function(String recipeId, int rating)>(
      (ref) =>
          (id, rating) => RecipeService().rateRecipe(id, rating),
    );

/// Shares a recipe from the "Fertig" page; overridden in tests.
final cookingShareRecipeProvider = Provider<Future<void> Function(Recipe)>(
  (ref) => (recipe) async {
    try {
      await Share.share(RecipeService().getShareText(recipe));
    } catch (e) {
      debugPrint('⚠️ [COOKING] Share failed: $e');
    }
  },
);

/// The cooking mode (R-14, Konzept 13 §16): always black, one page per
/// screen ("Zutaten", every step, "Fertig"), swipe or tap to move, timers
/// per step with a local notification, the screen stays on. Where one
/// stopped is kept for 24 h (§19.2).
///
/// Open it with [openCookingMode].
class CookingModeScreen extends ConsumerStatefulWidget {
  const CookingModeScreen({
    super.key,
    required this.recipe,
    required this.servings,
  });

  /// The recipe in the version shown in the detail.
  final Recipe recipe;

  /// The servings chosen in the detail.
  final int servings;

  @override
  ConsumerState<CookingModeScreen> createState() => _CookingModeScreenState();
}

class _CookingModeScreenState extends ConsumerState<CookingModeScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final List<String> _steps = [
    for (final s in widget.recipe.instructions)
      if (s.trim().isNotEmpty) s.trim(),
  ];
  late final List<List<StepTime>> _times = [
    for (final s in _steps) detectStepTimes(s),
  ];
  late final List<List<int>> _stepIngredients = [
    for (final s in _steps) ingredientsInStep(widget.recipe.ingredients, s),
  ];

  late int _servings = _initialServings(widget.servings);
  int _page = 0;
  final Set<int> _checked = {};
  final Set<int> _visited = {0};
  late int _rating = widget.recipe.userRating ?? 0;
  bool _rateFailed = false;

  String? _userId;
  bool _caloriesOn = false;
  bool _offline = false;

  bool _restoring = true;
  int? _resumedAt;
  bool _showHint = false;
  bool _closing = false;

  late final CookingTimers _timers;
  String _timerShape = '';
  late PageController _pages = PageController();
  late final AnimationController _pageSpring = AnimationController.unbounded(
    vsync: this,
  );
  bool _springing = false;

  late final CookingKeepAwake _keepAwake;
  bool _awake = false;
  late final StateController<AvoScreenContext?> _avoContext;
  AvoScreenContext? _previousContext;
  static const _ownContext = AvoScreenContext(screen: 'recipe');
  late final ProviderContainer _container;

  int get _stepCount => _steps.length;
  int get _donePage => _stepCount + 1;
  int get _pageCount => _stepCount + 2;

  int _initialServings(int value) {
    final fallback = widget.recipe.defaultServings;
    final v = value > 0 ? value : (fallback > 0 ? fallback : 2);
    return v.clamp(kCookingMinServings, kCookingMaxServings);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _container = ProviderScope.containerOf(context, listen: false);
    _timers = CookingTimers(
      alerts: ref.read(cookingTimerAlertsProvider),
      clock: ref.read(cookingClockProvider),
      notificationTitle: (_) => widget.recipe.name,
      notificationBody: (step) => context.tr(
        'recipe_cook_notification_body',
        params: {'n': '${step + 1}'},
      ),
      onFinished: _onTimerFinished,
    )..addListener(_onTimersChanged);
    _pageSpring.addListener(_followSpring);
    _keepAwake = ref.read(cookingKeepAwakeProvider);
    _setAwake(true);
    _avoContext = ref.read(avoScreenContextProvider.notifier);
    _previousContext = _avoContext.state;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _avoContext.state = _ownContext;
    });
    unawaited(_restore());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setAwake(false);
    if (!_closing) unawaited(_save());
    _timers
      ..removeListener(_onTimersChanged)
      ..dispose();
    _pageSpring.dispose();
    _pages.dispose();
    final controller = _avoContext;
    final previous = _previousContext;
    scheduleMicrotask(() {
      if (controller.mounted && controller.state == _ownContext) {
        controller.state = previous;
      }
    });
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    _setAwake(resumed);
    if (resumed) {
      _timers.tick();
    } else if (state == AppLifecycleState.paused) {
      unawaited(_save());
    }
  }

  void _setAwake(bool on) {
    if (on == _awake) return;
    _awake = on;
    unawaited(on ? _keepAwake.enable() : _keepAwake.disable());
  }

  // ---------------------------------------------------------------- state

  Future<void> _restore() async {
    final progress = await CookingProgressStore.load(widget.recipe.id);
    final hintSeen = await CookingProgressStore.hintSeen();
    if (!mounted) return;
    setState(() {
      _restoring = false;
      _showHint = !hintSeen;
      if (progress != null) {
        _page = progress.page.clamp(0, _donePage);
        _checked
          ..clear()
          ..addAll(progress.checked);
        _visited
          ..clear()
          ..addAll({0, ...progress.visited, _page});
        _servings = progress.servings.clamp(
          kCookingMinServings,
          kCookingMaxServings,
        );
        if (_page > 0) _resumedAt = _page;
      }
    });
    if (progress != null) _timers.restore(progress.timers);
  }

  bool get _hasProgress => _page > 0 || _checked.isNotEmpty || !_timers.isEmpty;

  Future<void> _save() async {
    if (_restoring) return;
    final id = widget.recipe.id;
    if (_hasProgress) {
      await CookingProgressStore.save(
        CookingProgress(
          recipeId: id,
          page: _page,
          servings: _servings,
          checked: Set.of(_checked),
          visited: Set.of(_visited),
          timers: _timers.timers,
          savedAt: DateTime.now(),
        ),
      );
    } else {
      await CookingProgressStore.clear(id);
    }
    _container.invalidate(cookingProgressProvider(id));
  }

  void _onTimersChanged() {
    final now = _timers.now;
    final shape = [
      for (final t in _timers.timers)
        '${t.step}:${t.running}:${t.finishedAt(now)}',
    ].join(',');
    if (shape == _timerShape) return;
    _timerShape = shape;
    if (mounted) setState(() {});
    unawaited(_save());
  }

  void _onTimerFinished(int step) {
    if (!mounted) return;
    unawaited(AvoHaptics.warning());
    announceTimerFinished(context, step);
  }

  StepTimerState _timerStateFor(int step) {
    final t = _timers.forStep(step);
    if (t == null) return StepTimerState.none;
    if (t.finishedAt(_timers.now)) return StepTimerState.finished;
    return t.running ? StepTimerState.running : StepTimerState.paused;
  }

  // ------------------------------------------------------------ navigation

  void _followSpring() {
    if (_pages.hasClients) _pages.jumpTo(_pageSpring.value);
  }

  void _goTo(int page) {
    final target = page.clamp(0, _pageCount - 1);
    if (target == _page) return;
    if (_lockedAt(target)) {
      _unlock(() => _goTo(page));
      return;
    }
    _pageSeen(target);
    if (context.reduceMotion || !_pages.hasClients) return;
    final position = _pages.position;
    final to = target * position.viewportDimension;
    _springing = true;
    _pageSpring.value = position.pixels;
    // Completes only when it lands (an interrupted spring never does).
    _pageSpring
        .animateWith(
          SpringSimulation(
            AvoMotion.standard,
            position.pixels,
            to,
            0,
            tolerance: _pageTolerance,
            snapToEnd: true,
          ),
        )
        .then((_) {
          _springing = false;
          if (mounted && _pages.hasClients) _pages.jumpTo(to);
        });
  }

  void _pageSeen(int page) {
    setState(() {
      _page = page;
      _visited.add(page);
      _resumedAt = null;
      if (_showHint) {
        _showHint = false;
        unawaited(CookingProgressStore.markHintSeen());
      }
    });
    unawaited(_save());
  }

  /// A swipe settled on [page] (PageView).
  void _onPageChanged(int page) {
    if (_springing || page == _page) return;
    if (_lockedAt(page)) {
      // A swipe past step 1 without Pro: back to step 1, then the paywall.
      if (_pages.hasClients) _pages.jumpToPage(_page);
      _unlock(() => _goTo(page));
      return;
    }
    unawaited(AvoHaptics.selection());
    _pageSeen(page);
  }

  /// Reduce Motion: pages cross-fade, a horizontal flick still moves.
  void _onFlick(DragEndDetails details) {
    final v = details.primaryVelocity ?? 0;
    if (v.abs() < _flickVelocity) return;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final forward = rtl ? v > 0 : v < 0;
    final next = forward ? _page + 1 : _page - 1;
    if (next < 0 || next >= _pageCount) return;
    unawaited(AvoHaptics.selection());
    _goTo(next);
  }

  /// "Weiter" on step 1 carries the Pro badge (rebuilds on a purchase).
  bool get _proLocked =>
      _page == 1 && _stepCount > 1 && ProGate.isLocked(ref, kCookModeFeature);

  /// Whether [page] is behind the Pro gate right now: every page after
  /// step 1, while the person has no Pro and comes from step 1 or before.
  bool _lockedAt(int page) =>
      page > 1 &&
      _page <= 1 &&
      _stepCount > 1 &&
      ProGate.isLockedNow(ref, kCookModeFeature);

  /// Opens the paywall from the cooking mode and runs [then] after a
  /// purchase; closing the paywall keeps the person on their step.
  void _unlock(VoidCallback then) {
    unawaited(
      ProGate.run(context, ref, feature: kCookModeFeature, action: then),
    );
  }

  void _next() {
    if (_page >= _donePage) {
      unawaited(_finish());
      return;
    }
    _goTo(_page + 1);
  }

  void _back() => _goTo(_page - 1);

  String _nextLabel() {
    if (_page >= _donePage) return context.tr('recipe_cook_close_done');
    if (_page == _stepCount && _stepCount > 0) {
      return context.tr('recipe_cook_finish');
    }
    return context.tr('recipe_cook_next');
  }

  // --------------------------------------------------------------- actions

  bool get _midCooking =>
      (_page >= 1 && _page <= _stepCount) || _timers.anyRunning;

  Future<void> _close() async {
    if (_closing) return;
    if (_page >= _donePage) {
      await _finish();
      return;
    }
    if (_midCooking) {
      final step = _page.clamp(1, math.max(1, _stepCount));
      final leave = await showAvoConfirm(
        context,
        title: context.tr('recipe_cook_leave_title'),
        message: context.tr(
          _timers.anyRunning
              ? 'recipe_cook_leave_message_timer'
              : 'recipe_cook_leave_message',
          params: {'n': '$step'},
        ),
        confirmLabel: context.tr('recipe_cook_leave_confirm'),
        cancelLabel: context.tr('recipe_cook_leave_cancel'),
        destructive: false,
      );
      if (!leave || !mounted) return;
    }
    _closing = true;
    await _save();
    if (mounted) Navigator.of(context).pop();
  }

  /// Done cooking: timers stop, the progress goes.
  Future<void> _finish() async {
    if (_closing) return;
    _closing = true;
    _timers.stopAll();
    await CookingProgressStore.clear(widget.recipe.id);
    _container.invalidate(cookingProgressProvider(widget.recipe.id));
    if (mounted) Navigator.of(context).pop();
  }

  void _startOver() {
    _timers.stopAll();
    setState(() {
      _checked.clear();
      _visited
        ..clear()
        ..add(0);
      _resumedAt = null;
    });
    if (_page == 0) {
      unawaited(_save());
    } else {
      _goTo(0);
    }
  }

  void _toggle(int index) {
    unawaited(AvoHaptics.light());
    setState(() {
      if (!_checked.remove(index)) _checked.add(index);
    });
    unawaited(_save());
  }

  void _toggleAll() {
    final all = widget.recipe.ingredients.length;
    setState(() {
      if (_checked.length >= all) {
        _checked.clear();
      } else {
        _checked.addAll(List.generate(all, (i) => i));
      }
    });
    unawaited(_save());
  }

  Future<void> _openServings() async {
    final next = await openCookingServings(
      context,
      recipe: widget.recipe,
      servings: _servings,
    );
    if (next == null || !mounted || next == _servings) return;
    // Checked ingredients stay checked (Konzept 13 §16.3).
    setState(() => _servings = next);
    unawaited(_save());
  }

  Future<void> _openOverview() async {
    final page = await openCookingOverview(
      context,
      steps: _steps,
      current: _page,
      visited: _visited,
    );
    if (page != null && mounted) _goTo(page);
  }

  void _startTimer(int step, Duration duration) {
    _timers.start(step, duration);
  }

  void _onTimerTap(BuildContext capsuleContext) {
    final list = _timers.timers;
    if (list.isEmpty) return;
    final now = _timers.now;
    final first = list.first;
    if (first.finishedAt(now)) {
      _timers.acknowledge(first.step);
      return;
    }
    final items = <AvoMenuEntry>[];
    for (final t in list) {
      final stepLabel = context.tr(
        'recipe_cook_step_label',
        params: {'n': '${t.step + 1}'},
      );
      final subtitle = t.finishedAt(now)
          ? context.tr(
              'recipe_cook_timer_done_step',
              params: {'step': stepLabel},
            )
          : '$stepLabel · ${formatTimerClock(t.left(now))}';
      if (items.isNotEmpty) items.add(const AvoMenuDivider());
      items
        ..add(
          AvoMenuItem(
            label: context.tr(
              t.running
                  ? 'recipe_cook_timer_pause'
                  : 'recipe_cook_timer_resume',
            ),
            subtitle: subtitle,
            enabled: !t.finishedAt(now),
            onSelected: () =>
                t.running ? _timers.pause(t.step) : _timers.resume(t.step),
          ),
        )
        ..add(
          AvoMenuItem(
            label: context.tr('recipe_cook_timer_plus_minute'),
            onSelected: () => _timers.addMinute(t.step),
          ),
        )
        ..add(
          AvoMenuItem(
            label: context.tr('recipe_cook_timer_stop'),
            destructive: true,
            onSelected: () => _timers.stop(t.step),
          ),
        );
    }
    unawaited(
      showAvoMenu(
        capsuleContext,
        items: items,
        semanticLabel: context.tr('recipe_cook_timers'),
      ),
    );
  }

  Future<void> _rate(int stars) async {
    final before = _rating;
    setState(() {
      _rating = stars;
      _rateFailed = false;
    });
    try {
      await ref.read(cookingRateRecipeProvider)(widget.recipe.id, stars);
    } catch (e) {
      debugPrint('❌ [COOKING] Rating failed: $e');
      if (!mounted) return;
      unawaited(AvoHaptics.error());
      setState(() {
        _rating = before;
        _rateFailed = true;
      });
    }
  }

  // ----------------------------------------------------------------- build

  String _pageLabel(BuildContext context, {required bool short}) {
    if (_page == 0) return context.tr('recipe_cook_page_ingredients');
    if (_page >= _donePage) return context.tr('recipe_cook_page_done');
    return context.tr(
      short ? 'recipe_cook_step_short' : 'recipe_cook_step_of',
      params: {'n': '$_page', 'total': '$_stepCount'},
    );
  }

  double get _progress {
    if (_page >= _donePage) return 1;
    if (_stepCount == 0) return 0;
    return _page / _stepCount;
  }

  List<Ingredient> get _scaled => [
    for (final i in widget.recipe.ingredients)
      scaleIngredient(i, widget.recipe.defaultServings, _servings),
  ];

  Widget _buildPage(BuildContext context, int page) {
    final lang = Localizations.localeOf(context).languageCode;
    final scaled = _scaled;
    if (page == 0) {
      return CookingIngredientsPage(
        ingredients: [
          for (final i in scaled)
            CookingIngredientLine(
              name: i.name,
              amount: formatIngredientAmount(i, lang),
            ),
        ],
        servings: _servings,
        checked: _checked,
        onToggle: _toggle,
        onToggleAll: _toggleAll,
      );
    }
    if (page >= _donePage) {
      final recipe = widget.recipe;
      final canLog = _caloriesOn && (recipe.nutrition?.hasData ?? false);
      return CookingDonePage(
        rating: _rating,
        canRate: recipe.id.isNotEmpty && recipe.authorId != _userId,
        onRate: _rate,
        rateFailed: _rateFailed,
        offline: _offline,
        onShare: () => unawaited(ref.read(cookingShareRecipeProvider)(recipe)),
        onLog: canLog ? () => unawaited(openLogRecipe(context, recipe)) : null,
      );
    }
    final step = page - 1;
    return CookingStepPage(
      number: page,
      text: _steps[step],
      ingredients: [
        for (final i in _stepIngredients[step])
          formatIngredientLine(scaled[i], lang),
      ],
      times: _times[step],
      timerState: _timerStateFor(step),
      onStartTimer: (d) => _startTimer(step, d),
    );
  }

  Widget _buildPages(BuildContext context) {
    if (_restoring) return const SizedBox.expand();
    if (context.reduceMotion) {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: _onFlick,
        child: AnimatedSwitcher(
          duration: AvoMotion.fadeReduced,
          child: KeyedSubtree(
            key: ValueKey(_page),
            child: _buildPage(context, _page),
          ),
        ),
      );
    }
    if (!_pages.hasClients && _pages.initialPage != _page) {
      final old = _pages;
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
      _pages = PageController(initialPage: _page);
    }
    return Listener(
      onPointerDown: (_) {
        if (!_springing) return;
        _pageSpring.stop();
        _springing = false;
      },
      child: PageView.builder(
        controller: _pages,
        physics: const BouncingScrollPhysics(),
        onPageChanged: _onPageChanged,
        itemCount: _pageCount,
        itemBuilder: _buildPage,
      ),
    );
  }

  Map<CustomSemanticsAction, VoidCallback> _semanticActions(
    BuildContext context,
  ) {
    final step = _page - 1;
    final first = step >= 0 && step < _stepCount && _times[step].isNotEmpty
        ? _times[step].first
        : null;
    return {
      if (_page < _donePage)
        CustomSemanticsAction(label: context.tr('recipe_cook_next_step')):
            _next,
      if (_page > 0)
        CustomSemanticsAction(label: context.tr('recipe_cook_previous')): _back,
      if (first != null && _timerStateFor(step) == StepTimerState.none)
        CustomSemanticsAction(
          label: context.tr('recipe_cook_start_timer'),
        ): () =>
            _startTimer(step, first.duration),
    };
  }

  @override
  Widget build(BuildContext context) {
    // Watched here, not in the page builder (which runs during layout).
    _userId = ref.watch(authUserIdProvider);
    _caloriesOn = ref.watch(moduleEnabledProvider(AppModule.calories));
    _offline = ref.watch(isOfflineProvider);
    return CookingModeTheme(
      child: Builder(
        builder: (context) {
          final colors = context.colors;
          final bottomSafe = MediaQuery.paddingOf(context).bottom;
          return PopScope<Object?>(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) unawaited(_close());
            },
            child: ColoredBox(
              color: colors.background,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: GlassToolbar.topOffset(context)),
                  CookingTopBar(
                    recipeName: widget.recipe.name,
                    pageLabel: _pageLabel(context, short: false),
                    shortPageLabel: _pageLabel(context, short: true),
                    servings: _servings,
                    onClose: () => unawaited(_close()),
                    onServings: () => unawaited(_openServings()),
                    onOverview: () => unawaited(_openOverview()),
                  ),
                  const SizedBox(height: AvoSpacing.m),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AvoSpacing.screen,
                    ),
                    child: ProgressLine(
                      value: _progress,
                      semanticLabel: context.tr('common_progress'),
                      semanticValue: _pageLabel(context, short: false),
                    ),
                  ),
                  if (_resumedAt != null)
                    _ResumeRow(step: _resumedAt!, onStartOver: _startOver)
                  else if (_showHint)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AvoSpacing.screen,
                        AvoSpacing.s,
                        AvoSpacing.screen,
                        0,
                      ),
                      child: Text(
                        context.tr('recipe_cook_first_hint'),
                        style: context.text(
                          AvoTextStyle.footnote,
                          color: colors.secondaryLabel,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Semantics(
                            customSemanticsActions: _semanticActions(context),
                            child: _buildPages(context),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: ScrollEdgeFade(
                            height: AvoSpacing.xl,
                            color: colors.background,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: RotatedBox(
                            quarterTurns: 2,
                            child: ScrollEdgeFade(
                              height: AvoSpacing.xl,
                              color: colors.background,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AvoSpacing.s),
                  CookingBottomBar(
                    onBack: _page > 0 ? _back : null,
                    nextLabel: _nextLabel(),
                    onNext: _next,
                    nextIsPro: _proLocked,
                    timer: _timers.isEmpty
                        ? null
                        : CookingTimerCapsule(
                            timers: _timers,
                            onTap: _onTimerTap,
                          ),
                  ),
                  SizedBox(height: math.max(bottomSafe, AvoSpacing.l)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// "Weiter bei Schritt 3 · Von vorn", once after reopening (Konzept 13
/// §16.1).
class _ResumeRow extends StatelessWidget {
  const _ResumeRow({required this.step, required this.onStartOver});

  final int step;
  final VoidCallback onStartOver;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AvoSpacing.screen,
        AvoSpacing.xs,
        AvoSpacing.screen,
        0,
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AvoSpacing.m,
        children: [
          Text(
            context.tr('recipe_cook_resumed', params: {'n': '$step'}),
            style: context.text(
              AvoTextStyle.subhead,
              color: colors.secondaryLabel,
            ),
          ),
          AppButton.plain(
            label: context.tr('recipe_cook_start_over'),
            onPressed: onStartOver,
          ),
        ],
      ),
    );
  }
}

/// Opens the cooking mode for [recipe] full screen above the tab bar (a
/// cover from the bottom; Reduce Motion: a cross-fade). The one entry point
/// for every screen.
Future<void> openCookingMode(
  BuildContext context, {
  required Recipe recipe,
  required int servings,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  Widget page(BuildContext _) =>
      CookingModeScreen(recipe: recipe, servings: servings);
  final PageRoute<void> route = context.reduceMotion
      ? PageRouteBuilder<void>(
          fullscreenDialog: true,
          transitionDuration: AvoMotion.fadeReduced,
          reverseTransitionDuration: AvoMotion.fadeReduced,
          pageBuilder: (context, _, _) => page(context),
          transitionsBuilder: (context, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        )
      : CupertinoPageRoute<void>(builder: page, fullscreenDialog: true);
  return navigator.push<void>(route);
}

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/services/calorie_day_store.dart' show entriesByMeal;
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_date_menu.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_entry_actions.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_format.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_meal_section.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_nav_rows.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_no_goal.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_water.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_week_section.dart';
import 'package:shoply/presentation/screens/calories/widgets/calories_today_summary.dart';
import 'package:shoply/presentation/state/calorie_diary_provider.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/glass_icon_button.dart';
import 'package:shoply/presentation/widgets/design/glass_toolbar.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';
import 'package:shoply/presentation/widgets/design/skeleton.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:shoply/routes/route_paths.dart';

/// Space between the toolbar row and the large title (D2: content at 106).
const double _kTitleGap = AvoSpacing.s; // D2
const double _kNavGlyph = 17; // D2 row symbols

/// A day change commits when the projected swipe passes this share of the
/// width (Apple's projection, `AvoMotion.project`).
const double _kSwipeCommit = 1 / 3;

/// The outgoing day counts as gone once it is within a point of off screen.
const Tolerance _kOffscreenTolerance = Tolerance(distance: 1, velocity: 50);

/// The calorie diary (`kalorien.md` S1, S1a, S2, S12): how much is left
/// today, what was eaten per meal, water, the week and the way to the other
/// calorie screens. A push screen in the Home tab at `/calories`
/// (`?date=YYYY-MM-DD`, `?focus=water`).
///
/// Local first: the day stored on the device is on screen in the first
/// frame; the server is asked afterwards and rows roll in place. Without a
/// goal it shows S1a (only when there really is none, never on a network
/// error). Swiping the date line or the "Heute" group changes the day 1:1
/// with the finger; VoiceOver changes it by swiping up or down on the group.
class CaloriesDiaryScreen extends ConsumerStatefulWidget {
  const CaloriesDiaryScreen({super.key, this.initialDateKey, this.focusWater = false});

  /// `?date=`; null opens today.
  final String? initialDateKey;

  /// `?focus=water`: scrolls the water row into the middle.
  final bool focusWater;

  @override
  ConsumerState<CaloriesDiaryScreen> createState() => _CaloriesDiaryScreenState();
}

class _CaloriesDiaryScreenState extends ConsumerState<CaloriesDiaryScreen>
    with SingleTickerProviderStateMixin {
  /// The shown day; null follows today.
  String? _dateKey;
  final _waterKey = GlobalKey();
  late final AnimationController _swipe = AnimationController.unbounded(vsync: this);
  double _swipeWidth = 1;

  @override
  void initState() {
    super.initState();
    _dateKey = widget.initialDateKey;
    _focusWaterPending = widget.focusWater;
  }

  /// `?focus=water` waits until the diary (not a placeholder) is on screen.
  bool _focusWaterPending = false;

  /// A new `?date=` or `?focus=water` on the open route (deep link, Home
  /// tile while the diary is open) takes effect.
  @override
  void didUpdateWidget(CaloriesDiaryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialDateKey != oldWidget.initialDateKey) _dateKey = widget.initialDateKey;
    if (widget.focusWater && !oldWidget.focusWater) _focusWaterPending = true;
  }

  @override
  void dispose() {
    _swipe.dispose();
    super.dispose();
  }

  void _focusWater() {
    final target = _waterKey.currentContext;
    if (target == null || !mounted) return;
    _focusWaterPending = false;
    Scrollable.ensureVisible(target, alignment: 0.5);
  }

  String get _today => ref.read(calorieTodayKeyProvider);

  String _shown(String today) {
    final key = _dateKey;
    if (key == null || key.compareTo(today) >= 0) return today;
    return key;
  }

  void _setDay(String key) {
    final today = _today;
    setState(() => _dateKey = key.compareTo(today) >= 0 ? null : key);
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RoutePaths.home);
    }
  }

  void _openAdd(String shown, {MealType? meal}) {
    final params = <String, String>{
      'meal': (meal ?? mealForTime(ref.read(calorieClockProvider)())).dbValue,
      if (shown != _today) 'date': shown,
    };
    context.push(Uri(path: '${RoutePaths.calories}/add', queryParameters: params).toString());
  }

  Future<void> _refresh(String shown) async {
    ref.invalidate(nutritionGoalProvider);
    ref.invalidate(calorieWeekServerProvider(calorieWeekStartKey(shown)));
    await ref.read(calorieDayProvider(shown).notifier).refresh();
  }

  void _openDateMenu(BuildContext anchor, String shown) {
    final today = _today;
    showCalorieDateMenu(
      anchor,
      shownKey: shown,
      todayKey: today,
      kcalByDay: calorieMenuDaysKcal(ref, today),
      onPick: _setDay,
    );
  }

  // ── Swiping the day ──────────────────────────────────────────────────

  bool _canGoNext(String shown) => shown.compareTo(_today) < 0;

  void _dragUpdate(DragUpdateDetails d, String shown) {
    var next = _swipe.value + d.delta.dx;
    // Left of today there is no next day: rubber band.
    if (next < 0 && !_canGoNext(shown)) {
      final raw = (_swipe.value < 0 ? _rawOvershoot : 0) + d.delta.dx;
      _rawOvershoot = raw;
      next = AvoMotion.rubberBand(raw, _swipeWidth);
    } else {
      _rawOvershoot = 0;
    }
    _swipe.value = next;
  }

  double _rawOvershoot = 0;

  Future<void> _dragEnd(DragEndDetails d, String shown) async {
    final velocity = d.velocity.pixelsPerSecond.dx;
    final projected = _swipe.value + AvoMotion.project(velocity);
    final width = _swipeWidth;
    _rawOvershoot = 0;
    final towardsPrevious = projected > width * _kSwipeCommit;
    final towardsNext = projected < -width * _kSwipeCommit && _canGoNext(shown);
    if (!towardsPrevious && !towardsNext) {
      if (context.reduceMotion) {
        _swipe.value = 0;
        return;
      }
      await _swipe.animateWith(SpringSimulation(AvoMotion.fling, _swipe.value, 0, velocity));
      return;
    }
    final target = shiftCalorieDayKey(shown, towardsPrevious ? -1 : 1);
    if (context.reduceMotion) {
      _swipe.value = 0;
      unawaited(AvoHaptics.selection());
      _setDay(target);
      return;
    }
    final out = towardsPrevious ? width : -width;
    // The old day only has to leave the screen: done within a point.
    await _swipe.animateWith(
      SpringSimulation(AvoMotion.fling, _swipe.value, out, velocity, tolerance: _kOffscreenTolerance),
    );
    if (!mounted) return;
    unawaited(AvoHaptics.selection());
    _setDay(target);
    _swipe.value = -out;
    await _swipe.animateWith(SpringSimulation(AvoMotion.fling, -out, 0, velocity));
  }

  void _step(String shown, int days) {
    final target = shiftCalorieDayKey(shown, days);
    if (days > 0 && !_canGoNext(shown)) return;
    unawaited(AvoHaptics.selection());
    _setDay(target);
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(calorieTodayKeyProvider);
    final shown = _shown(today);
    final goal = ref.watch(calorieGoalStateProvider);
    final withoutGoal = ref.watch(calorieWithoutGoalProvider);
    final dayState = ref.watch(calorieDiaryDayProvider(shown));
    final offline = ref.watch(isOfflineProvider);
    // Started early so the date menu has the week's kcal when it opens.
    ref.watch(calorieRecentDayTotalsProvider(today));
    // Back online: load again by itself (S1 "lädt selbst, sobald online").
    ref.listen<bool>(isOfflineProvider, (was, now) {
      if (was == true && !now) _refresh(shown);
    });

    final title = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
      child: Semantics(
        header: true,
        child: Text(context.tr('cal_title'), style: context.text(AvoTextStyle.largeTitle)),
      ),
    );

    final List<Widget> body;
    if (goal.status == CalorieGoalStatus.none && !withoutGoal) {
      body = [
        const SizedBox(height: AvoSpacing.l),
        CalorieNoGoalState(onTurnedOff: _back),
      ];
    } else if (dayState.isUnknown && (dayState.error != null || goal.status == CalorieGoalStatus.error)) {
      // Only the groups give way: the date line stays, so another day (or
      // "Heute") can still be chosen.
      body = [
        _dateLine(shown, today),
        offline
            ? _message(context, 'cal_diary_offline_empty')
            : _message(context, 'cal_diary_error', onRetry: () => _refresh(shown)),
      ];
    } else if (dayState.isUnknown || goal.status == CalorieGoalStatus.loading) {
      body = [
        _dateLine(shown, today),
        const SizedBox(height: AvoSpacing.s),
        InsetSection(children: [
          SkeletonSection(rows: 3, withImage: false, loadingLabel: context.tr('cal_loading')),
        ]),
        const SizedBox(height: AvoSpacing.section),
        InsetSection(children: [
          SkeletonSection(rows: 2, withImage: false, loadingLabel: context.tr('cal_loading')),
        ]),
      ];
    } else {
      body = _diary(context, shown: shown, today: today, goal: goal, dayState: dayState, offline: offline);
      if (_focusWaterPending) WidgetsBinding.instance.addPostFrameCallback((_) => _focusWater());
    }

    return ColoredBox(
      color: context.colors.background,
      child: Stack(
        children: [
          CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              CupertinoSliverRefreshControl(onRefresh: () => _refresh(shown)),
              SliverPadding(
                padding: EdgeInsets.only(
                  top: GlassToolbar.topOffset(context) + AvoSizes.toolbarButton + _kTitleGap,
                  bottom: ShellInsets.bottom(context),
                ),
                // Not lazy: the day is a few dozen rows, and `?focus=water`
                // needs the water row laid out.
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [title, ...body],
                  ),
                ),
              ),
            ],
          ),
          const Positioned(top: 0, left: 0, right: 0, child: ScrollEdgeFade()),
          Positioned(
            top: GlassToolbar.topOffset(context),
            left: 0,
            right: 0,
            child: GlassToolbar(
              leading: GlassIconButton(
                icon: const AvoIcon(AvoIcons.chevronBack),
                semanticLabel: context.tr('back'),
                onPressed: _back,
              ),
              trailing: [
                GlassIconButton(
                  icon: const AvoIcon(AvoIcons.plus),
                  semanticLabel: context.tr('cal_add_food'),
                  tinted: true,
                  onPressed: () => _openAdd(shown),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _message(BuildContext context, String key, {VoidCallback? onRetry}) {
    return Padding(
      padding: const EdgeInsets.only(top: AvoSpacing.l),
      child: StatusRow(
        kind: onRetry == null ? StatusKind.offline : StatusKind.sectionError,
        text: context.tr(key),
        actionLabel: onRetry == null ? null : context.tr('retry'),
        onAction: onRetry,
      ),
    );
  }

  Widget _dateLine(String shown, String today) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
        child: CalorieDateLine(
          shownKey: shown,
          todayKey: today,
          onOpenMenu: (anchor) => _openDateMenu(anchor, shown),
          onToday: () => _setDay(today),
        ),
      );

  List<Widget> _diary(
    BuildContext context, {
    required String shown,
    required String today,
    required CalorieGoalState goal,
    required CalorieDayState dayState,
    required bool offline,
  }) {
    final day = dayState.day ?? CalorieDay(dateKey: shown);
    final isToday = shown == today;
    final numbers = CalorieDayNumbers(day: day, goal: goal.goal, isToday: isToday);
    final pending = day.syncStates.values.where((s) => s == CalorieSyncState.pending).length;
    final actions = CalorieEntryActions(context: context, ref: ref);

    final Widget? status = offline
        ? StatusRow(kind: StatusKind.offline, text: context.tr('cal_status_offline'))
        : pending > 0 && dayState.error != null
            ? StatusRow(
                kind: StatusKind.pending,
                text: context.tr(pending == 1 ? 'cal_status_pending_one' : 'cal_status_pending_other',
                    params: {'n': '$pending'}),
              )
            : null;

    final goalFailed = goal.status == CalorieGoalStatus.error;
    final summaryRows = <Widget>[
      CaloriesDiarySummary(
        numbers: numbers,
        // The numbers are one adjustable element; the macros below it are
        // their own elements (S1 Barrierefreiheit).
        wrapLine: (line) => _SwipeSemantics(
          label: numbers.spoken(context, title: _summaryTitle(context, shown, today), withMacros: false),
          value: context.diaryDateSpoken(shown, today),
          canGoNext: _canGoNext(shown),
          nextLabel: _canGoNext(shown) ? context.diaryDateSpoken(shiftCalorieDayKey(shown, 1), today) : null,
          previousLabel: context.diaryDateSpoken(shiftCalorieDayKey(shown, -1), today),
          onNext: () => _step(shown, 1),
          onPrevious: () => _step(shown, -1),
          child: line,
        ),
      ),
      if (goalFailed)
        // The goal could not be loaded: eaten numbers only, and why. Never
        // "Ziel festlegen", an error is not "no goal".
        Padding(
          padding: const EdgeInsets.only(bottom: AvoSpacing.s),
          child: StatusRow(
            kind: StatusKind.sectionError,
            text: context.tr('cal_goal_error'),
            actionLabel: context.tr('retry'),
            onAction: () => _refresh(shown),
          ),
        )
      else if (numbers.goalKcal == null)
        NavRow(
          title: context.tr('cal_set_goal_row'),
          leading: AvoIcon(AvoIcons.plus, size: _kNavGlyph, color: context.colors.tint),
          onTap: () => context.push('${RoutePaths.calories}/goals/setup?from=empty'),
        )
      else if (isToday && (numbers.remaining ?? 0) >= 150 && _ideasCount(numbers.remaining!) != 0)
        _IdeasRow(count: _ideasCount(numbers.remaining!)),
    ];

    final byMeal = entriesByMeal(day);
    return [
      // The date line and the "Heute" group move together under the finger.
      LayoutBuilder(builder: (context, constraints) {
        _swipeWidth = constraints.maxWidth;
        return GestureDetector(
          onHorizontalDragStart: (_) => _swipe.stop(),
          onHorizontalDragUpdate: (d) => _dragUpdate(d, shown),
          onHorizontalDragEnd: (d) => _dragEnd(d, shown),
          child: AnimatedBuilder(
            animation: _swipe,
            builder: (context, child) => Transform.translate(offset: Offset(_swipe.value, 0), child: child),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _dateLine(shown, today),
                if (status != null) status,
                const SizedBox(height: AvoSpacing.s),
                InsetSection(children: summaryRows),
              ],
            ),
          ),
        );
      }),
      for (final meal in kMealOrder)
        MealSection(
          meal: meal,
          entries: byMeal[meal]!,
          syncStateOf: day.syncStateOf,
          actionsFor: (e) => actions.forEntry(e, pastDay: !isToday),
          onLog: () => _openAdd(shown, meal: meal),
        ),
      KeyedSubtree(
        key: _waterKey,
        child: InsetSection(
          header: context.tr('cal_water'),
          children: [WaterRow(dateKey: shown, day: dayState.day, followsToday: _dateKey == null)],
        ),
      ),
      const SizedBox(height: AvoSpacing.section),
      CalorieWeekSection(
        dateKey: shown,
        todayKey: today,
        goalKcal: numbers.goalKcal,
        onOpenWeek: () => context.push('${RoutePaths.calories}/week'),
      ),
      const SizedBox(height: AvoSpacing.section),
      CalorieNavRows(goalKcal: numbers.goalKcal),
    ];
  }

  /// Fitting recipes for [remaining] kcal; null while they load.
  int? _ideasCount(int remaining) =>
      ref.watch(calorieIdeasProvider(calorieIdeasBucket(remaining))).valueOrNull?.length;

  String _summaryTitle(BuildContext context, String shown, String today) => shown == today
      ? context.tr('cal_summary_title_today')
      : context.tr('cal_summary_title_day', params: {'date': context.longDate(parseCalorieDayKey(shown))});
}

/// The "Heute" group as one adjustable VoiceOver element: swiping up shows
/// the next day, down the previous one (§3.10).
class _SwipeSemantics extends StatelessWidget {
  const _SwipeSemantics({
    required this.label,
    required this.value,
    required this.canGoNext,
    required this.nextLabel,
    required this.previousLabel,
    required this.onNext,
    required this.onPrevious,
    required this.child,
  });

  final String label;

  /// The shown day: VoiceOver reads it after the numbers and says the new
  /// one after a swipe up or down.
  final String value;
  final bool canGoNext;
  final String? nextLabel;
  final String previousLabel;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: label,
      value: value,
      hint: context.tr('cal_day_swipe_hint'),
      increasedValue: nextLabel,
      decreasedValue: previousLabel,
      onIncrease: canGoNext ? onNext : null,
      onDecrease: onPrevious,
      excludeSemantics: true,
      child: child,
    );
  }
}

/// "Was passt noch?" with the number of fitting recipes (only today with at
/// least 150 kcal left); opens the ideas. [count] is null while loading.
class _IdeasRow extends StatelessWidget {
  const _IdeasRow({required this.count});

  final int? count;

  @override
  Widget build(BuildContext context) {
    final n = count;
    return NavRow(
      title: context.tr('cal_what_fits'),
      value: n == null
          ? null
          : context.tr(n == 1 ? 'cal_recipes_count_one' : 'cal_recipes_count_other', params: {'n': '$n'}),
      leading: AvoIcon(AvoIcons.forkKnife, size: _kNavGlyph, color: context.colors.secondaryLabel),
      onTap: () => context.push('${RoutePaths.calories}/ideas'),
    );
  }
}

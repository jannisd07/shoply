import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/services/calorie_recipe_nudge_service.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_format.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_ring.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_water.dart';
import 'package:shoply/presentation/screens/calories/widgets/calories_today_summary.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/calorie_diary_provider.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/hint_row.dart';
import 'package:shoply/presentation/widgets/design/home_card.dart';
import 'package:shoply/presentation/widgets/design/item_row.dart';
import 'package:shoply/routes/route_paths.dart';

// Home sections of the calories module (`kalorien.md` S0): the card
// "Kalorien heute", the tile "Wasser heute" and the evening hint. Each shows
// the day stored on this device in the first frame, so nothing on Home
// jumps in later, and renders nothing while the module is off.

/// Whether the module is on and someone is signed in: then the card and the
/// tile always have something to show (numbers, "Ziel einrichten", or the
/// "could not load" line). Reads the module first, so with the module off
/// nothing else is asked.
bool _caloriesShown(Ref ref) =>
    ref.watch(moduleEnabledProvider(AppModule.calories)) && ref.watch(authUserIdProvider) != null;

/// "Kalorien heute" has content (synchronous, for Home's first frame).
final homeCaloriesHasContentProvider = Provider<bool>(_caloriesShown);

/// "Wasser heute" has content (synchronous, for Home's first frame).
final homeWaterHasContentProvider = Provider<bool>(_caloriesShown);

String _hintHiddenKey(String userId) => 'cal_hint_hidden_v1_$userId';

/// The evening hint shows from 16:00 until 21:00 (S0).
const int _kHintFrom = 16;
const int _kHintUntil = 21;

/// The evening hint "Noch 640 kcal heute. Ideen fürs Abendessen": 16 to 21
/// o'clock, a goal, at least 150 kcal left, fitting recipes known on this
/// device for today, and not hidden today. Decided in the first frame.
final homeCalorieIdeasHintHasContentProvider = Provider<bool>((ref) {
  if (!_caloriesShown(ref)) return false;
  final now = ref.watch(calorieClockProvider)();
  // Decided again at 16:00, 21:00 and midnight, also when Home stays open.
  final next = [
    DateTime(now.year, now.month, now.day, _kHintFrom),
    DateTime(now.year, now.month, now.day, _kHintUntil),
    DateTime(now.year, now.month, now.day + 1),
  ].firstWhere((t) => t.isAfter(now));
  final timer = Timer(next.difference(now), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  if (now.hour < _kHintFrom || now.hour >= _kHintUntil) return false;
  final left = _remainingToday(ref);
  if (left == null || left < CalorieRecipeNudgeService.minRemainingCalories) return false;
  if ((ref.watch(calorieStoredIdeasCountProvider) ?? 0) == 0) return false;
  final userId = ref.watch(authUserIdProvider)!;
  final prefs = ref.watch(calorieSharedPreferencesProvider).valueOrNull;
  final today = ref.watch(calorieTodayKeyProvider);
  return prefs?.getString(_hintHiddenKey(userId)) != today && ref.watch(_hintHiddenOnProvider) != today;
});

/// The day the hint was hidden in this session (prefs are read once).
final _hintHiddenOnProvider = StateProvider<String?>((ref) => null);

int? _remainingToday(Ref ref) {
  final goal = ref.watch(calorieGoalStateProvider).kcal;
  final day = ref.watch(calorieDayProvider(ref.watch(calorieTodayKeyProvider))).day;
  if (goal == null || day == null) return null;
  return goal - day.totals.calories;
}

/// The Home card "Kalorien heute" (S0, D2-FuerDich §6).
class HomeCaloriesToday extends ConsumerWidget {
  const HomeCaloriesToday({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(homeCaloriesHasContentProvider)) return const SizedBox.shrink();
    final today = ref.watch(calorieTodayKeyProvider);
    final goal = ref.watch(calorieGoalStateProvider);
    final dayState = ref.watch(calorieDayProvider(today));
    final day = dayState.day;

    void retry() {
      ref.invalidate(nutritionGoalProvider);
      ref.read(calorieDayProvider(today).notifier).refresh();
    }

    // Back online: load again by itself (S0 "Wartet / offline").
    ref.listen<bool>(isOfflineProvider, (was, now) {
      if (was == true && !now) retry();
    });

    void openDiary() => context.push(RoutePaths.calories);
    void openAdd() => context.push(Uri(
          path: '${RoutePaths.calories}/add',
          queryParameters: {'meal': mealForTime(ref.read(calorieClockProvider)()).dbValue},
        ).toString());

    final addButton = AppButton.primary(
      label: context.tr('cal_add_food'),
      icon: const AvoIcon(AvoIcons.plus),
      expand: true,
      onPressed: openAdd,
    );

    if (day == null && (dayState.error != null || goal.status == CalorieGoalStatus.error)) {
      return AvoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const CalorieKicker(),
            Text(context.tr('cal_today'), style: context.text(AvoTextStyle.title3)),
            const SizedBox(height: AvoSpacing.s),
            Text(context.tr('cal_home_error'), style: context.text(AvoTextStyle.subhead)),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: AppButton.plain(label: context.tr('retry'), onPressed: retry),
            ),
            const SizedBox(height: AvoSpacing.s),
            addButton,
          ],
        ),
      );
    }

    if (day == null || goal.status == CalorieGoalStatus.loading) {
      return AvoCard(child: _CardSkeleton(label: context.tr('cal_loading')));
    }

    if (goal.status == CalorieGoalStatus.error) {
      // The day is known, the goal is not: what was eaten, and why the rest
      // is missing. Never "Ziel einrichten" (an error is not "no goal").
      final eaten = day.totals.calories;
      return AvoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              container: true,
              button: true,
              label: context.tr('cal_summary_a11y_eaten',
                  params: {'title': context.tr('cal_summary_title_today'), 'eaten': context.kcal(eaten)}),
              hint: context.tr('cal_opens_diary'),
              onTap: openDiary,
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: openDiary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CalorieKicker(),
                    Text(context.tr('cal_today'), style: context.text(AvoTextStyle.title3)),
                    Text(
                      '${context.kcal(eaten)} ${context.tr('cal_unit_eaten')}',
                      style: context.text(AvoTextStyle.footnote, color: context.colors.secondaryLabel),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AvoSpacing.s),
            Text(context.tr('cal_goal_error'), style: context.text(AvoTextStyle.subhead)),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: AppButton.plain(label: context.tr('retry'), onPressed: retry),
            ),
            const SizedBox(height: AvoSpacing.s),
            addButton,
          ],
        ),
      );
    }

    if (goal.status != CalorieGoalStatus.set) {
      final eaten = day.hasFoodEntries ? day.totals.calories : null;
      return AvoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              container: true,
              button: true,
              label: [
                context.tr('cal_summary_title_today'),
                if (eaten != null)
                  context.tr('cal_summary_a11y_eaten',
                      params: {'title': context.tr('cal_today'), 'eaten': context.kcal(eaten)}),
              ].join('. '),
              hint: context.tr('cal_opens_diary'),
              onTap: openDiary,
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: openDiary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CalorieKicker(),
                    Text(context.tr('cal_today'), style: context.text(AvoTextStyle.title3)),
                    if (eaten != null)
                      Text(
                        '${context.kcal(eaten)} ${context.tr('cal_unit_eaten')}',
                        style: context.text(AvoTextStyle.footnote, color: context.colors.secondaryLabel),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AvoSpacing.s),
            Text(context.tr('cal_home_no_goal'), style: context.text(AvoTextStyle.subhead)),
            const SizedBox(height: AvoSpacing.l),
            AppButton.primary(
              label: context.tr('cal_set_goal'),
              expand: true,
              onPressed: () => context.push('${RoutePaths.calories}/goals/setup?from=empty'),
            ),
          ],
        ),
      );
    }

    final numbers = CalorieDayNumbers(day: day, goal: goal.goal, isToday: true);
    final remaining = numbers.remaining ?? 0;
    return AvoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            container: true,
            button: true,
            label: numbers.spoken(context, title: context.tr('cal_summary_title_today')),
            hint: context.tr('cal_opens_diary'),
            onTap: openDiary,
            excludeSemantics: true,
            child: PressableScale(
              onPressed: openDiary,
              child: CaloriesCardSummary(numbers: numbers),
            ),
          ),
          const SizedBox(height: AvoSpacing.l),
          addButton,
          if (remaining >= CalorieRecipeNudgeService.minRemainingCalories) _IdeasFooter(remaining: remaining),
        ],
      ),
    );
  }
}

const double _kMiniImage = 20; // D2
const double _kHintGlyph = 17; // D2
const double _kSkeletonBar = 0.6; // bar height per line height
const double _kMiniRadius = 6; // D2
const double _kMiniBorder = 2; // D2
const double _kMiniOverlap = 4; // D2

/// "Was passt noch? 6 Rezepte" with two mini recipe pictures (S0 #6); the
/// whole line is a 44 pt target to the ideas. Nothing when no recipe fits.
class _IdeasFooter extends ConsumerWidget {
  const _IdeasFooter({required this.remaining});

  final int remaining;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ideas = ref.watch(calorieIdeasProvider(calorieIdeasBucket(remaining))).valueOrNull;
    if (ideas == null || ideas.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    final count = context.tr(
      ideas.length == 1 ? 'cal_recipes_count_one' : 'cal_recipes_count_other',
      params: {'n': '${ideas.length}'},
    );
    final text = '${context.tr('cal_what_fits')} $count';
    final pictures = [
      for (final s in ideas.take(2))
        if (s.recipe.imageUrl.isNotEmpty) s.recipe.imageUrl,
    ];
    void open() => context.push('${RoutePaths.calories}/ideas');

    return Padding(
      padding: const EdgeInsets.only(top: AvoSpacing.m),
      child: Semantics(
        container: true,
        button: true,
        label: text,
        onTap: open,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: open,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
            child: Row(
              children: [
                if (pictures.isNotEmpty && !context.isAccessibilityText) ...[
                  for (var i = 0; i < pictures.length; i++)
                    Transform.translate(
                      offset: Offset(-_kMiniOverlap * i, 0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(_kMiniRadius + _kMiniBorder),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(_kMiniBorder),
                          child: SizedBox.square(
                            dimension: _kMiniImage,
                            child: ItemThumb(image: NetworkImage(pictures[i]), radius: _kMiniRadius),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: AvoSpacing.s),
                ],
                Expanded(
                  child: Text(text, style: context.text(AvoTextStyle.footnote, color: colors.secondaryLabel)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Calm shapes in the card's form for the very first start (no spinner, no
/// animation); one VoiceOver element "Wird geladen".
class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final fill = context.colors.fill;
    final bar = context.typography.lineHeightOf(AvoTextStyle.footnote) * _kSkeletonBar;
    Widget line(double widthFactor) => FractionallySizedBox(
          alignment: AlignmentDirectional.centerStart,
          widthFactor: widthFactor,
          child: Container(
            height: bar,
            decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(bar / 2)),
          ),
        );
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          line(0.3),
          const SizedBox(height: AvoSpacing.s),
          line(0.5),
          const SizedBox(height: AvoSpacing.l),
          Row(
            children: [
              Container(
                width: kCalorieRingHome,
                height: kCalorieRingHome,
                decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
              ),
              const SizedBox(width: AvoSpacing.l),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    line(0.9),
                    const SizedBox(height: AvoSpacing.l),
                    line(0.8),
                    const SizedBox(height: AvoSpacing.l),
                    line(0.7),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AvoSpacing.l),
          Container(
            height: AvoSizes.hitTarget,
            decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(AvoSizes.hitTarget / 2)),
          ),
        ],
      ),
    );
  }
}

/// The Home tile "Wasser heute" (S0, S12).
class HomeWaterTile extends ConsumerWidget {
  const HomeWaterTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(homeWaterHasContentProvider)) return const SizedBox.shrink();
    final today = ref.watch(calorieTodayKeyProvider);
    final day = ref.watch(calorieDayProvider(today)).day;
    return WaterTile(day: day);
  }
}

/// The evening hint "Noch 640 kcal heute. Ideen fürs Abendessen" (S0
/// `CalorieIdeasHint`); waits for its place on Home (request A-H1).
class HomeCalorieIdeasHint extends ConsumerWidget {
  const HomeCalorieIdeasHint({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(homeCalorieIdeasHintHasContentProvider)) return const SizedBox.shrink();
    final goal = ref.watch(calorieGoalStateProvider).kcal ?? 0;
    final today = ref.watch(calorieTodayKeyProvider);
    final eaten = ref.watch(calorieDayProvider(today)).day?.totals.calories ?? 0;
    return HintRow(
      text: context.tr('cal_hint_ideas', params: {'kcal': context.kcal(goal - eaten)}),
      leading: Icon(CupertinoIcons.flame, size: _kHintGlyph, color: context.colors.secondaryLabel),
      onTap: () => context.push('${RoutePaths.calories}/ideas'),
      dismissLabel: context.tr('cal_hide_today'),
      onDismiss: () {
        final userId = ref.read(authUserIdProvider);
        final prefs = ref.read(calorieSharedPreferencesProvider).valueOrNull;
        if (userId != null) prefs?.setString(_hintHiddenKey(userId), today);
        ref.read(_hintHiddenOnProvider.notifier).state = today;
      },
    );
  }
}

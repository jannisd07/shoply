import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_date_menu.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_entry_actions.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_format.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_recent_row.dart';
import 'package:shoply/presentation/state/calorie_diary_provider.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';
import 'package:shoply/presentation/widgets/design/avo_figure.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/empty_state.dart';
import 'package:shoply/presentation/widgets/design/glass_icon_button.dart';
import 'package:shoply/presentation/widgets/design/glass_toolbar.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/search_field.dart';
import 'package:shoply/presentation/widgets/design/skeleton.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:shoply/routes/route_paths.dart';

/// How many foods "Zuletzt gegessen" shows without a search (S3).
const int _kRecentShown = 8;

const double _kTitleChevron = 11; // D2 X-Essen
const double _kTitleChevronStroke = 2.8; // D2 semibold chevron

/// "Essen eintragen" (`kalorien.md` S3, D2 `X-Essen`): the one place to log
/// food, full screen above the tab bar at `/calories/add` (`?meal=`,
/// `?date=`). Closing returns to where it was opened.
///
/// The title is the meal menu ("Mittagessen eintragen ⌄"); on another day
/// a second line "Für Do., 5. Nov." opens the date menu. "Zuletzt gegessen"
/// logs with one tap and stays open (undo in the toast); the search finds
/// everything logged before. Photo, barcode, quantity and manual entry
/// (S4–S8) join as segments and rows once their screens exist; until then
/// the screen has no segmented control.
class CaloriesAddScreen extends ConsumerStatefulWidget {
  const CaloriesAddScreen({super.key, this.meal, this.dateKey});

  /// `?meal=`; null picks the meal by the time of day.
  final MealType? meal;

  /// `?date=`; null logs for today.
  final String? dateKey;

  @override
  ConsumerState<CaloriesAddScreen> createState() => _CaloriesAddScreenState();
}

class _CaloriesAddScreenState extends ConsumerState<CaloriesAddScreen> {
  late MealType _meal = widget.meal ?? mealForTime(ref.read(calorieClockProvider)());
  late String? _dateKey = widget.dateKey;
  String _query = '';

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RoutePaths.home);
    }
  }

  void _openMealMenu(BuildContext anchor) {
    showAvoMenu(anchor, items: [
      for (final meal in kMealOrder)
        AvoMenuItem(
          label: context.mealName(meal),
          checked: meal == _meal,
          onSelected: () => setState(() => _meal = meal),
        ),
    ]);
  }

  void _openDateMenu(BuildContext anchor, String shown, String today) {
    showCalorieDateMenu(
      anchor,
      shownKey: shown,
      todayKey: today,
      kcalByDay: calorieMenuDaysKcal(ref, today),
      onPick: (key) => setState(() => _dateKey = key == today ? null : key),
    );
  }

  /// Logs [food] for the chosen day; "today" is read at the tap, so a screen
  /// left open over midnight logs for the new day.
  Future<bool> _log(RecentFood food) async {
    final saved = await logFoodAgain(context, ref, food.template, dateKey: _dateKey, meal: _meal);
    return saved != null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final today = ref.watch(calorieTodayKeyProvider);
    final shown = switch (_dateKey) {
      final k? when k.compareTo(today) < 0 => k,
      _ => today,
    };
    // The chosen day starts loading at once, so its numbers are known
    // before anything is logged for it.
    ref.watch(calorieDayProvider(shown));
    // The date menu shows the week's kcal from the server too.
    ref.watch(calorieRecentDayTotalsProvider(today));
    final recents = ref.watch(recentFoodsProvider);
    final offline = ref.watch(isOfflineProvider);
    final query = _query.trim().toLowerCase();
    final matches = query.isEmpty
        ? recents.foods.take(_kRecentShown).toList()
        : recents.foods
            .where((f) =>
                f.template.foodName.toLowerCase().contains(query) ||
                (f.template.brand?.toLowerCase().contains(query) ?? false))
            .toList();

    final content = <Widget>[
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
        child: AvoSearchField(
          hint: context.tr('cal_search_placeholder'),
          onChanged: (q) => setState(() => _query = q),
        ),
      ),
      if (offline) ...[
        const SizedBox(height: AvoSpacing.s),
        StatusRow(kind: StatusKind.offline, text: context.tr('cal_search_offline')),
      ] else if (recents.failed) ...[
        const SizedBox(height: AvoSpacing.s),
        StatusRow(
          kind: StatusKind.sectionError,
          text: context.tr('cal_recent_error'),
          actionLabel: context.tr('retry'),
          onAction: () => retryRecentFoods(ref),
        ),
      ],
      if (matches.isNotEmpty)
        InsetSection(
          header: context.tr('cal_sec_recent'),
          children: [
            for (final f in matches)
              RecentFoodRow(
                key: ValueKey('cal-recent-${f.key}'),
                food: f,
                onLog: () => _log(f),
                onRemove: () => ref.read(recentFoodsHiddenProvider.notifier).hide(f.key),
              ),
          ],
        )
      else if (query.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: AvoSpacing.l),
          child: EmptyState(
            pose: AvoPose.thinking,
            title: context.tr('cal_search_none', params: {'query': _query.trim()}),
          ),
        )
      else if (recents.failed)
        // Says so above; a failed load never looks like "nothing eaten yet".
        const SizedBox.shrink()
      else if (!recents.known)
        Padding(
          padding: const EdgeInsets.only(top: AvoSpacing.section),
          child: InsetSection(children: [
            SkeletonSection(rows: 3, withImage: false, loadingLabel: context.tr('cal_loading')),
          ]),
        )
      else
        Padding(
          padding: const EdgeInsets.fromLTRB(AvoSpacing.xxxl, AvoSpacing.xl, AvoSpacing.xxxl, 0),
          child: Text(
            context.tr('cal_recent_first_run'),
            style: context.text(AvoTextStyle.footnote, color: colors.secondaryLabel),
          ),
        ),
    ];

    final header = Padding(
      padding: EdgeInsets.fromLTRB(
        AvoSpacing.screen,
        GlassToolbar.topOffset(context),
        AvoSpacing.screen,
        AvoSpacing.m,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassIconButton(
            icon: const AvoIcon(AvoIcons.xmark),
            semanticLabel: context.tr('common_close'),
            onPressed: _close,
          ),
          const SizedBox(width: AvoSpacing.s),
          Expanded(
            child: _TitleBlock(
              title: context.tr('cal_add_title', params: {'meal': context.mealName(_meal)}),
              dateLine: shown == today
                  ? null
                  : context.tr('cal_add_for_date', params: {'date': context.shortDate(parseCalorieDayKey(shown))}),
              onMeal: _openMealMenu,
              onDate: (anchor) => _openDateMenu(anchor, shown, today),
            ),
          ),
          const SizedBox(width: AvoSpacing.s),
          // Keeps the title centred (D2 X-Essen).
          const SizedBox.square(dimension: AvoSizes.toolbarButton),
        ],
      ),
    );

    return ColoredBox(
      color: colors.background,
      child: Column(
        children: [
          header,
          Expanded(
            child: Stack(
              children: [
                // At most the person's history (60 rows): laid out at once.
                SingleChildScrollView(
                  padding: EdgeInsets.only(
                    top: AvoSpacing.xs,
                    bottom: MediaQuery.paddingOf(context).bottom + AvoSpacing.xxl,
                  ),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: content),
                ),
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: ScrollEdgeFade(height: AvoSpacing.l),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The inline title as a menu button ("Mittagessen eintragen ⌄") and, on
/// another day, the date line below it as a second button.
class _TitleBlock extends StatelessWidget {
  const _TitleBlock({
    required this.title,
    required this.dateLine,
    required this.onMeal,
    required this.onDate,
  });

  final String title;
  final String? dateLine;
  final ValueChanged<BuildContext> onMeal;
  final ValueChanged<BuildContext> onDate;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final date = dateLine;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Builder(
          builder: (anchor) => Semantics(
            container: true,
            button: true,
            header: true,
            label: title,
            hint: context.tr('cal_change_meal'),
            onTap: () => onMeal(anchor),
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onMeal(anchor),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
                child: Center(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: title),
                      const TextSpan(text: ' '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: AvoIcon(AvoIcons.chevronDown, size: _kTitleChevron, strokeWidth: _kTitleChevronStroke),
                      ),
                    ]),
                    textAlign: TextAlign.center,
                    style: context.text(AvoTextStyle.headline),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (date != null)
          Builder(
            builder: (anchor) => Semantics(
              container: true,
              button: true,
              label: date,
              hint: context.tr('cal_date_hint'),
              onTap: () => onDate(anchor),
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onDate(anchor),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
                  child: Center(
                    child: Text(
                      date,
                      textAlign: TextAlign.center,
                      style: context.text(AvoTextStyle.footnote, color: colors.secondaryLabel),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

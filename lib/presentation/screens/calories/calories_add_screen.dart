import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/semantics.dart';
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

/// How long a logged row says "Eingetragen" (S3).
const Duration _kLoggedShown = Duration(seconds: 2);

const double _kTitleChevron = 11; // D2 X-Essen
const double _kRowMin = 60; // D2
const double _kPlusGlyph = 22; // D2 plus.circle
const double _kRowVertical = 9; // D2 (60 - 22 - 20) / 2

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

  /// Foods logged in the last two seconds ("Eingetragen").
  final Set<String> _logged = {};
  final List<Timer> _timers = [];

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

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

  Future<void> _log(RecentFood food, String dateKey) async {
    final saved = await logFoodAgain(context, ref, food.template, dateKey: dateKey, meal: _meal);
    if (saved == null || !mounted) return;
    setState(() => _logged.add(food.key));
    _timers.add(Timer(_kLoggedShown, () {
      if (mounted) setState(() => _logged.remove(food.key));
    }));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final today = ref.watch(calorieTodayKeyProvider);
    final shown = switch (_dateKey) {
      final k? when k.compareTo(today) < 0 => k,
      _ => today,
    };
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
      ],
      if (matches.isNotEmpty)
        InsetSection(
          header: context.tr('cal_sec_recent'),
          children: [
            for (final f in matches)
              _RecentFoodRow(
                key: ValueKey('cal-recent-${f.key}'),
                food: f,
                logged: _logged.contains(f.key),
                onLog: () => _log(f, shown),
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
                        child: AvoIcon(AvoIcons.chevronDown, size: _kTitleChevron, strokeWidth: 2.8),
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

/// A "Zuletzt gegessen" row: name, "60 g · 220 kcal" and a green plus. One
/// tap logs it at once; the plus turns into a check and the second line says
/// "Eingetragen" for two seconds. Long press: "Aus „Zuletzt“ entfernen".
class _RecentFoodRow extends StatelessWidget {
  const _RecentFoodRow({
    super.key,
    required this.food,
    required this.logged,
    required this.onLog,
    required this.onRemove,
  });

  final RecentFood food;
  final bool logged;
  final VoidCallback onLog;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final e = food.template;
    final kcal = context.tr('cal_meal_sum', params: {'kcal': context.kcal(e.calories)});
    final amount = context.entryAmount(e);
    final subtitle = logged ? context.tr('cal_logged') : [?amount, kcal].join(' · ');
    final spoken = [
      e.foodName,
      ?amount,
      context.tr('cal_kcal_value', params: {'kcal': context.kcal(e.calories)}),
    ].join(', ');

    return Semantics(
      container: true,
      button: true,
      label: spoken,
      hint: context.tr('cal_log_item_a11y', params: {'name': e.foodName}),
      onTap: onLog,
      customSemanticsActions: {
        CustomSemanticsAction(label: context.tr('cal_remove_recent')): onRemove,
      },
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onLog,
        onLongPress: () => showAvoMenu(context, items: [
          AvoMenuItem(
            label: context.tr('cal_remove_recent'),
            icon: AvoIcons.trash,
            destructive: true,
            onSelected: onRemove,
          ),
        ]),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _kRowMin),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(AvoSpacing.l, _kRowVertical, AvoSpacing.xs, _kRowVertical),
            child: Row(
              crossAxisAlignment: context.isAccessibilityText ? CrossAxisAlignment.start : CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(e.foodName, style: context.text(AvoTextStyle.body)),
                      Text(subtitle, style: context.text(AvoTextStyle.subhead, color: colors.secondaryLabel)),
                    ],
                  ),
                ),
                SizedBox.square(
                  dimension: AvoSizes.hitTarget,
                  child: Center(child: _LogGlyph(logged: logged)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `plus.circle` that springs into `checkmark.circle.fill` (springQuick;
/// Reduce Motion: plain swap).
class _LogGlyph extends StatefulWidget {
  const _LogGlyph({required this.logged});

  final bool logged;

  @override
  State<_LogGlyph> createState() => _LogGlyphState();
}

class _LogGlyphState extends State<_LogGlyph> with SingleTickerProviderStateMixin {
  static const double _from = 0.6; // grows out of the plus
  late final AnimationController _scale = AnimationController.unbounded(vsync: this, value: 1);

  @override
  void didUpdateWidget(_LogGlyph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.logged == widget.logged || context.reduceMotion) return;
    _scale.value = _from;
    _scale.animateWith(SpringSimulation(AvoMotion.quick, _from, 1, 0));
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tint = context.colors.tint;
    return ScaleTransition(
      scale: _scale,
      child: Icon(
        widget.logged ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.plus_circle,
        size: _kPlusGlyph,
        color: tint,
      ),
    );
  }
}

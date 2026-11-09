import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/core/modules/module_labels.dart';
import 'package:shoply/data/services/avo_assistant_service.dart';
import 'package:shoply/data/services/avo_settings_bridge.dart';
import 'package:shoply/presentation/screens/avo/avo_card_format.dart';
import 'package:shoply/presentation/screens/avo/avo_chat.dart';
import 'package:shoply/presentation/screens/avo/avo_l10n.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_card_scope.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_result_card.dart';
import 'package:shoply/presentation/screens/profile/settings/data/notification_settings.dart'
    show ReminderTime;
import 'package:shoply/presentation/screens/profile/settings/notifications_settings_screen.dart'
    show formatReminderTime;
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/screens/history/history_paths.dart';
import 'package:shoply/routes/app_destinations.dart';
import 'package:shoply/routes/route_paths.dart';

/// The head of a record's card: the object, what happened, its symbol and
/// where "Ansehen" / "Liste öffnen" goes.
typedef AvoRecordHead = ({
  String title,
  String subtitle,
  Widget icon,
  String? openLabel,
  void Function(BuildContext context)? open,
});

/// A write Avo made (Kap. 5.2–5.7): the object, what happened, the target
/// and "Widerrufen" while the data is unchanged. [record] defaults to the
/// payload's own; cards pass the one a tap on them made.
class AvoRecordSection extends StatelessWidget {
  const AvoRecordSection({
    super.key,
    required this.payload,
    required this.scope,
    this.record,
  });

  /// Keys the undo state in the conversation.
  final AvoWidgetPayload payload;
  final AvoCardScope scope;
  final AvoRecord? record;

  @override
  Widget build(BuildContext context) {
    final r = record ?? scope.chat.recordOf(payload);
    if (r == null) return const SizedBox.shrink();
    final head = avoRecordHead(context, r);
    final phase = scope.chat.undoPhaseOf(payload);
    final state = switch (phase) {
      AvoUndoPhase.undone => AvoSectionState.undone,
      AvoUndoPhase.changedSince => AvoSectionState.changedSince,
      _ => AvoSectionState.done,
    };
    final undoable = r.undo != null;
    final open = head.open;
    final sentence = [
      '${head.title}: ${head.subtitle}',
      if (undoable && state == AvoSectionState.done)
        context.tr('avo_a11y_undo_available'),
    ].join('. ');
    // A write from a tap on a card replaces the card the focus was on: say
    // what happened, once (Kap. 3.6).
    if (payload.record == null && scope.chat.firstShowOf(r)) {
      _announce(context, sentence);
    }
    return AvoResultSection(
      title: head.title,
      subtitle: head.subtitle,
      state: state,
      semanticLabel: sentence,
      leading: AvoSymbolTile(icon: head.icon),
      onOpen: open == null ? null : () => open(context),
      actions: [
        if (open != null && head.openLabel != null)
          AvoCardAction(label: head.openLabel!, onPressed: () => open(context)),
        if (undoable)
          AvoCardAction(
            label: context.tr('avo_undo'),
            isUndo: true,
            working: phase == AvoUndoPhase.working,
            onPressed: phase == AvoUndoPhase.idle
                ? () => scope.chat.undo(payload)
                : null,
          ),
      ],
    );
  }
}

void _announce(BuildContext context, String text) {
  if (defaultTargetPlatform != TargetPlatform.iOS) return;
  final view = View.maybeOf(context);
  if (view == null) return;
  final direction = Directionality.of(context);
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => SemanticsService.sendAnnouncement(view, text, direction),
  );
}

void _go(BuildContext context, String destination) =>
    openAppDestination(context, destination);

/// The head of [r]'s card; also the text of its toast while the tab is
/// hidden (Kap. 3.2).
AvoRecordHead avoRecordHead(BuildContext context, AvoRecord r) {
  final view = context.tr('avo_view');
  void calories(BuildContext c) => _go(c, AppDestinations.calories);
  switch (r) {
    case AvoItemsRecord():
      return (
        title: r.listName,
        subtitle: _itemsLine(context, r),
        icon: const AvoIcon(AvoIcons.cart),
        openLabel: context.tr('avo_open_list'),
        open: (c) => _go(c, AppDestinations.list(r.listId)),
      );
    case AvoPlanRecord():
      return (
        title: r.moved ? r.recipeName : avoDay(context, r.day),
        subtitle: r.moved
            ? context.tr(
                'avo_rec_moved_to',
                params: {'date': avoDay(context, r.day)},
              )
            : r.servings == null
            ? r.recipeName
            : avoTrCount(context, 'avo_rec_planned', r.servings!, {
                'recipe': r.recipeName,
              }),
        icon: const AvoIcon(AvoIcons.calendar),
        openLabel: view,
        open: (c) => _go(c, AppDestinations.plan),
      );
    case AvoWaterRecord():
      String litres(int ml) => avoDecimal(context, ml / 1000, decimals: 2);
      return (
        title: context.tr('avo_rec_water_title'),
        subtitle: context.tr(
          'avo_rec_water',
          params: {
            'amount': avoInt(context, r.amountMl),
            'total': litres(r.totalMl),
            'target': litres(r.targetMl),
          },
        ),
        icon: const Icon(CupertinoIcons.drop),
        openLabel: view,
        open: calories,
      );
    case AvoWeightRecord():
      return (
        title: context.tr('avo_rec_weight_title'),
        subtitle: context.tr(
          'avo_rec_weight',
          params: {
            'kg': avoDecimal(context, r.kg),
            'date': avoDay(context, r.day),
          },
        ),
        icon: const Icon(CupertinoIcons.gauge),
        openLabel: view,
        open: calories,
      );
    case AvoWorkoutRecord():
      final kcal = avoInt(context, r.kcal);
      return (
        title: avoWorkoutName(context, r.type),
        subtitle: [
          context.tr('avo_rec_workout', params: {'n': '${r.minutes}'}),
          context.tr(
            r.estimated ? 'avo_rec_workout_kcal_est' : 'avo_rec_workout_kcal',
            params: {'kcal': kcal},
          ),
        ].join(' · '),
        icon: const Icon(CupertinoIcons.sportscourt),
        openLabel: view,
        open: calories,
      );
    case AvoFoodRecord():
      final left = r.leftKcal;
      return (
        title: context.tr('avo_rec_food_title', params: {'food': r.name}),
        subtitle: [
          avoMealName(context, r.meal),
          '${avoInt(context, r.kcal)} kcal',
          if (left != null)
            left >= 0
                ? context.tr(
                    'avo_rec_food_left',
                    params: {'kcal': avoInt(context, left)},
                  )
                : context.tr(
                    'avo_rec_food_over',
                    params: {'kcal': avoInt(context, -left)},
                  ),
        ].join(' · '),
        icon: const AvoIcon(AvoIcons.flame),
        openLabel: view,
        open: calories,
      );
    case AvoGoalRecord():
      final was = r.previousKcal;
      return (
        title: context.tr(
          'avo_rec_goal_title',
          params: {'kcal': avoInt(context, r.kcal)},
        ),
        subtitle: [
          if (was != null)
            context.tr('avo_goal_was', params: {'kcal': avoInt(context, was)}),
          if (r.weightKg != null)
            context.tr(
              'avo_goal_weight_logged',
              params: {'kg': avoDecimal(context, r.weightKg!)},
            ),
          if (r.weightFailed) context.tr('avo_goal_weight_failed'),
          context.tr('avo_guide_value'),
        ].join(' · '),
        icon: const Icon(CupertinoIcons.flag),
        openLabel: view,
        open: calories,
      );
    case AvoSettingRecord():
      return _settingHead(context, r);
    case AvoModuleRecord():
      final name = r.module.label(context);
      final where = r.enabled ? _moduleWhere(context, r.module) : null;
      return (
        title: context.tr('avo_rec_module_title'),
        subtitle: [
          context.tr(
            r.enabled ? 'avo_module_on' : 'avo_rec_module_off',
            params: {'module': name},
          ),
          ?where,
        ].join(' · '),
        icon: const AvoIcon(AvoIcons.switch2),
        openLabel: null,
        open: null,
      );
    case AvoSplitRecord():
      return (
        title: context.tr(
          'avo_rec_split_title',
          params: {'date': avoDay(context, r.tripDate)},
        ),
        subtitle: context.tr(
          'avo_rec_split',
          params: {
            'shares': [
              for (final s in r.shares)
                '${s.isYou ? context.tr('avo_you') : s.name} '
                    '${avoEuro(context, s.amount)}',
            ].join(' · '),
          },
        ),
        icon: const AvoIcon(AvoIcons.people),
        openLabel: view,
        open: (c) => r.historyId == null
            ? _go(c, AppDestinations.history)
            : unawaited(GoRouter.of(c).push<Object?>(historyTripLocation(r.historyId!))),
      );
  }
}

/// "9 Zutaten hinzugefügt · für 4 Portionen · 2 standen schon drauf:
/// Zwiebeln, Olivenöl".
String _itemsLine(BuildContext context, AvoItemsRecord r) {
  final already = r.alreadyOn;
  final named = already.isNotEmpty && already.length <= 3;
  return [
    if (r.source == AvoItemsSource.recipe || r.source == AvoItemsSource.plan)
      avoTrCount(context, 'avo_rec_ingredients_added', r.added)
    else
      context.tr('avo_card_added', params: {'n': '${r.added}'}),
    if (r.servings != null)
      avoTrCount(context, 'avo_rec_for_servings', r.servings!),
    if (named)
      avoTrCount(context, 'avo_rec_already_on_named', already.length, {
        'names': already.join(', '),
      })
    else if (already.isNotEmpty)
      avoTrCount(context, 'avo_rec_already_on', already.length),
  ].join(' · ');
}

String? _moduleWhere(BuildContext context, AppModule module) =>
    switch (module) {
      AppModule.calories => context.tr('avo_module_where_calories'),
      AppModule.offers => context.tr('avo_module_where_offers'),
      AppModule.mealPlan => context.tr('avo_module_where_plan'),
      AppModule.costSplit => context.tr('avo_module_where_split'),
      AppModule.avo => null,
    };

/// A setting's value in the person's words ("Dunkel", "aus").
String _value(BuildContext context, String key, String? raw) {
  if (raw == null || raw.isEmpty || raw == 'none') {
    return context.tr('avo_val_none');
  }
  switch (key) {
    case 'theme_mode':
      return switch (raw) {
        'light' => context.tr('avo_val_light'),
        'dark' => context.tr('avo_val_dark'),
        _ => context.tr('avo_val_system'),
      };
    case 'language':
      return switch (raw) {
        'de' => context.tr('avo_val_de'),
        'en' => context.tr('avo_val_en'),
        _ => context.tr('avo_val_system'),
      };
    case 'notifications':
      return context.tr(raw == 'true' ? 'avo_val_on' : 'avo_val_off');
    case 'gender':
      return switch (raw) {
        'male' => context.tr('avo_val_male'),
        'female' => context.tr('avo_val_female'),
        'other' => context.tr('avo_val_other'),
        _ => context.tr('avo_val_prefer_not'),
      };
    case 'height_cm':
      return '$raw cm';
    case 'notif_time_restock' || 'notif_time_dinner':
      final time = ReminderTime.parse(raw);
      return time == null ? raw : formatReminderTime(context, time);
    default:
      return switch (raw) {
        'on' => context.tr('avo_val_on'),
        'off' => context.tr('avo_val_off'),
        'last used list' => context.tr('avo_value_last_list'),
        _ => raw,
      };
  }
}

AvoRecordHead _settingHead(BuildContext context, AvoSettingRecord r) {
  void settings(BuildContext c) => _go(c, AppDestinations.settings);
  void diet(BuildContext c) => c.push(RoutePaths.dietPreferences);
  switch (r.key) {
    case 'allergies_add':
      return (
        title: context.tr('avo_set_allergies'),
        subtitle: context.tr(
          'avo_rec_allergy_added',
          params: {'allergen': r.value},
        ),
        icon: const AvoIcon(AvoIcons.leaf),
        openLabel: null,
        open: diet,
      );
    case 'allergies_remove':
      return (
        title: context.tr('avo_set_allergies'),
        subtitle: context.tr(
          'avo_rec_allergy_removed',
          params: {'allergen': r.value},
        ),
        icon: const AvoIcon(AvoIcons.leaf),
        openLabel: null,
        open: diet,
      );
    case 'diet_add':
      return (
        title: context.tr('avo_set_diet'),
        subtitle: context.tr(
          'avo_card_was',
          params: {'value': r.value, 'old': _value(context, r.key, r.previous)},
        ),
        icon: const AvoIcon(AvoIcons.leaf),
        openLabel: null,
        open: diet,
      );
    case 'diet_remove':
      return (
        title: context.tr('avo_set_diet'),
        subtitle: context.tr('avo_rec_diet_removed', params: {'diet': r.value}),
        icon: const AvoIcon(AvoIcons.leaf),
        openLabel: null,
        open: diet,
      );
  }
  final (titleKey, icon) = switch (r.key) {
    'theme_mode' => (
      'avo_set_appearance',
      const Icon(CupertinoIcons.circle_lefthalf_fill),
    ),
    'language' => ('avo_set_language', const Icon(CupertinoIcons.globe)),
    'notifications' => (
      'avo_set_notifications',
      const Icon(CupertinoIcons.bell),
    ),
    'zip_code' => ('avo_set_region', const AvoIcon(AvoIcons.location)),
    'age' => ('avo_set_age', const AvoIcon(AvoIcons.person)),
    'gender' => ('avo_set_gender', const AvoIcon(AvoIcons.person)),
    'height_cm' => ('avo_set_height', const AvoIcon(AvoIcons.person)),
    'display_name' ||
    'name' => ('avo_set_name', const AvoIcon(AvoIcons.person)),
    _ => ('avo_set_generic', const AvoIcon(AvoIcons.switch2)),
  };
  final value = _value(context, r.key, r.value);
  // The A8 keys name themselves (`avo_setkey_<key>`).
  final ownName = AvoSettingsBridge.labelKeyOf(r.key);
  final named = context.tr(ownName);
  final title = named == ownName ? context.tr(titleKey) : named;
  return (
    title: title,
    subtitle: r.previous == null && r.key == 'zip_code'
        ? value
        : context.tr(
            'avo_card_was',
            params: {'value': value, 'old': _value(context, r.key, r.previous)},
          ),
    icon: icon,
    openLabel: null,
    open: settings,
  );
}

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_format.dart';
import 'package:shoply/presentation/screens/profile/settings/data/notification_settings.dart';
import 'package:shoply/presentation/screens/profile/settings/data/settings_services.dart';
import 'package:shoply/presentation/screens/profile/settings/notifications_settings_screen.dart'
    show formatReminderTime;
import 'package:shoply/presentation/screens/profile/settings/widgets/settings_page.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/picker_row.dart';
import 'package:shoply/presentation/widgets/design/row_highlight.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:shoply/routes/route_paths.dart';

/// Row ids of the page (`/settings/health?row=…`, the settings search).
abstract final class CaloriesSettingsRows {
  static const goals = 'health.goals';
  static const dinnerIdeas = 'health.dinner_ideas';
  static const dinnerTime = 'health.dinner_time';
}

/// "Kalorien & Gesundheit" (S23, `/settings/health`, only with the module):
/// what the module has today, in one place.
///
/// "Ziele" with today's calorie goal (the goals page holds water and the
/// macros too) and the reminder "Ideen fürs Abendessen" with its time, the
/// same switch and time as in Einstellungen › Mitteilungen (one setting, two
/// places). The notification permission is asked only when the switch goes
/// on. Apple Health, units and deleting all meal photos join once they
/// exist (S22, S23 groups APPLE HEALTH, EINHEITEN, DATEN). Every switch
/// acts at once; no figure, never Pro.
class CaloriesSettingsScreen extends ConsumerStatefulWidget {
  const CaloriesSettingsScreen({super.key, this.highlightRowId});

  /// Row to highlight once (`?row=`).
  final String? highlightRowId;

  @override
  ConsumerState<CaloriesSettingsScreen> createState() =>
      _CaloriesSettingsScreenState();
}

class _CaloriesSettingsScreenState extends ConsumerState<CaloriesSettingsScreen>
    with WidgetsBindingObserver {
  bool _timeOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshPermission();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the iOS settings: the permission may have changed.
    if (state == AppLifecycleState.resumed) _refreshPermission();
  }

  void _refreshPermission() =>
      unawaited(ref.read(notificationPermissionProvider.notifier).refresh());

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _setDinnerIdeas(bool on) async {
    final notifications = ref.read(notificationSettingsProvider.notifier);
    await notifications.setEnabled(NotificationSetting.dinnerIdeas, on);
    if (!on) {
      if (mounted) setState(() => _timeOpen = false);
      return;
    }
    if (ref.read(notificationPermissionProvider) ==
        NotificationPermissionState.notAsked) {
      await ref.read(notificationPermissionProvider.notifier).request();
    }
  }

  String _goalValue(BuildContext context, CalorieGoalState goal) =>
      switch (goal.status) {
        CalorieGoalStatus.set => context.tr(
          'cal_meal_sum',
          params: {'kcal': context.kcal(goal.kcal ?? 0)},
        ),
        CalorieGoalStatus.none => context.tr('cal_set_no_goal'),
        // Loading or unreadable: no value rather than a wrong one.
        CalorieGoalStatus.loading || CalorieGoalStatus.error => '',
      };

  @override
  Widget build(BuildContext context) {
    final goal = ref.watch(calorieGoalStateProvider);
    final settings = ref.watch(notificationSettingsProvider);
    final permission = ref.watch(notificationPermissionProvider);
    final denied = permission == NotificationPermissionState.denied;
    final masterOff = settings.loaded && !settings.master;
    final blocked = denied || masterOff;
    final on = !blocked && settings.isOn(NotificationSetting.dinnerIdeas);
    final time = settings.timeOf(NotificationTimeSlot.dinnerIdeas);
    final timeText = formatReminderTime(context, time);
    final goalValue = _goalValue(context, goal);

    return SettingsPage(
      title: context.tr('cal_settings_title'),
      highlightRowId: widget.highlightRowId,
      showOffline: !blocked,
      children: [
        InsetSection(
          children: [
            HighlightableRow(
              id: CaloriesSettingsRows.goals,
              child: NavRow(
                title: context.tr('cal_goals_title'),
                value: goalValue.isEmpty ? null : goalValue,
                onTap: () => unawaited(
                  context.push('${RoutePaths.settingsHealth}/goals'),
                ),
              ),
            ),
          ],
        ),
        if (blocked) ...[
          const SizedBox(height: AvoSpacing.section),
          if (denied)
            StatusRow(
              kind: StatusKind.permission,
              text: context.tr('cal_set_notif_off'),
              actionLabel: context.tr('cal_set_notif_allow'),
              onAction: () => unawaited(
                ref.read(settingsExternalActionsProvider).openAppSettings(),
              ),
            )
          else
            StatusRow(
              kind: StatusKind.permission,
              text: context.tr('cal_set_master_off'),
              actionLabel: context.tr('cal_set_open_notifications'),
              onAction: () =>
                  unawaited(context.push(RoutePaths.settingsNotifications)),
            ),
        ],
        InsetSection(
          header: context.tr('cal_set_reminders'),
          children: [
            HighlightableRow(
              id: CaloriesSettingsRows.dinnerIdeas,
              child: ToggleRow(
                title: context.tr('cal_set_dinner_ideas'),
                subtitle: context.tr(
                  'cal_set_dinner_ideas_sub',
                  params: {'time': timeText},
                ),
                value: on,
                enabled: !blocked,
                onChanged: (v) => unawaited(_setDinnerIdeas(v)),
              ),
            ),
            if (on)
              HighlightableRow(
                id: CaloriesSettingsRows.dinnerTime,
                child: PickerRow(
                  title: context.tr('cal_set_time'),
                  value: timeText,
                  expanded: _timeOpen,
                  onExpandedChanged: (open) =>
                      setState(() => _timeOpen = open),
                  picker: TimeOfDayPicker(
                    hour: time.hour,
                    minute: time.minute,
                    use24Hour:
                        MediaQuery.alwaysUse24HourFormatOf(context) ||
                        Localizations.localeOf(context).languageCode == 'de',
                    semanticLabel: context.tr('cal_set_time'),
                    onChanged: (h, m) => unawaited(
                      ref
                          .read(notificationSettingsProvider.notifier)
                          .setTime(
                            NotificationTimeSlot.dinnerIdeas,
                            ReminderTime(h, m),
                          ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

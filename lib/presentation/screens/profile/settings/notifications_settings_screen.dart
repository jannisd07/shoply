import 'package:flutter/cupertino.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/presentation/screens/profile/settings/data/notification_settings.dart';
import 'package:shoply/presentation/screens/profile/settings/data/settings_services.dart';
import 'package:shoply/presentation/screens/profile/settings/widgets/settings_page.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/picker_row.dart';
import 'package:shoply/presentation/widgets/design/row_highlight.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';

/// Whether times are shown with 24 hours: German, or the iPhone is set so.
bool _uses24Hour(BuildContext context) =>
    MediaQuery.alwaysUse24HourFormatOf(context) ||
    Localizations.localeOf(context).languageCode == 'de';

/// "9:00" or "9:00 AM", as the person reads times (no locale data needed).
String formatReminderTime(BuildContext context, ReminderTime t) {
  final mm = t.minute.toString().padLeft(2, '0');
  if (_uses24Hour(context)) return '${t.hour}:$mm';
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:$mm ${t.hour < 12 ? 'AM' : 'PM'}';
}

/// Row ids of the switches (`notifications.restock`).
String notificationRowId(NotificationSetting s) => switch (s) {
  NotificationSetting.shoppingStarted => 'notifications.shopping_started',
  NotificationSetting.listChanges => 'notifications.list_changes',
  NotificationSetting.shoppingCompleted => 'notifications.shopping_completed',
  NotificationSetting.invitations => 'notifications.invitations',
  NotificationSetting.restock => 'notifications.restock',
  NotificationSetting.cookingTimer => 'notifications.cooking_timer',
  NotificationSetting.planReminder => 'notifications.plan_reminder',
  NotificationSetting.dinnerIdeas => 'notifications.dinner_ideas',
  NotificationSetting.costSplitOpen => 'notifications.cost_split',
  NotificationSetting.recipeLikes => 'notifications.recipe_likes',
  NotificationSetting.recipeComments => 'notifications.recipe_comments',
  NotificationSetting.newRecipes => 'notifications.new_recipes',
};

/// Mitteilungen (`/settings/notifications`, Konzept 18 §5.5, K18-06): the
/// iOS permission at the top where it matters (ask, or "In Einstellungen
/// erlauben"), the account-wide main switch, then the categories of shared
/// lists, reminders with their time (wheel in the row), the switched-on
/// modules and recipes. Off folds the categories away. Everything shows from
/// the local state at once; the permission is read again when the app comes
/// back from the iOS settings.
class NotificationsSettingsScreen extends ConsumerStatefulWidget {
  const NotificationsSettingsScreen({super.key, this.highlightRowId});

  /// Row to highlight once (`?row=`), see `RowHighlightScope`.
  final String? highlightRowId;

  @override
  ConsumerState<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends ConsumerState<NotificationsSettingsScreen>
    with WidgetsBindingObserver {
  NotificationTimeSlot? _openTime;

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
    if (state == AppLifecycleState.resumed) _refreshPermission();
  }

  void _refreshPermission() =>
      ref.read(notificationPermissionProvider.notifier).refresh();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Widget _toggle(
    BuildContext context,
    NotificationSettings s,
    NotificationSetting setting,
    String titleKey, {
    String? subtitleKey,
  }) {
    return HighlightableRow(
      id: notificationRowId(setting),
      child: ToggleRow(
        title: context.tr(titleKey),
        subtitle: subtitleKey == null ? null : context.tr(subtitleKey),
        value: s.isOn(setting),
        onChanged: (on) => ref
            .read(notificationSettingsProvider.notifier)
            .setEnabled(setting, on),
      ),
    );
  }

  Widget _time(
    BuildContext context,
    NotificationSettings s,
    NotificationTimeSlot slot,
    String rowId,
  ) {
    final t = s.timeOf(slot);
    return HighlightableRow(
      id: rowId,
      child: PickerRow(
        title: context.tr('setp_notif_time'),
        value: formatReminderTime(context, t),
        expanded: _openTime == slot,
        onExpandedChanged: (o) => setState(() => _openTime = o ? slot : null),
        picker: TimeOfDayPicker(
          hour: t.hour,
          minute: t.minute,
          use24Hour: _uses24Hour(context),
          semanticLabel: context.tr('setp_notif_time'),
          onChanged: (h, m) => ref
              .read(notificationSettingsProvider.notifier)
              .setTime(slot, ReminderTime(h, m)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(notificationSettingsProvider);
    final permission = ref.watch(notificationPermissionProvider);
    final modules = ref.watch(appModulesProvider);
    final denied = permission == NotificationPermissionState.denied;
    final reduce = context.reduceMotion;

    final moduleRows = <Widget>[
      if (modules.isEnabled(AppModule.mealPlan))
        _toggle(
          context,
          s,
          NotificationSetting.planReminder,
          'setp_notif_plan_reminder',
        ),
      if (modules.isEnabled(AppModule.calories)) ...[
        _toggle(
          context,
          s,
          NotificationSetting.dinnerIdeas,
          'setp_notif_dinner_ideas',
        ),
        if (s.isOn(NotificationSetting.dinnerIdeas))
          _time(
            context,
            s,
            NotificationTimeSlot.dinnerIdeas,
            'notifications.dinner_time',
          ),
      ],
      if (modules.isEnabled(AppModule.costSplit))
        _toggle(
          context,
          s,
          NotificationSetting.costSplitOpen,
          'setp_notif_cost_split',
        ),
    ];

    final categories = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        InsetSection(
          header: context.tr('setp_notif_shared'),
          children: [
            _toggle(
              context,
              s,
              NotificationSetting.shoppingStarted,
              'setp_notif_shopping_started',
            ),
            _toggle(
              context,
              s,
              NotificationSetting.listChanges,
              'setp_notif_list_changes',
              subtitleKey: 'setp_notif_list_changes_sub',
            ),
            _toggle(
              context,
              s,
              NotificationSetting.shoppingCompleted,
              'setp_notif_shopping_completed',
            ),
            _toggle(
              context,
              s,
              NotificationSetting.invitations,
              'setp_notif_invitations',
            ),
          ],
        ),
        InsetSection(
          header: context.tr('setp_notif_reminders'),
          children: [
            _toggle(
              context,
              s,
              NotificationSetting.restock,
              'setp_notif_restock',
            ),
            if (s.isOn(NotificationSetting.restock))
              _time(
                context,
                s,
                NotificationTimeSlot.restock,
                'notifications.restock_time',
              ),
            _toggle(
              context,
              s,
              NotificationSetting.cookingTimer,
              'setp_notif_cooking_timer',
              subtitleKey: 'setp_notif_cooking_timer_sub',
            ),
          ],
        ),
        InsetSection(
          header: context.tr('setp_notif_modules'),
          children: moduleRows,
        ),
        InsetSection(
          header: context.tr('setp_notif_recipes'),
          children: [
            _toggle(
              context,
              s,
              NotificationSetting.recipeLikes,
              'setp_notif_recipe_likes',
            ),
            _toggle(
              context,
              s,
              NotificationSetting.recipeComments,
              'setp_notif_recipe_comments',
            ),
            _toggle(
              context,
              s,
              NotificationSetting.newRecipes,
              'setp_notif_new_recipes',
            ),
          ],
        ),
      ],
    );

    return SettingsPage(
      title: context.tr('setp_notif_title'),
      highlightRowId: widget.highlightRowId,
      // One status per screen: the missing permission matters more here.
      showOffline: !denied,
      children: [
        if (denied)
          HighlightableRow(
            id: 'notifications.permission',
            child: StatusRow(
              kind: StatusKind.permission,
              text: context.tr('setp_notif_denied'),
              actionLabel: context.tr('setp_notif_open_settings'),
              onAction: () =>
                  ref.read(settingsExternalActionsProvider).openAppSettings(),
            ),
          ),
        if (permission == NotificationPermissionState.notAsked) ...[
          InsetSection(
            children: [
              HighlightableRow(
                id: 'notifications.permission',
                child: SettingsActionRow(
                  title: context.tr('setp_notif_allow'),
                  subtitle: context.tr('setp_notif_allow_sub'),
                  onTap: () => ref
                      .read(notificationPermissionProvider.notifier)
                      .request(),
                ),
              ),
            ],
          ),
          const SizedBox(height: kSettingsSectionGap),
        ],
        if (denied) const SizedBox(height: AvoSpacing.s),
        InsetSection(
          children: [
            HighlightableRow(
              id: 'notifications.master',
              child: ToggleRow(
                title: context.tr('setp_notif_master'),
                subtitle: context.tr('setp_notif_master_sub'),
                value: s.master,
                onChanged: (on) => ref
                    .read(notificationSettingsProvider.notifier)
                    .setMaster(on),
              ),
            ),
          ],
        ),
        AnimatedSize(
          duration: reduce ? Duration.zero : AvoMotion.fadeReduced,
          curve: Curves.easeInOut,
          alignment: AlignmentDirectional.topStart,
          child: s.master ? categories : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

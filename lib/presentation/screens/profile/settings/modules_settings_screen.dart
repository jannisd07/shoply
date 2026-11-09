import 'package:flutter/cupertino.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/core/modules/module_descriptors.dart';
import 'package:shoply/presentation/screens/profile/settings/data/settings_services.dart';
import 'package:shoply/presentation/screens/profile/settings/widgets/settings_page.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/row_highlight.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';

/// Row id of a module switch for search and highlight (`modules.calories`).
String moduleRowId(AppModule module) => 'modules.${module.storageKey}';

/// The sentence that replaces a module's benefit right after it was switched
/// off (Konzept 18 §5.1); null when there is nothing to say.
String? _offNoteKey(AppModule module) => switch (module) {
  AppModule.offers => 'setp_modules_off_offers',
  AppModule.calories => 'setp_modules_off_calories',
  AppModule.avo => 'setp_modules_off_avo',
  AppModule.mealPlan || AppModule.costSplit => null,
};

/// Module (`/settings/modules`, Konzept 18 §5.1, D2 X-Profil "Module"): one
/// switch per released module with the onboarding's tile, title and benefit
/// (`moduleDescriptors`). Switching acts at once through
/// [appModulesProvider]; switching off shows "… ausgeschaltet ·
/// Widerrufen". The footer names the tabs that result. With the offers kill
/// switch on, "Preise & Angebote" is missing without a hint.
class ModulesSettingsScreen extends ConsumerStatefulWidget {
  const ModulesSettingsScreen({super.key, this.highlightRowId});

  /// Row to highlight once (`?row=`), see `RowHighlightScope`.
  final String? highlightRowId;

  @override
  ConsumerState<ModulesSettingsScreen> createState() =>
      _ModulesSettingsScreenState();
}

class _ModulesSettingsScreenState extends ConsumerState<ModulesSettingsScreen> {
  /// Modules switched off on this visit: their row says what stays.
  final Set<AppModule> _justOff = {};

  void _set(ModuleDescriptor d, bool on) {
    final notifier = ref.read(appModulesProvider.notifier);
    notifier.setEnabled(d.module, on);
    setState(() => on ? _justOff.remove(d.module) : _justOff.add(d.module));
    if (on) return;
    AvoToast.show(
      context,
      message: context.tr(
        'setp_modules_off_toast',
        params: {'module': context.tr(d.titleKey)},
      ),
      actionLabel: context.tr('common_undo'),
      onAction: () {
        notifier.setEnabled(d.module, true);
        if (mounted) setState(() => _justOff.remove(d.module));
      },
    );
  }

  String _tabsLine(BuildContext context, AppModulesState modules) {
    final tabs = [
      context.tr('common_tab_home'),
      context.tr('common_tab_lists'),
      if (modules.isEnabled(AppModule.avo)) context.tr('common_tab_avo'),
      context.tr('common_tab_recipes'),
      context.tr('common_tab_profile'),
    ];
    return context.tr('setp_modules_tabs', params: {'tabs': tabs.join(', ')});
  }

  @override
  Widget build(BuildContext context) {
    final modules = ref.watch(appModulesProvider);
    final killSwitch = ref.watch(offersKillSwitchProvider);
    final rows = visibleModuleDescriptors(offersAvailable: !killSwitch);

    String subtitle(ModuleDescriptor d) {
      final note = _offNoteKey(d.module);
      if (note != null && _justOff.contains(d.module)) return context.tr(note);
      return context.tr(d.benefitKey);
    }

    return SettingsPage(
      title: context.tr('setp_modules_title'),
      intro: context.tr('setp_modules_intro'),
      highlightRowId: widget.highlightRowId,
      children: [
        InsetSection(
          separatorIndent: kSettingsTileRowIndent,
          footer: _tabsLine(context, modules),
          children: [
            for (final d in rows)
              HighlightableRow(
                id: moduleRowId(d.module),
                child: ToggleRow(
                  title: context.tr(d.titleKey),
                  subtitle: subtitle(d),
                  value: modules.isEnabled(d.module),
                  leading: SettingsIconTile(icon: d.icon, color: d.tileColor),
                  onChanged: (on) => _set(d, on),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

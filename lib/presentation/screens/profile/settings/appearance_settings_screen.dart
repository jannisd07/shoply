import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ThemeMode;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/screens/profile/settings/data/settings_services.dart';
import 'package:shoply/presentation/screens/profile/settings/widgets/settings_page.dart';
import 'package:shoply/presentation/state/theme_provider.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/row_highlight.dart';

/// Darstellung (`/settings/appearance`, Konzept 18 §5.6): "System" (follows
/// the iPhone), "Hell", "Dunkel" with a checkmark; acts at once through
/// [themeModeProvider] (device first, then the account). Text size, bold
/// text and contrast stay with iOS; the footer says so and opens the iOS
/// settings. No accent colours, no preview tiles.
class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key, this.highlightRowId});

  /// Row to highlight once (`?row=`), see `RowHighlightScope`.
  final String? highlightRowId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    void set(ThemeMode m) =>
        ref.read(themeModeProvider.notifier).setThemeMode(m);

    return SettingsPage(
      title: context.tr('setp_appearance_title'),
      highlightRowId: highlightRowId,
      children: [
        InsetSection(
          footer: context.tr('setp_appearance_footer'),
          children: [
            HighlightableRow(
              id: 'appearance.system',
              child: ChoiceRow(
                title: context.tr('setp_appearance_system'),
                subtitle: context.tr('setp_appearance_system_sub'),
                selected: mode == ThemeMode.system,
                onTap: () => set(ThemeMode.system),
              ),
            ),
            HighlightableRow(
              id: 'appearance.light',
              child: ChoiceRow(
                title: context.tr('setp_appearance_light'),
                selected: mode == ThemeMode.light,
                onTap: () => set(ThemeMode.light),
              ),
            ),
            HighlightableRow(
              id: 'appearance.dark',
              child: ChoiceRow(
                title: context.tr('setp_appearance_dark'),
                selected: mode == ThemeMode.dark,
                onTap: () => set(ThemeMode.dark),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.l),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppButton.plain(
              label: context.tr('setp_open_ios_settings'),
              onPressed: () =>
                  ref.read(settingsExternalActionsProvider).openAppSettings(),
            ),
          ),
        ),
      ],
    );
  }
}

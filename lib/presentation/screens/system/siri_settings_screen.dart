import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/constants/app_brand.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/screens/profile/settings/data/settings_services.dart';
import 'package:shoply/presentation/screens/profile/settings/widgets/settings_page.dart';
import 'package:shoply/presentation/screens/system/widgets/settings_info_row.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/row_highlight.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';

/// The Shortcuts app (opens it on iOS).
final Uri kShortcutsAppUrl = Uri.parse('shortcuts://');

/// The Siri sentences of `ios/Runner/AppIntents.swift` (`ShoplyAppShortcuts`),
/// one example each: the sentence key and what it does.
const List<(String, String)> kSiriSentences = [
  ('sys_siri_add', 'sys_siri_add_action'),
  ('sys_siri_create', 'sys_siri_create_action'),
  ('sys_siri_lists', 'sys_siri_lists_action'),
  ('sys_siri_search', 'sys_siri_search_action'),
  ('sys_siri_saved', 'sys_siri_saved_action'),
];

/// "Siri & Kurzbefehle" (`/settings/siri`, Konzept 18 §6): the sentences
/// Siri understands with "Avo" in them and a way into the Shortcuts app
/// (its own actions, the Action Button). An info page until B9 rebuilds
/// Siri; nothing here changes a setting.
class SiriSettingsScreen extends ConsumerWidget {
  const SiriSettingsScreen({super.key, this.highlightRowId});

  /// Row to highlight once (`?row=`).
  final String? highlightRowId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = {'app': AppBrand.name};
    return SettingsPage(
      title: context.tr('sys_siri_title'),
      intro: context.tr('sys_siri_intro'),
      highlightRowId: highlightRowId,
      children: [
        InsetSection(
          header: context.tr('sys_siri_section_say'),
          children: [
            for (final (sentence, action) in kSiriSentences)
              HighlightableRow(
                id: 'siri.$sentence',
                child: SettingsInfoRow(
                  title: context.tr(sentence, params: app),
                  subtitle: context.tr(action),
                ),
              ),
          ],
        ),
        InsetSection(
          header: context.tr('sys_siri_section_shortcuts'),
          footer: context.tr('sys_siri_shortcuts_note', params: app),
          children: [
            HighlightableRow(
              id: 'siri.shortcuts',
              child: NavRow(
                title: context.tr('sys_siri_open_shortcuts'),
                onTap: () => unawaited(
                  ref.read(settingsExternalActionsProvider).openUrl(
                    kShortcutsAppUrl,
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

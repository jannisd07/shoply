import 'package:flutter/widgets.dart';

import 'package:shoply/core/constants/app_brand.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/screens/profile/settings/widgets/settings_page.dart';
import 'package:shoply/presentation/screens/system/widgets/settings_info_row.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';

/// The home-screen widgets of `ios/ShoppingListWidget` (`WidgetBundle`):
/// name key, description key and sizes key.
const List<(String, String, String)> kHomeWidgets = [
  ('sys_widget_list', 'sys_widget_list_sub', 'sys_widget_sizes_all'),
  ('sys_widget_quick', 'sys_widget_quick_sub', 'sys_widget_sizes_small_medium'),
  ('sys_widget_recipes', 'sys_widget_recipes_sub', 'sys_widget_sizes_all'),
];

/// "Widgets" (`/settings/widgets`, Konzept 18 §6): which widgets Avo has, in
/// which sizes, and how to add one. An info page until B9 rebuilds the
/// widgets; nothing here changes a setting.
class WidgetsSettingsScreen extends StatelessWidget {
  const WidgetsSettingsScreen({super.key, this.highlightRowId});

  /// Row to highlight once (`?row=`).
  final String? highlightRowId;

  @override
  Widget build(BuildContext context) {
    final app = {'app': AppBrand.name};
    return SettingsPage(
      title: context.tr('sys_widgets_title'),
      intro: context.tr('sys_widgets_intro', params: app),
      highlightRowId: highlightRowId,
      children: [
        InsetSection(
          header: context.tr('sys_widgets_section', params: app),
          footer: context.tr('sys_widgets_how', params: app),
          children: [
            for (final (name, description, sizes) in kHomeWidgets)
              SettingsInfoRow(
                title: context.tr(name),
                subtitle: context.tr(description),
                value: context.tr(sizes),
              ),
          ],
        ),
      ],
    );
  }
}

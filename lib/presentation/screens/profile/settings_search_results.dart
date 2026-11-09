import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/screens/profile/profile_root_pages.dart';
import 'package:shoply/presentation/screens/profile/settings_search_index.dart';
import 'package:shoply/presentation/widgets/design/avo_figure.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/empty_state.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';
import 'package:shoply/routes/route_paths.dart';

/// Separator between the page titles of a hit's path.
const String _kPathSeparator = ' › ';

/// The hits of the settings search (Konzept 18 §3.5): one section
/// "Einstellungen" with the title, the path as second line and the page's
/// tile; without hits an [EmptyState] that points to the iOS Settings.
class SettingsSearchResults extends StatelessWidget {
  const SettingsSearchResults({
    super.key,
    required this.query,
    required this.hits,
    required this.onOpen,
    required this.onOpenSystemSettings,
    this.killSwitch = false,
  });

  /// What was typed (shown in the empty state).
  final String query;
  final List<SettingsSearchHit> hits;

  /// Opens a hit's location (`/settings/diet?row=diet.allergies`).
  final ValueChanged<String> onOpen;

  /// "iOS-Einstellungen öffnen".
  final VoidCallback onOpenSystemSettings;

  final bool killSwitch;

  @override
  Widget build(BuildContext context) {
    if (hits.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: AvoSpacing.m),
        child: EmptyState(
          pose: AvoPose.thinking,
          icon: const AvoIcon(AvoIcons.search),
          title: context.tr(
            'prof_search_none_title',
            params: {'query': query.trim()},
          ),
          message: context.tr('prof_search_none_message'),
          actionLabel: context.tr('prof_search_open_ios'),
          onAction: onOpenSystemSettings,
        ),
      );
    }
    return InsetSection(
      header: context.tr('prof_search_section'),
      separatorIndent: kProfileRowTextInset,
      children: [
        for (final hit in hits)
          NavRow(
            title: context.tr(hit.titleKey),
            subtitle: hit.pathKeys.isEmpty
                ? null
                : hit.pathKeys.map(context.tr).join(_kPathSeparator),
            leading: _tileOf(hit),
            onTap: () => onOpen(hit.location),
          ),
      ],
    );
  }

  Widget _tileOf(SettingsSearchHit hit) {
    final page = hit.page;
    if (page != null) return ProfileRowTile.page(page, killSwitch: killSwitch);
    return switch (hit.entry.route) {
      RoutePaths.pro => const ProfileRowTile(
        icon: ProfileIcons.pro,
        color: ProfileTileColors.pro,
      ),
      _ => ProfileRowTile(
        icon: hit.entry.icon ?? AvoIcons.person,
        color: ProfileTileColors.account,
      ),
    };
  }
}

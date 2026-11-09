import 'package:flutter/widgets.dart';

import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/core/modules/module_descriptors.dart';
import 'package:shoply/presentation/screens/profile/settings/widgets/settings_page.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/routes/route_paths.dart';

/// Stroke of the outline glyphs on a tile, so a 16 pt line stays visible.
const double _kTileStroke = 2;

/// Text edge of a row with a tile (D2 `.sep` left 58), the same as on the
/// settings pages. Hairlines between such rows start here.
const double kProfileRowTextInset = kSettingsTileRowIndent;

/// Glyphs of the profile rows that neither `AvoIcons` nor the settings
/// pages' `SettingsIcons` have, on the 24 grid; the D2 ones from the
/// X-Profil SVG paths.
abstract final class ProfileIcons {
  /// Avo Pro: a four-point star (D2 X-Profil).
  static const pro = AvoIconData([
    AvoIconPath(
      'M12 2l2.4 7.2L22 12l-7.6 2.8L12 22l-2.4-7.2L2 12l7.6-2.8z',
      style: AvoIconStyle.fill,
    ),
  ]);

  /// Preise & Angebote: a basket (D2 X-Profil).
  static const offers = AvoIconData([
    AvoIconPath('M4 7h16l-1.5 11H5.5z', style: AvoIconStyle.fill),
  ]);

  /// Siri & Kurzbefehle: a waveform.
  static const siri = AvoIconData([
    AvoIconPath('M4 10v4M8 7v10M12 4v16M16 7v10M20 10v4'),
  ], strokeWidth: _kTileStroke);

  /// Widgets: three tiles.
  static const widgets = AvoIconData([
    AvoIconRect(3, 3, 8, 8, radius: 2),
    AvoIconRect(13, 3, 8, 8, radius: 2),
    AvoIconRect(3, 13, 18, 8, radius: 2),
  ], strokeWidth: _kTileStroke);

  /// Konto: a person in a circle (`person.crop.circle`).
  static const account = AvoIconData([
    AvoIconCircle(12, 12, 9),
    AvoIconCircle(12, 10, 3),
    AvoIconPath('M6.4 18.3c1.2-2 3.2-3.1 5.6-3.1s4.4 1.1 5.6 3.1'),
  ], strokeWidth: _kTileStroke);
}

/// Tile colours of the profile rows. Data like the list palette and the
/// module tiles, not design tokens: the D2 ones from X-Profil, the others
/// iOS system colours so neighbouring rows differ.
abstract final class ProfileTileColors {
  static const pro = Color(0xFF1F7A3A); // D2
  static const modules = Color(0xFF0062CC); // D2
  static const offers = Color(0xFF34C759); // D2
  static const diet = Color(0xFF30B0C7); // iOS teal
  static const personal = Color(0xFFAF52DE); // iOS purple
  static const lists = Color(0xFFFF9F0A); // D2
  static const notifications = Color(0xFFFF3B30); // D2
  static const appearance = Color(0xFF8E8E93); // D2
  static const language = Color(0xFF007AFF); // iOS blue
  static const siri = Color(0xFF5856D6); // iOS indigo
  static const widgets = Color(0xFFFF2D55); // D2
  static const help = Color(0xFF32ADE6); // iOS cyan
  static const legal = Color(0xFF636366); // iOS grey 2
  static const account = Color(0xFFA2845E); // iOS brown
}

/// The pages the profile root links to, in its order (Konzept 18 §3.2, §6).
enum ProfilePageId {
  modules,
  offers,
  health,
  plan,
  avo,
  diet,
  personal,
  lists,
  notifications,
  appearance,
  language,
  siri,
  widgets,
  help,
  legal,
  account,
}

/// One page of the profile root: route, title, symbol and tile.
@immutable
class ProfilePage {
  const ProfilePage({
    required this.id,
    required this.route,
    required this.titleKey,
    required this.icon,
    required this.tileColor,
    this.keywordsKey,
    this.module,
    this.teilB = false,
    this.killSwitchTitleKey,
    this.killSwitchIcon,
  });

  final ProfilePageId id;

  /// `/settings/<page>`.
  final String route;
  final String titleKey;
  final AvoIconData icon;
  final Color tileColor;

  /// Comma-separated search words of the page.
  final String? keywordsKey;

  /// Shown only while this module is on (the Module section).
  final AppModule? module;

  /// Teil B builds the page; the row shows only once its route exists.
  final bool teilB;

  /// Title and symbol while the offers kill switch is on ("Märkte").
  final String? killSwitchTitleKey;
  final AvoIconData? killSwitchIcon;

  String titleKeyFor({required bool killSwitch}) =>
      killSwitch ? (killSwitchTitleKey ?? titleKey) : titleKey;

  AvoIconData iconFor({required bool killSwitch}) =>
      killSwitch ? (killSwitchIcon ?? icon) : icon;
}

ModuleDescriptor _descriptor(AppModule module) =>
    moduleDescriptors.firstWhere((d) => d.module == module);

/// All pages of the profile root. Module pages use the symbol and tile of
/// their module (same as onboarding and Einstellungen > Module).
final List<ProfilePage> profilePages = [
  const ProfilePage(
    id: ProfilePageId.modules,
    route: RoutePaths.settingsModules,
    titleKey: 'prof_row_modules',
    icon: SettingsIcons.switches,
    tileColor: ProfileTileColors.modules,
    keywordsKey: 'prof_kw_modules',
  ),
  const ProfilePage(
    id: ProfilePageId.offers,
    route: RoutePaths.settingsOffers,
    titleKey: 'prof_row_offers',
    icon: ProfileIcons.offers,
    tileColor: ProfileTileColors.offers,
    keywordsKey: 'prof_kw_markets',
    teilB: true,
    killSwitchTitleKey: 'prof_row_markets',
    killSwitchIcon: AvoIcons.storefront,
  ),
  ProfilePage(
    id: ProfilePageId.health,
    route: RoutePaths.settingsHealth,
    titleKey: 'prof_row_health',
    icon: _descriptor(AppModule.calories).icon,
    tileColor: _descriptor(AppModule.calories).tileColor,
    keywordsKey: 'prof_kw_health',
    module: AppModule.calories,
    teilB: true,
  ),
  ProfilePage(
    id: ProfilePageId.plan,
    route: RoutePaths.settingsPlan,
    titleKey: 'prof_row_plan',
    icon: _descriptor(AppModule.mealPlan).icon,
    tileColor: _descriptor(AppModule.mealPlan).tileColor,
    keywordsKey: 'prof_kw_plan',
    module: AppModule.mealPlan,
    teilB: true,
  ),
  ProfilePage(
    id: ProfilePageId.avo,
    route: RoutePaths.settingsAvo,
    titleKey: 'prof_row_avo',
    icon: _descriptor(AppModule.avo).icon,
    tileColor: _descriptor(AppModule.avo).tileColor,
    keywordsKey: 'prof_kw_avo',
    module: AppModule.avo,
    teilB: true,
  ),
  const ProfilePage(
    id: ProfilePageId.diet,
    route: RoutePaths.settingsDiet,
    titleKey: 'prof_row_diet',
    icon: SettingsIcons.leaf,
    tileColor: ProfileTileColors.diet,
    keywordsKey: 'prof_kw_diet',
  ),
  const ProfilePage(
    id: ProfilePageId.personal,
    route: RoutePaths.settingsPersonal,
    titleKey: 'prof_row_personal',
    icon: SettingsIcons.personText,
    tileColor: ProfileTileColors.personal,
    keywordsKey: 'prof_kw_personal',
  ),
  const ProfilePage(
    id: ProfilePageId.lists,
    route: RoutePaths.settingsLists,
    titleKey: 'prof_row_lists',
    icon: SettingsIcons.checklist,
    tileColor: ProfileTileColors.lists,
    keywordsKey: 'prof_kw_lists',
  ),
  const ProfilePage(
    id: ProfilePageId.notifications,
    route: RoutePaths.settingsNotifications,
    titleKey: 'prof_row_notifications',
    icon: SettingsIcons.bell,
    tileColor: ProfileTileColors.notifications,
    keywordsKey: 'prof_kw_notifications',
  ),
  const ProfilePage(
    id: ProfilePageId.appearance,
    route: RoutePaths.settingsAppearance,
    titleKey: 'prof_row_appearance',
    icon: SettingsIcons.appearance,
    tileColor: ProfileTileColors.appearance,
    keywordsKey: 'prof_kw_appearance',
  ),
  const ProfilePage(
    id: ProfilePageId.language,
    route: RoutePaths.settingsLanguage,
    titleKey: 'prof_row_language',
    icon: SettingsIcons.globe,
    tileColor: ProfileTileColors.language,
    keywordsKey: 'prof_kw_language',
  ),
  const ProfilePage(
    id: ProfilePageId.siri,
    route: RoutePaths.settingsSiri,
    titleKey: 'prof_row_siri',
    icon: ProfileIcons.siri,
    tileColor: ProfileTileColors.siri,
    keywordsKey: 'prof_kw_siri',
    teilB: true,
  ),
  const ProfilePage(
    id: ProfilePageId.widgets,
    route: RoutePaths.settingsWidgets,
    titleKey: 'prof_row_widgets',
    icon: ProfileIcons.widgets,
    tileColor: ProfileTileColors.widgets,
    keywordsKey: 'prof_kw_widgets',
    teilB: true,
  ),
  const ProfilePage(
    id: ProfilePageId.help,
    route: RoutePaths.settingsHelp,
    titleKey: 'prof_row_help',
    icon: AvoIcons.questionmarkCircle,
    tileColor: ProfileTileColors.help,
    keywordsKey: 'prof_kw_help',
  ),
  const ProfilePage(
    id: ProfilePageId.legal,
    route: RoutePaths.settingsLegal,
    titleKey: 'prof_row_legal',
    icon: SettingsIcons.doc,
    tileColor: ProfileTileColors.legal,
    keywordsKey: 'prof_kw_legal',
  ),
  const ProfilePage(
    id: ProfilePageId.account,
    route: RoutePaths.settingsAccount,
    titleKey: 'prof_row_account',
    icon: ProfileIcons.account,
    tileColor: ProfileTileColors.account,
    keywordsKey: 'prof_kw_account',
  ),
];

/// The page [id].
ProfilePage profilePage(ProfilePageId id) =>
    profilePages.firstWhere((p) => p.id == id);

/// The page a settings location belongs to (`/settings/diet?row=x` → Ernährung
/// & Allergien, `/settings/legal/sources` → Rechtliches), or null.
ProfilePage? profilePageOf(String location) {
  final segments = Uri.parse(location).pathSegments;
  if (segments.length < 2 || '/${segments.first}' != RoutePaths.settings) {
    return null;
  }
  final route = '${RoutePaths.settings}/${segments[1]}';
  for (final p in profilePages) {
    if (p.route == route) return p;
  }
  return null;
}

/// The coloured icon tile in front of a profile row (D2 X-Profil): the
/// settings pages' [SettingsIconTile], white glyph on [color], decorative
/// (the row title carries the meaning).
class ProfileRowTile extends StatelessWidget {
  const ProfileRowTile({super.key, required this.icon, required this.color});

  /// The tile of [page].
  ProfileRowTile.page(ProfilePage page, {super.key, bool killSwitch = false})
    : icon = page.iconFor(killSwitch: killSwitch),
      color = page.tileColor;

  final AvoIconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      SettingsIconTile(icon: icon, color: color);
}

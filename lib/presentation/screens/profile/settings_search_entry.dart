import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';

/// One entry of the settings search (Konzept 18 §3.5, E18-12): a page or one
/// row on it. Titles and search words are translation keys, so the index
/// works in both languages and offline.
class SettingsSearchEntry {
  const SettingsSearchEntry({
    required this.route,
    required this.titleKey,
    this.pathKeys = const [],
    this.keywordsKeys = const [],
    this.rowId,
    this.icon,
    this.offersTerm = false,
    this.module,
    this.killSwitchTitleKey,
    this.killSwitchPathKeys,
  });

  /// Route of the page, e.g. `/settings/diet`.
  final String route;

  /// Title of the hit (the row, or the page itself).
  final String titleKey;

  /// Page titles shown as the path under the hit ("Preise & Angebote ›
  /// Region"), outermost first.
  final List<String> pathKeys;

  /// Keys whose texts hold comma-separated search words ("PLZ, Postleitzahl").
  final List<String> keywordsKeys;

  /// Row to highlight after the push (`?row=<rowId>`, E18-14); null for a page.
  final String? rowId;

  /// Symbol of the page.
  final AvoIconData? icon;

  /// An offers term ("Angebot", "Prospekt"): hidden while the offers kill
  /// switch is on (§3.5).
  final bool offersTerm;

  /// The entry belongs to this module's page: hidden while the module is off
  /// (Konzept 18 Regel 4).
  final AppModule? module;

  /// Title while the offers kill switch is on ("Märkte" instead of "Preise &
  /// Angebote", Regel 4); null keeps [titleKey].
  final String? killSwitchTitleKey;

  /// Path while the offers kill switch is on; null keeps [pathKeys].
  final List<String>? killSwitchPathKeys;
}

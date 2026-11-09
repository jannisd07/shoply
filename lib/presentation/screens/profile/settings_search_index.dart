import 'package:flutter/foundation.dart';

import 'package:shoply/core/localization/app_translations.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/presentation/screens/profile/account/account_search.dart';
import 'package:shoply/presentation/screens/profile/profile_root_pages.dart';
import 'package:shoply/presentation/screens/profile/settings/settings_pages_search.dart';
import 'package:shoply/presentation/screens/profile/settings_search_entry.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart'
    show bSettingsSearchEntries;
import 'package:shoply/routes/route_paths.dart';

/// Search entries of the profile root itself: Profil bearbeiten, Avo Pro and
/// every Teil-A page it links to (Konzept 18 §3.5). The pages add their rows
/// in `settingsPagesSearchEntries` and `accountSearchEntries`.
final List<SettingsSearchEntry> profileRootSearchEntries = [
  const SettingsSearchEntry(
    route: RoutePaths.settingsProfile,
    titleKey: 'prof_edit_profile',
    keywordsKeys: ['prof_kw_profile'],
  ),
  const SettingsSearchEntry(
    route: RoutePaths.pro,
    titleKey: 'prof_pro',
    keywordsKeys: ['prof_kw_pro'],
    icon: ProfileIcons.pro,
  ),
  for (final p in profilePages)
    if (!p.teilB)
      SettingsSearchEntry(
        route: p.route,
        titleKey: p.titleKey,
        keywordsKeys: [?p.keywordsKey],
        icon: p.icon,
      ),
];

/// Every entry of the settings search. The pages' own entries come first,
/// so a page that describes itself wins over the root's short entry.
List<SettingsSearchEntry> allSettingsSearchEntries() => [
  ...settingsPagesSearchEntries,
  ...accountSearchEntries,
  ...profileRootSearchEntries,
  ...bSettingsSearchEntries,
];

/// What the search has to know about the app right now.
@immutable
class SettingsSearchScope {
  const SettingsSearchScope({
    required this.routes,
    required this.enabledModules,
    this.killSwitch = false,
    this.languageCode = 'de',
  });

  /// Registered route patterns (`/settings/legal/:doc`), see
  /// [isRouteRegistered].
  final Set<String> routes;

  /// Modules that are on.
  final Set<AppModule> enabledModules;

  /// The offers kill switch is on.
  final bool killSwitch;

  /// The app language: its hits rank before hits in the other language.
  final String languageCode;
}

/// One hit, with title and path resolved for the kill switch.
@immutable
class SettingsSearchHit {
  const SettingsSearchHit({
    required this.entry,
    required this.titleKey,
    required this.pathKeys,
    required this.page,
  });

  final SettingsSearchEntry entry;
  final String titleKey;

  /// Path under the title, outermost first; empty for a page of the root.
  final List<String> pathKeys;

  /// The root page the hit belongs to (symbol, tile); null for Avo Pro and
  /// Profil bearbeiten.
  final ProfilePage? page;

  /// Where tapping the hit leads: the page, with `?row=` for a row.
  String get location {
    final row = entry.rowId;
    return row == null ? entry.route : RoutePaths.settingsRow(entry.route, row);
  }
}

/// Whether [location] (path, query ignored) matches one of [patterns];
/// `:name` segments match any value.
bool isRouteRegistered(Set<String> patterns, String location) {
  final path = Uri.parse(location).path;
  if (patterns.contains(path)) return true;
  final segments = path.split('/');
  for (final pattern in patterns) {
    final parts = pattern.split('/');
    if (parts.length != segments.length) continue;
    var ok = true;
    for (var i = 0; i < parts.length && ok; i++) {
      ok = parts[i].startsWith(':') || parts[i] == segments[i];
    }
    if (ok) return true;
  }
  return false;
}

/// Lower case, umlauts and ß folded, hyphens dropped ("E-Mail" → "email"),
/// everything else that is not a letter or digit a space.
String normalizeSettingsQuery(String text) {
  final lower = text
      .toLowerCase()
      .replaceAll('ä', 'a')
      .replaceAll('ö', 'o')
      .replaceAll('ü', 'u')
      .replaceAll('ß', 'ss')
      .replaceAll('é', 'e')
      .replaceAll('-', '');
  return lower.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

const List<String> _kSearchLanguages = ['de', 'en'];

String _text(String key, String language) => AppTranslations.get(key, language);

/// Searches [entries] for [query] in German and English at once, locally and
/// without waiting (Konzept 18 §3.5).
///
/// Every word of the query must start a word of the entry's title, search
/// words or path. Title matches rank first. Hits of one page stay together,
/// the page itself first. Entries whose route does not exist, whose module is
/// off or that are offers terms under the kill switch are left out; the same
/// title at the same place shows once.
List<SettingsSearchHit> searchSettings(
  String query,
  SettingsSearchScope scope, {
  List<SettingsSearchEntry>? entries,
}) {
  final tokens = normalizeSettingsQuery(query).split(' ')
    ..removeWhere((t) => t.isEmpty);
  if (tokens.isEmpty) return const [];

  final scored = <({SettingsSearchHit hit, int score, int order})>[];
  final seen = <String>{};
  var order = 0;
  for (final entry in entries ?? allSettingsSearchEntries()) {
    order++;
    if (!_visible(entry, scope)) continue;
    final page = profilePageOf(entry.route);
    final titleKey = scope.killSwitch
        ? (entry.killSwitchTitleKey ?? entry.titleKey)
        : entry.titleKey;
    var pathKeys = scope.killSwitch
        ? (entry.killSwitchPathKeys ?? entry.pathKeys)
        : entry.pathKeys;
    if (pathKeys.isEmpty && entry.rowId != null && page != null) {
      pathKeys = [page.titleKeyFor(killSwitch: scope.killSwitch)];
    }
    final score = _rankedScore(
      tokens,
      titleKey,
      entry.keywordsKeys,
      pathKeys,
      scope.languageCode,
    );
    if (score == 0) continue;
    final hit = SettingsSearchHit(
      entry: entry,
      titleKey: titleKey,
      pathKeys: pathKeys,
      page: page,
    );
    // The same title at the same place shows once (a page that describes
    // itself and the root's entry for it, the two offers entries).
    if (!seen.add('${hit.location}|${_text(titleKey, 'de')}')) continue;
    scored.add((hit: hit, score: score, order: order));
  }

  // Group by page, best group first; inside a group the page, then its rows.
  String groupOf(SettingsSearchHit h) => h.page?.route ?? h.entry.route;
  final best = <String, int>{};
  final firstSeen = <String, int>{};
  for (final s in scored) {
    final g = groupOf(s.hit);
    if ((best[g] ?? 0) < s.score) best[g] = s.score;
    firstSeen.putIfAbsent(g, () => _rootOrder(s.hit));
  }
  scored.sort((a, b) {
    final ga = groupOf(a.hit);
    final gb = groupOf(b.hit);
    if (ga != gb) {
      final byScore = best[gb]!.compareTo(best[ga]!);
      if (byScore != 0) return byScore;
      return firstSeen[ga]!.compareTo(firstSeen[gb]!);
    }
    final pageA = _isPage(a.hit, ga) ? 0 : 1;
    final pageB = _isPage(b.hit, gb) ? 0 : 1;
    if (pageA != pageB) return pageA.compareTo(pageB);
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.order.compareTo(b.order);
  });
  return [for (final s in scored) s.hit];
}

/// The hit is the page of its group itself (not a row or a subpage).
bool _isPage(SettingsSearchHit hit, String group) =>
    hit.entry.rowId == null && Uri.parse(hit.entry.route).path == group;

/// Shown when the route exists, the offers term is allowed and both the
/// row's module and its page's module are on: a Kalorien row on the Avo
/// page needs Avo **and** Kalorien (status-B 16).
bool _visible(SettingsSearchEntry entry, SettingsSearchScope scope) {
  if (entry.offersTerm && scope.killSwitch) return false;
  bool off(AppModule? m) => m != null && !scope.enabledModules.contains(m);
  if (off(entry.module) || off(profilePageOf(entry.route)?.module)) {
    return false;
  }
  return entry.route == RoutePaths.pro ||
      isRouteRegistered(scope.routes, entry.route);
}

/// Position of the hit's page on the root (unknown pages last).
int _rootOrder(SettingsSearchHit hit) {
  final page = hit.page;
  if (hit.entry.route == RoutePaths.settingsProfile) return -2;
  if (hit.entry.route == RoutePaths.pro) return -1;
  return page == null ? profilePages.length : profilePages.indexOf(page);
}

/// [_score] in the app language first: any hit there (4 to 6) ranks before a
/// hit that only the other language finds (1 to 3), so "nut" in English
/// finds the allergies before the German "Nutzungsbedingungen".
int _rankedScore(
  List<String> tokens,
  String titleKey,
  List<String> keywordsKeys,
  List<String> pathKeys,
  String languageCode,
) {
  final own = _score(tokens, titleKey, keywordsKeys, pathKeys, [languageCode]);
  if (own > 0) return own + 3;
  return _score(tokens, titleKey, keywordsKeys, pathKeys, _kSearchLanguages);
}

/// 3: the title starts with the whole query; 2: every word starts a title
/// word; 1: every word starts a word somewhere in the entry; 0: no hit.
int _score(
  List<String> tokens,
  String titleKey,
  List<String> keywordsKeys,
  List<String> pathKeys,
  List<String> languages,
) {
  final titles = [
    for (final l in languages) normalizeSettingsQuery(_text(titleKey, l)),
  ];
  final phrase = tokens.join(' ');
  if (titles.any((t) => t.startsWith(phrase))) return 3;
  bool allIn(Iterable<String> words) =>
      tokens.every((t) => words.any((w) => w.startsWith(t)));
  final titleWords = [for (final t in titles) ...t.split(' ')];
  if (allIn(titleWords)) return 2;
  final words = <String>[
    ...titleWords,
    for (final l in languages) ...[
      for (final k in keywordsKeys)
        for (final term in _text(k, l).split(','))
          ...normalizeSettingsQuery(term).split(' '),
      for (final k in pathKeys)
        ...normalizeSettingsQuery(_text(k, l)).split(' '),
    ],
  ];
  // A search word made of several words ("Bildschirm an") also matches as a
  // whole.
  final phrases = [
    for (final l in languages)
      for (final k in keywordsKeys)
        for (final term in _text(k, l).split(',')) normalizeSettingsQuery(term),
  ];
  if (allIn(words) || phrases.any((p) => p.startsWith(phrase))) return 1;
  return 0;
}

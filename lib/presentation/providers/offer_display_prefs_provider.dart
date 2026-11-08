/// What the person chose about offer surfaces and markets (`angebote.md`
/// 3.1, 3.4, S1, S3, S5, S7, S10, S12, S13): the single switches of "Preise
/// & Angebote", "Diese Woche ausblenden" per list, "Nicht dieses Angebot"
/// per item, "Nicht interessiert" per offer, the snoozed "Markt wählen" and
/// "Postleitzahl festlegen" hints, "Nicht fragen" for a suggested market,
/// the favourite markets in their order and "Markt automatisch erkennen".
///
/// The favourite markets and the detection switch are core ("Markt pro
/// Liste"): they work with the offers module off and the kill switch too.
///
/// Kept on this device per account until the account table
/// `user_offer_prefs` exists (Lücke L4/L6, owner question 14): one JSON
/// value in SharedPreferences under [offerDisplayPrefsKeyFor]; signed out
/// nothing is stored. Another account on the device starts with none of it.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/providers/list_offer_prefs_provider.dart';
import 'package:shoply/presentation/providers/region_provider.dart';

/// Prefix of the SharedPreferences key of [OfferDisplayPrefs]. A value
/// stored under the bare prefix (device-wide, only on development builds of
/// this branch) is dropped, not moved to an account.
const String offerDisplayPrefsKey = 'offers_display_prefs_v1';

/// SharedPreferences key of the choices of [userId].
String offerDisplayPrefsKeyFor(String userId) =>
    '$offerDisplayPrefsKey:$userId';

/// SharedPreferences key of the favourite markets picked while nobody is
/// signed in (the onboarding asks before the account step). The first
/// account that loads its choices on this device takes them over, unless it
/// has favourites of its own; then the key goes.
const String pendingFavoriteStoresKey = 'offers_pending_favorites_v1';

/// How long a dismissed "Für welchen Markt ist …?" hint stays away.
const Duration noStoreHintPause = Duration(days: 7);

/// How long a dismissed "Postleitzahl festlegen" hint stays away (3.4).
const Duration postcodeHintPause = Duration(days: 7);

/// "Nicht interessiert" holds at most this long, or until the offer ends.
const Duration notInterestedMax = Duration(days: 7);

/// The surfaces with a switch of their own in "Preise & Angebote" (S12).
enum OfferSurface {
  /// S3 pill, S4 card, S8 counter, S9 rows: "Angebote an Artikeln".
  itemOffers,

  /// S6: "Vorschläge beim Tippen".
  typingSuggestions,

  /// S7: "Ersparnis in der Liste".
  listSavings,

  /// "Oft gekauft" in S9 and S10, the Home savings tips: "Spar-Hinweise
  /// auf der Startseite".
  homeTips,

  /// Savings after shopping and in the history: "Ersparnis im Verlauf und
  /// nach dem Einkauf".
  historySavings,
}

/// An offer the person does not want for one item, until the offer ends.
@immutable
class DeclinedOffer {
  const DeclinedOffer({required this.offerId, required this.until});

  final int offerId;
  final DateTime until;
}

@immutable
class OfferDisplayPrefs {
  const OfferDisplayPrefs({
    this.off = const {},
    this.summaryHiddenWeek = const {},
    this.declined = const {},
    this.noStoreHintUntil = const {},
    this.noStoreHintWeek = const {},
    this.dontAskStore = const {},
    this.favorites = const [],
    this.favoritesChosen = false,
    this.detectOff = false,
    this.postcodeHintUntil,
    this.notInterested = const {},
  });

  /// Surfaces the person switched off.
  final Set<OfferSurface> off;

  /// List id -> week key ([weekKey]) in which the savings line is hidden.
  final Map<String, String> summaryHiddenWeek;

  /// Item id -> the offer hidden for it.
  final Map<String, DeclinedOffer> declined;

  /// List id -> until when the "Markt wählen" hint stays away (closed).
  final Map<String, DateTime> noStoreHintUntil;

  /// List id -> week key ([weekKey]) in which the "Markt wählen" hint was
  /// shown: at most once a week per list (`angebote.md` 3.4).
  final Map<String, String> noStoreHintWeek;

  /// List id -> chain the person does not want suggested again.
  final Map<String, String> dontAskStore;

  /// Favourite markets (directory chain ids) in the person's order (S13):
  /// the menu of S1 lists them first, S2 under "Deine Märkte".
  final List<String> favorites;

  /// Whether the person ever chose favourites (an empty choice counts), so
  /// a pending choice from the onboarding never overwrites one.
  final bool favoritesChosen;

  /// "Markt automatisch erkennen" is off: no suggested markets.
  final bool detectOff;

  /// Until when the "Postleitzahl festlegen" hint stays away (closed).
  final DateTime? postcodeHintUntil;

  /// Offer id -> until when "Nicht interessiert" hides it (S10).
  final Map<int, DateTime> notInterested;

  bool isOn(OfferSurface surface) => !off.contains(surface);

  /// Whether "Markt automatisch erkennen" is on.
  bool get detectStore => !detectOff;

  /// Whether the "Postleitzahl festlegen" hint may show at [now].
  bool postcodeHintAllowed(DateTime now) {
    final until = postcodeHintUntil;
    return until == null || !now.isBefore(until);
  }

  /// Whether [offerId] is hidden by "Nicht interessiert" at [now].
  bool isNotInterested(int offerId, DateTime now) {
    final until = notInterested[offerId];
    return until != null && now.isBefore(until);
  }

  /// Whether [offerId] is hidden for [itemId] at [now].
  bool isDeclined(String itemId, int offerId, DateTime now) {
    final d = declined[itemId];
    return d != null && d.offerId == offerId && now.isBefore(d.until);
  }

  OfferDisplayPrefs copyWith({
    Set<OfferSurface>? off,
    Map<String, String>? summaryHiddenWeek,
    Map<String, DeclinedOffer>? declined,
    Map<String, DateTime>? noStoreHintUntil,
    Map<String, String>? noStoreHintWeek,
    Map<String, String>? dontAskStore,
    List<String>? favorites,
    bool? favoritesChosen,
    bool? detectOff,
    DateTime? postcodeHintUntil,
    Map<int, DateTime>? notInterested,
  }) => OfferDisplayPrefs(
    off: off ?? this.off,
    summaryHiddenWeek: summaryHiddenWeek ?? this.summaryHiddenWeek,
    declined: declined ?? this.declined,
    noStoreHintUntil: noStoreHintUntil ?? this.noStoreHintUntil,
    noStoreHintWeek: noStoreHintWeek ?? this.noStoreHintWeek,
    dontAskStore: dontAskStore ?? this.dontAskStore,
    favorites: favorites ?? this.favorites,
    favoritesChosen: favoritesChosen ?? this.favoritesChosen,
    detectOff: detectOff ?? this.detectOff,
    postcodeHintUntil: postcodeHintUntil ?? this.postcodeHintUntil,
    notInterested: notInterested ?? this.notInterested,
  );

  Map<String, Object?> toJson() => {
    'off': [for (final s in off) s.name],
    'summaryHiddenWeek': summaryHiddenWeek,
    'declined': {
      for (final e in declined.entries)
        e.key: {
          'offer': e.value.offerId,
          'until': e.value.until.toIso8601String(),
        },
    },
    'noStoreHintUntil': {
      for (final e in noStoreHintUntil.entries)
        e.key: e.value.toIso8601String(),
    },
    'noStoreHintWeek': noStoreHintWeek,
    'dontAskStore': dontAskStore,
    if (favoritesChosen) 'favorites': favorites,
    'detectOff': detectOff,
    if (postcodeHintUntil case final until?)
      'postcodeHintUntil': until.toIso8601String(),
    'notInterested': {
      for (final e in notInterested.entries)
        '${e.key}': e.value.toIso8601String(),
    },
  };

  /// Reads [toJson]; drops what has run out at [now].
  static OfferDisplayPrefs fromJson(Map<String, dynamic> json, DateTime now) {
    final week = weekKey(now);
    return OfferDisplayPrefs(
      off: {
        for (final name in (json['off'] as List? ?? const []))
          for (final s in OfferSurface.values)
            if (s.name == name) s,
      },
      summaryHiddenWeek: {
        for (final e in (json['summaryHiddenWeek'] as Map? ?? const {}).entries)
          if (e.value == week) '${e.key}': week,
      },
      declined: {
        for (final e in (json['declined'] as Map? ?? const {}).entries)
          if (_declined(e.value) case final d? when now.isBefore(d.until))
            '${e.key}': d,
      },
      noStoreHintUntil: {
        for (final e in (json['noStoreHintUntil'] as Map? ?? const {}).entries)
          if (DateTime.tryParse('${e.value}') case final until?
              when now.isBefore(until))
            '${e.key}': until,
      },
      noStoreHintWeek: {
        for (final e in (json['noStoreHintWeek'] as Map? ?? const {}).entries)
          if (e.value == week) '${e.key}': week,
      },
      dontAskStore: {
        for (final e in (json['dontAskStore'] as Map? ?? const {}).entries)
          '${e.key}': '${e.value}',
      },
      favorites: [
        for (final id in (json['favorites'] as List? ?? const []))
          if (id is String) id,
      ],
      favoritesChosen: json['favorites'] is List,
      detectOff: json['detectOff'] == true,
      postcodeHintUntil: switch (DateTime.tryParse(
        '${json['postcodeHintUntil']}',
      )) {
        final until? when now.isBefore(until) => until,
        _ => null,
      },
      notInterested: {
        for (final e in (json['notInterested'] as Map? ?? const {}).entries)
          if ((int.tryParse('${e.key}'), DateTime.tryParse('${e.value}'))
              case (final id?, final until?) when now.isBefore(until))
            id: until,
      },
    );
  }

  static DeclinedOffer? _declined(Object? value) {
    if (value is! Map) return null;
    final id = value['offer'];
    final until = DateTime.tryParse('${value['until']}');
    if (id is! int || until == null) return null;
    return DeclinedOffer(offerId: id, until: until);
  }
}

/// "2026-W45": the ISO week of [date], the unit of "Diese Woche
/// ausblenden" (offers run Monday to Saturday).
String weekKey(DateTime date) {
  final d = DateTime.utc(date.year, date.month, date.day);
  // The Thursday of the same ISO week decides the year and the number.
  final thursday = d.add(Duration(days: DateTime.thursday - d.weekday));
  final week = 1 + thursday.difference(DateTime.utc(thursday.year)).inDays ~/ 7;
  return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
}

/// The clock of the offer prefs; override in tests.
final offerClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// The prefs of the signed-in account, null until loaded from the device.
/// Starts again (and loads the other account's choices) when the account
/// changes; signed out it holds an empty, unsaved set.
final offerDisplayPrefsProvider =
    StateNotifierProvider<OfferDisplayPrefsNotifier, OfferDisplayPrefs?>(
      (ref) => OfferDisplayPrefsNotifier(
        ref.watch(offerClockProvider),
        userId: ref.watch(offerAccountIdProvider),
      ),
    );

/// The favourite markets in the person's order (S13); empty until loaded
/// and without any. Core: independent of the offers module.
final favoriteStoresProvider = Provider<List<String>>(
  (ref) => ref.watch(
    offerDisplayPrefsProvider.select((p) => p?.favorites ?? const <String>[]),
  ),
);

/// "Markt automatisch erkennen" (S12): suggested markets only while it is
/// on. On until the saved choices say otherwise.
final storeDetectionOnProvider = Provider<bool>(
  (ref) => ref.watch(
    offerDisplayPrefsProvider.select((p) => p?.detectStore ?? true),
  ),
);

/// Whether an offer surface may show on [listId] (`angebote.md` 3.1):
/// offers available (module and kill switch), not hidden on the list, a
/// real region and the surface's own switch on. Closed until the saved
/// choices are loaded, so nothing flashes up and is taken back.
final offerSurfaceVisibleProvider =
    Provider.family<bool, ({OfferSurface surface, String listId})>((ref, key) {
      // The kill switch first: until the flags are known nothing else is
      // read, so neither the module choice nor the region is touched.
      if (!ref.watch(offersRemoteEnabledProvider)) return false;
      if (!ref.watch(offersVisibleForListProvider(key.listId))) return false;
      if (ref.watch(regionProvider) == null) return false;
      return ref.watch(
        offerDisplayPrefsProvider.select((p) => p?.isOn(key.surface) ?? false),
      );
    });

class OfferDisplayPrefsNotifier extends StateNotifier<OfferDisplayPrefs?> {
  OfferDisplayPrefsNotifier(this._now, {this.userId}) : super(null) {
    _loaded = _load();
  }

  final DateTime Function() _now;

  /// Whose choices these are; null signed out (nothing is stored).
  final String? userId;
  late final Future<void> _loaded;

  Future<void> _load() async {
    final id = userId;
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getStringList(pendingFavoriteStoresKey);
      if (id == null) {
        // Signed out (onboarding): only favourites picked here, kept until
        // an account takes them over.
        if (mounted) {
          state = OfferDisplayPrefs(
            favorites: [...?pending],
            favoritesChosen: pending != null,
          );
        }
        return;
      }
      if (prefs.containsKey(offerDisplayPrefsKey)) {
        await prefs.remove(offerDisplayPrefsKey);
      }
      final raw = prefs.getString(offerDisplayPrefsKeyFor(id));
      final json = raw == null ? null : jsonDecode(raw);
      var loaded = json is Map<String, dynamic>
          ? OfferDisplayPrefs.fromJson(json, _now())
          : const OfferDisplayPrefs();
      if (pending != null) {
        // Once: favourites from the onboarding go to this account, unless
        // it has chosen its own.
        await prefs.remove(pendingFavoriteStoresKey);
        if (!loaded.favoritesChosen) {
          loaded = loaded.copyWith(favorites: pending, favoritesChosen: true);
          await prefs.setString(
            offerDisplayPrefsKeyFor(id),
            jsonEncode(loaded.toJson()),
          );
        }
      }
      if (mounted) state = loaded;
    } catch (e) {
      debugPrint('⚠️ [OFFERS] Offer display choices not loaded: $e');
      if (mounted) state = const OfferDisplayPrefs();
    }
  }

  Future<void> _update(
    OfferDisplayPrefs Function(OfferDisplayPrefs) change,
  ) async {
    await _loaded;
    if (!mounted) return;
    final next = change(state ?? const OfferDisplayPrefs());
    state = next;
    final id = userId;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (id == null) {
        // Signed out only the favourites are kept, for the account that
        // signs in next.
        if (next.favoritesChosen) {
          await prefs.setStringList(pendingFavoriteStoresKey, next.favorites);
        }
        return;
      }
      await prefs.setString(
        offerDisplayPrefsKeyFor(id),
        jsonEncode(next.toJson()),
      );
    } catch (e) {
      debugPrint('⚠️ [OFFERS] Offer display choices not saved: $e');
    }
  }

  /// Turns [surface] on or off ("Nicht mehr zeigen" turns S7 off).
  Future<void> setSurface(OfferSurface surface, bool on) => _update(
    (p) => p.copyWith(
      off: on ? ({...p.off}..remove(surface)) : {...p.off, surface},
    ),
  );

  /// "Diese Woche ausblenden" on the savings line of [listId]; [hidden]
  /// false takes it back.
  Future<void> setSummaryHiddenThisWeek(String listId, bool hidden) => _update(
    (p) => p.copyWith(
      summaryHiddenWeek: hidden
          ? {...p.summaryHiddenWeek, listId: weekKey(_now())}
          : ({...p.summaryHiddenWeek}..remove(listId)),
    ),
  );

  /// "Nicht dieses Angebot": hides [offerId] for [itemId] until [until].
  Future<void> decline(String itemId, int offerId, DateTime until) => _update(
    (p) => p.copyWith(
      declined: {
        ...p.declined,
        itemId: DeclinedOffer(offerId: offerId, until: until),
      },
    ),
  );

  /// Takes "Nicht dieses Angebot" back for [itemId].
  Future<void> undecline(String itemId) =>
      _update((p) => p.copyWith(declined: {...p.declined}..remove(itemId)));

  /// The "Markt wählen" hint of [listId] stays away for [noStoreHintPause].
  Future<void> snoozeNoStoreHint(String listId) => _update(
    (p) => p.copyWith(
      noStoreHintUntil: {
        ...p.noStoreHintUntil,
        listId: _now().add(noStoreHintPause),
      },
    ),
  );

  /// Notes that the "Markt wählen" hint of [listId] was shown this week, so
  /// a later opening in the same week does not show it again.
  Future<void> markNoStoreHintShown(String listId) => _update(
    (p) => p.copyWith(
      noStoreHintWeek: {...p.noStoreHintWeek, listId: weekKey(_now())},
    ),
  );

  /// "Nicht fragen": [chainId] is not suggested for [listId] again.
  Future<void> dontAskStore(String listId, String chainId) => _update(
    (p) => p.copyWith(dontAskStore: {...p.dontAskStore, listId: chainId}),
  );

  /// The favourite markets in this order (S13, S14); unknown ids and
  /// doubles drop out.
  Future<void> setFavorites(List<String> chainIds) => _update((p) {
    final seen = <String>{};
    return p.copyWith(
      favorites: [
        for (final id in chainIds)
          if (seen.add(id)) id,
      ],
      favoritesChosen: true,
    );
  });

  /// Adds [chainId] at the end of the favourites, or removes it.
  Future<void> toggleFavorite(String chainId) => _update((p) {
    final next = [...p.favorites];
    if (!next.remove(chainId)) next.add(chainId);
    return p.copyWith(favorites: next, favoritesChosen: true);
  });

  /// Moves [chainId] [by] places (negative: up), within the list.
  Future<void> moveFavorite(String chainId, int by) => _update((p) {
    final next = [...p.favorites];
    final from = next.indexOf(chainId);
    if (from < 0) return p;
    final to = (from + by).clamp(0, next.length - 1);
    next
      ..removeAt(from)
      ..insert(to, chainId);
    return p.copyWith(favorites: next, favoritesChosen: true);
  });

  /// "Markt automatisch erkennen" on or off.
  Future<void> setDetectStore(bool on) =>
      _update((p) => p.copyWith(detectOff: !on));

  /// The "Postleitzahl festlegen" hint stays away for [postcodeHintPause].
  Future<void> snoozePostcodeHint() => _update(
    (p) => p.copyWith(postcodeHintUntil: _now().add(postcodeHintPause)),
  );

  /// "Nicht interessiert": hides [offerId] until [offerEnd], at most
  /// [notInterestedMax]; returns the day it shows again.
  Future<DateTime> notInterested(int offerId, DateTime? offerEnd) async {
    final max = _now().add(notInterestedMax);
    final until = offerEnd == null || offerEnd.isAfter(max) ? max : offerEnd;
    await _update(
      (p) => p.copyWith(notInterested: {...p.notInterested, offerId: until}),
    );
    return until;
  }

  /// Takes "Nicht interessiert" back for [offerId].
  Future<void> undoNotInterested(int offerId) => _update(
    (p) => p.copyWith(notInterested: {...p.notInterested}..remove(offerId)),
  );
}

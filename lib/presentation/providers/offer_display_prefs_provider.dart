/// What the person chose about offer surfaces (`angebote.md` 3.1, 3.4, S1,
/// S3, S5, S7): the single switches of "Preise & Angebote", "Diese Woche
/// ausblenden" per list, "Nicht dieses Angebot" per item, the snoozed
/// "Markt wählen" hint and "Nicht fragen" for a suggested market.
///
/// Kept on this device only until the account table `user_offer_prefs`
/// exists (Lücke L4/L6, owner question 14); one JSON value in
/// SharedPreferences.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/providers/list_offer_prefs_provider.dart';
import 'package:shoply/presentation/providers/region_provider.dart';

/// SharedPreferences key of [OfferDisplayPrefs].
const String offerDisplayPrefsKey = 'offers_display_prefs_v1';

/// How long a dismissed "Für welchen Markt ist …?" hint stays away.
const Duration noStoreHintPause = Duration(days: 7);

/// The surfaces with a switch of their own in "Preise & Angebote" (S12).
enum OfferSurface {
  /// S3 pill, S4 card, S8 counter, S9 rows: "Angebote an Artikeln".
  itemOffers,

  /// S6: "Vorschläge beim Tippen".
  typingSuggestions,

  /// S7: "Ersparnis in der Liste".
  listSavings,
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
    this.dontAskStore = const {},
  });

  /// Surfaces the person switched off.
  final Set<OfferSurface> off;

  /// List id -> week key ([weekKey]) in which the savings line is hidden.
  final Map<String, String> summaryHiddenWeek;

  /// Item id -> the offer hidden for it.
  final Map<String, DeclinedOffer> declined;

  /// List id -> until when the "Markt wählen" hint stays away.
  final Map<String, DateTime> noStoreHintUntil;

  /// List id -> chain the person does not want suggested again.
  final Map<String, String> dontAskStore;

  bool isOn(OfferSurface surface) => !off.contains(surface);

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
    Map<String, String>? dontAskStore,
  }) => OfferDisplayPrefs(
    off: off ?? this.off,
    summaryHiddenWeek: summaryHiddenWeek ?? this.summaryHiddenWeek,
    declined: declined ?? this.declined,
    noStoreHintUntil: noStoreHintUntil ?? this.noStoreHintUntil,
    dontAskStore: dontAskStore ?? this.dontAskStore,
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
    'dontAskStore': dontAskStore,
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
      dontAskStore: {
        for (final e in (json['dontAskStore'] as Map? ?? const {}).entries)
          '${e.key}': '${e.value}',
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

/// The prefs, null until loaded from the device.
final offerDisplayPrefsProvider =
    StateNotifierProvider<OfferDisplayPrefsNotifier, OfferDisplayPrefs?>(
      (ref) => OfferDisplayPrefsNotifier(ref.watch(offerClockProvider)),
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
  OfferDisplayPrefsNotifier(this._now) : super(null) {
    _loaded = _load();
  }

  final DateTime Function() _now;
  late final Future<void> _loaded;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(offerDisplayPrefsKey);
      final json = raw == null ? null : jsonDecode(raw);
      if (mounted) {
        state = json is Map<String, dynamic>
            ? OfferDisplayPrefs.fromJson(json, _now())
            : const OfferDisplayPrefs();
      }
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
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(offerDisplayPrefsKey, jsonEncode(next.toJson()));
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

  /// "Nicht fragen": [chainId] is not suggested for [listId] again.
  Future<void> dontAskStore(String listId, String chainId) => _update(
    (p) => p.copyWith(dontAskStore: {...p.dontAskStore, listId: chainId}),
  );
}

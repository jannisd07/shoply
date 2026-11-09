import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart'
    show openAppSettings;

import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/services/onboarding_answers_service.dart'
    show kOnboardingDietIds;
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/data/services/store_chain_directory.dart';
import 'package:shoply/data/services/subscription_service.dart';
import 'package:shoply/presentation/providers/region_provider.dart';
import 'package:shoply/presentation/providers/subscription_provider.dart';
import 'package:shoply/presentation/screens/profile/account/account_backend.dart';
import 'package:shoply/presentation/screens/profile/account/profile_edit_controller.dart';
import 'package:shoply/presentation/screens/profile/settings/data/notification_settings.dart';
import 'package:shoply/presentation/screens/profile/settings/data/profile_settings.dart';
import 'package:shoply/presentation/screens/profile/settings_search_index.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/language_provider.dart';
import 'package:shoply/presentation/state/theme_provider.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';
import 'package:shoply/routes/areas/profile_routes.dart';
import 'package:shoply/routes/route_paths.dart';

/// Translates a key, like `context.tr`.
typedef ProfileTr = String Function(String key, {Map<String, String>? params});

/// Status of the Avo Pro row (Konzept 18 §3.4), from [SubscriptionStatus].
enum ProRowStatus {
  /// Not known yet (start, offline): no second line.
  unknown,

  /// Not Pro, the trial can start: "14 Tage gratis testen".
  trialAvailable,

  /// Not Pro, Pro ran out: "Alle Vorteile ansehen".
  subscribe,

  /// Pro is active: "Aktiv".
  active,

  /// A purchase waits for approval (Ask to Buy): "Wartet auf Freigabe".
  pending;

  static ProRowStatus of(SubscriptionStatus status) => switch (status) {
    SubscriptionStatus.unknown => ProRowStatus.unknown,
    SubscriptionStatus.notSubscribed => ProRowStatus.trialAvailable,
    SubscriptionStatus.expired => ProRowStatus.subscribe,
    SubscriptionStatus.subscribed => ProRowStatus.active,
    SubscriptionStatus.pending => ProRowStatus.pending,
  };
}

/// What the Mitteilungen row says (Konzept 18 §3.2).
enum NotificationRowState {
  /// "An".
  on,

  /// "Aus": switched off in the app, or iOS was never asked.
  off,

  /// "In iOS aus": the app wants to, iOS forbids it.
  blockedInIos,
}

/// The signed-in person as far as the device knows (name, e-mail, photo,
/// sign-in), never waiting for the network.
@immutable
class ProfileIdentity {
  const ProfileIdentity({
    this.name,
    this.email,
    this.avatarUrl,
    this.localPhoto,
    this.photoSyncing = false,
    this.signInMethod,
    this.loading = false,
  });

  final String? name;
  final String? email;
  final String? avatarUrl;

  /// A photo picked in Profil bearbeiten that is not uploaded yet.
  final Uint8List? localPhoto;

  /// The photo is on its way to the account.
  final bool photoSyncing;

  final SignInMethod? signInMethod;

  /// The account profile is still loading for the first time.
  final bool loading;

  /// Name and e-mail are both unknown and nothing is loading any more
  /// ("Profil nicht geladen", §3.6).
  bool get missing => name == null && email == null && !loading;
}

/// Everything the profile root shows, from local state and providers.
@immutable
class ProfileRootData {
  const ProfileRootData({
    this.identity = const ProfileIdentity(),
    this.pro = ProRowStatus.unknown,
    this.enabledModules = const {},
    this.killSwitch = false,
    this.regionLabel,
    this.favoritesLabel,
    this.dietIds = const [],
    this.allergyCount = 0,
    this.notifications,
    this.themeMode = ThemeMode.system,
    this.languageCode = 'de',
    this.version,
    this.offline = false,
    this.routes = const {},
  });

  final ProfileIdentity identity;
  final ProRowStatus pro;

  /// Modules that are on (unreleased ones never).
  final Set<AppModule> enabledModules;

  /// The offers kill switch is on (known from the flags): "Märkte".
  final bool killSwitch;

  /// "79098 Freiburg" for the offers row, or null.
  final String? regionLabel;

  /// "Lidl, REWE": the favourite markets in their order (D2 X-Profil), or
  /// null without any.
  final String? favoritesLabel;

  /// Diet chips in their order and the number of allergies (Ernährung &
  /// Allergien, the same state as the page).
  final List<String> dietIds;
  final int allergyCount;

  /// Null until read.
  final NotificationRowState? notifications;

  final ThemeMode themeMode;

  /// The app language in use (`de`, `en`).
  final String languageCode;

  /// "1.1.4 (31)", or null until read.
  final String? version;

  final bool offline;

  /// Registered route patterns (`/settings/legal/:doc`).
  final Set<String> routes;

  bool hasRoute(String location) => isRouteRegistered(routes, location);

  bool isOn(AppModule module) => enabledModules.contains(module);

  /// The scope of the settings search.
  SettingsSearchScope get searchScope => SettingsSearchScope(
    routes: routes,
    enabledModules: enabledModules,
    killSwitch: killSwitch,
  );
}

// ------------------------------------------------------------------ values

/// "4 an": modules that are on and shown (offers not under the kill switch).
String modulesValue(ProfileTr tr, ProfileRootData data) {
  final count = AppModulesState.visibleModules
      .where((m) => data.isOn(m) && !(data.killSwitch && m == AppModule.offers))
      .length;
  return tr('prof_value_modules_on', params: {'n': '$count'});
}

/// "Vegetarisch · 1 Allergie", "Vegan +1", "2 Allergien"; null when nothing
/// is set. [dietIds] are the diet chips (the "frei von" ids count as
/// allergies, Konzept 17 §9.7).
String? dietValue(ProfileTr tr, List<String> dietIds, int allergyCount) {
  final parts = <String>[];
  if (dietIds.isNotEmpty) {
    final first = tr('diet_${dietIds.first}');
    parts.add(dietIds.length == 1 ? first : '$first +${dietIds.length - 1}');
  }
  if (allergyCount == 1) {
    parts.add(tr('prof_value_allergies_one'));
  } else if (allergyCount > 1) {
    parts.add(tr('prof_value_allergies', params: {'n': '$allergyCount'}));
  }
  return parts.isEmpty ? null : parts.join(' · ');
}

/// The Mitteilungen row from the page's state: the app's main switch, then
/// what iOS allows. An unread permission keeps the switch's value.
NotificationRowState? notificationRowState({
  required bool master,
  required bool loaded,
  required NotificationPermissionState permission,
}) {
  if (!loaded) return null;
  if (!master) return NotificationRowState.off;
  return switch (permission) {
    NotificationPermissionState.allowed ||
    NotificationPermissionState.unknown => NotificationRowState.on,
    NotificationPermissionState.notAsked => NotificationRowState.off,
    NotificationPermissionState.denied => NotificationRowState.blockedInIos,
  };
}

/// Second line of the Avo Pro row, or null (§3.4).
String? proSubtitle(ProfileTr tr, ProRowStatus status) => switch (status) {
  ProRowStatus.unknown => null,
  ProRowStatus.trialAvailable => tr('prof_pro_trial'),
  ProRowStatus.subscribe => tr('prof_pro_all_benefits'),
  ProRowStatus.active => tr('prof_pro_active'),
  ProRowStatus.pending => tr('prof_pro_pending'),
};

String? notificationsValue(ProfileTr tr, NotificationRowState? state) =>
    switch (state) {
      null => null,
      NotificationRowState.on => tr('prof_value_on'),
      NotificationRowState.off => tr('prof_value_off'),
      NotificationRowState.blockedInIos => tr('prof_value_ios_off'),
    };

String appearanceValue(ProfileTr tr, ThemeMode mode) => switch (mode) {
  ThemeMode.system => tr('prof_value_theme_system'),
  ThemeMode.light => tr('prof_value_theme_light'),
  ThemeMode.dark => tr('prof_value_theme_dark'),
};

/// Language names in their own language, as iOS shows them.
String languageValue(ProfileTr tr, String code) =>
    code == 'en' ? tr('prof_value_lang_en') : tr('prof_value_lang_de');

/// Value of the "Preise & Angebote" row (D2 X-Profil, Konzept 18 §3.2):
/// the favourite markets, else the region; "Aus" while the module is off.
/// Under the kill switch the row is "Märkte" with the markets only.
String? offersValue(ProfileTr tr, ProfileRootData data) {
  if (data.killSwitch) return data.favoritesLabel;
  if (!data.isOn(AppModule.offers)) return tr('prof_value_off');
  return data.favoritesLabel ?? data.regionLabel;
}

/// The first two market names, "+n" for the rest ("Lidl, REWE +1").
String? favoritesValue(List<String> names) {
  if (names.isEmpty) return null;
  final shown = names.take(2).join(', ');
  return names.length > 2 ? '$shown +${names.length - 2}' : shown;
}

/// "79098 Freiburg im Breisgau", or the zip code alone.
String? regionValue(Region? region) {
  if (region == null) return null;
  final city = region.city?.trim();
  return city == null || city.isEmpty ? region.zip : '${region.zip} $city';
}

// --------------------------------------------------------------- providers

String? _clean(Object? value) {
  if (value is! String) return null;
  final t = value.trim();
  return t.isEmpty ? null : t;
}

/// The signed-in person from Teil "Konto"'s providers: the name taken over
/// in Profil bearbeiten at once (also offline), else the account row or the
/// name saved on the device; e-mail and sign-in from the restored session;
/// the photo picked a moment ago before the stored one.
final profileIdentityProvider = Provider<ProfileIdentity>((ref) {
  final account = ref.watch(accountIdentityProvider);
  final profile = ref.watch(accountProfileProvider);
  final edit = ref.watch(profileEditControllerProvider);
  final userAsync = ref.watch(currentUserProvider);
  return ProfileIdentity(
    name: _clean(ref.watch(accountDisplayNameProvider)),
    email: _clean(account?.email),
    avatarUrl: edit.removed ? null : _clean(profile.avatarUrl),
    localPhoto: edit.removed ? null : edit.localPhoto,
    photoSyncing: edit.uploading,
    signInMethod: account?.method,
    loading: userAsync.isLoading && !userAsync.hasValue,
  );
});

/// "1.1.4 (31)" from the app bundle, or null.
final appVersionProvider = FutureProvider<String?>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    final build = info.buildNumber.trim();
    return build.isEmpty ? info.version : '${info.version} ($build)';
  } catch (e) {
    debugPrint('⚠️ [PROFILE] Reading the app version failed: $e');
    return null;
  }
});

/// Opens the app's page in the iOS Settings (text size, permissions).
final openSystemSettingsProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    try {
      await openAppSettings();
    } catch (e) {
      debugPrint('⚠️ [PROFILE] Opening the iOS settings failed: $e');
    }
  },
);

/// Full paths of every route below [routes], depth first.
Set<String> collectRoutePatterns(List<RouteBase> routes, [String parent = '']) {
  final out = <String>{};
  for (final r in routes) {
    if (r is GoRoute) {
      final full = r.path.startsWith('/')
          ? r.path
          : (parent == '/' ? '/${r.path}' : '$parent/${r.path}');
      out
        ..add(full)
        ..addAll(collectRoutePatterns(r.routes, full));
    } else if (r is ShellRouteBase) {
      out.addAll(collectRoutePatterns(r.routes, parent));
    }
  }
  return out;
}

/// The routes of the Profil tab (both parts' settings pages) plus the
/// paywall. Teil B's rows and search entries appear once their route is here.
final settingsRoutePatternsProvider = Provider<Set<String>>(
  (ref) => {...collectRoutePatterns(profileBranchRoutes), RoutePaths.pro},
);

/// Everything the profile root shows. Override in tests.
final profileRootDataProvider = Provider<ProfileRootData>((ref) {
  final routes = ref.watch(settingsRoutePatternsProvider);
  final modules = ref.watch(appModulesProvider);
  final status =
      ref.watch(subscriptionStatusProvider).valueOrNull ??
      ref.watch(subscriptionServiceProvider).status;
  // Only a known "off" counts: an unknown state must not rename the row.
  final killSwitch = ref.watch(offersKillSwitchOffProvider);
  final offersRow = isRouteRegistered(routes, RoutePaths.settingsOffers);
  final diet = ref.watch(dietSettingsProvider);
  final notifications = ref.watch(notificationSettingsProvider);
  return ProfileRootData(
    identity: ref.watch(profileIdentityProvider),
    pro: ProRowStatus.of(status),
    enabledModules: {
      for (final m in AppModule.values)
        if (modules.isEnabled(m)) m,
    },
    killSwitch: killSwitch,
    regionLabel: offersRow ? regionValue(ref.watch(regionProvider)) : null,
    favoritesLabel: offersRow
        ? favoritesValue([
            for (final id in ref.watch(favoriteStoresProvider))
              StoreChainDirectory.byId(id)?.displayName ?? id,
          ])
        : null,
    dietIds: [
      for (final id in kOnboardingDietIds)
        if (diet.diet.contains(id)) id,
    ],
    allergyCount: diet.allergyCount,
    notifications: notificationRowState(
      master: notifications.master,
      loaded: notifications.loaded,
      permission: ref.watch(notificationPermissionProvider),
    ),
    themeMode: ref.watch(themeModeProvider),
    languageCode: ref.watch(languageProvider),
    version: ref.watch(appVersionProvider).valueOrNull,
    offline: ref.watch(isOfflineProvider),
    routes: routes,
  );
});

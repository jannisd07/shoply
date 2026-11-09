import 'package:shared_preferences/shared_preferences.dart';

/// Device settings that stay on the iPhone when someone signs out (Konzept
/// 18 §7.2, K18-09): Darstellung and Sprache, plus facts about the device
/// itself, not about the account.
///
/// Everything else in SharedPreferences is account-bound and goes: modules,
/// notification categories, region and favourite markets, the Pro status,
/// Avo's conversation and Pro hint counter, tips, list and recipe state,
/// drafts, caches of what the person typed. A new device-wide setting has to
/// be added here, otherwise it is reset on sign-out.
const Set<String> kDeviceBoundPreferenceKeys = {
  // Darstellung (theme_provider.dart).
  'theme_mode',
  'accent_color',
  // Sprache (language_provider.dart).
  'language',
  // The device knows the first start: after signing out Willkommen opens in
  // the variant "Anmelden" (Konzept 17 §3.2).
  'onboarding_complete_v1',
  // iOS asks for notifications once per device.
  'notif_permission_prompted_v1',
  // Remote feature flags and the offers source configuration: not personal.
  'app_flags_v1',
  'marktguru_keys_v1',
  // Avo Pro prices of the App Store country (paywall_screen.dart).
  'pro_price_cache_v1',
};

/// Prefixes of device-bound keys: the App Store review pacing counts per
/// device and Apple ID, not per account.
const List<String> kDeviceBoundPreferencePrefixes = ['app_review_'];

/// Whether [key] survives a sign-out.
bool isDeviceBoundPreference(String key) =>
    kDeviceBoundPreferenceKeys.contains(key) ||
    kDeviceBoundPreferencePrefixes.any(key.startsWith);

/// Deletes every account-bound value from [prefs]; returns the removed
/// keys. Call it after the session is gone.
Future<List<String>> clearAccountBoundPreferences(
  SharedPreferences prefs,
) async {
  final removed = [
    for (final key in prefs.getKeys())
      if (!isDeviceBoundPreference(key)) key,
  ];
  for (final key in removed) {
    await prefs.remove(key);
  }
  return removed;
}

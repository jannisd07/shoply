import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Resolves the user's zip code (PLZ) for nearby-offers lookups.
///
/// Priority: manual override → fresh GPS fix (reverse geocoded) → cached
/// value. The zip is cached for a day; a manual PLZ set by the user wins
/// until cleared.
class UserLocationService {
  UserLocationService._();
  static final UserLocationService instance = UserLocationService._();

  static const _zipKey = 'offers_zip_code';
  static const _zipTimeKey = 'offers_zip_fetched_at';
  static const _manualZipKey = 'offers_zip_manual';
  static const _cacheMaxAge = Duration(hours: 24);

  Future<String?> getZipCode({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();

    final manual = prefs.getString(_manualZipKey);
    if (manual != null && manual.isNotEmpty) return manual;

    if (!forceRefresh) {
      final cached = prefs.getString(_zipKey);
      final fetchedAt = DateTime.tryParse(prefs.getString(_zipTimeKey) ?? '');
      if (cached != null &&
          fetchedAt != null &&
          DateTime.now().difference(fetchedAt) < _cacheMaxAge) {
        return cached;
      }
    }

    final fromGps = await _zipFromGps();
    if (fromGps != null) {
      await prefs.setString(_zipKey, fromGps);
      await prefs.setString(_zipTimeKey, DateTime.now().toIso8601String());
      return fromGps;
    }

    // GPS failed — fall back to any stale cache.
    return prefs.getString(_zipKey);
  }

  /// User-entered PLZ override (empty string clears it).
  Future<void> setManualZipCode(String zip) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = zip.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(_manualZipKey);
    } else {
      await prefs.setString(_manualZipKey, trimmed);
    }
  }

  Future<String?> getManualZipCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_manualZipKey);
  }

  Future<String?> _zipFromGps() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        print('⚠️ [LOCATION] Location services disabled');
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print('⚠️ [LOCATION] Permission denied');
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      final zip = placemarks
          .map((p) => p.postalCode)
          .firstWhere((z) => z != null && z.isNotEmpty, orElse: () => null);

      if (zip != null) {
        print('✅ [LOCATION] Resolved zip code: $zip');
      }
      return zip;
    } catch (e) {
      print('❌ [LOCATION] Failed to resolve zip: $e');
      return null;
    }
  }
}

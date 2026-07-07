import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Resolves the user's zip code (PLZ) for nearby-offers lookups.
///
/// Priority: manual override → fresh GPS fix (reverse geocoded) → cached
/// value. The zip is cached for a day; a manual PLZ set by the user wins
/// until cleared.
/// Zip code plus whether it's the user's real location (manual/GPS) or a
/// generic fallback used only so the offers feature is never empty.
class ZipInfo {
  final String zipCode;
  final bool isReal;
  const ZipInfo(this.zipCode, this.isReal);
}

/// Raw GPS coordinates, used for distance-based store lookups (there's no
/// manual-entry equivalent — a zip code alone can't tell us how far a store
/// branch is, so this is null unless the user has granted location access).
class UserCoordinates {
  final double latitude;
  final double longitude;
  const UserCoordinates(this.latitude, this.longitude);
}

class UserLocationService {
  UserLocationService._();
  static final UserLocationService instance = UserLocationService._();

  // v2: previous versions cached any reverse-geocoded zip, including foreign
  // ones (e.g. the simulator's US location). Bumping the key drops those.
  static const _zipKey = 'offers_zip_code_v2';
  static const _zipTimeKey = 'offers_zip_fetched_at_v2';
  static const _manualZipKey = 'offers_zip_manual';
  static const _cacheMaxAge = Duration(hours: 24);

  static const _latKey = 'offers_lat_v1';
  static const _lonKey = 'offers_lon_v1';
  static const _coordsTimeKey = 'offers_coords_fetched_at_v1';

  /// Central German zip used only when we have no real location, so search
  /// suggestions still return offers from the big nationwide chains.
  static const String defaultZip = '10115';

  /// Always returns a usable zip. [isReal] is false when it's [defaultZip],
  /// which the UI surfaces as a "set your PLZ" hint.
  Future<ZipInfo> getZipInfo({bool forceRefresh = false}) async {
    final zip = await getZipCode(forceRefresh: forceRefresh);
    if (zip != null && zip.isNotEmpty) return ZipInfo(zip, true);
    return const ZipInfo(defaultZip, false);
  }

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
      final position = await _getPosition();
      if (position == null) return null;

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      // Offers are Germany-only, so only accept a German placemark. A
      // non-DE location (e.g. the simulator's default US coordinates) must
      // fall through to the nationwide default zip instead of querying with
      // a foreign postal code that returns zero offers.
      for (final p in placemarks) {
        final isGerman = (p.isoCountryCode?.toUpperCase() == 'DE') ||
            (p.country == 'Deutschland') ||
            (p.country == 'Germany');
        final zip = p.postalCode;
        if (isGerman && zip != null && zip.isNotEmpty) {
          print('✅ [LOCATION] Resolved German zip code: $zip');
          return zip;
        }
      }

      print('⚠️ [LOCATION] No German placemark found; using fallback zip');
      return null;
    } catch (e) {
      print('❌ [LOCATION] Failed to resolve zip: $e');
      return null;
    }
  }

  /// Raw lat/lon for distance-based store lookups (e.g. "closest branch of
  /// the cheapest chain"). Unlike the zip code there's no manual-entry
  /// fallback — a zip alone can't place a store on a map — so this returns
  /// null whenever GPS isn't available, and callers must handle that by
  /// simply not showing distance info rather than guessing.
  Future<UserCoordinates?> getCoordinates({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();

    if (!forceRefresh) {
      final lat = prefs.getDouble(_latKey);
      final lon = prefs.getDouble(_lonKey);
      final fetchedAt = DateTime.tryParse(prefs.getString(_coordsTimeKey) ?? '');
      if (lat != null &&
          lon != null &&
          fetchedAt != null &&
          DateTime.now().difference(fetchedAt) < _cacheMaxAge) {
        return UserCoordinates(lat, lon);
      }
    }

    final position = await _getPosition();
    if (position == null) return null;

    await prefs.setDouble(_latKey, position.latitude);
    await prefs.setDouble(_lonKey, position.longitude);
    await prefs.setString(_coordsTimeKey, DateTime.now().toIso8601String());
    return UserCoordinates(position.latitude, position.longitude);
  }

  /// Shared permission-check + fix, used by both the zip resolver and
  /// [getCoordinates] so there's only one place that requests location
  /// permission.
  Future<Position?> _getPosition() async {
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

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      print('❌ [LOCATION] Failed to get position: $e');
      return null;
    }
  }
}

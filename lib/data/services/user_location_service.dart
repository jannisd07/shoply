import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where a [Region] comes from: the device location or a zip code the
/// person typed.
enum RegionSource { gps, manual }

/// The person's real region for offers (Kap. 12, rule 4). There is no
/// stand-in: without a location and without a typed zip code there is no
/// region, and no offer request is made anywhere.
@immutable
class Region {
  const Region({required this.zip, this.city, required this.source});

  /// Five-digit German zip code (PLZ).
  final String zip;

  /// Town of the zip code when the location resolved it, e.g. "Ulm".
  final String? city;

  final RegionSource source;

  @override
  bool operator ==(Object other) =>
      other is Region &&
      other.zip == zip &&
      other.city == city &&
      other.source == source;

  @override
  int get hashCode => Object.hash(zip, city, source);

  @override
  String toString() => 'Region($zip, $city, ${source.name})';
}

/// Whether [zip] is a German zip code: exactly five digits.
bool isValidZip(String zip) => RegExp(r'^\d{5}$').hasMatch(zip);

/// What the region provider reads and writes; [UserLocationService] in the
/// app, a fake in tests.
abstract interface class RegionLookup {
  /// The current region, or null. Asks for location permission only with
  /// [allowPermissionPrompt].
  Future<Region?> getRegion({
    bool allowPermissionPrompt = false,
    bool forceRefresh = false,
  });

  /// Saves a typed zip code; an empty string removes it.
  Future<void> setManualZipCode(String zip);

  /// Fires after every change of the region, from whichever screen.
  Stream<void> get changes;
}

/// Raw GPS coordinates, used for distance-based store lookups (there's no
/// manual-entry equivalent — a zip code alone can't tell us how far a store
/// branch is, so this is null unless the user has granted location access).
class UserCoordinates {
  final double latitude;
  final double longitude;
  const UserCoordinates(this.latitude, this.longitude);
}

/// Resolves the person's region (zip code and town) for offer lookups.
///
/// Priority: typed zip code → cached location (a day) → a fresh location
/// fix (reverse geocoded, Germany only) → the last known location. Never
/// asks for location permission unless the caller says so.
class UserLocationService implements RegionLookup {
  UserLocationService._();
  static final UserLocationService instance = UserLocationService._();

  // v2: previous versions cached any reverse-geocoded zip, including foreign
  // ones (e.g. the simulator's US location). Bumping the key drops those.
  static const _zipKey = 'offers_zip_code_v2';
  static const _zipTimeKey = 'offers_zip_fetched_at_v2';
  static const _cityKey = 'offers_city_v2';
  static const _manualZipKey = 'offers_zip_manual';
  static const _cacheMaxAge = Duration(hours: 24);

  static const _latKey = 'offers_lat_v1';
  static const _lonKey = 'offers_lon_v1';
  static const _coordsTimeKey = 'offers_coords_fetched_at_v1';

  /// After a failed GPS fix (no permission, timeout, outside Germany) don't
  /// try again for this long — every attempt can take up to 10 s.
  static const _gpsRetryAfter = Duration(minutes: 30);
  DateTime? _gpsFailedAt;

  /// One GPS fix shared by concurrent callers (zip and coordinates).
  Future<Position?>? _positionInFlight;

  final _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<Region?> getRegion({
    bool allowPermissionPrompt = false,
    bool forceRefresh = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final manual = prefs.getString(_manualZipKey);
    if (manual != null && manual.isNotEmpty) {
      return Region(zip: manual, source: RegionSource.manual);
    }

    Region? cachedGps() {
      final zip = prefs.getString(_zipKey);
      if (zip == null || zip.isEmpty) return null;
      return Region(
        zip: zip,
        city: prefs.getString(_cityKey),
        source: RegionSource.gps,
      );
    }

    if (!forceRefresh) {
      final fetchedAt = DateTime.tryParse(prefs.getString(_zipTimeKey) ?? '');
      final cached = cachedGps();
      if (cached != null &&
          fetchedAt != null &&
          DateTime.now().difference(fetchedAt) < _cacheMaxAge) {
        return cached;
      }
    }

    final fromGps = await _regionFromGps(
      forceRefresh: forceRefresh,
      allowPermissionPrompt: allowPermissionPrompt,
    );
    if (fromGps != null) {
      final changed = prefs.getString(_zipKey) != fromGps.zip;
      await prefs.setString(_zipKey, fromGps.zip);
      await prefs.setString(_zipTimeKey, DateTime.now().toIso8601String());
      if (fromGps.city == null) {
        await prefs.remove(_cityKey);
      } else {
        await prefs.setString(_cityKey, fromGps.city!);
      }
      if (changed) _changes.add(null);
      return fromGps;
    }

    // GPS failed — fall back to the last known location.
    return cachedGps();
  }

  /// The zip code of [getRegion], for callers that only need the number.
  Future<String?> getZipCode({
    bool forceRefresh = false,
    bool allowPermissionPrompt = false,
  }) async {
    final region = await getRegion(
      forceRefresh: forceRefresh,
      allowPermissionPrompt: allowPermissionPrompt,
    );
    return region?.zip;
  }

  /// User-entered PLZ override (empty string clears it). Every screen that
  /// shows offers follows the change through [changes].
  @override
  Future<void> setManualZipCode(String zip) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = zip.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(_manualZipKey);
    } else {
      await prefs.setString(_manualZipKey, trimmed);
    }
    _changes.add(null);
  }

  Future<String?> getManualZipCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_manualZipKey);
  }

  Future<Region?> _regionFromGps({
    required bool forceRefresh,
    required bool allowPermissionPrompt,
  }) async {
    try {
      final position = await _getPosition(
        forceRefresh: forceRefresh,
        allowPermissionPrompt: allowPermissionPrompt,
      );
      if (position == null) return null;

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      // Offers are Germany-only, so only accept a German placemark. A
      // non-DE location (e.g. the simulator's default US coordinates) means
      // no region rather than a foreign postal code that returns no offers.
      for (final p in placemarks) {
        final isGerman = (p.isoCountryCode?.toUpperCase() == 'DE') ||
            (p.country == 'Deutschland') ||
            (p.country == 'Germany');
        final zip = p.postalCode;
        if (isGerman && zip != null && isValidZip(zip)) {
          debugPrint('✅ [LOCATION] Resolved German zip code: $zip');
          final city = p.locality?.trim();
          return Region(
            zip: zip,
            city: city == null || city.isEmpty ? null : city,
            source: RegionSource.gps,
          );
        }
      }

      debugPrint('⚠️ [LOCATION] No German placemark found; no region');
      _gpsFailedAt = DateTime.now();
      return null;
    } catch (e) {
      debugPrint('❌ [LOCATION] Failed to resolve zip: $e');
      return null;
    }
  }

  /// Raw lat/lon for distance-based store lookups (e.g. "closest branch of
  /// the cheapest chain"). Unlike the zip code there's no manual-entry
  /// fallback — a zip alone can't place a store on a map — so this returns
  /// null whenever GPS isn't available, and callers must handle that by
  /// simply not showing distance info rather than guessing.
  Future<UserCoordinates?> getCoordinates({
    bool forceRefresh = false,
    bool allowPermissionPrompt = true,
  }) async {
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

    final position = await _getPosition(
      forceRefresh: forceRefresh,
      allowPermissionPrompt: allowPermissionPrompt,
    );
    if (position == null) return null;
    return UserCoordinates(position.latitude, position.longitude);
  }

  /// Shared permission-check + fix, used by both the region resolver and
  /// [getCoordinates]. Concurrent callers share one fix; every successful
  /// fix also refreshes the cached coordinates.
  Future<Position?> _getPosition({
    required bool forceRefresh,
    required bool allowPermissionPrompt,
  }) {
    final failedAt = _gpsFailedAt;
    if (!forceRefresh &&
        failedAt != null &&
        DateTime.now().difference(failedAt) < _gpsRetryAfter) {
      return Future.value(null);
    }
    return _positionInFlight ??= _fetchPosition(allowPermissionPrompt)
        .whenComplete(() => _positionInFlight = null);
  }

  Future<Position?> _fetchPosition(bool allowPermissionPrompt) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        debugPrint('⚠️ [LOCATION] Location services disabled');
        _gpsFailedAt = DateTime.now();
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && allowPermissionPrompt) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('⚠️ [LOCATION] Permission denied');
        // Only back off after the user actually answered; a background
        // caller must not block a later interactive prompt.
        if (allowPermissionPrompt) _gpsFailedAt = DateTime.now();
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
      _gpsFailedAt = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_latKey, position.latitude);
      await prefs.setDouble(_lonKey, position.longitude);
      await prefs.setString(_coordsTimeKey, DateTime.now().toIso8601String());
      return position;
    } catch (e) {
      debugPrint('❌ [LOCATION] Failed to get position: $e');
      _gpsFailedAt = DateTime.now();
      return null;
    }
  }
}

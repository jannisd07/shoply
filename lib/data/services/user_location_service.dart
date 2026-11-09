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

/// Whether [zip] can be a German zip code at all: five digits from 01001 to
/// 99998 (no zone "00"). Without a zip table (Lücke L10) this is the only
/// check "Diese Postleitzahl kennen wir nicht." can make.
bool isKnownZip(String zip) {
  if (!isValidZip(zip)) return false;
  final n = int.parse(zip);
  return n >= 1001 && n <= 99998;
}

/// What "Standort verwenden" found out (S11, S14).
enum LocateOutcome {
  /// A German zip code (and town, when known).
  found,

  /// The person declined location access (or declined it before).
  denied,

  /// No fix in time, location services off, or no address for it.
  unavailable,

  /// The location is outside Germany: there are no offers there.
  abroad,
}

/// The answer of [RegionLookup.locate]. Nothing of it is saved yet.
@immutable
class LocateResult {
  const LocateResult(this.outcome, {this.region, this.coordinates});

  final LocateOutcome outcome;

  /// Set for [LocateOutcome.found].
  final Region? region;

  /// The fix itself, in memory only (distances to nearby markets in S14);
  /// never stored ("Gespeichert wird nur die Postleitzahl").
  final UserCoordinates? coordinates;
}

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

  /// "Standort verwenden": asks for permission when needed (the screen has
  /// explained why), takes one fix within 3 s and resolves its zip code.
  /// Saves nothing.
  Future<LocateResult> locate();

  /// Keeps [region] (found by [locate]) as the person's region: it replaces
  /// a typed zip code.
  Future<void> saveLocatedRegion(Region region);

  /// "Region entfernen": no typed zip code, no remembered location, and no
  /// new one from the background either, until the person sets one again.
  Future<void> removeRegion();

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

  /// Set by "Region entfernen": the background never finds a region again
  /// until the person types a zip code or uses the location.
  static const _removedKey = 'offers_region_removed_v1';

  /// "Standort verwenden" waits at most this long for a fix (S11).
  static const _locateTimeLimit = Duration(seconds: 3);

  /// Where coordinates used to be stored for a day. They are kept in memory
  /// only now ("Gespeichert wird nur die Postleitzahl"); the old values are
  /// deleted the next time the region is read.
  static const _latKey = 'offers_lat_v1';
  static const _lonKey = 'offers_lon_v1';
  static const _coordsTimeKey = 'offers_coords_fetched_at_v1';

  /// The last fix, in memory only (nearby markets), never on the device.
  UserCoordinates? _lastCoords;
  DateTime? _lastCoordsAt;

  /// Coordinates are reused for at most this long within a session.
  static const _coordsMaxAge = Duration(minutes: 30);

  Future<void> _forgetStoredCoordinates(SharedPreferences prefs) async {
    for (final key in [_latKey, _lonKey, _coordsTimeKey]) {
      if (prefs.containsKey(key)) await prefs.remove(key);
    }
  }

  /// After a failed GPS fix (no permission, timeout, outside Germany) don't
  /// try again for this long — every attempt can take up to 10 s.
  static const _gpsRetryAfter = Duration(minutes: 30);
  DateTime? _gpsFailedAt;

  /// One GPS fix shared by concurrent callers (zip and coordinates).
  Future<Position?>? _positionInFlight;

  final _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  /// Sign-out: forgets the last fix and the GPS back-off held in memory, so
  /// the next account starts without this one's location. The stored zip
  /// code goes with the account-bound preferences (Teil A's sign-out).
  void clearMemory() {
    _lastCoords = null;
    _lastCoordsAt = null;
    _gpsFailedAt = null;
    _positionInFlight = null;
  }

  @override
  Future<Region?> getRegion({
    bool allowPermissionPrompt = false,
    bool forceRefresh = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await _forgetStoredCoordinates(prefs);

    final manual = prefs.getString(_manualZipKey);
    if (manual != null && manual.isNotEmpty) {
      return Region(zip: manual, source: RegionSource.manual);
    }
    if (prefs.getBool(_removedKey) ?? false) return null;

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
      await prefs.remove(_removedKey);
    }
    _changes.add(null);
  }

  @override
  Future<LocateResult> locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocateResult(LocateOutcome.unavailable);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const LocateResult(LocateOutcome.denied);
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: _locateTimeLimit,
        ),
      );
      final coordinates = UserCoordinates(
        position.latitude,
        position.longitude,
      );
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      var foreign = false;
      for (final p in placemarks) {
        final country = p.isoCountryCode?.toUpperCase();
        final isGerman =
            country == 'DE' ||
            p.country == 'Deutschland' ||
            p.country == 'Germany';
        final zip = p.postalCode;
        if (isGerman && zip != null && isValidZip(zip)) {
          final city = p.locality?.trim();
          return LocateResult(
            LocateOutcome.found,
            region: Region(
              zip: zip,
              city: city == null || city.isEmpty ? null : city,
              source: RegionSource.gps,
            ),
            coordinates: coordinates,
          );
        }
        if (country != null && country != 'DE') foreign = true;
      }
      return LocateResult(
        foreign ? LocateOutcome.abroad : LocateOutcome.unavailable,
        coordinates: coordinates,
      );
    } catch (e) {
      debugPrint('⚠️ [LOCATION] No location for the region: $e');
      return const LocateResult(LocateOutcome.unavailable);
    }
  }

  @override
  Future<void> saveLocatedRegion(Region region) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_manualZipKey);
    await prefs.remove(_removedKey);
    await prefs.setString(_zipKey, region.zip);
    await prefs.setString(_zipTimeKey, DateTime.now().toIso8601String());
    final city = region.city;
    if (city == null) {
      await prefs.remove(_cityKey);
    } else {
      await prefs.setString(_cityKey, city);
    }
    _changes.add(null);
  }

  @override
  Future<void> removeRegion() async {
    _lastCoords = null;
    _lastCoordsAt = null;
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      _manualZipKey,
      _zipKey,
      _zipTimeKey,
      _cityKey,
      _latKey,
      _lonKey,
      _coordsTimeKey,
    ]) {
      await prefs.remove(key);
    }
    await prefs.setBool(_removedKey, true);
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

  /// Raw lat/lon for distance-based store lookups (stores nearby), from
  /// the last fix of this session (at most 30 min old, never stored on the
  /// device). Unlike the zip code there's no manual-entry
  /// fallback — a zip alone can't place a store on a map — so this returns
  /// null whenever GPS isn't available, and callers must handle that by
  /// simply not showing distance info rather than guessing.
  Future<UserCoordinates?> getCoordinates({
    bool forceRefresh = false,
    bool allowPermissionPrompt = true,
  }) async {
    if (!forceRefresh) {
      final known = _lastCoords;
      final at = _lastCoordsAt;
      if (known != null &&
          at != null &&
          DateTime.now().difference(at) < _coordsMaxAge) {
        return known;
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
  /// fix also refreshes the coordinates kept in memory.
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

      // In memory only: the device keeps the postcode, not where one was.
      _lastCoords = UserCoordinates(position.latitude, position.longitude);
      _lastCoordsAt = DateTime.now();
      return position;
    } catch (e) {
      debugPrint('❌ [LOCATION] Failed to get position: $e');
      _gpsFailedAt = DateTime.now();
      return null;
    }
  }
}

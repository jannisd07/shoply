import 'dart:math';

/// A real, physical supermarket branch near the user, resolved from
/// OpenStreetMap data — used to answer "how far is the cheapest store,
/// really?" rather than just naming a chain.
class NearbyStore {
  /// Matches `StoreOffer.retailerUniqueName` / marktguru's retailer ids when
  /// the OSM brand could be confidently mapped to a known grocery chain;
  /// null for branches of chains outside marktguru's coverage (still shown
  /// on a map, just not matched to a price comparison).
  final String? retailerUniqueName;
  final String displayName;
  final String? street;
  final String? houseNumber;
  final String? city;
  final double latitude;
  final double longitude;
  final double distanceMeters;

  const NearbyStore({
    required this.retailerUniqueName,
    required this.displayName,
    required this.street,
    required this.houseNumber,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
  });

  double get distanceKm => distanceMeters / 1000;

  String? get address {
    final line1 = [street, houseNumber].where((s) => s != null && s.isNotEmpty).join(' ');
    if (line1.isEmpty) return city;
    if (city == null || city!.isEmpty) return line1;
    return '$line1, $city';
  }

  /// Human-readable distance, e.g. "350 m" or "2.4 km".
  String get distanceLabel {
    if (distanceMeters < 1000) return '${distanceMeters.round()} m';
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  static const double _earthRadiusMeters = 6371000;

  /// Haversine great-circle distance in meters — accurate enough for
  /// "which nearby branch is closest", not turn-by-turn routing.
  static double distanceBetween(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = _radians(lat2 - lat1);
    final dLon = _radians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_radians(lat1)) *
            cos(_radians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return _earthRadiusMeters * c;
  }

  static double _radians(double degrees) => degrees * pi / 180;
}

import 'package:equatable/equatable.dart';

/// Model für ein extrahiertes Angebot aus einem Prospekt
class ExtractedDeal extends Equatable {
  final String id;
  final String supermarket;
  final String productName;
  final String? productBrand;
  final String? productCategory;
  final double originalPrice;
  final double discountedPrice;
  final double discountPercentage;
  final String? unit; // z.B. "1kg", "500g", "1L"
  final DateTime validFrom;
  final DateTime validUntil;
  final String? imageUrl;
  final DateTime scannedAt;
  final bool isActive;

  const ExtractedDeal({
    required this.id,
    required this.supermarket,
    required this.productName,
    this.productBrand,
    this.productCategory,
    required this.originalPrice,
    required this.discountedPrice,
    required this.discountPercentage,
    this.unit,
    required this.validFrom,
    required this.validUntil,
    this.imageUrl,
    required this.scannedAt,
    this.isActive = true,
  });

  /// Berechnet die Ersparnis in Euro
  double get savings => originalPrice - discountedPrice;

  /// Prüft ob das Angebot noch gültig ist
  bool get isValid {
    final now = DateTime.now();
    return now.isAfter(validFrom) && now.isBefore(validUntil) && isActive;
  }

  /// Gibt die verbleibenden Tage zurück
  int get daysRemaining {
    final now = DateTime.now();
    return validUntil.difference(now).inDays;
  }

  /// Formatierter Preis für UI
  String get formattedOriginalPrice => '${originalPrice.toStringAsFixed(2)} €';
  String get formattedDiscountedPrice => '${discountedPrice.toStringAsFixed(2)} €';
  String get formattedSavings => '${savings.toStringAsFixed(2)} €';
  String get formattedDiscount => '-${discountPercentage.toStringAsFixed(0)}%';

  @override
  List<Object?> get props => [
        id,
        supermarket,
        productName,
        productBrand,
        productCategory,
        originalPrice,
        discountedPrice,
        discountPercentage,
        unit,
        validFrom,
        validUntil,
        imageUrl,
        scannedAt,
        isActive,
      ];

  /// Von JSON erstellen
  factory ExtractedDeal.fromJson(Map<String, dynamic> json) {
    return ExtractedDeal(
      id: json['id'] as String,
      supermarket: json['supermarket'] as String,
      productName: json['productName'] as String,
      productBrand: json['productBrand'] as String?,
      productCategory: json['productCategory'] as String?,
      originalPrice: (json['originalPrice'] as num).toDouble(),
      discountedPrice: (json['discountedPrice'] as num).toDouble(),
      discountPercentage: (json['discountPercentage'] as num).toDouble(),
      unit: json['unit'] as String?,
      validFrom: DateTime.parse(json['validFrom'] as String),
      validUntil: DateTime.parse(json['validUntil'] as String),
      imageUrl: json['imageUrl'] as String?,
      scannedAt: DateTime.parse(json['scannedAt'] as String),
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  /// Zu JSON konvertieren
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'supermarket': supermarket,
      'productName': productName,
      'productBrand': productBrand,
      'productCategory': productCategory,
      'originalPrice': originalPrice,
      'discountedPrice': discountedPrice,
      'discountPercentage': discountPercentage,
      'unit': unit,
      'validFrom': validFrom.toIso8601String(),
      'validUntil': validUntil.toIso8601String(),
      'imageUrl': imageUrl,
      'scannedAt': scannedAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  /// Für SQLite Database (Map<String, Object?>)
  Map<String, Object?> toDatabase() {
    return {
      'id': id,
      'supermarket': supermarket,
      'productName': productName,
      'productBrand': productBrand,
      'productCategory': productCategory,
      'originalPrice': originalPrice,
      'discountedPrice': discountedPrice,
      'discountPercentage': discountPercentage,
      'unit': unit,
      'validFrom': validFrom.toIso8601String(),
      'validUntil': validUntil.toIso8601String(),
      'imageUrl': imageUrl,
      'scannedAt': scannedAt.toIso8601String(),
      'isActive': isActive ? 1 : 0,
    };
  }

  /// Von SQLite Database erstellen
  factory ExtractedDeal.fromDatabase(Map<String, dynamic> map) {
    return ExtractedDeal(
      id: map['id'] as String,
      supermarket: map['supermarket'] as String,
      productName: map['productName'] as String,
      productBrand: map['productBrand'] as String?,
      productCategory: map['productCategory'] as String?,
      originalPrice: (map['originalPrice'] as num).toDouble(),
      discountedPrice: (map['discountedPrice'] as num).toDouble(),
      discountPercentage: (map['discountPercentage'] as num).toDouble(),
      unit: map['unit'] as String?,
      validFrom: DateTime.parse(map['validFrom'] as String),
      validUntil: DateTime.parse(map['validUntil'] as String),
      imageUrl: map['imageUrl'] as String?,
      scannedAt: DateTime.parse(map['scannedAt'] as String),
      isActive: (map['isActive'] as int) == 1,
    );
  }

  /// Kopie mit geänderten Werten erstellen
  ExtractedDeal copyWith({
    String? id,
    String? supermarket,
    String? productName,
    String? productBrand,
    String? productCategory,
    double? originalPrice,
    double? discountedPrice,
    double? discountPercentage,
    String? unit,
    DateTime? validFrom,
    DateTime? validUntil,
    String? imageUrl,
    DateTime? scannedAt,
    bool? isActive,
  }) {
    return ExtractedDeal(
      id: id ?? this.id,
      supermarket: supermarket ?? this.supermarket,
      productName: productName ?? this.productName,
      productBrand: productBrand ?? this.productBrand,
      productCategory: productCategory ?? this.productCategory,
      originalPrice: originalPrice ?? this.originalPrice,
      discountedPrice: discountedPrice ?? this.discountedPrice,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      unit: unit ?? this.unit,
      validFrom: validFrom ?? this.validFrom,
      validUntil: validUntil ?? this.validUntil,
      imageUrl: imageUrl ?? this.imageUrl,
      scannedAt: scannedAt ?? this.scannedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() {
    return 'ExtractedDeal('
        'supermarket: $supermarket, '
        'product: $productName, '
        'price: $formattedDiscountedPrice (war $formattedOriginalPrice), '
        'discount: $formattedDiscount, '
        'valid: ${isValid ? "Ja" : "Nein"}'
        ')';
  }
}

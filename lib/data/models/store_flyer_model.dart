import 'package:equatable/equatable.dart';

/// Model für Supermarkt-Prospekte
class StoreFlyerModel extends Equatable {
  final String id;
  final String storeName;
  final String storeChain; // lidl, rewe, aldi, netto, kaufland
  final String logoUrl;
  final String coverImageUrl;
  final List<String> pageImages; // Alle Prospektseiten
  final DateTime validFrom;
  final DateTime validUntil;
  final String? title;
  final int pageCount;
  final bool isActive;
  final String? detailUrl; // URL für mehr Seiten

  const StoreFlyerModel({
    required this.id,
    required this.storeName,
    required this.storeChain,
    required this.logoUrl,
    required this.coverImageUrl,
    required this.pageImages,
    required this.validFrom,
    required this.validUntil,
    this.title,
    required this.pageCount,
    required this.isActive,
    this.detailUrl,
  });

  factory StoreFlyerModel.fromJson(Map<String, dynamic> json) {
    return StoreFlyerModel(
      id: json['id'] as String,
      storeName: json['store_name'] as String,
      storeChain: json['store_chain'] as String,
      logoUrl: json['logo_url'] as String,
      coverImageUrl: json['cover_image_url'] as String,
      pageImages: (json['page_images'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      validFrom: DateTime.parse(json['valid_from'] as String),
      validUntil: DateTime.parse(json['valid_until'] as String),
      title: json['title'] as String?,
      pageCount: json['page_count'] as int,
      isActive: json['is_active'] as bool? ?? true,
      detailUrl: json['detail_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'store_name': storeName,
      'store_chain': storeChain,
      'logo_url': logoUrl,
      'cover_image_url': coverImageUrl,
      'page_images': pageImages,
      'valid_from': validFrom.toIso8601String(),
      'valid_until': validUntil.toIso8601String(),
      'title': title,
      'page_count': pageCount,
      'is_active': isActive,
      'detail_url': detailUrl,
    };
  }

  /// Prüft ob das Prospekt noch gültig ist
  bool get isValid {
    final now = DateTime.now();
    return now.isAfter(validFrom) && now.isBefore(validUntil);
  }

  /// Formatierte Gültigkeitsdauer
  String get validityPeriod {
    final fromDay = validFrom.day.toString().padLeft(2, '0');
    final fromMonth = validFrom.month.toString().padLeft(2, '0');
    final untilDay = validUntil.day.toString().padLeft(2, '0');
    final untilMonth = validUntil.month.toString().padLeft(2, '0');
    
    return 'Gültig vom $fromDay.$fromMonth bis $untilDay.$untilMonth';
  }

  @override
  List<Object?> get props => [
        id,
        storeName,
        storeChain,
        logoUrl,
        coverImageUrl,
        pageImages,
        validFrom,
        validUntil,
        title,
        pageCount,
        isActive,
        detailUrl,
      ];
}

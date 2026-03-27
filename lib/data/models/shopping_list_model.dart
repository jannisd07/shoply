import 'package:equatable/equatable.dart';

class ShoppingListModel extends Equatable {
  final String id;
  final String name;
  final String ownerId;
  final String? shareCode;
  final String? qrCodeData;
  final String? shareLink;
  final bool isShared;
  final String sortMode;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastAccessedAt;
  final int? itemCount;
  final int? uncheckedCount;
  final int? orderIndex;
  
  // Background System (Prompt 5)
  final String? backgroundGradient; // DEPRECATED: Use backgroundValue instead
  final String backgroundType; // 'color', 'gradient', 'image'
  final String? backgroundValue; // Hex color, gradient ID, or image filename
  final String? backgroundImageUrl; // Full Supabase storage URL for images

  const ShoppingListModel({
    required this.id,
    required this.name,
    required this.ownerId,
    this.shareCode,
    this.qrCodeData,
    this.shareLink,
    this.isShared = false,
    this.sortMode = 'category',
    required this.createdAt,
    required this.updatedAt,
    this.lastAccessedAt,
    this.itemCount,
    this.uncheckedCount,
    this.orderIndex,
    @Deprecated('Use backgroundValue instead') this.backgroundGradient,
    this.backgroundType = 'gradient',
    this.backgroundValue,
    this.backgroundImageUrl,
  });

  factory ShoppingListModel.fromJson(Map<String, dynamic> json) {
    // Extract item count from the items array if present
    int? itemCount = json['item_count'] as int?;
    if (itemCount == null && json['items'] != null) {
      final items = json['items'] as List?;
      if (items != null && items.isNotEmpty) {
        itemCount = items[0]['count'] as int?;
      }
    }

    return ShoppingListModel(
      id: json['id'] as String,
      name: json['name'] as String,
      ownerId: json['owner_id'] as String,
      shareCode: json['share_code'] as String?,
      qrCodeData: json['qr_code_data'] as String?,
      shareLink: json['share_link'] as String?,
      isShared: json['is_shared'] as bool? ?? false,
      sortMode: json['sort_mode'] as String? ?? 'category',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      lastAccessedAt: json['last_accessed_at'] != null
          ? DateTime.parse(json['last_accessed_at'] as String)
          : null,
      itemCount: itemCount,
      uncheckedCount: json['unchecked_count'] as int?,
      orderIndex: json['order_index'] as int?,
      backgroundGradient: json['background_gradient'] as String?,
      backgroundType: json['background_type'] as String? ?? 'gradient',
      backgroundValue: json['background_value'] as String?,
      backgroundImageUrl: json['background_image_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'owner_id': ownerId,
      'share_code': shareCode,
      'qr_code_data': qrCodeData,
      'share_link': shareLink,
      'is_shared': isShared,
      'sort_mode': sortMode,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'last_accessed_at': lastAccessedAt?.toIso8601String(),
      'order_index': orderIndex,
      'background_gradient': backgroundGradient,
      'background_type': backgroundType,
      'background_value': backgroundValue,
      'background_image_url': backgroundImageUrl,
    };
  }

  ShoppingListModel copyWith({
    String? id,
    String? name,
    String? ownerId,
    String? shareCode,
    String? qrCodeData,
    String? shareLink,
    bool? isShared,
    String? sortMode,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastAccessedAt,
    int? itemCount,
    int? uncheckedCount,
    int? orderIndex,
    String? backgroundGradient,
    String? backgroundType,
    String? backgroundValue,
    String? backgroundImageUrl,
  }) {
    return ShoppingListModel(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      shareCode: shareCode ?? this.shareCode,
      qrCodeData: qrCodeData ?? this.qrCodeData,
      shareLink: shareLink ?? this.shareLink,
      isShared: isShared ?? this.isShared,
      sortMode: sortMode ?? this.sortMode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      itemCount: itemCount ?? this.itemCount,
      uncheckedCount: uncheckedCount ?? this.uncheckedCount,
      orderIndex: orderIndex ?? this.orderIndex,
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      backgroundType: backgroundType ?? this.backgroundType,
      backgroundValue: backgroundValue ?? this.backgroundValue,
      backgroundImageUrl: backgroundImageUrl ?? this.backgroundImageUrl,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        ownerId,
        shareCode,
        qrCodeData,
        shareLink,
        isShared,
        sortMode,
        createdAt,
        updatedAt,
        lastAccessedAt,
        itemCount,
        uncheckedCount,
        orderIndex,
        backgroundGradient,
        backgroundType,
        backgroundValue,
        backgroundImageUrl,
      ];
  
  /// Helper method to get the effective background for rendering
  /// Handles migration from old backgroundGradient to new system
  String getBackgroundType() {
    // If new system is used, return it
    if (backgroundValue != null) {
      return backgroundType;
    }
    // Fallback to old gradient system
    if (backgroundGradient != null) {
      return 'gradient';
    }
    // Default to black color
    return 'color';
  }
  
  String? getBackgroundValue() {
    // New system takes priority
    if (backgroundValue != null) {
      return backgroundValue;
    }
    // Fallback to old gradient
    if (backgroundGradient != null) {
      return backgroundGradient;
    }
    // Default black color
    return '#000000';
  }
}

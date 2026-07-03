import 'package:equatable/equatable.dart';

class ShoppingItemModel extends Equatable {
  final String id;
  final String listId;
  final String name;
  final double quantity;
  final String? unit;
  final String? category; // Legacy field - keep for backward compatibility
  final String? categoryId; // New: language-agnostic category ID
  final String? language; // New: 'en' or 'de'
  final String? notes;
  final bool isChecked;
  final bool isDietWarning;
  final String? barcode;
  final String? addedBy;
  final int? sortOrder;
  final int? orderIndex;
  final DateTime createdAt;
  final DateTime? checkedAt;
  final DateTime updatedAt;
  final double? price;
  final String? priceCurrency;
  final String? priceRetailer;
  final String? priceUnit;
  final DateTime? priceUpdatedAt;

  const ShoppingItemModel({
    required this.id,
    required this.listId,
    required this.name,
    this.quantity = 1.0,
    this.unit,
    this.category,
    this.categoryId,
    this.language,
    this.notes,
    this.isChecked = false,
    this.isDietWarning = false,
    this.barcode,
    this.addedBy,
    this.sortOrder,
    this.orderIndex,
    required this.createdAt,
    this.checkedAt,
    required this.updatedAt,
    this.price,
    this.priceCurrency,
    this.priceRetailer,
    this.priceUnit,
    this.priceUpdatedAt,
  });

  /// Whether this item has a known price (from a picked offer or manual entry).
  bool get hasPrice => price != null;

  /// How many times a per-product price should be counted for this item.
  /// Piece-like quantities ("3" bottles) multiply; measured quantities
  /// ("500 g") count the price once, since prices are per product, not per
  /// measurement unit.
  double get pricingQuantity {
    final u = unit?.trim().toLowerCase();
    final isPieceLike = u == null ||
        u.isEmpty ||
        u == 'x' ||
        u == 'stk' ||
        u == 'stk.' ||
        u == 'st' ||
        u == 'pcs' ||
        u == 'pc' ||
        u == 'piece' ||
        u == 'pieces' ||
        u == 'stück';
    if (!isPieceLike) return 1;
    if (quantity < 1 || quantity > 50) return 1;
    return quantity;
  }

  factory ShoppingItemModel.fromJson(Map<String, dynamic> json) {
    return ShoppingItemModel(
      id: json['id'] as String,
      listId: json['list_id'] as String,
      name: json['name'] as String,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: json['unit'] as String?,
      category: json['category'] as String?, // Legacy field
      categoryId: json['category_id'] as String?, // New field
      language: json['language'] as String?, // New field
      notes: json['notes'] as String?,
      isChecked: json['is_checked'] as bool? ?? false,
      isDietWarning: json['is_diet_warning'] as bool? ?? false,
      barcode: json['barcode'] as String?,
      addedBy: json['added_by'] as String?,
      sortOrder: json['sort_order'] as int?,
      orderIndex: json['order_index'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      checkedAt: json['checked_at'] != null
          ? DateTime.parse(json['checked_at'] as String)
          : null,
      updatedAt: DateTime.parse(json['updated_at'] as String),
      price: (json['price'] as num?)?.toDouble(),
      priceCurrency: json['price_currency'] as String?,
      priceRetailer: json['price_retailer'] as String?,
      priceUnit: json['price_unit'] as String?,
      priceUpdatedAt: json['price_updated_at'] != null
          ? DateTime.parse(json['price_updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'list_id': listId,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'category': category, // Legacy field
      'category_id': categoryId, // New field
      'language': language, // New field
      'notes': notes,
      'is_checked': isChecked,
      'is_diet_warning': isDietWarning,
      'barcode': barcode,
      'added_by': addedBy,
      'sort_order': sortOrder,
      'order_index': orderIndex,
      'created_at': createdAt.toIso8601String(),
      'checked_at': checkedAt?.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'price': price,
      'price_currency': priceCurrency,
      'price_retailer': priceRetailer,
      'price_unit': priceUnit,
      'price_updated_at': priceUpdatedAt?.toIso8601String(),
    };
  }

  ShoppingItemModel copyWith({
    String? id,
    String? listId,
    String? name,
    double? quantity,
    String? unit,
    String? category,
    String? categoryId,
    String? language,
    String? notes,
    bool? isChecked,
    bool? isDietWarning,
    String? barcode,
    String? addedBy,
    int? sortOrder,
    int? orderIndex,
    DateTime? createdAt,
    DateTime? checkedAt,
    DateTime? updatedAt,
    double? price,
    String? priceCurrency,
    String? priceRetailer,
    String? priceUnit,
    DateTime? priceUpdatedAt,
  }) {
    return ShoppingItemModel(
      id: id ?? this.id,
      listId: listId ?? this.listId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      category: category ?? this.category,
      categoryId: categoryId ?? this.categoryId,
      language: language ?? this.language,
      notes: notes ?? this.notes,
      isChecked: isChecked ?? this.isChecked,
      isDietWarning: isDietWarning ?? this.isDietWarning,
      barcode: barcode ?? this.barcode,
      addedBy: addedBy ?? this.addedBy,
      sortOrder: sortOrder ?? this.sortOrder,
      orderIndex: orderIndex ?? this.orderIndex,
      createdAt: createdAt ?? this.createdAt,
      checkedAt: checkedAt ?? this.checkedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      price: price ?? this.price,
      priceCurrency: priceCurrency ?? this.priceCurrency,
      priceRetailer: priceRetailer ?? this.priceRetailer,
      priceUnit: priceUnit ?? this.priceUnit,
      priceUpdatedAt: priceUpdatedAt ?? this.priceUpdatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        listId,
        name,
        quantity,
        unit,
        category,
        categoryId,
        language,
        notes,
        isChecked,
        isDietWarning,
        barcode,
        addedBy,
        sortOrder,
        orderIndex,
        createdAt,
        checkedAt,
        price,
        priceCurrency,
        priceRetailer,
        priceUnit,
        priceUpdatedAt,
        updatedAt,
      ];
}

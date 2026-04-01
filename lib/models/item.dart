import 'dart:convert';
import 'category.dart';

// ---------------------------------------------------------------------------
// Packing / moving-day status (feature: moving-day checklist)
// ---------------------------------------------------------------------------
enum PackingStatus {
  notStarted,
  packed,
  loaded,
  delivered;

  String get displayName {
    switch (this) {
      case PackingStatus.notStarted:
        return 'Not Packed';
      case PackingStatus.packed:
        return 'Packed';
      case PackingStatus.loaded:
        return 'Loaded';
      case PackingStatus.delivered:
        return 'Delivered';
    }
  }
}

// ---------------------------------------------------------------------------
// Physical dimensions (feature: AR measurement)
// ---------------------------------------------------------------------------
class ItemDimensions {
  final double? lengthCm;
  final double? widthCm;
  final double? heightCm;
  final double? weightKg;

  const ItemDimensions({this.lengthCm, this.widthCm, this.heightCm, this.weightKg});

  bool get hasAny =>
      lengthCm != null || widthCm != null || heightCm != null || weightKg != null;

  String get summary {
    final parts = <String>[];
    if (lengthCm != null) parts.add('${lengthCm!.toStringAsFixed(1)} L');
    if (widthCm != null) parts.add('${widthCm!.toStringAsFixed(1)} W');
    if (heightCm != null) parts.add('${heightCm!.toStringAsFixed(1)} H');
    if (weightKg != null) parts.add('${weightKg!.toStringAsFixed(1)} kg');
    return parts.join(' × ');
  }

  Map<String, dynamic> toJson() => {
        'l': lengthCm,
        'w': widthCm,
        'h': heightCm,
        'kg': weightKg,
      };

  factory ItemDimensions.fromJson(Map<String, dynamic> j) => ItemDimensions(
        lengthCm: (j['l'] as num?)?.toDouble(),
        widthCm: (j['w'] as num?)?.toDouble(),
        heightCm: (j['h'] as num?)?.toDouble(),
        weightKg: (j['kg'] as num?)?.toDouble(),
      );
}

// ---------------------------------------------------------------------------
// Core Item model
// ---------------------------------------------------------------------------

/// Represents a single inventory item with all associated metadata.
class Item {
  final String id;
  final String name;
  final Category category;

  /// Sub-classification label (e.g. "living room" for Move, "eBay" for Sell).
  final String? subCategory;

  /// Physical location / room tag (feature: room/location tagging).
  final String? roomLocation;

  /// Ordered list of local file paths for item photographs.
  final List<String> photoPaths;

  /// Raw speech transcription captured while photographing.
  final String? voiceDescription;

  final String? notes;

  /// Best label returned by image-recognition service.
  final String? identifiedAs;

  /// Barcode / UPC value if scanned (feature: barcode scanning).
  final String? barcodeValue;

  /// Product name resolved from barcode lookup.
  final String? barcodeProductName;

  /// Insurance / estimated market value (feature: insurance valuation).
  final double? estimatedValue;

  /// Physical dimensions (feature: AR measurement).
  final ItemDimensions? dimensions;

  /// Moving-day checklist status (feature: moving-day checklist).
  final PackingStatus packingStatus;

  /// Whether this item was flagged as a potential duplicate (feature: duplicate detection).
  final bool isDuplicateFlagged;

  /// Path to the AI-enhanced photo (feature: photo enhancement).
  final String? enhancedPhotoPath;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Sell-specific metadata (populated when category == sell).
  final SellDetails? sellDetails;

  const Item({
    required this.id,
    required this.name,
    required this.category,
    this.subCategory,
    this.roomLocation,
    this.photoPaths = const [],
    this.voiceDescription,
    this.notes,
    this.identifiedAs,
    this.barcodeValue,
    this.barcodeProductName,
    this.estimatedValue,
    this.dimensions,
    this.packingStatus = PackingStatus.notStarted,
    this.isDuplicateFlagged = false,
    this.enhancedPhotoPath,
    required this.createdAt,
    required this.updatedAt,
    this.sellDetails,
  });

  Item copyWith({
    String? id,
    String? name,
    Category? category,
    String? subCategory,
    String? roomLocation,
    List<String>? photoPaths,
    String? voiceDescription,
    String? notes,
    String? identifiedAs,
    String? barcodeValue,
    String? barcodeProductName,
    double? estimatedValue,
    ItemDimensions? dimensions,
    PackingStatus? packingStatus,
    bool? isDuplicateFlagged,
    String? enhancedPhotoPath,
    DateTime? createdAt,
    DateTime? updatedAt,
    SellDetails? sellDetails,
    bool clearSubCategory = false,
    bool clearRoomLocation = false,
    bool clearSellDetails = false,
    bool clearDimensions = false,
  }) {
    return Item(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      subCategory: clearSubCategory ? null : (subCategory ?? this.subCategory),
      roomLocation: clearRoomLocation ? null : (roomLocation ?? this.roomLocation),
      photoPaths: photoPaths ?? this.photoPaths,
      voiceDescription: voiceDescription ?? this.voiceDescription,
      notes: notes ?? this.notes,
      identifiedAs: identifiedAs ?? this.identifiedAs,
      barcodeValue: barcodeValue ?? this.barcodeValue,
      barcodeProductName: barcodeProductName ?? this.barcodeProductName,
      estimatedValue: estimatedValue ?? this.estimatedValue,
      dimensions: clearDimensions ? null : (dimensions ?? this.dimensions),
      packingStatus: packingStatus ?? this.packingStatus,
      isDuplicateFlagged: isDuplicateFlagged ?? this.isDuplicateFlagged,
      enhancedPhotoPath: enhancedPhotoPath ?? this.enhancedPhotoPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sellDetails: clearSellDetails ? null : (sellDetails ?? this.sellDetails),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category.name,
        'sub_category': subCategory,
        'room_location': roomLocation,
        'photo_paths': photoPaths.join('|'),
        'voice_description': voiceDescription,
        'notes': notes,
        'identified_as': identifiedAs,
        'barcode_value': barcodeValue,
        'barcode_product_name': barcodeProductName,
        'estimated_value': estimatedValue,
        'dimensions': dimensions != null ? jsonEncode(dimensions!.toJson()) : null,
        'packing_status': packingStatus.name,
        'is_duplicate_flagged': isDuplicateFlagged ? 1 : 0,
        'enhanced_photo_path': enhancedPhotoPath,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'sell_details': sellDetails != null ? jsonEncode(sellDetails!.toJson()) : null,
      };

  factory Item.fromMap(Map<String, dynamic> map) => Item(
        id: map['id'] as String,
        name: map['name'] as String,
        category: Category.values.firstWhere((c) => c.name == map['category']),
        subCategory: map['sub_category'] as String?,
        roomLocation: map['room_location'] as String?,
        photoPaths: (map['photo_paths'] as String?)
                ?.split('|')
                .where((s) => s.isNotEmpty)
                .toList() ??
            [],
        voiceDescription: map['voice_description'] as String?,
        notes: map['notes'] as String?,
        identifiedAs: map['identified_as'] as String?,
        barcodeValue: map['barcode_value'] as String?,
        barcodeProductName: map['barcode_product_name'] as String?,
        estimatedValue: (map['estimated_value'] as num?)?.toDouble(),
        dimensions: map['dimensions'] != null
            ? ItemDimensions.fromJson(
                jsonDecode(map['dimensions'] as String) as Map<String, dynamic>)
            : null,
        packingStatus: PackingStatus.values.firstWhere(
          (s) => s.name == (map['packing_status'] as String? ?? 'notStarted'),
          orElse: () => PackingStatus.notStarted,
        ),
        isDuplicateFlagged: (map['is_duplicate_flagged'] as int? ?? 0) == 1,
        enhancedPhotoPath: map['enhanced_photo_path'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
        sellDetails: map['sell_details'] != null
            ? SellDetails.fromJson(
                jsonDecode(map['sell_details'] as String) as Map<String, dynamic>)
            : null,
      );

  String get displayName => name.isNotEmpty ? name : (barcodeProductName ?? identifiedAs ?? 'Unknown Item');
  String? get primaryPhotoPath => enhancedPhotoPath ?? (photoPaths.isNotEmpty ? photoPaths.first : null);
  bool get hasSellDetails => sellDetails != null;
}

// ---------------------------------------------------------------------------
// Marketplace constants
// ---------------------------------------------------------------------------
abstract class Marketplace {
  static const String ebay = 'ebay';
  static const String amazon = 'amazon';
  static const String facebook = 'facebook';
  static const String craigslist = 'craigslist';
  static const String etsy = 'etsy';
  static const String walmart = 'walmart';
  static const String offerUp = 'offerup';
  static const String poshmark = 'poshmark';
  static const String mercari = 'mercari';
  static const String depop = 'depop';

  static const List<String> all = [
    ebay, amazon, facebook, craigslist, etsy, walmart, offerUp, poshmark, mercari, depop,
  ];

  static String displayName(String id) {
    const names = {
      ebay: 'eBay',
      amazon: 'Amazon',
      facebook: 'Facebook Marketplace',
      craigslist: 'Craigslist',
      etsy: 'Etsy',
      walmart: 'Walmart',
      offerUp: 'OfferUp',
      poshmark: 'Poshmark',
      mercari: 'Mercari',
      depop: 'Depop',
    };
    return names[id] ?? id;
  }
}

enum ListingType { buyItNow, auction, auctionWithBuyItNow }

extension ListingTypeExt on ListingType {
  String get displayName {
    switch (this) {
      case ListingType.buyItNow:        return 'Buy It Now';
      case ListingType.auction:         return 'Auction';
      case ListingType.auctionWithBuyItNow: return 'Auction + Buy It Now';
    }
  }
}

enum ShippingOption { free, buyerArranges, exactCost, flatRate, localPickup }

extension ShippingOptionExt on ShippingOption {
  String get displayName {
    switch (this) {
      case ShippingOption.free:          return 'Free Shipping';
      case ShippingOption.buyerArranges: return 'Buyer Arranges';
      case ShippingOption.exactCost:     return 'Exact Cost';
      case ShippingOption.flatRate:      return 'Flat Rate';
      case ShippingOption.localPickup:   return 'Local Pickup Only';
    }
  }
}

// ---------------------------------------------------------------------------
// SellDetails
// ---------------------------------------------------------------------------
class SellDetails {
  final String marketplace;
  final ListingType listingType;
  final String title;
  final String? subtitle;
  final double? price;
  final double? buyItNowPrice;
  final String? description;
  final bool aiGeneratedDescription;
  final ShippingOption shippingOption;
  final double? shippingCost;
  final String? listingId;
  final String? listingUrl;
  final bool isListed;
  /// Fields that were AI-inferred are wrapped in [brackets] in the display.
  final bool isAiGuessed;
  /// Condition of the item for marketplace listing.
  final String? condition; // new, like_new, good, fair, poor

  const SellDetails({
    required this.marketplace,
    required this.listingType,
    required this.title,
    this.subtitle,
    this.price,
    this.buyItNowPrice,
    this.description,
    this.aiGeneratedDescription = false,
    required this.shippingOption,
    this.shippingCost,
    this.listingId,
    this.listingUrl,
    this.isListed = false,
    this.isAiGuessed = false,
    this.condition,
  });

  SellDetails copyWith({
    String? marketplace,
    ListingType? listingType,
    String? title,
    String? subtitle,
    double? price,
    double? buyItNowPrice,
    String? description,
    bool? aiGeneratedDescription,
    ShippingOption? shippingOption,
    double? shippingCost,
    String? listingId,
    String? listingUrl,
    bool? isListed,
    bool? isAiGuessed,
    String? condition,
  }) =>
      SellDetails(
        marketplace: marketplace ?? this.marketplace,
        listingType: listingType ?? this.listingType,
        title: title ?? this.title,
        subtitle: subtitle ?? this.subtitle,
        price: price ?? this.price,
        buyItNowPrice: buyItNowPrice ?? this.buyItNowPrice,
        description: description ?? this.description,
        aiGeneratedDescription: aiGeneratedDescription ?? this.aiGeneratedDescription,
        shippingOption: shippingOption ?? this.shippingOption,
        shippingCost: shippingCost ?? this.shippingCost,
        listingId: listingId ?? this.listingId,
        listingUrl: listingUrl ?? this.listingUrl,
        isListed: isListed ?? this.isListed,
        isAiGuessed: isAiGuessed ?? this.isAiGuessed,
        condition: condition ?? this.condition,
      );

  Map<String, dynamic> toJson() => {
        'marketplace': marketplace,
        'listing_type': listingType.name,
        'title': title,
        'subtitle': subtitle,
        'price': price,
        'buy_it_now_price': buyItNowPrice,
        'description': description,
        'ai_generated_description': aiGeneratedDescription,
        'shipping_option': shippingOption.name,
        'shipping_cost': shippingCost,
        'listing_id': listingId,
        'listing_url': listingUrl,
        'is_listed': isListed,
        'is_ai_guessed': isAiGuessed,
        'condition': condition,
      };

  factory SellDetails.fromJson(Map<String, dynamic> j) => SellDetails(
        marketplace: j['marketplace'] as String,
        listingType: ListingType.values.firstWhere((t) => t.name == j['listing_type']),
        title: j['title'] as String,
        subtitle: j['subtitle'] as String?,
        price: (j['price'] as num?)?.toDouble(),
        buyItNowPrice: (j['buy_it_now_price'] as num?)?.toDouble(),
        description: j['description'] as String?,
        aiGeneratedDescription: j['ai_generated_description'] as bool? ?? false,
        shippingOption:
            ShippingOption.values.firstWhere((s) => s.name == j['shipping_option']),
        shippingCost: (j['shipping_cost'] as num?)?.toDouble(),
        listingId: j['listing_id'] as String?,
        listingUrl: j['listing_url'] as String?,
        isListed: j['is_listed'] as bool? ?? false,
        isAiGuessed: j['is_ai_guessed'] as bool? ?? false,
        condition: j['condition'] as String?,
      );
}

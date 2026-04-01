import 'package:flutter/material.dart';

/// Core disposal categories. The sealed class enforces exhaustive when() checks.
enum Category {
  move,
  store,
  donate,
  sell,
  recycle,
  trash;

  String get displayName {
    switch (this) {
      case Category.move:
        return 'Move';
      case Category.store:
        return 'Store';
      case Category.donate:
        return 'Donate';
      case Category.sell:
        return 'Sell';
      case Category.recycle:
        return 'Recycle';
      case Category.trash:
        return 'Trash';
    }
  }

  Color get color {
    switch (this) {
      case Category.move:
        return const Color(0xFF2196F3); // blue
      case Category.store:
        return const Color(0xFF9C27B0); // purple
      case Category.donate:
        return const Color(0xFF4CAF50); // green
      case Category.sell:
        return const Color(0xFFFF9800); // orange
      case Category.recycle:
        return const Color(0xFF00BCD4); // cyan
      case Category.trash:
        return const Color(0xFF9E9E9E); // grey
    }
  }

  IconData get icon {
    switch (this) {
      case Category.move:
        return Icons.local_shipping;
      case Category.store:
        return Icons.warehouse;
      case Category.donate:
        return Icons.volunteer_activism;
      case Category.sell:
        return Icons.sell;
      case Category.recycle:
        return Icons.recycling;
      case Category.trash:
        return Icons.delete;
    }
  }

  String get defaultSpeechKeyword => displayName.toLowerCase();

  static Category? fromString(String value) {
    for (final cat in Category.values) {
      if (cat.name.toLowerCase() == value.toLowerCase() ||
          cat.displayName.toLowerCase() == value.toLowerCase()) {
        return cat;
      }
    }
    return null;
  }
}

/// A configurable category keyword set stored in settings.
/// Each [CategoryConfig] defines a main-level keyword (which may be one of the
/// built-in [Category] values or a custom alias) plus an ordered list of
/// sub-classification keywords.
class CategoryConfig {
  final String id;
  final Category category;

  /// Additional trigger words for this category beyond the default.
  final List<String> aliases;

  /// Sub-classification labels, e.g. ["living room", "bedroom", "garage"].
  final List<SubClassification> subClassifications;

  const CategoryConfig({
    required this.id,
    required this.category,
    this.aliases = const [],
    this.subClassifications = const [],
  });

  CategoryConfig copyWith({
    String? id,
    Category? category,
    List<String>? aliases,
    List<SubClassification>? subClassifications,
  }) {
    return CategoryConfig(
      id: id ?? this.id,
      category: category ?? this.category,
      aliases: aliases ?? this.aliases,
      subClassifications: subClassifications ?? this.subClassifications,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category.name,
        'aliases': aliases,
        'subClassifications': subClassifications.map((s) => s.toJson()).toList(),
      };

  factory CategoryConfig.fromJson(Map<String, dynamic> json) =>
      CategoryConfig(
        id: json['id'] as String,
        category: Category.values.firstWhere((c) => c.name == json['category']),
        aliases: List<String>.from(json['aliases'] as List? ?? []),
        subClassifications: (json['subClassifications'] as List? ?? [])
            .map((e) => SubClassification.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// Returns all keywords (default + aliases) that trigger this category.
  List<String> get allKeywords => [
        category.defaultSpeechKeyword,
        ...aliases,
      ];

  /// Default configs for all built-in categories.
  static List<CategoryConfig> defaults() => [
        CategoryConfig(
          id: 'move',
          category: Category.move,
          aliases: ['moving', 'take', 'keep', 'bring'],
          subClassifications: [
            SubClassification(id: 'lr', label: 'living room', keywords: ['living room', 'lounge']),
            SubClassification(id: 'br', label: 'bedroom', keywords: ['bedroom', 'master', 'guest room']),
            SubClassification(id: 'kit', label: 'kitchen', keywords: ['kitchen']),
            SubClassification(id: 'gar', label: 'garage', keywords: ['garage']),
            SubClassification(id: 'off', label: 'office', keywords: ['office', 'study']),
          ],
        ),
        CategoryConfig(
          id: 'store',
          category: Category.store,
          aliases: ['storage', 'storing', 'box up'],
          subClassifications: [
            SubClassification(id: 'unit', label: 'storage unit', keywords: ['storage unit', 'unit']),
            SubClassification(id: 'attic', label: 'attic', keywords: ['attic', 'loft']),
            SubClassification(id: 'bsmt', label: 'basement', keywords: ['basement']),
          ],
        ),
        CategoryConfig(
          id: 'donate',
          category: Category.donate,
          aliases: ['donation', 'give away', 'charity', 'goodwill'],
          subClassifications: [
            SubClassification(id: 'gw', label: 'Goodwill', keywords: ['goodwill']),
            SubClassification(id: 'sa', label: 'Salvation Army', keywords: ['salvation army']),
            SubClassification(id: 'hab', label: 'Habitat', keywords: ['habitat']),
          ],
        ),
        CategoryConfig(
          id: 'sell',
          category: Category.sell,
          aliases: ['for sale', 'selling', 'list it'],
          subClassifications: [
            SubClassification(id: 'ebay', label: 'eBay', keywords: ['ebay', 'e-bay']),
            SubClassification(id: 'amz', label: 'Amazon', keywords: ['amazon']),
            SubClassification(id: 'fb', label: 'Facebook Marketplace', keywords: ['facebook', 'marketplace', 'fb marketplace']),
            SubClassification(id: 'cl', label: 'Craigslist', keywords: ['craigslist', 'craig']),
            SubClassification(id: 'etsy', label: 'Etsy', keywords: ['etsy']),
            SubClassification(id: 'wmt', label: 'Walmart', keywords: ['walmart']),
            SubClassification(id: 'offerup', label: 'OfferUp', keywords: ['offerup', 'offer up']),
            SubClassification(id: 'posh', label: 'Poshmark', keywords: ['poshmark', 'posh']),
          ],
        ),
        CategoryConfig(
          id: 'recycle',
          category: Category.recycle,
          aliases: ['recycling', 'reclaim', 'scrap'],
          subClassifications: [
            SubClassification(id: 'elec', label: 'electronics', keywords: ['electronics', 'e-waste']),
            SubClassification(id: 'paper', label: 'paper', keywords: ['paper', 'cardboard']),
            SubClassification(id: 'metal', label: 'metal', keywords: ['metal', 'scrap metal']),
          ],
        ),
        CategoryConfig(
          id: 'trash',
          category: Category.trash,
          aliases: ['garbage', 'junk', 'throw away', 'throw out', 'discard', 'dump'],
          subClassifications: [
            SubClassification(id: 'haz', label: 'hazardous', keywords: ['hazardous', 'hazmat', 'chemical']),
            SubClassification(id: 'bulk', label: 'bulk pickup', keywords: ['bulk', 'large item pickup']),
          ],
        ),
      ];
}

class SubClassification {
  final String id;
  final String label;
  final List<String> keywords;

  const SubClassification({
    required this.id,
    required this.label,
    required this.keywords,
  });

  SubClassification copyWith({
    String? id,
    String? label,
    List<String>? keywords,
  }) =>
      SubClassification(
        id: id ?? this.id,
        label: label ?? this.label,
        keywords: keywords ?? this.keywords,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'keywords': keywords,
      };

  factory SubClassification.fromJson(Map<String, dynamic> json) =>
      SubClassification(
        id: json['id'] as String,
        label: json['label'] as String,
        keywords: List<String>.from(json['keywords'] as List? ?? []),
      );
}

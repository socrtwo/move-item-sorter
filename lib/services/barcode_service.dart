import 'dart:convert';
import 'package:dio/dio.dart';

/// Result of a barcode lookup.
class BarcodeProduct {
  final String barcode;
  final String? name;
  final String? brand;
  final String? category;
  final String? description;
  final String? imageUrl;

  const BarcodeProduct({
    required this.barcode,
    this.name,
    this.brand,
    this.category,
    this.description,
    this.imageUrl,
  });

  String get displayName => [brand, name].where((s) => s != null && s.isNotEmpty).join(' ');
}

/// Looks up product information from a barcode/UPC using the Open Food Facts
/// and UPCitemdb public APIs (no key required for basic lookups).
class BarcodeService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  Future<BarcodeProduct?> lookup(String barcode) async {
    // Try UPCitemdb first (broad product database)
    final result = await _lookupUpcItemDb(barcode);
    if (result != null) return result;
    // Fallback: Open Food Facts (food/grocery items)
    return _lookupOpenFoodFacts(barcode);
  }

  Future<BarcodeProduct?> _lookupUpcItemDb(String barcode) async {
    try {
      final resp = await _dio.get(
        'https://api.upcitemdb.com/prod/trial/lookup',
        queryParameters: {'upc': barcode},
      );
      final items = (resp.data as Map)['items'] as List?;
      if (items == null || items.isEmpty) return null;
      final item = items.first as Map;
      return BarcodeProduct(
        barcode: barcode,
        name: item['title'] as String?,
        brand: item['brand'] as String?,
        category: item['category'] as String?,
        description: item['description'] as String?,
        imageUrl: (item['images'] as List?)?.firstOrNull as String?,
      );
    } catch (_) {
      return null;
    }
  }

  Future<BarcodeProduct?> _lookupOpenFoodFacts(String barcode) async {
    try {
      final resp = await _dio.get(
        'https://world.openfoodfacts.org/api/v0/product/$barcode.json',
      );
      final data = resp.data as Map;
      if (data['status'] != 1) return null;
      final product = data['product'] as Map?;
      if (product == null) return null;
      return BarcodeProduct(
        barcode: barcode,
        name: product['product_name'] as String?,
        brand: product['brands'] as String?,
        category: product['categories'] as String?,
        imageUrl: product['image_url'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

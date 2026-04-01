import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';

import '../core/constants.dart';
import '../models/app_settings.dart';
import '../models/item.dart';

class MarketplaceResult {
  final bool success;
  final String? listingId;
  final String? listingUrl;
  final String? error;
  const MarketplaceResult({required this.success, this.listingId, this.listingUrl, this.error});
}

/// Handles submitting listings to marketplaces.
/// - eBay: uses the Trading API (requires user OAuth token)
/// - Others: open marketplace's listing page / app via deep-link with
///   pre-filled query parameters where the API supports it.
class MarketplaceService {
  final Dio _dio = Dio();

  Future<MarketplaceResult> listItem(Item item, AppSettings settings) async {
    final sd = item.sellDetails;
    if (sd == null) return const MarketplaceResult(success: false, error: 'No sell details');

    switch (sd.marketplace) {
      case 'ebay':
        return _listOnEbay(item, settings);
      default:
        return _openDeepLink(item, settings);
    }
  }

  // ---- eBay (Trading API) --------------------------------------------------

  Future<MarketplaceResult> _listOnEbay(Item item, AppSettings settings) async {
    if (settings.ebayUserToken.isEmpty) {
      // Fallback: open eBay sell page in browser
      return _openDeepLink(item, settings);
    }

    final sd = item.sellDetails!;
    // Build AddItem XML (Trading API)
    final xml = _buildEbayXml(item, settings);

    try {
      final resp = await _dio.post(
        'https://api.ebay.com/ws/api.dll',
        data: xml,
        options: Options(headers: {
          'X-EBAY-API-SITEID': '0',
          'X-EBAY-API-COMPATIBILITY-LEVEL': '1155',
          'X-EBAY-API-CALL-NAME': 'AddItem',
          'X-EBAY-API-APP-NAME': settings.ebayAppId,
          'X-EBAY-API-DEV-NAME': settings.ebayDevId,
          'X-EBAY-API-CERT-NAME': settings.ebayCertId,
          'Content-Type': 'text/xml',
        }),
      );

      final body = resp.data as String;
      if (body.contains('<Ack>Success</Ack>') || body.contains('<Ack>Warning</Ack>')) {
        final idMatch = RegExp(r'<ItemID>(\d+)</ItemID>').firstMatch(body);
        final listingId = idMatch?.group(1);
        final url = listingId != null ? 'https://www.ebay.com/itm/$listingId' : null;
        return MarketplaceResult(success: true, listingId: listingId, listingUrl: url);
      } else {
        final errMatch = RegExp(r'<LongMessage>(.*?)</LongMessage>').firstMatch(body);
        return MarketplaceResult(
            success: false, error: errMatch?.group(1) ?? 'eBay API error');
      }
    } catch (e) {
      return MarketplaceResult(success: false, error: e.toString());
    }
  }

  String _buildEbayXml(Item item, AppSettings settings) {
    final sd = item.sellDetails!;
    final price = sd.price ?? 9.99;
    final listingType = sd.listingType.name == 'buyItNow'
        ? 'FixedPriceItem'
        : 'Chinese'; // auction
    final desc = sd.description ?? item.displayName;

    return '''<?xml version="1.0" encoding="utf-8"?>
<AddItemRequest xmlns="urn:ebay:apis:eBLBaseComponents">
  <RequesterCredentials>
    <eBayAuthToken>${settings.ebayUserToken}</eBayAuthToken>
  </RequesterCredentials>
  <Item>
    <Title>${_xmlEscape(sd.title)}</Title>
    <Description><![CDATA[$desc]]></Description>
    <PrimaryCategory><CategoryID>99</CategoryID></PrimaryCategory>
    <StartPrice>${price.toStringAsFixed(2)}</StartPrice>
    <ListingType>$listingType</ListingType>
    <ListingDuration>Days_7</ListingDuration>
    <Country>US</Country>
    <Currency>USD</Currency>
    <PaymentMethods>PayPal</PaymentMethods>
    <Quantity>1</Quantity>
    <ConditionID>1000</ConditionID>
    <ShippingDetails>
      <ShippingType>${sd.shippingOption.name == 'free' ? 'Flat' : 'Calculated'}</ShippingType>
      <ShippingServiceOptions>
        <ShippingServicePriority>1</ShippingServicePriority>
        <ShippingService>USPSMedia</ShippingService>
        <ShippingServiceCost>${sd.shippingOption.name == 'free' ? '0.00' : (sd.shippingCost ?? 0.0).toStringAsFixed(2)}</ShippingServiceCost>
      </ShippingServiceOptions>
    </ShippingDetails>
  </Item>
</AddItemRequest>''';
  }

  static String _xmlEscape(String s) =>
      s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

  // ---- Deep-link / web fallback --------------------------------------------

  Future<MarketplaceResult> _openDeepLink(Item item, AppSettings settings) async {
    final sd = item.sellDetails!;
    final baseUrl = AppConstants.marketplaceListingUrls[sd.marketplace];
    if (baseUrl == null) {
      return MarketplaceResult(
          success: false, error: 'Unknown marketplace: ${sd.marketplace}');
    }

    // Build URL with pre-filled parameters where supported
    String url;
    switch (sd.marketplace) {
      case 'facebook':
        url = 'https://www.facebook.com/marketplace/create/item';
        break;
      case 'craigslist':
        url = 'https://post.craigslist.org/c/sss?query=${Uri.encodeComponent(sd.title)}';
        break;
      case 'etsy':
        url = 'https://www.etsy.com/your/shops/me/tools/listings/create';
        break;
      default:
        url = baseUrl;
    }

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return const MarketplaceResult(success: true);
      } else {
        return MarketplaceResult(success: false, error: 'Could not open $url');
      }
    } catch (e) {
      return MarketplaceResult(success: false, error: e.toString());
    }
  }
}

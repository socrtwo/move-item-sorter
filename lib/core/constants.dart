/// App-wide constants.
abstract class AppConstants {
  static const String appName = 'Move Item Sorter';
  static const String dbName = 'move_item_sorter.db';
  static const int dbVersion = 1;
  static const String settingsKey = 'app_settings_v1';
  static const String photosSubDir = 'item_photos';
  static const String exportSubDir = 'exports';

  // Table names
  static const String itemsTable = 'items';

  // Auto-capture
  static const int autoCaptureFpsCheck = 3; // frames per second to evaluate
  static const int multiAngleMaxPhotos = 8;

  // Sell flow timeouts
  static const int sellFlowListenTimeoutSeconds = 8;

  // Image recognition
  static const String googleVisionEndpoint =
      'https://vision.googleapis.com/v1/images:annotate';

  // AI service
  static const String openAiEndpoint = 'https://api.openai.com/v1/chat/completions';
  static const String openAiModel = 'gpt-4o';

  // Marketplace base URLs
  static const Map<String, String> marketplaceListingUrls = {
    'ebay': 'https://www.ebay.com/sl/sell',
    'amazon': 'https://sellercentral.amazon.com/listing/upload',
    'facebook': 'https://www.facebook.com/marketplace/create/item',
    'craigslist': 'https://post.craigslist.org',
    'etsy': 'https://www.etsy.com/sell',
    'walmart': 'https://seller.walmart.com',
    'offerup': 'https://offerup.com/sell',
    'poshmark': 'https://poshmark.com/sell',
  };

  // Export
  static const String csvExportFilename = 'inventory_export.csv';
  static const String excelExportFilename = 'inventory_export.xlsx';
  static const String sqliteExportFilename = 'inventory_export.db';
}

import '../models/app_settings.dart';
import '../models/category.dart';
import '../models/item.dart';

/// Result of a voice command match.
class VoiceCommandResult {
  final VoiceCommandType type;
  final Category? category;
  final String? subCategory;
  final String? itemDescription; // words not matched as a command
  final bool isMultiAngle;

  const VoiceCommandResult({
    required this.type,
    this.category,
    this.subCategory,
    this.itemDescription,
    this.isMultiAngle = false,
  });

  @override
  String toString() =>
      'VoiceCommandResult(type=$type, cat=$category, sub=$subCategory, '
      'desc=$itemDescription, multi=$isMultiAngle)';
}

enum VoiceCommandType {
  /// A disposal category was spoken (may include subcategory).
  categoryAssignment,

  /// A "new item" trigger was spoken in semi-auto mode.
  newItem,

  /// A "multi-angle" trigger was spoken.
  multiAngle,

  /// Free-form description without a command.
  description,

  /// Nothing recognisable matched.
  unknown,
}

/// Parses raw speech transcriptions into structured [VoiceCommandResult]s.
///
/// All keyword comparisons are case-insensitive. The matcher prefers the
/// longest trigger phrase when multiple could match.
class KeywordMatcher {
  final AppSettings settings;

  KeywordMatcher(this.settings);

  /// Normalise a string: lowercase, collapse whitespace, strip punctuation.
  static String _normalise(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Returns true if [haystack] contains [needle] as a whole-word phrase.
  static bool _containsPhrase(String haystack, String needle) {
    if (needle.isEmpty) return false;
    // Simple substring check — works for multi-word phrases.
    return haystack.contains(needle);
  }

  /// Attempt to parse [transcript] into a [VoiceCommandResult].
  VoiceCommandResult match(String transcript) {
    final text = _normalise(transcript);

    // --- 1. Multi-angle trigger (highest priority) ---
    for (final trigger in settings.multiAngleTriggers) {
      if (_containsPhrase(text, _normalise(trigger))) {
        return const VoiceCommandResult(
          type: VoiceCommandType.multiAngle,
          isMultiAngle: true,
        );
      }
    }

    // --- 2. New-item trigger ---
    for (final trigger in settings.newItemTriggers) {
      if (_containsPhrase(text, _normalise(trigger))) {
        // If anything follows the trigger, treat it as a description.
        final desc = _extractAfterPhrase(text, _normalise(trigger));
        return VoiceCommandResult(
          type: VoiceCommandType.newItem,
          itemDescription: desc.isNotEmpty ? desc : null,
        );
      }
    }

    // --- 3. Category assignment ---
    // Try each trigger phrase first (prefer explicit "add this to…")
    String remainder = text;
    bool hasTrigger = false;
    for (final trigger in _sortedByLength(settings.triggerPhrases)) {
      final norm = _normalise(trigger);
      if (_containsPhrase(text, norm)) {
        remainder = _extractAfterPhrase(text, norm).trim();
        hasTrigger = true;
        break;
      }
    }

    // Try to find a category keyword in the remainder (or full text if no trigger).
    final searchIn = hasTrigger ? remainder : text;
    final categoryResult = _matchCategory(searchIn);
    if (categoryResult != null) {
      // Anything before the category keyword may be the item description
      final beforeCat = _extractBeforePhrase(searchIn, categoryResult.$3);
      final desc = beforeCat.trim();
      return VoiceCommandResult(
        type: VoiceCommandType.categoryAssignment,
        category: categoryResult.$1,
        subCategory: categoryResult.$2,
        itemDescription: desc.isNotEmpty ? desc : null,
      );
    }

    // --- 4. No category found — treat as a free description if it's non-trivial ---
    if (text.length > 2) {
      return VoiceCommandResult(
        type: VoiceCommandType.description,
        itemDescription: transcript.trim(),
      );
    }

    return const VoiceCommandResult(type: VoiceCommandType.unknown);
  }

  /// Returns (Category, subCategoryLabel?, matchedKeyword) or null.
  (Category, String?, String)? _matchCategory(String text) {
    for (final config in settings.categoryConfigs) {
      for (final keyword in _sortedByLength(config.allKeywords)) {
        final norm = _normalise(keyword);
        if (_containsPhrase(text, norm)) {
          // Look for a sub-classification keyword in what follows.
          final afterCat = _extractAfterPhrase(text, norm);
          final sub = _matchSubClassification(afterCat, config);
          return (config.category, sub, norm);
        }
      }
    }
    return null;
  }

  String? _matchSubClassification(String text, CategoryConfig config) {
    for (final sub in config.subClassifications) {
      for (final keyword in _sortedByLength(sub.keywords)) {
        if (_containsPhrase(text, _normalise(keyword))) {
          return sub.label;
        }
      }
    }
    return null;
  }

  /// Extract text that comes AFTER [phrase] in [text].
  static String _extractAfterPhrase(String text, String phrase) {
    final idx = text.indexOf(phrase);
    if (idx < 0) return '';
    return text.substring(idx + phrase.length).trim();
  }

  /// Extract text that comes BEFORE [phrase] in [text].
  static String _extractBeforePhrase(String text, String phrase) {
    final idx = text.indexOf(phrase);
    if (idx < 0) return text;
    return text.substring(0, idx).trim();
  }

  /// Sort keywords longest-first so we prefer "add this to" over "add".
  static List<String> _sortedByLength(List<String> list) =>
      [...list]..sort((a, b) => b.length.compareTo(a.length));

  // ---- Shipping keyword matching ----

  /// Match a spoken [text] to a [ShippingOption].
  static ShippingOption? matchShipping(String text, List<String>? customKeywords) {
    final norm = _normalise(text);
    final defaults = {
      'free': ShippingOption.free,
      'free shipping': ShippingOption.free,
      'buyer arranges': ShippingOption.buyerArranges,
      'buyer': ShippingOption.buyerArranges,
      'exact': ShippingOption.exactCost,
      'actual cost': ShippingOption.exactCost,
      'flat rate': ShippingOption.flatRate,
      'flat': ShippingOption.flatRate,
      'local pickup': ShippingOption.localPickup,
      'local': ShippingOption.localPickup,
      'pickup only': ShippingOption.localPickup,
    };
    final sorted = _sortedByLength(defaults.keys.toList());
    for (final key in sorted) {
      if (_containsPhrase(norm, key)) return defaults[key];
    }
    return null;
  }

  // ---- Marketplace matching ----

  static const _marketplaceKeywords = {
    'ebay': 'ebay',
    'e-bay': 'ebay',
    'amazon': 'amazon',
    'facebook': 'facebook',
    'marketplace': 'facebook',
    'fb marketplace': 'facebook',
    'craigslist': 'craigslist',
    'craig': 'craigslist',
    'etsy': 'etsy',
    'walmart': 'walmart',
    'offer up': 'offerup',
    'offerup': 'offerup',
    'poshmark': 'poshmark',
    'posh': 'poshmark',
  };

  static String? matchMarketplace(String text) {
    final norm = _normalise(text);
    final sorted = _sortedByLength(_marketplaceKeywords.keys.toList());
    for (final key in sorted) {
      if (_containsPhrase(norm, key)) return _marketplaceKeywords[key];
    }
    return null;
  }

  // ---- Listing type matching ----

  static const _listingTypeKeywords = {
    'buy it now': ListingType.buyItNow,
    'buy now': ListingType.buyItNow,
    'fixed price': ListingType.buyItNow,
    'auction with buy it now': ListingType.auctionWithBuyItNow,
    'auction buy it now': ListingType.auctionWithBuyItNow,
    'auction': ListingType.auction,
    'bid': ListingType.auction,
  };

  static ListingType? matchListingType(String text) {
    final norm = _normalise(text);
    final sorted = _sortedByLength(_listingTypeKeywords.keys.toList());
    for (final key in sorted) {
      if (_containsPhrase(norm, key)) return _listingTypeKeywords[key];
    }
    return null;
  }

  // ---- Affirmation / negation ----

  static bool isAffirmative(String text) {
    final norm = _normalise(text);
    return ['yes', 'yeah', 'yep', 'sure', 'ok', 'okay', 'correct', 'right', 'affirmative']
        .any((w) => _containsPhrase(norm, w));
  }

  static bool isNegative(String text) {
    final norm = _normalise(text);
    return ['no', 'nope', 'nah', 'negative', "don't", 'skip', 'next']
        .any((w) => _containsPhrase(norm, w));
  }

  // ---- Price extraction ----

  /// Attempt to extract a dollar amount from speech.
  static double? extractPrice(String text) {
    // Match patterns like "$25", "25 dollars", "25.99", "twenty five dollars"
    final norm = _normalise(text);
    // Numeric pattern
    final numMatch = RegExp(r'(\d+(?:\.\d{1,2})?)').firstMatch(norm);
    if (numMatch != null) {
      return double.tryParse(numMatch.group(1)!);
    }
    return null;
  }
}

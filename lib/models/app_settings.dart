import 'dart:convert';
import 'category.dart';

enum CameraMode { manual, semiAuto, fullyAuto }
extension CameraModeExt on CameraMode {
  String get displayName {
    switch (this) {
      case CameraMode.manual:     return 'Manual';
      case CameraMode.semiAuto:   return 'Semi-Auto';
      case CameraMode.fullyAuto:  return 'Fully Automatic';
    }
  }
}

/// A user-defined room / location used for tagging and label printing.
class RoomConfig {
  final String id;
  final String label;
  final List<String> keywords; // speech keywords for this room
  final String? color; // hex color for UI

  const RoomConfig({
    required this.id,
    required this.label,
    this.keywords = const [],
    this.color,
  });

  RoomConfig copyWith({String? id, String? label, List<String>? keywords, String? color}) =>
      RoomConfig(id: id ?? this.id, label: label ?? this.label,
          keywords: keywords ?? this.keywords, color: color ?? this.color);

  Map<String, dynamic> toJson() =>
      {'id': id, 'label': label, 'keywords': keywords, 'color': color};

  factory RoomConfig.fromJson(Map<String, dynamic> j) => RoomConfig(
        id: j['id'] as String,
        label: j['label'] as String,
        keywords: List<String>.from(j['keywords'] as List? ?? []),
        color: j['color'] as String?,
      );

  static List<RoomConfig> defaults() => [
        RoomConfig(id: 'lr', label: 'Living Room', keywords: ['living room', 'lounge', 'family room']),
        RoomConfig(id: 'mbr', label: 'Master Bedroom', keywords: ['master bedroom', 'master', 'main bedroom']),
        RoomConfig(id: 'br2', label: 'Bedroom 2', keywords: ['bedroom 2', 'second bedroom', 'guest room']),
        RoomConfig(id: 'br3', label: 'Bedroom 3', keywords: ['bedroom 3', 'third bedroom', "kid's room"]),
        RoomConfig(id: 'kit', label: 'Kitchen', keywords: ['kitchen']),
        RoomConfig(id: 'din', label: 'Dining Room', keywords: ['dining room', 'dining']),
        RoomConfig(id: 'bath', label: 'Bathroom', keywords: ['bathroom', 'bath']),
        RoomConfig(id: 'gar', label: 'Garage', keywords: ['garage']),
        RoomConfig(id: 'off', label: 'Office', keywords: ['office', 'study', 'den']),
        RoomConfig(id: 'bsmt', label: 'Basement', keywords: ['basement']),
        RoomConfig(id: 'attic', label: 'Attic', keywords: ['attic', 'loft']),
        RoomConfig(id: 'out', label: 'Outdoor', keywords: ['outdoor', 'yard', 'garden', 'patio']),
      ];
}

/// Full application settings — all fields are user-configurable.
class AppSettings {
  // ---- API Keys ----
  final String googleVisionApiKey;
  final String openAiApiKey;
  final String ebayAppId;
  final String ebayDevId;
  final String ebayCertId;
  final String ebayUserToken;
  final String amazonSellerId;
  final String amazonMwsAuthToken;

  // ---- Camera ----
  final CameraMode defaultCameraMode;
  final double autoCaptureSilenceSeconds;
  final double autoCaptureSharpnessThreshold;
  final double autoCaptureMotionThreshold;

  // ---- Voice / Speech ----
  final List<String> triggerPhrases;
  final List<String> newItemTriggers;
  final List<String> multiAngleTriggers;
  final double ttsRate;
  final double ttsVolume;
  final bool ttsEnabled;
  final int speechListenTimeoutSeconds;

  // ---- Categories ----
  final List<CategoryConfig> categoryConfigs;

  // ---- Rooms (feature: room tagging + label printing) ----
  final List<RoomConfig> rooms;

  // ---- Sell / Marketplace ----
  final String defaultMarketplace;
  final bool autoListOnSell;
  final String defaultShippingOption;
  final double defaultShippingCost;

  // ---- Insurance mode (feature: insurance valuation) ----
  final bool insuranceModeEnabled;
  final String insurancePolicyNumber;
  final String insuranceCompany;

  // ---- Cloud sync (feature: cloud sync) ----
  final bool cloudSyncEnabled;
  final String? cloudSyncEmail;

  // ---- Duplicate detection (feature: duplicate detection) ----
  final bool duplicateDetectionEnabled;
  final double duplicateSimilarityThreshold; // 0–1

  // ---- Photo enhancement (feature: smart photo enhancement) ----
  final bool autoEnhancePhotos;
  final bool autoRemoveBackground;

  // ---- Barcode scanning (feature: barcode scanning) ----
  final bool barcodeScanEnabled;
  final bool autoLookupBarcode;

  // ---- Export ----
  final String exportDirectory;
  final bool includePhotosInExport;

  const AppSettings({
    this.googleVisionApiKey = '',
    this.openAiApiKey = '',
    this.ebayAppId = '',
    this.ebayDevId = '',
    this.ebayCertId = '',
    this.ebayUserToken = '',
    this.amazonSellerId = '',
    this.amazonMwsAuthToken = '',
    this.defaultCameraMode = CameraMode.manual,
    this.autoCaptureSilenceSeconds = 2.0,
    this.autoCaptureSharpnessThreshold = 0.6,
    this.autoCaptureMotionThreshold = 0.02,
    this.triggerPhrases = const [
      'add this to', 'put this in', 'categorize this as', 'categorize as',
      'this goes to', 'this goes in', 'place this in', 'move this to',
      'mark as', 'label as',
    ],
    this.newItemTriggers = const [
      'new item', 'next item', 'item', 'capture', 'take photo', 'photograph', 'scan',
    ],
    this.multiAngleTriggers = const [
      'angles', 'multi', 'multiple angles', 'all angles', 'multiple photos', 'multi shot', 'rotate',
    ],
    this.ttsRate = 0.5,
    this.ttsVolume = 1.0,
    this.ttsEnabled = true,
    this.speechListenTimeoutSeconds = 5,
    List<CategoryConfig>? categoryConfigs,
    List<RoomConfig>? rooms,
    this.defaultMarketplace = 'ebay',
    this.autoListOnSell = false,
    this.defaultShippingOption = 'free',
    this.defaultShippingCost = 0.0,
    this.insuranceModeEnabled = false,
    this.insurancePolicyNumber = '',
    this.insuranceCompany = '',
    this.cloudSyncEnabled = false,
    this.cloudSyncEmail,
    this.duplicateDetectionEnabled = true,
    this.duplicateSimilarityThreshold = 0.85,
    this.autoEnhancePhotos = false,
    this.autoRemoveBackground = false,
    this.barcodeScanEnabled = true,
    this.autoLookupBarcode = true,
    this.exportDirectory = '',
    this.includePhotosInExport = true,
  })  : categoryConfigs = categoryConfigs ?? const [],
        rooms = rooms ?? const [];

  static AppSettings defaults() => AppSettings(
        categoryConfigs: CategoryConfig.defaults(),
        rooms: RoomConfig.defaults(),
      );

  AppSettings copyWith({
    String? googleVisionApiKey,
    String? openAiApiKey,
    String? ebayAppId,
    String? ebayDevId,
    String? ebayCertId,
    String? ebayUserToken,
    String? amazonSellerId,
    String? amazonMwsAuthToken,
    CameraMode? defaultCameraMode,
    double? autoCaptureSilenceSeconds,
    double? autoCaptureSharpnessThreshold,
    double? autoCaptureMotionThreshold,
    List<String>? triggerPhrases,
    List<String>? newItemTriggers,
    List<String>? multiAngleTriggers,
    double? ttsRate,
    double? ttsVolume,
    bool? ttsEnabled,
    int? speechListenTimeoutSeconds,
    List<CategoryConfig>? categoryConfigs,
    List<RoomConfig>? rooms,
    String? defaultMarketplace,
    bool? autoListOnSell,
    String? defaultShippingOption,
    double? defaultShippingCost,
    bool? insuranceModeEnabled,
    String? insurancePolicyNumber,
    String? insuranceCompany,
    bool? cloudSyncEnabled,
    String? cloudSyncEmail,
    bool? duplicateDetectionEnabled,
    double? duplicateSimilarityThreshold,
    bool? autoEnhancePhotos,
    bool? autoRemoveBackground,
    bool? barcodeScanEnabled,
    bool? autoLookupBarcode,
    String? exportDirectory,
    bool? includePhotosInExport,
  }) =>
      AppSettings(
        googleVisionApiKey: googleVisionApiKey ?? this.googleVisionApiKey,
        openAiApiKey: openAiApiKey ?? this.openAiApiKey,
        ebayAppId: ebayAppId ?? this.ebayAppId,
        ebayDevId: ebayDevId ?? this.ebayDevId,
        ebayCertId: ebayCertId ?? this.ebayCertId,
        ebayUserToken: ebayUserToken ?? this.ebayUserToken,
        amazonSellerId: amazonSellerId ?? this.amazonSellerId,
        amazonMwsAuthToken: amazonMwsAuthToken ?? this.amazonMwsAuthToken,
        defaultCameraMode: defaultCameraMode ?? this.defaultCameraMode,
        autoCaptureSilenceSeconds: autoCaptureSilenceSeconds ?? this.autoCaptureSilenceSeconds,
        autoCaptureSharpnessThreshold: autoCaptureSharpnessThreshold ?? this.autoCaptureSharpnessThreshold,
        autoCaptureMotionThreshold: autoCaptureMotionThreshold ?? this.autoCaptureMotionThreshold,
        triggerPhrases: triggerPhrases ?? this.triggerPhrases,
        newItemTriggers: newItemTriggers ?? this.newItemTriggers,
        multiAngleTriggers: multiAngleTriggers ?? this.multiAngleTriggers,
        ttsRate: ttsRate ?? this.ttsRate,
        ttsVolume: ttsVolume ?? this.ttsVolume,
        ttsEnabled: ttsEnabled ?? this.ttsEnabled,
        speechListenTimeoutSeconds: speechListenTimeoutSeconds ?? this.speechListenTimeoutSeconds,
        categoryConfigs: categoryConfigs ?? this.categoryConfigs,
        rooms: rooms ?? this.rooms,
        defaultMarketplace: defaultMarketplace ?? this.defaultMarketplace,
        autoListOnSell: autoListOnSell ?? this.autoListOnSell,
        defaultShippingOption: defaultShippingOption ?? this.defaultShippingOption,
        defaultShippingCost: defaultShippingCost ?? this.defaultShippingCost,
        insuranceModeEnabled: insuranceModeEnabled ?? this.insuranceModeEnabled,
        insurancePolicyNumber: insurancePolicyNumber ?? this.insurancePolicyNumber,
        insuranceCompany: insuranceCompany ?? this.insuranceCompany,
        cloudSyncEnabled: cloudSyncEnabled ?? this.cloudSyncEnabled,
        cloudSyncEmail: cloudSyncEmail ?? this.cloudSyncEmail,
        duplicateDetectionEnabled: duplicateDetectionEnabled ?? this.duplicateDetectionEnabled,
        duplicateSimilarityThreshold: duplicateSimilarityThreshold ?? this.duplicateSimilarityThreshold,
        autoEnhancePhotos: autoEnhancePhotos ?? this.autoEnhancePhotos,
        autoRemoveBackground: autoRemoveBackground ?? this.autoRemoveBackground,
        barcodeScanEnabled: barcodeScanEnabled ?? this.barcodeScanEnabled,
        autoLookupBarcode: autoLookupBarcode ?? this.autoLookupBarcode,
        exportDirectory: exportDirectory ?? this.exportDirectory,
        includePhotosInExport: includePhotosInExport ?? this.includePhotosInExport,
      );

  Map<String, dynamic> toJson() => {
        'googleVisionApiKey': googleVisionApiKey,
        'openAiApiKey': openAiApiKey,
        'ebayAppId': ebayAppId,
        'ebayDevId': ebayDevId,
        'ebayCertId': ebayCertId,
        'ebayUserToken': ebayUserToken,
        'amazonSellerId': amazonSellerId,
        'amazonMwsAuthToken': amazonMwsAuthToken,
        'defaultCameraMode': defaultCameraMode.name,
        'autoCaptureSilenceSeconds': autoCaptureSilenceSeconds,
        'autoCaptureSharpnessThreshold': autoCaptureSharpnessThreshold,
        'autoCaptureMotionThreshold': autoCaptureMotionThreshold,
        'triggerPhrases': triggerPhrases,
        'newItemTriggers': newItemTriggers,
        'multiAngleTriggers': multiAngleTriggers,
        'ttsRate': ttsRate,
        'ttsVolume': ttsVolume,
        'ttsEnabled': ttsEnabled,
        'speechListenTimeoutSeconds': speechListenTimeoutSeconds,
        'categoryConfigs': categoryConfigs.map((c) => c.toJson()).toList(),
        'rooms': rooms.map((r) => r.toJson()).toList(),
        'defaultMarketplace': defaultMarketplace,
        'autoListOnSell': autoListOnSell,
        'defaultShippingOption': defaultShippingOption,
        'defaultShippingCost': defaultShippingCost,
        'insuranceModeEnabled': insuranceModeEnabled,
        'insurancePolicyNumber': insurancePolicyNumber,
        'insuranceCompany': insuranceCompany,
        'cloudSyncEnabled': cloudSyncEnabled,
        'cloudSyncEmail': cloudSyncEmail,
        'duplicateDetectionEnabled': duplicateDetectionEnabled,
        'duplicateSimilarityThreshold': duplicateSimilarityThreshold,
        'autoEnhancePhotos': autoEnhancePhotos,
        'autoRemoveBackground': autoRemoveBackground,
        'barcodeScanEnabled': barcodeScanEnabled,
        'autoLookupBarcode': autoLookupBarcode,
        'exportDirectory': exportDirectory,
        'includePhotosInExport': includePhotosInExport,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) {
    final d = AppSettings.defaults();
    return AppSettings(
      googleVisionApiKey: j['googleVisionApiKey'] as String? ?? '',
      openAiApiKey: j['openAiApiKey'] as String? ?? '',
      ebayAppId: j['ebayAppId'] as String? ?? '',
      ebayDevId: j['ebayDevId'] as String? ?? '',
      ebayCertId: j['ebayCertId'] as String? ?? '',
      ebayUserToken: j['ebayUserToken'] as String? ?? '',
      amazonSellerId: j['amazonSellerId'] as String? ?? '',
      amazonMwsAuthToken: j['amazonMwsAuthToken'] as String? ?? '',
      defaultCameraMode: CameraMode.values.firstWhere(
          (m) => m.name == j['defaultCameraMode'], orElse: () => CameraMode.manual),
      autoCaptureSilenceSeconds: (j['autoCaptureSilenceSeconds'] as num?)?.toDouble() ?? 2.0,
      autoCaptureSharpnessThreshold: (j['autoCaptureSharpnessThreshold'] as num?)?.toDouble() ?? 0.6,
      autoCaptureMotionThreshold: (j['autoCaptureMotionThreshold'] as num?)?.toDouble() ?? 0.02,
      triggerPhrases: List<String>.from(j['triggerPhrases'] as List? ?? d.triggerPhrases),
      newItemTriggers: List<String>.from(j['newItemTriggers'] as List? ?? d.newItemTriggers),
      multiAngleTriggers: List<String>.from(j['multiAngleTriggers'] as List? ?? d.multiAngleTriggers),
      ttsRate: (j['ttsRate'] as num?)?.toDouble() ?? 0.5,
      ttsVolume: (j['ttsVolume'] as num?)?.toDouble() ?? 1.0,
      ttsEnabled: j['ttsEnabled'] as bool? ?? true,
      speechListenTimeoutSeconds: j['speechListenTimeoutSeconds'] as int? ?? 5,
      categoryConfigs: (j['categoryConfigs'] as List? ?? [])
          .map((e) => CategoryConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
      rooms: (j['rooms'] as List? ?? [])
          .map((e) => RoomConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
      defaultMarketplace: j['defaultMarketplace'] as String? ?? 'ebay',
      autoListOnSell: j['autoListOnSell'] as bool? ?? false,
      defaultShippingOption: j['defaultShippingOption'] as String? ?? 'free',
      defaultShippingCost: (j['defaultShippingCost'] as num?)?.toDouble() ?? 0.0,
      insuranceModeEnabled: j['insuranceModeEnabled'] as bool? ?? false,
      insurancePolicyNumber: j['insurancePolicyNumber'] as String? ?? '',
      insuranceCompany: j['insuranceCompany'] as String? ?? '',
      cloudSyncEnabled: j['cloudSyncEnabled'] as bool? ?? false,
      cloudSyncEmail: j['cloudSyncEmail'] as String?,
      duplicateDetectionEnabled: j['duplicateDetectionEnabled'] as bool? ?? true,
      duplicateSimilarityThreshold: (j['duplicateSimilarityThreshold'] as num?)?.toDouble() ?? 0.85,
      autoEnhancePhotos: j['autoEnhancePhotos'] as bool? ?? false,
      autoRemoveBackground: j['autoRemoveBackground'] as bool? ?? false,
      barcodeScanEnabled: j['barcodeScanEnabled'] as bool? ?? true,
      autoLookupBarcode: j['autoLookupBarcode'] as bool? ?? true,
      exportDirectory: j['exportDirectory'] as String? ?? '',
      includePhotosInExport: j['includePhotosInExport'] as bool? ?? true,
    );
  }

  String toJsonString() => jsonEncode(toJson());
  factory AppSettings.fromJsonString(String s) =>
      AppSettings.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

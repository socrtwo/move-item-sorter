import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/constants.dart';
import '../models/app_settings.dart';
import '../models/category.dart';
import '../models/item.dart';
import '../services/ai_service.dart';
import '../services/barcode_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/database_service.dart';
import '../services/duplicate_detection_service.dart';
import '../services/export_service.dart';
import '../services/marketplace_service.dart';
import '../services/photo_service.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import '../services/vision_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Singleton service providers
// ─────────────────────────────────────────────────────────────────────────────

final databaseServiceProvider = Provider<DatabaseService>(
    (_) => DatabaseService());

final photoServiceProvider = Provider<PhotoService>((_) => PhotoService());

final aiServiceProvider = Provider<AiService>((_) => AiService());

final barcodeServiceProvider = Provider<BarcodeService>((_) => BarcodeService());

final visionServiceProvider = Provider<VisionService>((_) => VisionService());

final exportServiceProvider = Provider<ExportService>((_) => ExportService());

final marketplaceServiceProvider =
    Provider<MarketplaceService>((_) => MarketplaceService());

final duplicateDetectionProvider = Provider<DuplicateDetectionService>(
    (ref) => DuplicateDetectionService(ref.read(photoServiceProvider)));

final cloudSyncServiceProvider = Provider<CloudSyncService>(
    (_) => LocalBackupSyncService());

// ─────────────────────────────────────────────────────────────────────────────
// Settings
// ─────────────────────────────────────────────────────────────────────────────

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(AppSettings.defaults()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(AppConstants.settingsKey);
    if (json != null) {
      state = AppSettings.fromJsonString(json);
    }
  }

  Future<void> save(AppSettings settings) async {
    state = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.settingsKey, settings.toJsonString());
  }

  Future<void> update(AppSettings Function(AppSettings) updater) async {
    await save(updater(state));
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((_) => SettingsNotifier());

// ─────────────────────────────────────────────────────────────────────────────
// Theme mode
// ─────────────────────────────────────────────────────────────────────────────

final themeModeProvider = StateProvider<ThemeMode>((_) => ThemeMode.system);

// ─────────────────────────────────────────────────────────────────────────────
// Items
// ─────────────────────────────────────────────────────────────────────────────

class ItemsNotifier extends StateNotifier<AsyncValue<List<Item>>> {
  final DatabaseService _db;
  ItemsNotifier(this._db) : super(const AsyncValue.loading()) {
    loadAll();
  }

  Future<void> loadAll({
    Category? filterCategory,
    PackingStatus? filterPackingStatus,
    String? filterRoom,
    String? searchQuery,
  }) async {
    state = const AsyncValue.loading();
    try {
      final items = await _db.getAllItems(
        filterCategory: filterCategory,
        filterPackingStatus: filterPackingStatus,
        filterRoom: filterRoom,
        searchQuery: searchQuery,
      );
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addItem(Item item) async {
    await _db.insertItem(item);
    await loadAll();
  }

  Future<void> updateItem(Item item) async {
    await _db.updateItem(item);
    await loadAll();
  }

  Future<void> deleteItem(String id) async {
    await _db.deleteItem(id);
    await loadAll();
  }

  Future<void> deleteItems(List<String> ids) async {
    await _db.deleteItems(ids);
    await loadAll();
  }

  Future<void> batchSetCategory(List<String> ids, Category category,
      {String? subCategory}) async {
    final items = state.valueOrNull ?? [];
    for (final item in items.where((i) => ids.contains(i.id))) {
      await _db.updateItem(item.copyWith(
        category: category,
        subCategory: subCategory,
        updatedAt: DateTime.now(),
        clearSubCategory: subCategory == null,
      ));
    }
    await loadAll();
  }

  Future<void> batchSetPackingStatus(
      List<String> ids, PackingStatus status) async {
    final items = state.valueOrNull ?? [];
    for (final item in items.where((i) => ids.contains(i.id))) {
      await _db.updateItem(
          item.copyWith(packingStatus: status, updatedAt: DateTime.now()));
    }
    await loadAll();
  }
}

final itemsProvider =
    StateNotifierProvider<ItemsNotifier, AsyncValue<List<Item>>>(
        (ref) => ItemsNotifier(ref.read(databaseServiceProvider)));

// ─────────────────────────────────────────────────────────────────────────────
// Category counts + budget summary
// ─────────────────────────────────────────────────────────────────────────────

final categoryCountsProvider = FutureProvider<Map<Category, int>>((ref) async {
  ref.watch(itemsProvider); // re-run when items change
  return ref.read(databaseServiceProvider).getCategoryCounts();
});

final sellRevenueProvider = FutureProvider<double>((ref) async {
  ref.watch(itemsProvider);
  final db = ref.read(databaseServiceProvider);
  final items = await db.getAllItems(filterCategory: Category.sell);
  return items
      .where((i) => i.sellDetails?.price != null)
      .fold(0.0, (s, i) => s + i.sellDetails!.price!);
});

final totalEstimatedValueProvider = FutureProvider<double>((ref) async {
  ref.watch(itemsProvider);
  return ref.read(databaseServiceProvider).getTotalEstimatedValue();
});

final donationValueProvider = FutureProvider<double>((ref) async {
  ref.watch(itemsProvider);
  return ref
      .read(databaseServiceProvider)
      .getTotalEstimatedValue(category: Category.donate);
});

// ─────────────────────────────────────────────────────────────────────────────
// Speech + TTS
// ─────────────────────────────────────────────────────────────────────────────

final speechServiceProvider = Provider<SpeechService>((ref) {
  final settings = ref.read(settingsProvider);
  return SpeechService(settings);
});

final ttsServiceProvider = Provider<TtsService>((_) => TtsService());

// ─────────────────────────────────────────────────────────────────────────────
// Camera state
// ─────────────────────────────────────────────────────────────────────────────

enum CaptureState { idle, capturing, processing }

class CameraStateNotifier extends StateNotifier<CaptureState> {
  CameraStateNotifier() : super(CaptureState.idle);

  void setCapturing() => state = CaptureState.capturing;
  void setProcessing() => state = CaptureState.processing;
  void setIdle() => state = CaptureState.idle;
}

final cameraStateProvider =
    StateNotifierProvider<CameraStateNotifier, CaptureState>(
        (_) => CameraStateNotifier());

// ─────────────────────────────────────────────────────────────────────────────
// Sell-flow state machine
// ─────────────────────────────────────────────────────────────────────────────

enum SellFlowStep {
  marketplace,
  listingType,
  title,
  subtitle,
  price,
  description,
  shipping,
  condition,
  review,
  done,
}

class SellFlowState {
  final SellFlowStep step;
  final String? marketplace;
  final ListingType? listingType;
  final String? title;
  final String? subtitle;
  final double? price;
  final String? description;
  final ShippingOption? shippingOption;
  final double? shippingCost;
  final String? condition;
  final bool isListening;
  final String? currentTranscript;

  const SellFlowState({
    this.step = SellFlowStep.marketplace,
    this.marketplace,
    this.listingType,
    this.title,
    this.subtitle,
    this.price,
    this.description,
    this.shippingOption,
    this.shippingCost,
    this.condition,
    this.isListening = false,
    this.currentTranscript,
  });

  SellFlowState copyWith({
    SellFlowStep? step,
    String? marketplace,
    ListingType? listingType,
    String? title,
    String? subtitle,
    double? price,
    String? description,
    ShippingOption? shippingOption,
    double? shippingCost,
    String? condition,
    bool? isListening,
    String? currentTranscript,
  }) =>
      SellFlowState(
        step: step ?? this.step,
        marketplace: marketplace ?? this.marketplace,
        listingType: listingType ?? this.listingType,
        title: title ?? this.title,
        subtitle: subtitle ?? this.subtitle,
        price: price ?? this.price,
        description: description ?? this.description,
        shippingOption: shippingOption ?? this.shippingOption,
        shippingCost: shippingCost ?? this.shippingCost,
        condition: condition ?? this.condition,
        isListening: isListening ?? this.isListening,
        currentTranscript: currentTranscript ?? this.currentTranscript,
      );

  bool get isComplete => step == SellFlowStep.done;

  SellDetails? toSellDetails() {
    if (marketplace == null || listingType == null || title == null) return null;
    return SellDetails(
      marketplace: marketplace!,
      listingType: listingType!,
      title: title!,
      subtitle: subtitle,
      price: price,
      description: description,
      aiGeneratedDescription: description != null && title != null,
      shippingOption: shippingOption ?? ShippingOption.free,
      shippingCost: shippingCost,
      condition: condition,
      isAiGuessed: price == null || description == null,
    );
  }
}

class SellFlowNotifier extends StateNotifier<SellFlowState> {
  SellFlowNotifier() : super(const SellFlowState());

  void reset() => state = const SellFlowState();
  void advance(SellFlowState next) => state = next;
  void setStep(SellFlowStep step) => state = state.copyWith(step: step);

  void setMarketplace(String mp) =>
      state = state.copyWith(marketplace: mp, step: SellFlowStep.listingType);
  void setListingType(ListingType lt) =>
      state = state.copyWith(listingType: lt, step: SellFlowStep.title);
  void setTitle(String t) =>
      state = state.copyWith(title: t, step: SellFlowStep.subtitle);
  void setSubtitle(String? s) =>
      state = state.copyWith(subtitle: s, step: SellFlowStep.price);
  void setPrice(double p) =>
      state = state.copyWith(price: p, step: SellFlowStep.description);
  void setDescription(String d) =>
      state = state.copyWith(description: d, step: SellFlowStep.shipping);
  void setShipping(ShippingOption so, {double? cost}) =>
      state = state.copyWith(
          shippingOption: so, shippingCost: cost, step: SellFlowStep.condition);
  void setCondition(String c) =>
      state = state.copyWith(condition: c, step: SellFlowStep.review);
  void setListening(bool v) => state = state.copyWith(isListening: v);
  void setTranscript(String t) => state = state.copyWith(currentTranscript: t);
  void markDone() => state = state.copyWith(step: SellFlowStep.done);
}

final sellFlowProvider =
    StateNotifierProvider.autoDispose<SellFlowNotifier, SellFlowState>(
        (_) => SellFlowNotifier());

// ─────────────────────────────────────────────────────────────────────────────
// Filters / search
// ─────────────────────────────────────────────────────────────────────────────

class FilterState {
  final Category? category;
  final PackingStatus? packingStatus;
  final String? room;
  final String searchQuery;
  final bool batchMode;
  final Set<String> selectedIds;

  const FilterState({
    this.category,
    this.packingStatus,
    this.room,
    this.searchQuery = '',
    this.batchMode = false,
    this.selectedIds = const {},
  });

  FilterState copyWith({
    Category? category,
    PackingStatus? packingStatus,
    String? room,
    String? searchQuery,
    bool? batchMode,
    Set<String>? selectedIds,
    bool clearCategory = false,
    bool clearRoom = false,
    bool clearPackingStatus = false,
  }) =>
      FilterState(
        category: clearCategory ? null : (category ?? this.category),
        packingStatus: clearPackingStatus ? null : (packingStatus ?? this.packingStatus),
        room: clearRoom ? null : (room ?? this.room),
        searchQuery: searchQuery ?? this.searchQuery,
        batchMode: batchMode ?? this.batchMode,
        selectedIds: selectedIds ?? this.selectedIds,
      );
}

final filterProvider = StateNotifierProvider<FilterNotifier, FilterState>(
    (_) => FilterNotifier());

class FilterNotifier extends StateNotifier<FilterState> {
  FilterNotifier() : super(const FilterState());

  void setCategory(Category? c) =>
      state = state.copyWith(category: c, clearCategory: c == null);
  void setPackingStatus(PackingStatus? s) =>
      state = state.copyWith(packingStatus: s, clearPackingStatus: s == null);
  void setRoom(String? r) => state = state.copyWith(room: r, clearRoom: r == null);
  void setSearch(String q) => state = state.copyWith(searchQuery: q);
  void toggleBatchMode() => state = state.copyWith(
      batchMode: !state.batchMode, selectedIds: {});
  void toggleSelected(String id) {
    final ids = Set<String>.from(state.selectedIds);
    if (ids.contains(id)) {
      ids.remove(id);
    } else {
      ids.add(id);
    }
    state = state.copyWith(selectedIds: ids);
  }
  void clearSelection() =>
      state = state.copyWith(batchMode: false, selectedIds: {});
  void selectAll(List<String> ids) =>
      state = state.copyWith(selectedIds: ids.toSet());
}

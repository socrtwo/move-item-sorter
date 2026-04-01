import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants.dart';
import '../../models/app_settings.dart';
import '../../models/category.dart';
import '../../models/item.dart';
import '../../providers/app_providers.dart';
import '../../utils/keyword_matcher.dart';
import '../../widgets/camera_overlay.dart';
import '../../widgets/voice_indicator.dart';

class CameraScreen extends ConsumerStatefulWidget {
  final String? initialModeOverride;
  const CameraScreen({super.key, this.initialModeOverride});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver {
  static const _uuid = Uuid();

  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _cameraReady = false;

  // Current item being built
  String? _currentItemId;
  String? _currentItemName;
  Category? _pendingCategory;
  String? _pendingSubCategory;
  List<String> _capturedPhotos = [];
  String? _voiceBuffer;

  // Mode
  late CameraMode _mode;
  bool _multiAngleMode = false;
  bool _scanningBarcode = false;

  // Auto-capture
  Timer? _autoCheckTimer;
  DateTime? _stationarySince;
  List<int>? _lastFrameHash;

  // Speech
  StreamSubscription? _commandSub;
  StreamSubscription? _transcriptSub;
  String _liveTranscript = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final settings = ref.read(settingsProvider);
    _mode = settings.defaultCameraMode;
    _initCamera();
    _initSpeech();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;
    _cameraController = CameraController(
      _cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await _cameraController!.initialize();
    if (mounted) setState(() => _cameraReady = true);
    if (_mode == CameraMode.fullyAuto) _startAutoCapture();
  }

  Future<void> _initSpeech() async {
    final speechService = ref.read(speechServiceProvider);
    final settings = ref.read(settingsProvider);
    final ok = await speechService.initialize();
    if (!ok) return;

    _commandSub = speechService.commandStream.listen(_handleVoiceCommand);
    _transcriptSub = speechService.rawTranscriptStream.listen((t) {
      if (mounted) setState(() => _liveTranscript = t);
    });

    await speechService.startListening();
    await ref.read(ttsServiceProvider).speak(
      'Camera ready. Say "new item" to capture, or speak a category.',
      settings: settings,
    );
  }

  void _handleVoiceCommand(VoiceCommandResult cmd) {
    final settings = ref.read(settingsProvider);
    switch (cmd.type) {
      case VoiceCommandType.newItem:
        if (_mode == CameraMode.semiAuto || _mode == CameraMode.manual) {
          if (cmd.itemDescription != null) _currentItemName = cmd.itemDescription;
          _capturePhoto();
        }
        break;
      case VoiceCommandType.multiAngle:
        setState(() => _multiAngleMode = true);
        ref.read(ttsServiceProvider).speak(
          'Multi-angle mode. Capture up to ${AppConstants.multiAngleMaxPhotos} angles.',
          settings: settings,
        );
        break;
      case VoiceCommandType.categoryAssignment:
        _pendingCategory = cmd.category;
        _pendingSubCategory = cmd.subCategory;
        if (cmd.itemDescription != null) _currentItemName = cmd.itemDescription;
        _applyPendingCategory();
        break;
      case VoiceCommandType.description:
        _voiceBuffer = (_voiceBuffer != null)
            ? '$_voiceBuffer ${cmd.itemDescription}'
            : cmd.itemDescription;
        if (mounted) setState(() {});
        break;
      case VoiceCommandType.unknown:
        break;
    }
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null || !_cameraReady) return;
    if (_capturedPhotos.length >= AppConstants.multiAngleMaxPhotos) return;

    ref.read(cameraStateProvider.notifier).setCapturing();
    try {
      final xFile = await _cameraController!.takePicture();
      final photoService = ref.read(photoServiceProvider);
      final settings = ref.read(settingsProvider);

      // Save + optionally enhance
      String path = await photoService.savePhoto(File(xFile.path));
      if (settings.autoEnhancePhotos) {
        final enhanced = await photoService.enhancePhoto(path);
        if (enhanced != null) path = enhanced;
      }

      if (_currentItemId == null) {
        _currentItemId = _uuid.v4();
        _capturedPhotos = [];
      }
      _capturedPhotos.add(path);

      // Duplicate check after first photo
      if (_capturedPhotos.length == 1 && settings.duplicateDetectionEnabled) {
        _checkDuplicates(path);
      }

      // Image recognition on first photo
      if (_capturedPhotos.length == 1 && settings.googleVisionApiKey.isNotEmpty) {
        _identifyItem(path);
      }

      // Barcode scan on every photo (if enabled)
      if (settings.barcodeScanEnabled) {
        // barcode scanning is handled by the MobileScanner overlay
      }

      setState(() {});

      if (!_multiAngleMode) {
        _promptCategory();
      } else {
        ref.read(ttsServiceProvider).speak(
          'Photo ${_capturedPhotos.length} captured. Rotate for next angle or say "done".',
          settings: settings,
        );
      }
    } finally {
      ref.read(cameraStateProvider.notifier).setIdle();
    }
  }

  Future<void> _identifyItem(String photoPath) async {
    final settings = ref.read(settingsProvider);
    if (settings.googleVisionApiKey.isEmpty) return;
    final result = await ref
        .read(visionServiceProvider)
        .identifyItem(File(photoPath), settings.googleVisionApiKey);
    if (result.hasResult && _currentItemName == null) {
      setState(() => _currentItemName = result.bestName);
    }
  }

  Future<void> _checkDuplicates(String photoPath) async {
    final settings = ref.read(settingsProvider);
    if (!settings.duplicateDetectionEnabled) return;
    final existingItems = ref.read(itemsProvider).valueOrNull ?? [];
    final duplicates = await ref.read(duplicateDetectionProvider).findDuplicates(
      newImagePath: photoPath,
      existingItems: existingItems,
      threshold: settings.duplicateSimilarityThreshold,
    );
    if (duplicates.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Possible duplicate of "${duplicates.first.displayName}"'),
        action: SnackBarAction(
            label: 'View',
            onPressed: () => context.push('/item/${duplicates.first.id}')),
      ));
    }
  }

  Future<void> _promptCategory() async {
    final settings = ref.read(settingsProvider);
    await ref.read(ttsServiceProvider).speak(
      'Photo captured${_currentItemName != null ? " of ${_currentItemName!}" : ""}. '
      'Say a category: move, store, donate, sell, recycle, or trash.',
      settings: settings,
    );
  }

  void _applyPendingCategory() {
    if (_pendingCategory == null) return;
    if (_currentItemId == null) {
      _currentItemId = _uuid.v4();
    }
    final now = DateTime.now();
    final item = Item(
      id: _currentItemId!,
      name: _currentItemName ?? _voiceBuffer ?? '',
      category: _pendingCategory!,
      subCategory: _pendingSubCategory,
      photoPaths: List.from(_capturedPhotos),
      voiceDescription: _voiceBuffer,
      createdAt: now,
      updatedAt: now,
    );

    ref.read(itemsProvider.notifier).addItem(item);

    final settings = ref.read(settingsProvider);
    ref.read(ttsServiceProvider).sayCategorized(
      item.displayName,
      _pendingCategory!.displayName,
      _pendingSubCategory,
      s: settings,
    );

    // If sell, navigate to sell flow
    if (_pendingCategory == Category.sell) {
      context.push('/sell/${_currentItemId!}');
    }

    // Reset for next item
    _resetCurrentItem();
    setState(() {});
  }

  void _resetCurrentItem() {
    _currentItemId = null;
    _currentItemName = null;
    _pendingCategory = null;
    _pendingSubCategory = null;
    _capturedPhotos = [];
    _voiceBuffer = null;
    _multiAngleMode = false;
  }

  // ── Auto-capture ───────────────────────────────────────────────────────────

  void _startAutoCapture() {
    _autoCheckTimer = Timer.periodic(
      Duration(milliseconds: (1000 / AppConstants.autoCaptureFpsCheck).round()),
      (_) => _autoCheck(),
    );
  }

  Future<void> _autoCheck() async {
    if (_cameraController == null || !_cameraReady) return;
    if (ref.read(cameraStateProvider) != CaptureState.idle) return;
    // Simplified: in a real implementation, capture a low-res frame,
    // compute pixel diff vs last frame, and trigger if stationary + focused.
    // Placeholder logic — always requires manual trigger in this build.
  }

  // ── Barcode ────────────────────────────────────────────────────────────────

  void _onBarcodeDetected(BarcodeCapture capture) async {
    if (!_scanningBarcode) return;
    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode == null) return;

    setState(() => _scanningBarcode = false);
    final settings = ref.read(settingsProvider);
    if (!settings.autoLookupBarcode) {
      setState(() => _currentItemName = barcode);
      return;
    }

    final product = await ref.read(barcodeServiceProvider).lookup(barcode);
    if (product != null && mounted) {
      setState(() {
        _currentItemName = product.displayName;
      });
      await ref.read(ttsServiceProvider).speak(
        'Identified: ${product.displayName}',
        settings: settings,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null) return;
    if (state == AppLifecycleState.inactive) {
      _cameraController!.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoCheckTimer?.cancel();
    _commandSub?.cancel();
    _transcriptSub?.cancel();
    _cameraController?.dispose();
    ref.read(speechServiceProvider).stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera preview ────────────────────────────────────────────
          if (_cameraReady && _cameraController != null)
            CameraPreview(_cameraController!)
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          // ── Barcode scanner overlay ───────────────────────────────────
          if (_scanningBarcode)
            MobileScanner(onDetect: _onBarcodeDetected),

          // ── Camera overlay UI ─────────────────────────────────────────
          CameraOverlay(
            mode: _mode,
            multiAngleMode: _multiAngleMode,
            capturedCount: _capturedPhotos.length,
            currentItemName: _currentItemName,
            pendingCategory: _pendingCategory,
            liveTranscript: _liveTranscript,
            voiceBuffer: _voiceBuffer,
            onShutter: _capturePhoto,
            onBarcodeToggle: () => setState(() => _scanningBarcode = !_scanningBarcode),
            onModeChange: (m) {
              setState(() => _mode = m);
              _autoCheckTimer?.cancel();
              if (m == CameraMode.fullyAuto) _startAutoCapture();
            },
            onMultiAngleDone: () {
              if (_capturedPhotos.isNotEmpty) _promptCategory();
              setState(() => _multiAngleMode = false);
            },
            onClose: () {
              if (_currentItemId != null) {
                // Save partial item without category
                final now = DateTime.now();
                final item = Item(
                  id: _currentItemId!,
                  name: _currentItemName ?? _voiceBuffer ?? 'Unknown',
                  category: Category.move, // default
                  photoPaths: List.from(_capturedPhotos),
                  voiceDescription: _voiceBuffer,
                  createdAt: now,
                  updatedAt: now,
                );
                ref.read(itemsProvider.notifier).addItem(item);
              }
              context.pop();
            },
          ),

          // ── Voice indicator ───────────────────────────────────────────
          Positioned(
            bottom: 120,
            left: 0,
            right: 0,
            child: VoiceIndicator(
              transcript: _liveTranscript,
              speechState: ref.watch(speechServiceProvider).state,
            ),
          ),
        ],
      ),
    );
  }
}

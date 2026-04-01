import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../models/app_settings.dart';
import '../models/category.dart';

class CameraOverlay extends StatelessWidget {
  final CameraMode mode;
  final bool multiAngleMode;
  final int capturedCount;
  final String? currentItemName;
  final Category? pendingCategory;
  final String liveTranscript;
  final String? voiceBuffer;
  final VoidCallback onShutter;
  final VoidCallback onBarcodeToggle;
  final void Function(CameraMode) onModeChange;
  final VoidCallback onMultiAngleDone;
  final VoidCallback onClose;

  const CameraOverlay({
    super.key,
    required this.mode,
    required this.multiAngleMode,
    required this.capturedCount,
    required this.currentItemName,
    required this.pendingCategory,
    required this.liveTranscript,
    required this.voiceBuffer,
    required this.onShutter,
    required this.onBarcodeToggle,
    required this.onModeChange,
    required this.onMultiAngleDone,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Top bar ────────────────────────────────────────────────────
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: onClose,
                  ),
                  const Spacer(),
                  _ModeSelector(current: mode, onChanged: onModeChange),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                    tooltip: 'Scan barcode',
                    onPressed: onBarcodeToggle,
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Item name + category badge ──────────────────────────────────
        if (currentItemName != null || pendingCategory != null)
          Positioned(
            top: 80, left: 16, right: 16,
            child: _InfoBadge(
              name: currentItemName,
              category: pendingCategory,
            ),
          ),

        // ── Multi-angle progress ────────────────────────────────────────
        if (multiAngleMode)
          Positioned(
            top: 130, left: 16, right: 16,
            child: _MultiAngleBar(
                count: capturedCount, onDone: onMultiAngleDone),
          ),

        // ── Voice buffer ────────────────────────────────────────────────
        if (voiceBuffer != null && voiceBuffer!.isNotEmpty)
          Positioned(
            top: 180, left: 32, right: 32,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('"$voiceBuffer"',
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center),
            ),
          ),

        // ── Bottom controls ─────────────────────────────────────────────
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Photo count
                  _CountBadge(count: capturedCount),

                  // Shutter button
                  GestureDetector(
                    onTap: onShutter,
                    child: Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        color: Colors.white.withOpacity(0.2),
                      ),
                      child: const Icon(Icons.camera_alt,
                          color: Colors.white, size: 32),
                    ),
                  ),

                  // Multi-angle done / placeholder
                  multiAngleMode
                      ? IconButton(
                          icon: const Icon(Icons.done_all,
                              color: Colors.white, size: 28),
                          onPressed: onMultiAngleDone,
                          tooltip: 'Done capturing angles',
                        )
                      : const SizedBox(width: 48),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ModeSelector extends StatelessWidget {
  final CameraMode current;
  final void Function(CameraMode) onChanged;
  const _ModeSelector({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _pick(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.settings_suggest, color: Colors.white70, size: 14),
            const SizedBox(width: 4),
            Text(current.displayName,
                style: const TextStyle(color: Colors.white, fontSize: 12)),
            const Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext ctx) async {
    final mode = await showDialog<CameraMode>(
      context: ctx,
      builder: (_) => SimpleDialog(
        title: const Text('Camera mode'),
        children: CameraMode.values
            .map((m) => SimpleDialogOption(
                  child: Text(m.displayName),
                  onPressed: () => Navigator.pop(ctx, m),
                ))
            .toList(),
      ),
    );
    if (mode != null) onChanged(mode);
  }
}

class _InfoBadge extends StatelessWidget {
  final String? name;
  final Category? category;
  const _InfoBadge({this.name, this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (category != null)
            Icon(category!.icon, color: category!.color, size: 16),
          if (category != null) const SizedBox(width: 4),
          if (name != null)
            Flexible(
              child: Text(name!,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  overflow: TextOverflow.ellipsis),
            ),
        ],
      ),
    );
  }
}

class _MultiAngleBar extends StatelessWidget {
  final int count;
  final VoidCallback onDone;
  const _MultiAngleBar({required this.count, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
          color: Colors.black54, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.rotate_right, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text('$count / ${AppConstants.multiAngleMaxPhotos} angles',
              style: const TextStyle(color: Colors.white)),
          const Spacer(),
          TextButton(
            onPressed: onDone,
            child: const Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48, height: 48,
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.photo_library_outlined, color: Colors.white, size: 18),
          Text('$count', style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }
}


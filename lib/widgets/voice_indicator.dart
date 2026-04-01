import 'package:flutter/material.dart';
import '../services/speech_service.dart';

class VoiceIndicator extends StatelessWidget {
  final String transcript;
  final SpeechState speechState;

  const VoiceIndicator({
    super.key,
    required this.transcript,
    required this.speechState,
  });

  @override
  Widget build(BuildContext context) {
    if (speechState == SpeechState.unavailable) return const SizedBox.shrink();
    final listening = speechState == SpeechState.listening;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MicPulse(listening: listening),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              transcript.isNotEmpty ? transcript : (listening ? 'Listening…' : ''),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _MicPulse extends StatefulWidget {
  final bool listening;
  const _MicPulse({required this.listening});

  @override
  State<_MicPulse> createState() => _MicPulseState();
}

class _MicPulseState extends State<_MicPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.85, end: 1.15).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.listening) {
      return const Icon(Icons.mic_off, color: Colors.white54, size: 18);
    }
    return ScaleTransition(
      scale: _scale,
      child: const Icon(Icons.mic, color: Colors.redAccent, size: 18),
    );
  }
}

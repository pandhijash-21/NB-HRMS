import 'package:flutter/material.dart';
import '../services/mr_nb_tour_service.dart';

class MrNbGuideDialog extends StatefulWidget {
  final List<MrNbNarrationStep> steps;
  final VoidCallback? onComplete;

  const MrNbGuideDialog({
    super.key,
    required this.steps,
    this.onComplete,
  });

  static Future<void> show(
    BuildContext context, {
    required List<MrNbNarrationStep> steps,
    VoidCallback? onComplete,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => MrNbGuideDialog(
        steps: steps,
        onComplete: onComplete,
      ),
    );
  }

  @override
  State<MrNbGuideDialog> createState() => _MrNbGuideDialogState();
}

class _MrNbGuideDialogState extends State<MrNbGuideDialog> {
  int _currentIndex = 0;
  final MrNbTourService _tourService = MrNbTourService.instance;

  MrNbNarrationStep get _currentStep => widget.steps[_currentIndex];

  @override
  void initState() {
    super.initState();
    _initAndPlay();
  }

  Future<void> _initAndPlay() async {
    await _tourService.init();
    if (mounted) {
      _tourService.narrateStep(_currentStep);
    }
  }

  void _next() {
    if (_currentIndex < widget.steps.length - 1) {
      setState(() => _currentIndex++);
      _tourService.narrateStep(_currentStep);
    } else {
      _tourService.stop();
      Navigator.of(context).pop();
      widget.onComplete?.call();
    }
  }

  void _back() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _tourService.narrateStep(_currentStep);
    }
  }

  void _skip() {
    _tourService.stop();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _tourService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentIndex == widget.steps.length - 1;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: const Color(0xFF1E1E1E),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Bar: Step count, sound mute toggle, and close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Step ${_currentIndex + 1} of ${widget.steps.length}',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: _tourService.isMuted ? 'Unmute voice' : 'Mute voice',
                        icon: Icon(
                          _tourService.isMuted ? Icons.volume_off : Icons.volume_up,
                          color: Colors.white70,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() => _tourService.toggleMute());
                          if (!_tourService.isMuted) {
                            _tourService.narrateStep(_currentStep);
                          }
                        },
                      ),
                      IconButton(
                        tooltip: 'Skip Tour',
                        icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                        onPressed: _skip,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Mascot Animation Card
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(19),
                  child: Image.asset(
                    _currentStep.expression.assetPath,
                    key: ValueKey(_currentStep.expression.assetPath),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                _currentStep.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // Speech Subtitles / Dialogue
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.chat_bubble_outline, color: Colors.amber, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _currentStep.speechText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Replay voice',
                      icon: const Icon(Icons.replay, color: Colors.white54, size: 16),
                      onPressed: () => _tourService.narrateStep(_currentStep),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  if (_currentIndex > 0)
                    TextButton(
                      onPressed: _back,
                      child: const Text('Back', style: TextStyle(color: Colors.white54)),
                    )
                  else
                    const SizedBox.shrink(),
                  const Spacer(),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _next,
                    child: Text(
                      isLast ? 'Got it, let\'s go!' : 'Next',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/app_config.dart';
import '../../../../core/utils/open_url.dart';
import '../../domain/crm_models.dart';
import '../crm_providers.dart';

/// In-app audio player dialog for CRM telephony recordings.
///
/// Plays audio streams directly inside the application dialog without navigating away
/// or opening external tabs. Supports scrubbing, skip +/-10s, speed cycling,
/// volume/mute, animated equalizer bars, local download, and direct recording URL updating.
class CrmAudioPlayerDialog extends ConsumerStatefulWidget {
  final CrmCallLog log;

  const CrmAudioPlayerDialog({super.key, required this.log});

  static Future<void> show(BuildContext context, CrmCallLog log) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CrmAudioPlayerDialog(log: log),
    );
  }

  @override
  ConsumerState<CrmAudioPlayerDialog> createState() =>
      _CrmAudioPlayerDialogState();
}

class _CrmAudioPlayerDialogState extends ConsumerState<CrmAudioPlayerDialog>
    with SingleTickerProviderStateMixin {
  late final AudioPlayer _player;
  late final AnimationController _waveAnimController;

  StreamSubscription? _playerStateSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _completeSub;

  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  double _playbackRate = 1.0;
  double _volume = 1.0;
  bool _isMuted = false;
  bool _isSeeking = false;
  double _seekingValue = 0.0;

  String _currentRecordingUrl = '';
  String _resolvedUrl = '';

  // URL Editor state
  bool _isEditingUrl = false;
  late final TextEditingController _urlEditController;
  bool _isSavingUrl = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();

    _currentRecordingUrl = widget.log.recordingUrl?.trim() ?? '';
    _urlEditController = TextEditingController(text: _currentRecordingUrl);

    _waveAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    if (widget.log.duration > 0) {
      _duration = Duration(seconds: widget.log.duration);
    }

    _setupSubscriptions();
    _initAndPlayAudio();
  }

  void _setupSubscriptions() {
    _playerStateSub = _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _playerState = state;
        if (state == PlayerState.playing) {
          _isLoading = false;
          if (!_waveAnimController.isAnimating) {
            _waveAnimController.repeat(reverse: true);
          }
        } else {
          if (_waveAnimController.isAnimating) {
            _waveAnimController.stop();
          }
        }
      });
    });

    _durationSub = _player.onDurationChanged.listen((dur) {
      if (!mounted) return;
      if (dur > Duration.zero) {
        setState(() => _duration = dur);
      }
    });

    _positionSub = _player.onPositionChanged.listen((pos) {
      if (!mounted || _isSeeking) return;
      setState(() => _position = pos);
    });

    _completeSub = _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _playerState = PlayerState.completed;
        _position = Duration.zero;
      });
    });
  }

  String _resolveAudioUrl() {
    if (widget.log.id.isNotEmpty) {
      final base = AppConfig.apiBaseUrl;
      return '$base/crm/telephony/recordings/${widget.log.id}/audio';
    }
    return _currentRecordingUrl;
  }

  Future<void> _initAndPlayAudio() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    final targetUrl = _resolveAudioUrl();
    _resolvedUrl = targetUrl;

    if (_currentRecordingUrl.isEmpty && targetUrl.isEmpty) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'No recording audio file URL is linked to this call.';
      });
      return;
    }

    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setPlaybackRate(_playbackRate);
      await _player.setVolume(_isMuted ? 0.0 : _volume);

      await _player.play(UrlSource(targetUrl));

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      // Fallback: try direct URL if available and different
      if (_currentRecordingUrl.isNotEmpty && _currentRecordingUrl != targetUrl) {
        try {
          _resolvedUrl = _currentRecordingUrl;
          await _player.play(UrlSource(_currentRecordingUrl));
          if (mounted) {
            setState(() {
              _isLoading = false;
              _hasError = false;
            });
          }
          return;
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage =
              'Could not load recording from PBX. Check if file exists on server or update URL below.';
        });
      }
    }
  }

  Future<void> _saveNewUrl() async {
    final newUrl = _urlEditController.text.trim();
    if (newUrl.isEmpty) return;

    setState(() => _isSavingUrl = true);
    try {
      await ref.read(crmRepositoryProvider).updateCallLog(
            widget.log.id,
            recordingUrl: newUrl,
          );

      _currentRecordingUrl = newUrl;
      setState(() {
        _isSavingUrl = false;
        _isEditingUrl = false;
      });

      ref.invalidate(crmCallLogsProvider);
      await _initAndPlayAudio();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recording URL updated successfully!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (err) {
      if (mounted) {
        setState(() => _isSavingUrl = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update URL: $err'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _togglePlayPause() async {
    if (_hasError) {
      await _initAndPlayAudio();
      return;
    }

    if (_playerState == PlayerState.playing) {
      await _player.pause();
    } else {
      if (_playerState == PlayerState.completed ||
          (_duration > Duration.zero && _position >= _duration)) {
        await _player.seek(Duration.zero);
      }
      await _player.resume();
    }
  }

  Future<void> _seek(Duration pos) async {
    final clamped = pos < Duration.zero
        ? Duration.zero
        : (_duration > Duration.zero && pos > _duration ? _duration : pos);
    setState(() => _position = clamped);
    await _player.seek(clamped);
  }

  Future<void> _skip(int seconds) async {
    final target = _position + Duration(seconds: seconds);
    await _seek(target);
  }

  void _cycleSpeed() {
    const speeds = [1.0, 1.25, 1.5, 2.0];
    final curr = speeds.indexOf(_playbackRate);
    final next = speeds[(curr + 1) % speeds.length];
    setState(() => _playbackRate = next);
    _player.setPlaybackRate(next);
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _player.setVolume(_isMuted ? 0.0 : _volume);
  }

  void _setVolume(double val) {
    setState(() {
      _volume = val;
      _isMuted = val == 0.0;
    });
    _player.setVolume(val);
  }

  @override
  void dispose() {
    _waveAnimController.dispose();
    _urlEditController.dispose();
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _completeSub?.cancel();
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  String _formatTime(Duration d) {
    final totalSeconds = d.inSeconds;
    final mins = totalSeconds ~/ 60;
    final secs = totalSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final day = local.day.toString().padLeft(2, '0');
    final month = months[local.month - 1];
    final year = local.year;
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    return '$day $month $year, $hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF1E1B18) : Colors.white;
    final cardBg = isDark ? const Color(0xFF282420) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? Colors.white60 : const Color(0xFF64748B);
    const primaryGreen = Color(0xFF16A34A);

    final isPlaying = _playerState == PlayerState.playing;
    final maxMs = math.max(1, _duration.inMilliseconds).toDouble();
    final currentMs = math.min(
      maxMs,
      (_isSeeking ? _seekingValue : _position.inMilliseconds.toDouble())
          .clamp(0.0, maxMs),
    );

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      backgroundColor: bgColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dialog Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryGreen.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.headphones_rounded,
                      color: primaryGreen,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Call Recording Player',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Listening inside NB CRM',
                          style: TextStyle(
                            fontSize: 12,
                            color: primaryGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: textMuted),
                    tooltip: 'Close Player',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Call Metadata Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SelectableText(
                          widget.log.customerNumber ?? 'Customer Call',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                            color: textPrimary,
                          ),
                        ),
                        if (widget.log.leadName != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.log.leadName!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: primaryGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.log.callStatus,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: primaryGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 14,
                      runSpacing: 4,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today_rounded,
                                size: 13, color: textMuted),
                            const SizedBox(width: 5),
                            Text(
                              _formatDate(widget.log.callTime),
                              style: TextStyle(fontSize: 12, color: textMuted),
                            ),
                          ],
                        ),
                        if (widget.log.agentNumber != null &&
                            widget.log.agentNumber!.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_pin_circle_rounded,
                                  size: 14, color: textMuted),
                              const SizedBox(width: 5),
                              Text(
                                'Agent: ${widget.log.agentNumber}',
                                style: TextStyle(fontSize: 12, color: textMuted),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Animated Sound Wave / Equalizer Strip
              Container(
                height: 44,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: AnimatedBuilder(
                  animation: _waveAnimController,
                  builder: (context, _) {
                    return CustomPaint(
                      size: const Size(double.infinity, 44),
                      painter: _SoundWavePainter(
                        progress: _waveAnimController.value,
                        isPlaying: isPlaying,
                        barColor: primaryGreen,
                        inactiveColor: textMuted.withValues(alpha: 0.25),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),

              // Progress Bar (Slider) & Timestamps
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: primaryGreen,
                  inactiveTrackColor: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                  thumbColor: primaryGreen,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: currentMs,
                  min: 0.0,
                  max: maxMs,
                  onChangeStart: (_) => setState(() => _isSeeking = true),
                  onChanged: (val) {
                    setState(() => _seekingValue = val);
                  },
                  onChangeEnd: (val) {
                    _isSeeking = false;
                    _seek(Duration(milliseconds: val.toInt()));
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatTime(_position),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                        color: textMuted,
                      ),
                    ),
                    Text(
                      _formatTime(_duration),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
              ),

              if (_hasError) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: Colors.amber, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage,
                              style: const TextStyle(fontSize: 12, color: Colors.amber),
                            ),
                          ),
                          TextButton(
                            onPressed: _initAndPlayAudio,
                            child: const Text('Retry', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Playback Controls Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Rewind 10 seconds
                  IconButton(
                    icon: const Icon(Icons.replay_10_rounded),
                    iconSize: 28,
                    color: textPrimary,
                    tooltip: 'Rewind 10 seconds',
                    onPressed: () => _skip(-10),
                  ),
                  const SizedBox(width: 14),

                  // Main Play/Pause Button
                  GestureDetector(
                    onTap: _togglePlayPause,
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: primaryGreen,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? Colors.white24 : Colors.black12,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 34,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Forward 10 seconds
                  IconButton(
                    icon: const Icon(Icons.forward_10_rounded),
                    iconSize: 28,
                    color: textPrimary,
                    tooltip: 'Forward 10 seconds',
                    onPressed: () => _skip(10),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Inline Recording URL Editor / Attachment
              if (_isEditingUrl) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Attach Greeter Recording URL',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _urlEditController,
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                        decoration: InputDecoration(
                          hintText: 'https://greeter.co.in/recordings/... or audio file link',
                          hintStyle: TextStyle(fontSize: 11, color: textMuted),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => setState(() => _isEditingUrl = false),
                            child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                          ),
                          const SizedBox(width: 6),
                          ElevatedButton(
                            onPressed: _isSavingUrl ? null : _saveNewUrl,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            child: _isSavingUrl
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Save & Play Audio', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Utility Footer: Speed, Volume, Edit URL, Download & Copy Link
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    // Playback Speed Button
                    InkWell(
                      onTap: _cycleSpeed,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.black12,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_playbackRate}x',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Mute / Unmute
                    IconButton(
                      icon: Icon(
                        _isMuted || _volume == 0
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                        size: 20,
                        color: textMuted,
                      ),
                      tooltip: _isMuted ? 'Unmute' : 'Mute',
                      onPressed: _toggleMute,
                    ),

                    // Mini Volume Slider
                    SizedBox(
                      width: 60,
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 4),
                          overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 8),
                          activeTrackColor: textMuted,
                          inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
                          thumbColor: textMuted,
                        ),
                        child: Slider(
                          value: _isMuted ? 0.0 : _volume,
                          min: 0.0,
                          max: 1.0,
                          onChanged: _setVolume,
                        ),
                      ),
                    ),
                    const Spacer(),

                    // Edit / Attach Audio URL Button
                    IconButton(
                      icon: Icon(Icons.link_rounded, size: 20, color: textMuted),
                      tooltip: 'Edit / Attach Recording Link',
                      onPressed: () {
                        setState(() {
                          _isEditingUrl = !_isEditingUrl;
                        });
                      },
                    ),

                    // Copy Link Button
                    IconButton(
                      icon: Icon(Icons.copy_rounded, size: 17, color: textMuted),
                      tooltip: 'Copy Audio URL',
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: _currentRecordingUrl.isNotEmpty ? _currentRecordingUrl : _resolvedUrl));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Audio URL copied to clipboard!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),

                    // Download Button
                    IconButton(
                      icon: Icon(Icons.download_rounded,
                          size: 19, color: textMuted),
                      tooltip: 'Download Recording File',
                      onPressed: () {
                        final downloadUrlStr = _currentRecordingUrl.isNotEmpty
                            ? _currentRecordingUrl
                            : _resolvedUrl;
                        if (downloadUrlStr.isNotEmpty) {
                          downloadUrl(
                            downloadUrlStr,
                            'recording_${widget.log.customerNumber ?? 'call'}.mp3',
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Canvas painter for audio equalizer bars.
///
/// Uses line drawing with round caps to avoid degenerate rounded rectangle
/// geometry and prevent WebGL shader compilation issues on CanvasKit/Skia.
class _SoundWavePainter extends CustomPainter {
  final double progress;
  final bool isPlaying;
  final Color barColor;
  final Color inactiveColor;

  _SoundWavePainter({
    required this.progress,
    required this.isPlaying,
    required this.barColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const count = 28;
    final spacing = size.width / (count + 1);
    final centerY = size.height / 2;

    for (int i = 0; i < count; i++) {
      final x = spacing * (i + 1);
      final heightFactor = isPlaying
          ? (math.sin(progress * 2 * math.pi + (i * 0.45)).abs() * 0.75 + 0.15)
          : 0.12;
      final halfH = (size.height * heightFactor) / 2;

      paint.color = isPlaying ? barColor : inactiveColor;
      canvas.drawLine(
        Offset(x, centerY - halfH),
        Offset(x, centerY + halfH),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SoundWavePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.barColor != barColor;
  }
}

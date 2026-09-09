import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../core/widgets/hold_mic_button.dart';
import '../../providers/player_provider.dart';
import '../../providers/theme_provider.dart';

class VoiceSearchSheet extends StatefulWidget {
  const VoiceSearchSheet({Key? key}) : super(key: key);

  static Future<String?> show(BuildContext context) {
    return showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Voice search',
      barrierColor: Colors.black.withOpacity(0.78),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (ctx, _, __) => const VoiceSearchSheet(),
    );
  }

  @override
  State<VoiceSearchSheet> createState() => _VoiceSearchSheetState();
}

class _VoiceSearchSheetState extends State<VoiceSearchSheet> {
  final SpeechToText _speech = SpeechToText();
  String _heard = '';
  String _status = 'Listening...';
  bool _listening = false;
  bool _failed = false;
  bool _busy = false;
  double _level = 0.25;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _speech.stop();
    _speech.cancel();
    super.dispose();
  }

  Future<void> _hushPlayer() async {
    try {
      final player = context.read<PlayerProvider>();
      if (player.isPlaying) await player.togglePlayPause();
    } catch (_) {}
  }

  Future<String?> _pickLocale() async {
    try {
      final locales = await _speech.locales();
      String? hi;
      String? enIn;
      for (final locale in locales) {
        final id = locale.localeId.toLowerCase().replaceAll('-', '_');
        if (id == 'hi_in' || id.startsWith('hi_')) hi ??= locale.localeId;
        if (id == 'en_in') enIn ??= locale.localeId;
      }
      return hi ?? enIn;
    } catch (_) {
      return 'hi_IN';
    }
  }

  Future<void> _start() async {
    if (_busy) return;
    _busy = true;
    setState(() {
      _failed = false;
      _heard = '';
      _status = 'Listening...';
      _listening = false;
      _level = 0.25;
    });

    final mic = await Permission.microphone.request();
    if (!mounted) return;
    if (!mic.isGranted) {
      _busy = false;
      setState(() {
        _failed = true;
        _status = mic.isPermanentlyDenied
            ? 'Microphone permission is off. Open Settings to allow it.'
            : 'Allow microphone to search by voice.';
      });
      return;
    }

    await _hushPlayer();
    if (!mounted) return;

    final ok = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          _finishIfHeard();
        }
      },
      onError: (error) {
        if (!mounted) return;
        final id = error.errorMsg;
        if (id == 'error_no_match' ||
            id == 'error_speech_timeout' ||
            id == 'error_none') {
          setState(() {
            _listening = false;
            _failed = true;
            _status = "Didn't catch that. Try again";
          });
          _busy = false;
          return;
        }
        setState(() {
          _listening = false;
          _failed = true;
          _status = id == 'error_network'
              ? 'No internet. Voice search needs Google speech.'
              : "Didn't catch that. Try again";
        });
        _busy = false;
      },
    );
    if (!mounted) return;
    if (!ok) {
      _busy = false;
      setState(() {
        _failed = true;
        _status = 'Google voice search is not available on this phone.';
      });
      return;
    }

    final localeId = await _pickLocale();
    if (!mounted) return;

    setState(() {
      _listening = true;
      _status = 'Listening...';
    });

    try {
      await _speech.listen(
        localeId: localeId,
        onResult: (result) {
          if (!mounted) return;
          setState(() => _heard = result.recognizedWords);
          if (result.finalResult) _finishIfHeard();
        },
        onSoundLevelChange: (level) {
          if (!mounted || !_listening) return;
          setState(() => _level = ((level + 8) / 18).clamp(0.22, 1.0));
        },
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.search,
          partialResults: true,
          cancelOnError: false,
          listenFor: const Duration(seconds: 8),
          pauseFor: const Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _listening = false;
        _failed = true;
        _status = "Didn't catch that. Try again";
      });
    }
    _busy = false;
  }

  void _finishIfHeard() {
    if (!mounted) return;
    final phrase = _heard.trim();
    if (phrase.isEmpty) {
      if (_listening || !_failed) {
        setState(() {
          _listening = false;
          _failed = true;
          _status = "Didn't catch that. Try again";
        });
      }
      return;
    }
    _listening = false;
    Navigator.of(context).pop(phrase);
  }

  void _onMicTap() {
    if (_listening) {
      _speech.stop();
      _finishIfHeard();
      return;
    }
    _start();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>().theme;
    final ring = 72.0 + 28.0 * _level;

    return Material(
      color: t.background,
      child: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: Icon(Icons.close, color: t.textPrimary, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const Spacer(flex: 2),
            Text(
              _status,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: t.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_heard.isNotEmpty) ...[
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  _heard,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: t.accent,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const Spacer(flex: 3),
            if (_listening)
              GestureDetector(
                onTap: _onMicTap,
                child: SizedBox(
                  width: 140,
                  height: 140,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 80),
                      width: ring,
                      height: ring,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: t.accent.withOpacity(0.16),
                      ),
                      child: Center(
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: t.accent,
                          ),
                          child: Icon(
                            Icons.mic,
                            color: t.background,
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              HoldMicButton(
                idleColor: _failed ? t.textSecondary : t.accent,
                holdColor: t.accent,
                onArmed: _start,
                builder: (color, progress) {
                  return SizedBox(
                    width: 140,
                    height: 140,
                    child: Center(
                      child: Container(
                        width: 72 + 28 * progress,
                        height: 72 + 28 * progress,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withOpacity(0.16 + 0.24 * progress),
                        ),
                        child: Center(
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color,
                            ),
                            child: Icon(
                              _failed ? Icons.mic_off : Icons.mic,
                              color: t.background,
                              size: 36,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 12),
            Text(
              _listening
                  ? 'Tap the mic when you are done'
                  : 'Hold the mic for 2 seconds',
              style: TextStyle(color: t.textSecondary, fontSize: 13),
            ),
            if (_failed &&
                _status.contains('Settings'))
              TextButton(
                onPressed: () => openAppSettings(),
                child: Text('Open Settings', style: TextStyle(color: t.accent)),
              ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }
}
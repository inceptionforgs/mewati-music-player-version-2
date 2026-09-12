import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../providers/player_provider.dart';
import '../../providers/theme_provider.dart';

class VoiceSearchSheet extends StatefulWidget {
  const VoiceSearchSheet({Key? key}) : super(key: key);

  static Future<String?> show(BuildContext context) {
    return showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Voice search',
      barrierColor: Colors.black.withOpacity(0.82),
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
  bool _closing = false;
  double _level = 0.28;
  Timer? _settle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _settle?.cancel();
    if (_speech.isListening) {
      _speech.stop();
    }
    super.dispose();
  }

  Future<void> _hushPlayer() async {
    try {
      final player = context.read<PlayerProvider>();
      if (player.isPlaying) await player.togglePlayPause();
    } catch (_) {}
  }

  void _fail(String message) {
    if (!mounted || _closing) return;
    _busy = false;
    _listening = false;
    setState(() {
      _failed = true;
      _status = message;
    });
  }

  void _popWith(String phrase) {
    final q = phrase.trim();
    if (!mounted || _closing || q.isEmpty) return;
    _closing = true;
    _listening = false;
    _busy = false;
    Navigator.of(context).pop(q);
  }

  void _maybeFinish({required bool forceFail}) {
    if (!mounted || _closing) return;
    final phrase = _heard.trim();
    if (phrase.isNotEmpty) {
      _popWith(phrase);
      return;
    }
    if (forceFail) {
      _fail("Didn't catch that. Tap the mic and try again.");
    }
  }

  void _onStatus(String status) {
    if (!mounted || _closing) return;
    final done = status == 'done' || status == 'notListening';
    if (!done) return;
    _listening = false;
    _settle?.cancel();
    _settle = Timer(const Duration(milliseconds: 350), () {
      _maybeFinish(forceFail: true);
    });
  }

  void _onError(dynamic error) {
    if (!mounted || _closing) return;
    final id = error.errorMsg?.toString() ?? '';
    if (id == 'error_no_match' ||
        id == 'error_speech_timeout' ||
        id == 'error_none') {
      _settle?.cancel();
      _settle = Timer(const Duration(milliseconds: 350), () {
        _maybeFinish(forceFail: true);
      });
      return;
    }
    if (id == 'error_network' || id == 'error_network_timeout') {
      _fail('Voice search needs internet. Check your connection.');
      return;
    }
    if (id == 'error_permission' || id == 'error_audio') {
      _fail('Microphone is blocked. Allow it in Settings.');
      return;
    }
    _fail("Didn't catch that. Tap the mic and try again.");
  }

  Future<void> _start() async {
    if (_busy || _closing) return;
    _busy = true;
    _settle?.cancel();
    setState(() {
      _failed = false;
      _heard = '';
      _status = 'Listening...';
      _listening = false;
      _level = 0.28;
    });

    final mic = await Permission.microphone.request();
    if (!mounted) return;
    if (!mic.isGranted) {
      _fail(
        mic.isPermanentlyDenied
            ? 'Microphone permission is off. Open Settings to allow it.'
            : 'Allow the microphone to search by voice.',
      );
      return;
    }

    await _hushPlayer();
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    final ok = await _speech.initialize(
      onStatus: _onStatus,
      onError: _onError,
    );
    if (!mounted) return;
    if (!ok) {
      _fail('Voice search is not available on this phone.');
      return;
    }

    if (_speech.isListening) {
      await _speech.stop();
    }

    setState(() {
      _listening = true;
      _status = 'Listening...';
    });

    try {
      await _speech.listen(
        onResult: (result) {
          if (!mounted || _closing) return;
          final words = result.recognizedWords.trim();
          setState(() {
            _heard = words;
            if (words.isNotEmpty) _status = words;
          });
          if (result.finalResult && words.isNotEmpty) {
            _popWith(words);
          }
        },
        onSoundLevelChange: (level) {
          if (!mounted || !_listening) return;
          setState(() => _level = ((level + 8) / 18).clamp(0.22, 1.0));
        },
        listenFor: const Duration(seconds: 12),
        pauseFor: const Duration(seconds: 2),
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.search,
      );
    } catch (_) {
      if (!mounted) return;
      try {
        await _speech.listen(
          onResult: (result) {
            if (!mounted || _closing) return;
            final words = result.recognizedWords.trim();
            setState(() {
              _heard = words;
              if (words.isNotEmpty) _status = words;
            });
            if (result.finalResult && words.isNotEmpty) {
              _popWith(words);
            }
          },
          listenFor: const Duration(seconds: 12),
          pauseFor: const Duration(seconds: 2),
          partialResults: true,
        );
      } catch (_) {
        _fail("Didn't catch that. Tap the mic and try again.");
        return;
      }
    }
    _busy = false;
  }

  void _onMicTap() {
    if (_listening) {
      _speech.stop();
      _maybeFinish(forceFail: true);
      return;
    }
    _start();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>().theme;
    final ring = 78.0 + 34.0 * _level;

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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                _failed ? _status : (_heard.isEmpty ? 'Listening...' : _heard),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ),
            const Spacer(flex: 3),
            GestureDetector(
              onTap: _onMicTap,
              child: SizedBox(
                width: 160,
                height: 160,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 70),
                    width: _listening ? ring : 104,
                    height: _listening ? ring : 104,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (_failed ? t.textSecondary : t.accent)
                          .withOpacity(0.16),
                    ),
                    child: Center(
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _failed ? t.textSecondary : t.accent,
                        ),
                        child: Icon(
                          _failed && !_listening ? Icons.mic_off : Icons.mic,
                          color: t.background,
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _listening ? 'Speak now' : 'Tap the mic to try again',
              style: TextStyle(color: t.textSecondary, fontSize: 14),
            ),
            if (_failed && _status.contains('Settings'))
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
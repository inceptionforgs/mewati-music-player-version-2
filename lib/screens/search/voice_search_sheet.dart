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
  bool _inited = false;
  bool _closing = false;
  double _level = 0.25;
  Timer? _settle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _settle?.cancel();
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
      if (locales.isEmpty) return null;
      String? hi;
      String? enIn;
      for (final locale in locales) {
        final id = locale.localeId.toLowerCase().replaceAll('-', '_');
        if (id == 'hi_in' || id.startsWith('hi_')) hi ??= locale.localeId;
        if (id == 'en_in') enIn ??= locale.localeId;
      }
      return hi ?? enIn;
    } catch (_) {
      return null;
    }
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
    if (!mounted || _closing) return;
    _closing = true;
    _listening = false;
    _busy = false;
    Navigator.of(context).pop(phrase);
  }

  void _onStatus(String status) {
    if (!mounted || _closing) return;
    if (status != 'done' && status != 'notListening') return;
    _listening = false;
    final phrase = _heard.trim();
    if (phrase.isNotEmpty) {
      _popWith(phrase);
      return;
    }
    _settle?.cancel();
    _settle = Timer(const Duration(milliseconds: 400), () {
      if (!mounted || _closing) return;
      final late = _heard.trim();
      if (late.isNotEmpty) {
        _popWith(late);
      } else {
        _fail("Didn't catch that. Try again");
      }
    });
  }

  void _onError(dynamic error) {
    if (!mounted || _closing) return;
    final id = error.errorMsg?.toString() ?? '';
    if (id == 'error_no_match' ||
        id == 'error_speech_timeout' ||
        id == 'error_none') {
      _settle?.cancel();
      _settle = Timer(const Duration(milliseconds: 400), () {
        if (!mounted || _closing) return;
        final late = _heard.trim();
        if (late.isNotEmpty) {
          _popWith(late);
        } else {
          _fail("Didn't catch that. Try again");
        }
      });
      return;
    }
    _fail(
      id == 'error_network'
          ? 'No internet. Voice search needs Google speech.'
          : "Didn't catch that. Try again",
    );
  }

  Future<void> _start() async {
    if (_busy || _listening || _closing) return;
    _busy = true;
    _settle?.cancel();
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
      _fail(
        mic.isPermanentlyDenied
            ? 'Microphone permission is off. Open Settings to allow it.'
            : 'Allow microphone to search by voice.',
      );
      return;
    }

    await _hushPlayer();
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;

    if (!_inited || !_speech.isAvailable) {
      final ok = await _speech.initialize(
        onStatus: _onStatus,
        onError: _onError,
      );
      if (!mounted) return;
      _inited = ok;
      if (!ok) {
        _fail('Google voice search is not available on this phone.');
        return;
      }
    }

    if (_speech.isListening) {
      await _speech.stop();
    }

    final localeId = await _pickLocale();
    if (!mounted) return;

    setState(() {
      _listening = true;
      _status = 'Listening...';
    });

    Future<void> startListen({String? locale}) {
      return _speech.listen(
        localeId: locale,
        onResult: (result) {
          if (!mounted || _closing) return;
          setState(() => _heard = result.recognizedWords);
          if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
            _popWith(result.recognizedWords.trim());
          }
        },
        onSoundLevelChange: (level) {
          if (!mounted || !_listening) return;
          setState(() => _level = ((level + 8) / 18).clamp(0.22, 1.0));
        },
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 4),
        ),
      );
    }

    try {
      await startListen(locale: localeId);
    } catch (_) {
      if (!mounted) return;
      try {
        await startListen();
      } catch (_) {
        _fail("Didn't catch that. Try again");
        return;
      }
    }
    _busy = false;
  }

  void _onMicTap() {
    if (_listening) {
      _speech.stop();
      final phrase = _heard.trim();
      if (phrase.isNotEmpty) {
        _popWith(phrase);
      } else {
        _fail("Didn't catch that. Try again");
      }
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
            GestureDetector(
              onTap: _onMicTap,
              child: SizedBox(
                width: 140,
                height: 140,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 80),
                    width: _listening ? ring : 100,
                    height: _listening ? ring : 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (_failed ? t.textSecondary : t.accent)
                          .withOpacity(0.16),
                    ),
                    child: Center(
                      child: Container(
                        width: 72,
                        height: 72,
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
            const SizedBox(height: 12),
            Text(
              _listening
                  ? 'Tap the mic when you are done'
                  : 'Tap the mic to try again',
              style: TextStyle(color: t.textSecondary, fontSize: 13),
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
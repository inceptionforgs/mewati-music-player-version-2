import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../providers/theme_provider.dart';

class VoiceSearchSheet extends StatefulWidget {
  const VoiceSearchSheet({Key? key}) : super(key: key);

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const VoiceSearchSheet(),
    );
  }

  @override
  State<VoiceSearchSheet> createState() => _VoiceSearchSheetState();
}

class _VoiceSearchSheetState extends State<VoiceSearchSheet> {
  final SpeechToText _speech = SpeechToText();
  String _heard = '';
  String _status = 'Mic khul raha hai…';
  bool _listening = false;
  bool _failed = false;

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

  Future<void> _start() async {
    final mic = await Permission.microphone.request();
    if (!mounted) return;
    if (!mic.isGranted) {
      setState(() {
        _failed = true;
        _status = 'Mic ki ijazat chahiye. Settings se on karo.';
      });
      return;
    }

    final ok = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          _finishIfHeard();
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _listening = false;
          _failed = true;
          _status = 'Samajh nahi aaya. Phir se bolo.';
        });
      },
    );
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _failed = true;
        _status = 'Is phone pe Google speech nahi mili.';
      });
      return;
    }

    String? localeId;
    try {
      final locales = await _speech.locales();
      for (final locale in locales) {
        final id = locale.localeId.toLowerCase();
        if (id == 'hi_in' || id.startsWith('hi')) {
          localeId = locale.localeId;
          break;
        }
      }
    } catch (_) {}

    setState(() {
      _listening = true;
      _status = 'Gaane ka naam bolo';
    });

    await _speech.listen(
      localeId: localeId,
      listenFor: const Duration(seconds: 12),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      cancelOnError: true,
      listenMode: ListenMode.confirmation,
      onResult: (result) {
        if (!mounted) return;
        setState(() => _heard = result.recognizedWords);
        if (result.finalResult) {
          _finishIfHeard();
        }
      },
    );
  }

  void _finishIfHeard() {
    if (!mounted) return;
    final phrase = _heard.trim();
    if (phrase.isEmpty) {
      if (_listening) {
        setState(() {
          _listening = false;
          _failed = true;
          _status = 'Kuch suna nahi. Phir se try karo.';
        });
      }
      return;
    }
    Navigator.of(context).pop(phrase);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>().theme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: t.accent.withOpacity(0.45)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _failed ? Icons.mic_off : Icons.mic,
                size: 56,
                color: _failed ? t.textSecondary : t.accent,
              ),
              const SizedBox(height: 12),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (_heard.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  _heard,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: t.accent,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Band karo',
                  style: TextStyle(color: t.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
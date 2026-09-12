import 'package:flutter/services.dart';

class ShutterSound {
  static const _ch = MethodChannel('mewati.sound/volume');

  static Future<void> play() async {
    try {
      await _ch.invokeMethod('playShutter');
    } catch (_) {
      SystemSound.play(SystemSoundType.click);
    }
  }
}
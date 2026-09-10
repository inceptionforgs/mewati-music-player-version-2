import 'package:flutter/services.dart';

class SystemVolume {
  static const _ch = MethodChannel('mewati.sound/volume');
  static const _ev = EventChannel('mewati.sound/volumeEvents');

  static Future<double> get() async {
    try {
      final v = await _ch.invokeMethod<num>('get');
      return (v?.toDouble() ?? 1.0).clamp(0.0, 1.0);
    } catch (_) {
      return 1.0;
    }
  }

  static Future<double> set(double value) async {
    try {
      final v = await _ch.invokeMethod<num>('set', value.clamp(0.0, 1.0));
      return (v?.toDouble() ?? value).clamp(0.0, 1.0);
    } catch (_) {
      return value.clamp(0.0, 1.0);
    }
  }

  static Future<int> maxSteps() async {
    try {
      final n = await _ch.invokeMethod<num>('max');
      return (n?.toInt() ?? 15).clamp(1, 50);
    } catch (_) {
      return 15;
    }
  }

  static Future<bool> isLocked() async {
    try {
      return await _ch.invokeMethod<bool>('locked') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Stream<double> get changes =>
      _ev.receiveBroadcastStream().map((e) => (e as num).toDouble().clamp(0.0, 1.0));
}
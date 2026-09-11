import 'package:flutter/services.dart';

class SystemVolumeEvent {
  final double value;
  final bool fromApp;

  const SystemVolumeEvent(this.value, {required this.fromApp});
}

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

  /// [silent] true = no Android volume banner.
  /// Hardware volume keys still show the OEM banner. That is the OS.
  static Future<double> set(double value, {bool silent = true}) async {
    try {
      final v = await _ch.invokeMethod<num>('set', {
        'value': value.clamp(0.0, 1.0),
        'silent': silent,
      });
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

  static Future<bool> isHeadsetOrBluetooth() async {
    try {
      return await _ch.invokeMethod<bool>('headset') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Stream<SystemVolumeEvent> get changes =>
      _ev.receiveBroadcastStream().map((e) {
        if (e is Map) {
          final v = (e['value'] as num?)?.toDouble() ?? 1.0;
          return SystemVolumeEvent(
            v.clamp(0.0, 1.0),
            fromApp: e['fromApp'] == true,
          );
        }
        return SystemVolumeEvent(
          (e as num).toDouble().clamp(0.0, 1.0),
          fromApp: false,
        );
      });
}
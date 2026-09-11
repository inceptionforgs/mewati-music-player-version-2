import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'eq_presets.dart';
import 'sound_policy.dart';
import 'system_volume.dart';

class EqualizerService {
  static final EqualizerService _instance = EqualizerService._internal();
  factory EqualizerService() => _instance;
  EqualizerService._internal();

  static const _channel = MethodChannel('mewati.sound/dsp');
  static const presetPrefsKey = 'mtp-eq-preset-v1';
  static const _legacyPresetKey = 'eq_preset';
  static const _customEqBandsKey = 'custom_eq_band_gains';
  static const _customEqBassKey = 'custom_eq_bass_boost';
  static const defaultPresetId = 'normal';

  bool _isInitialized = false;
  bool _dspAlive = false;
  bool get isSupported => SoundPolicy.isSoftwareEngine;
  bool get dspAlive => _dspAlive;

  List<dynamic> get androidAudioEffects => const [];

  static const double maxBassBoostDb = EqPresets.maxBassBoostDb;

  Timer? _persistDebounce;
  List<double>? _pendingBands;
  double? _pendingBass;
  String _activeId = defaultPresetId;
  double _vol = 1.0;
  double _intentVol = 1.0;
  bool _writingVol = false;
  double _writeTarget = -1;
  double _volStep = 1.0 / 15.0;
  bool _fg = true;
  StreamSubscription<double>? _volSub;
  Timer? _volDebounce;
  AppLifecycleListener? _life;

  /// Hardware volume just before Bass/Beats first raised STREAM_MUSIC.
  double? _volumeBeforeBoost;

  static const _loudIds = {'mewati-bass'};
  static const _streamBoostIds = {'mewati-bass', 'beats'};
  static const _bassScaleIds = <String>{};

  static double bassScaleForVolume(double vol) =>
      (1.65 - 1.5 * vol.clamp(0.0, 1.0)).clamp(0.35, 1.50);

  static double loudnessBoostPctOriginal(double vol) {
    const pts = <List<double>>[
      [0.00, 1.00],
      [0.01, 1.00],
      [0.10, 0.60],
      [0.20, 0.60],
      [0.30, 0.50],
      [0.40, 0.40],
      [0.50, 0.35],
      [0.60, 0.30],
      [0.70, 0.25],
      [0.80, 0.20],
      [0.90, 0.15],
      [1.00, 0.10],
    ];
    return _lerpPts(pts, vol, 0.10);
  }

  static double loudnessBoostPctFor(String id, double vol) {
    if (id == 'mewati-bass' || id == 'beats') {
      return loudnessBoostPctOriginal(vol);
    }
    return 0.0;
  }

  static double _lerpPts(List<List<double>> pts, double vol, double fallback) {
    final v = vol.clamp(0.0, 1.0);
    for (var i = 1; i < pts.length; i++) {
      if (v <= pts[i][0]) {
        final t = (v - pts[i - 1][0]) / (pts[i][0] - pts[i - 1][0]);
        return pts[i - 1][1] + t * (pts[i][1] - pts[i - 1][1]);
      }
    }
    return fallback;
  }

  static double loudnessMakeupDbFor(String id, double vol) {
    final lin = 1.0 + loudnessBoostPctFor(id, vol);
    if (lin <= 1.0) return 0.0;
    return 20.0 * math.log(lin) / math.ln10;
  }

  static double invertLoudnessNet(String id, double net) {
    final n = net.clamp(0.0, 1.0);
    if (loudnessBoostPctFor(id, 0.5) <= 0) return n;
    var lo = 0.0;
    var hi = 1.0;
    for (var i = 0; i < 18; i++) {
      final mid = (lo + hi) / 2;
      final pred = (mid * (1.0 + loudnessBoostPctFor(id, mid))).clamp(0.0, 1.0);
      if (pred < n) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return ((lo + hi) / 2).clamp(0.0, 1.0);
  }

  bool get _mayWriteStream => _fg;

  Future<void> init() async {
    if (_isInitialized) return;
    if (!SoundPolicy.isSoftwareEngine) {
      _isInitialized = true;
      _dspAlive = false;
      return;
    }
    try {
      final ok = await _channel.invokeMethod<bool>('init') ?? false;
      _dspAlive = ok;
    } on MissingPluginException {
      _dspAlive = false;
    } catch (e) {
      _dspAlive = false;
      if (kDebugMode) debugPrint('EqualizerService init dry: $e');
    }
    _isInitialized = true;
    _volSub?.cancel();
    var saved = defaultPresetId;
    try {
      final prefs = await SharedPreferences.getInstance();
      saved = prefs.getString(presetPrefsKey) ??
          prefs.getString(_legacyPresetKey) ??
          defaultPresetId;
      if (prefs.getString(presetPrefsKey) == null) {
        await prefs.setString(presetPrefsKey, saved);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('EqualizerService prefs dry: $e');
    }
    try {
      _vol = await SystemVolume.get();
      final steps = await SystemVolume.maxSteps();
      _volStep = 1.0 / steps;
      _intentVol = _streamBoostIds.contains(saved)
          ? invertLoudnessNet(saved, _vol)
          : _vol;
      if (_streamBoostIds.contains(saved)) {
        _volumeBeforeBoost = _intentVol;
      }
    } catch (_) {
      _vol = 1.0;
      _intentVol = 1.0;
    }
    _volSub = SystemVolume.changes.listen((v) {
      if (_writingVol) {
        _vol = v;
        if (_writeTarget >= 0 && (v - _writeTarget).abs() <= _volStep * 0.8) {
          _writingVol = false;
        }
        return;
      }
      unawaited(_onHardwareVolume(v));
    });
    try {
      await applyPreset(saved);
    } catch (e) {
      if (kDebugMode) debugPrint('EqualizerService apply saved dry: $e');
    }
    _life?.dispose();
    _life = AppLifecycleListener(
      onStateChange: (state) {
        _fg = state == AppLifecycleState.resumed;
      },
      onResume: () {
        unawaited(_syncFromHardwareThenDsp());
      },
    );
  }

  Future<void> _onHardwareVolume(double v) async {
    final locked = await SystemVolume.isLocked();
    final prev = _vol;
    _vol = v;

    if (_streamBoostIds.contains(_activeId)) {
      final stepish = (v - prev).abs() <= _volStep * 1.8;
      if (_fg && !locked && stepish) {
        if (v + 0.008 < prev) {
          _intentVol = (_intentVol - _volStep).clamp(0.0, 1.0);
        } else if (v > prev + 0.008) {
          _intentVol = (_intentVol + _volStep).clamp(0.0, 1.0);
        } else {
          return;
        }
      } else {
        _intentVol = invertLoudnessNet(_activeId, v);
      }
      _volumeBeforeBoost = _intentVol;
    } else {
      _intentVol = v;
    }

    if (!_loudIds.contains(_activeId) &&
        !_streamBoostIds.contains(_activeId) &&
        !_bassScaleIds.contains(_activeId)) {
      return;
    }
    final writeStream = _fg && !locked && _streamBoostIds.contains(_activeId);
    _volDebounce?.cancel();
    _volDebounce = Timer(const Duration(milliseconds: 80), () {
      unawaited(_pushNative(
        EqPresets.byId(_activeId),
        writeStream: writeStream,
      ));
    });
  }

  Future<void> _syncFromHardwareThenDsp() async {
    try {
      _vol = await SystemVolume.get();
      if (_streamBoostIds.contains(_activeId)) {
        _intentVol = invertLoudnessNet(_activeId, _vol);
        _volumeBeforeBoost = _intentVol;
      } else {
        _intentVol = _vol;
      }
    } catch (_) {}
    await _reassertEngine();
  }

  Future<void> _reassertEngine() async {
    if (!SoundPolicy.isSoftwareEngine) return;
    try {
      final ok = await _channel.invokeMethod<bool>('init') ?? false;
      _dspAlive = ok;
    } on MissingPluginException {
      _dspAlive = false;
      return;
    } catch (_) {}
    if (_activeId == 'custom') {
      await _applyPersistedCustomEq();
    } else {
      await _pushNative(
        EqPresets.byId(_activeId),
        writeStream: _streamBoostIds.contains(_activeId),
      );
    }
  }

  void _enterBoostFloor() {
    _volumeBeforeBoost ??= _intentVol;
  }

  Future<void> _leaveBoostFloor({required bool writeStream}) async {
    final saved = _volumeBeforeBoost;
    if (saved == null) return;
    _volumeBeforeBoost = null;
    _intentVol = saved;
    if (!writeStream || !_mayWriteStream) return;
    if ((saved - _vol).abs() <= 0.005) return;
    _writingVol = true;
    _writeTarget = saved;
    unawaited(SystemVolume.set(saved).whenComplete(() {
      Future<void>.delayed(const Duration(milliseconds: 800), () {
        _writingVol = false;
      });
    }));
  }

  Future<void> applyPreset(String preset) async {
    try {
      if (!_isInitialized) await init();
      if (preset == 'custom') {
        final leavingBoost = _streamBoostIds.contains(_activeId);
        _activeId = 'custom';
        if (leavingBoost) {
          await _leaveBoostFloor(writeStream: true);
        }
        await _applyPersistedCustomEq();
        await _savePresetId('custom');
        return;
      }
      final p = EqPresets.byId(preset);
      final wasBoost = _streamBoostIds.contains(_activeId);
      final nowBoost = _streamBoostIds.contains(p.id);
      _activeId = p.id;
      if (nowBoost) {
        _enterBoostFloor();
      } else if (wasBoost) {
        await _leaveBoostFloor(writeStream: true);
      }
      await _pushNative(p);
      await _savePresetId(p.id);
    } catch (e) {
      if (kDebugMode) debugPrint('EqualizerService applyPreset: $e');
    }
  }

  Future<bool> shouldHintHeadphones(String id) async {
    if (!EqPresets.headphoneHintIds.contains(id)) return false;
    if (await SystemVolume.isHeadsetOrBluetooth()) return false;
    return true;
  }

  Future<void> applyCustomSnapshot({
    required List<double> bandGains,
    required double bassBoostDb,
  }) async {
    try {
      final gains = [
        for (final g in bandGains) g.clamp(EqPresets.minDb, EqPresets.maxDb)
      ];
      final bass = bassBoostDb.clamp(0.0, maxBassBoostDb);
      _schedulePersist(gains, bass);
      await _pushCustom(gains, bass);
    } catch (e) {
      if (kDebugMode) debugPrint('EqualizerService applyCustomSnapshot: $e');
    }
  }

  Future<void> setBandGain(int bandIndex, double gainDb) async {
    try {
      final saved = await loadPersistedCustomEq(bandCount: EqPresets.uiBandsHz.length);
      final gains = List<double>.from(saved.bandGains);
      if (bandIndex < 0 || bandIndex >= gains.length) return;
      gains[bandIndex] = gainDb.clamp(EqPresets.minDb, EqPresets.maxDb);
      _schedulePersist(gains, saved.bassBoostDb);
      await _pushCustom(gains, saved.bassBoostDb);
    } catch (e) {
      if (kDebugMode) debugPrint('EqualizerService setBandGain: $e');
    }
  }

  Future<void> setBassBoost(double gainDb) async {
    try {
      final saved = await loadPersistedCustomEq(bandCount: EqPresets.uiBandsHz.length);
      final bass = gainDb.clamp(0.0, maxBassBoostDb);
      _schedulePersist(saved.bandGains, bass);
      await _pushCustom(saved.bandGains, bass);
    } catch (e) {
      if (kDebugMode) debugPrint('EqualizerService setBassBoost: $e');
    }
  }

  void _schedulePersist(List<double> bandGains, double bassBoostDb) {
    _pendingBands = List<double>.from(bandGains);
    _pendingBass = bassBoostDb;
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 280), () {
      final g = _pendingBands;
      final b = _pendingBass;
      if (g == null || b == null) return;
      unawaited(persistCustomEq(bandGains: g, bassBoostDb: b));
    });
  }

  Future<void> persistCustomEq({
    required List<double> bandGains,
    required double bassBoostDb,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_customEqBandsKey, jsonEncode(bandGains));
      await prefs.setDouble(_customEqBassKey, bassBoostDb);
    } catch (e) {
      if (kDebugMode) debugPrint('EqualizerService persistCustomEq: $e');
    }
  }

  Future<({List<double> bandGains, double bassBoostDb})> loadPersistedCustomEq({
    required int bandCount,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_customEqBandsKey);
      List<double> gains;
      if (raw != null) {
        final decoded = (jsonDecode(raw) as List<dynamic>)
            .map((e) => (e as num).toDouble())
            .toList();
        gains = List<double>.generate(
          bandCount,
          (i) => i < decoded.length
              ? decoded[i].clamp(EqPresets.minDb, EqPresets.maxDb)
              : 0.0,
        );
      } else {
        gains = List<double>.filled(bandCount, 0.0);
      }
      final bass =
          (prefs.getDouble(_customEqBassKey) ?? 0.0).clamp(0.0, maxBassBoostDb);
      return (bandGains: gains, bassBoostDb: bass);
    } catch (e) {
      if (kDebugMode) debugPrint('EqualizerService loadPersistedCustomEq: $e');
      return (
        bandGains: List<double>.filled(bandCount, 0.0),
        bassBoostDb: 0.0
      );
    }
  }

  Future<void> resetCustomEq() async {
    _persistDebounce?.cancel();
    final zeros = List<double>.filled(EqPresets.uiBandsHz.length, 0.0);
    await persistCustomEq(bandGains: zeros, bassBoostDb: 0);
    await _pushCustom(zeros, 0);
  }

  Future<void> _applyPersistedCustomEq() async {
    final saved =
        await loadPersistedCustomEq(bandCount: EqPresets.uiBandsHz.length);
    await _pushCustom(saved.bandGains, saved.bassBoostDb);
  }

  Future<void> _savePresetId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(presetPrefsKey, id);
    await prefs.setString(_legacyPresetKey, id);
  }

  Future<void> _pushNative(EqPreset p, {bool writeStream = true}) async {
    if (!_dspAlive) return;
    try {
      var gains = List<double>.from(
        p.advanced ? p.gains : EqPresets.upsample5to10(p.gains),
      );
      var truBass = p.advanced ? p.truBass : 0.0;
      var makeup = p.advanced ? p.makeup : 0.0;
      if (_bassScaleIds.contains(p.id)) {
        final s = bassScaleForVolume(_intentVol);
        if (gains.length > 1) {
          gains[1] = (gains[1] * s).clamp(EqPresets.minDb, EqPresets.maxDb);
        }
        truBass = (truBass * s).clamp(0.0, 1.0);
      }
      if (_loudIds.contains(p.id)) {
        makeup += loudnessMakeupDbFor(p.id, _intentVol);
      }
      if (writeStream && _mayWriteStream) {
        final boost = _streamBoostIds.contains(p.id);
        if (boost) {
          _enterBoostFloor();
        }
        var target = boost
            ? (_intentVol * (1.0 + loudnessBoostPctFor(p.id, _intentVol)))
                .clamp(0.0, 1.0)
            : _intentVol;
        if (boost && target < 1.0 && target <= _vol + _volStep * 0.35) {
          target = (_vol + _volStep).clamp(0.0, 1.0);
        }
        if ((target - _vol).abs() > 0.005) {
          _writingVol = true;
          _writeTarget = target;
          unawaited(SystemVolume.set(target).whenComplete(() {
            Future<void>.delayed(const Duration(milliseconds: 800), () {
              _writingVol = false;
            });
          }));
        }
      }
      await _channel.invokeMethod('apply', {
        'gains': gains,
        'bass': p.bass,
        'width': p.advanced ? p.width : 1.0,
        'truBass': truBass,
        'focus': p.advanced ? p.focus : 0.0,
        'definition': p.advanced ? p.definition : 0.0,
        'makeup': makeup,
        'compress': p.advanced && p.compress,
        'haas': p.advanced ? p.haas : 0.0,
        'air': p.advanced ? p.air : 0.0,
        'truTreble': p.advanced ? p.truTreble : 0.0,
      });
    } catch (e) {
      _dspAlive = false;
      if (kDebugMode) {
        debugPrint('EqualizerService native apply failed, staying dry: $e');
      }
    }
  }

  Future<void> _pushCustom(List<double> gains5, double bass) async {
    if (!_dspAlive) return;
    try {
      await _channel.invokeMethod('apply', {
        'gains': EqPresets.upsample5to10(gains5),
        'bass': bass,
        'width': 1.0,
        'truBass': 0.0,
        'focus': 0.0,
        'definition': 0.0,
        'makeup': 0.0,
        'compress': false,
        'haas': 0.0,
        'air': 0.0,
        'truTreble': 0.0,
      });
    } catch (e) {
      _dspAlive = false;
      if (kDebugMode) debugPrint('EqualizerService custom apply dry: $e');
    }
  }
}
/// Mirror of EqPresets.mewati-bass (NOT SOUND_LOCK.json — that file is stale).
/// 64 Hz +5.3 / truBass 0.40. Bands 125..16k stay 0 so native splitBassOnly
/// stays on (gol path). Any non-zero from 125 Hz up leaves that path.
class MewatiBassChain {
  MewatiBassChain._();

  static const id = 'mewati-bass';
  static const label = 'Mewati Bass™';

  /// DSP: 32, 64, 125, 250, 500, 1k, 2k, 4k, 8k, 16k
  static const gains10 = <double>[
    0.0, // 32
    5.3, // 64
    0.0, // 125
    0.0, // 250
    0.0, // 500
    0.0, // 1k
    0.0, // 2k
    0.0, // 4k
    0.0, // 8k
    0.0, // 16k
  ];

  static const truBass = 0.40;
  static const width = 1.0;
  static const haas = 0.0;
  static const air = 0.0;
  static const truTreble = 0.0;
  static const compress = false;
  static const bass = 0.0;
  static const makeup = 0.0;
  static const focus = 0.0;
  static const definition = 0.0;
  static const advanced = true;
}
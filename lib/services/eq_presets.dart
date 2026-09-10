class EqPreset {
  const EqPreset({
    required this.id,
    required this.label,
    required this.gains,
    required this.bass,
    this.width = 1.0,
    this.truBass = 0.0,
    this.focus = 0.0,
    this.definition = 0.0,
    this.makeup = 0.0,
    this.compress = false,
    this.haas = 0.0,
    this.air = 0.0,
    this.truTreble = 0.0,
    this.advanced = false,
  });

  final String id;
  final String label;
  final List<double> gains;
  final double bass;
  final double width;
  final double truBass;
  final double focus;
  final double definition;
  final double makeup;
  final bool compress;
  final double haas;
  final double air;
  final double truTreble;
  final bool advanced;
}

class EqPresets {
  static const uiBandsHz = [60.0, 230.0, 910.0, 3600.0, 14000.0];
  static const dspBandsHz = [
    32.0, 64.0, 125.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0, 16000.0,
  ];
  static const minDb = -15.0;
  static const maxDb = 15.0;
  static const maxBassBoostDb = 6.0;
  static const headphoneHintIds = {'mewati-bass'};
  static const headphoneHint =
      'Please use your headphones for premium sound quality';

  static const list = <EqPreset>[
    EqPreset(id: 'normal', label: 'Normal', gains: [0, 0, 0, 0, 0], bass: 0),
    EqPreset(id: 'bass', label: 'Bass', gains: [6, 4, 0, 0, 0], bass: 0),
    EqPreset(
      id: 'mewati-bass',
      label: 'Mewati Bass™',
      gains: [0, 5.3, 0, 0, 0, 0, 0, 0, 0, 0],
      bass: 0,
      width: 1,
      truBass: 0.40,
      air: 0,
      truTreble: 0,
      advanced: true,
    ),
    EqPreset(id: 'vocal', label: 'Voice', gains: [-2, -1, 5.5, 5, 0.5], bass: 0),
    EqPreset(id: 'treble', label: 'Treble', gains: [0, 0, 0, 2.5, 6], bass: 0),
    EqPreset(
      id: 'beats',
      label: 'Mewati Beats™',
      gains: [0, 5.3, 0, 0, 0, 0, 0, 0, 0, 0],
      bass: 0,
      width: 1,
      truBass: 0.36,
      air: 0,
      truTreble: 0,
      advanced: true,
    ),
    EqPreset(
      id: 'wow',
      label: 'Mewati Boom™',
      gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      bass: 0,
      width: 1,
      truBass: 0,
      air: 9.5,
      truTreble: 0.28,
      advanced: true,
    ),
  ];

  static const drawerIds = {'normal', 'bass', 'mewati-bass', 'vocal', 'treble'};

  static List<EqPreset> get drawerList =>
      list.where((p) => drawerIds.contains(p.id)).toList();

  static EqPreset byId(String id) {
    for (final p in list) {
      if (p.id == id) return p;
    }
    return list[1];
  }

  static List<double> upsample5to10(List<double> g) {
    final a = g.isNotEmpty ? g[0] : 0.0;
    final b = g.length > 1 ? g[1] : 0.0;
    final c = g.length > 2 ? g[2] : 0.0;
    final d = g.length > 3 ? g[3] : 0.0;
    final e = g.length > 4 ? g[4] : 0.0;
    return [
      a,
      a,
      (a + b) / 2,
      b,
      (b + c) / 2,
      c,
      (c + d) / 2,
      d,
      (d + e) / 2,
      e
    ];
  }
}
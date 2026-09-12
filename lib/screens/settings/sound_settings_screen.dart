import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_themes.dart';
import '../../providers/theme_provider.dart';
import '../../services/bass_energy.dart';
import '../../services/equalizer_service.dart';
import '../../services/eq_presets.dart';

class SoundSettingsScreen extends StatefulWidget {
  const SoundSettingsScreen({super.key});

  @override
  State<SoundSettingsScreen> createState() => _SoundSettingsScreenState();
}

class _SoundSettingsScreenState extends State<SoundSettingsScreen> {
  static const _panelTop = Color(0xFFE67A2E);
  static const _panelBottom = Color(0xFFC45A16);
  static const _barFill = Color(0xFFF3D59A);
  static const _barEdge = Color(0xFFE8C56E);
  static const _labels = [
    '100Hz',
    '300Hz',
    '1kHz',
    '3kHz',
    '10kHz',
  ];

  String? _editId;
  List<double>? _editGains;

  static List<double> visualGains(EqPreset p) {
    if (!p.advanced) {
      final g = p.gains;
      return [
        g.isNotEmpty ? g[0] : 0,
        g.length > 1 ? g[1] : 0,
        g.length > 2 ? g[2] : 0,
        g.length > 3 ? g[3] : 0,
        g.length > 4 ? g[4] : 0,
      ];
    }
    final g = p.gains;
    final v = <double>[
      g.length > 1 ? g[1] : 0,
      g.length > 3 ? g[3] : 0,
      g.length > 5 ? g[5] : 0,
      g.length > 7 ? g[7] : 0,
      g.length > 9 ? g[9] : 0,
    ];
    v[0] = (v[0] + p.truBass * 12).clamp(EqPresets.minDb, EqPresets.maxDb);
    v[1] = (v[1] + p.truBass * 8).clamp(EqPresets.minDb, EqPresets.maxDb);
    v[3] = (v[3] + p.truTreble * 6).clamp(EqPresets.minDb, EqPresets.maxDb);
    v[4] = (v[4] + p.air * 0.6 + p.truTreble * 10)
        .clamp(EqPresets.minDb, EqPresets.maxDb);
    return v;
  }

  static int barsFor(double db) {
    return (((db + 15) / 30) * 18 + 2).round().clamp(2, 20);
  }

  List<double> _gainsFor(EqPreset p) {
    if (p.id == 'mewati-bass') return visualGains(p);
    if (_editId == p.id && _editGains != null) return _editGains!;
    return visualGains(p);
  }

  void _setBand(EqPreset preset, int index, double db) {
    if (preset.id == 'mewati-bass') return;
    final next = List<double>.from(_gainsFor(preset));
    next[index] = db.clamp(EqPresets.minDb, EqPresets.maxDb);
    setState(() {
      _editId = preset.id;
      _editGains = next;
    });
    EqualizerService().applyCustomSnapshot(
      bandGains: next,
      bassBoostDb: 0,
    );
  }

  Future<void> _selectPreset(String id) async {
    setState(() {
      _editId = null;
      _editGains = null;
    });
    await context.read<ThemeProvider>().setEqPreset(id);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final t = themeProvider.theme;
    final radius = t.id == AppThemeId.silverChrome ? 10.0 : 14.0;
    final selectedId = themeProvider.eqPreset;
    final selected = EqPresets.byId(
      EqPresets.drawerIds.contains(selectedId) ? selectedId : 'normal',
    );
    final locked = selected.id == 'mewati-bass';
    final gains = _gainsFor(selected);

    final apple = t.id == AppThemeId.silverChrome;
    final panelTop = apple ? const Color(0xFF243528) : _panelTop;
    final panelBottom = apple ? const Color(0xFF121A14) : _panelBottom;
    final panelBorder = apple ? t.accent : const Color(0xFFFFC48A);

    return Scaffold(
      backgroundColor: t.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon:
                        Icon(Icons.chevron_left, color: t.textPrimary, size: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'SOUND EFFECT',
                    style: TextStyle(
                      color: t.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [panelTop, panelBottom],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      border: Border.all(color: panelBorder, width: 1.2),
                    ),
                    child: Column(
                      children: [
                        if (!locked) ...[
                          Text(
                            selected.label.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        SizedBox(
                          height: locked ? 236 : 168,
                          child: locked
                              ? const _MewatiBassLock()
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: List.generate(5, (i) {
                                    return Expanded(
                                      child: _WalkmanBand(
                                        filled: barsFor(gains[i]),
                                        fill: _barFill,
                                        edge: _barEdge,
                                        onChangeDb: (db) =>
                                            _setBand(selected, i, db),
                                      ),
                                    );
                                  }),
                                ),
                        ),
                        const SizedBox(height: 10),
                        if (!locked)
                          Row(
                            children: _labels
                                .map(
                                  (l) => Expanded(
                                    child: Text(
                                      l,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'EQUALIZER',
                    style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...EqPresets.drawerList.map((preset) {
                    final active = selected.id == preset.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () async {
                          final was = selected.id;
                          await _selectPreset(preset.id);
                          if (!context.mounted) return;
                          if (was == preset.id) return;
                          if (await EqualizerService()
                              .shouldHintHeadphones(preset.id)) {
                            final messenger = ScaffoldMessenger.of(context);
                            messenger.clearSnackBars();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(EqPresets.headphoneHint),
                                duration: Duration(seconds: 4),
                              ),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(radius),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? t.accent.withOpacity(0.18)
                                : t.surface,
                            borderRadius: BorderRadius.circular(radius),
                            border: Border.all(
                              color: active
                                  ? t.accent
                                  : t.textPrimary.withOpacity(0.16),
                              width: active ? 1.6 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  preset.label,
                                  style: TextStyle(
                                    color: active ? t.accent : t.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: active
                                      ? t.accent
                                      : t.textPrimary.withOpacity(0.28),
                                  boxShadow: active
                                      ? [
                                          BoxShadow(
                                            color: t.accent.withOpacity(0.7),
                                            blurRadius: 8,
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalkmanBand extends StatelessWidget {
  final int filled;
  final Color fill;
  final Color edge;
  final ValueChanged<double> onChangeDb;

  const _WalkmanBand({
    required this.filled,
    required this.fill,
    required this.edge,
    required this.onChangeDb,
  });

  double _dbFromLocalY(double localY, double height) {
    final t = (1.0 - (localY / height)).clamp(0.0, 1.0);
    return EqPresets.minDb + t * (EqPresets.maxDb - EqPresets.minDb);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: LayoutBuilder(
        builder: (context, box) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) =>
                onChangeDb(_dbFromLocalY(d.localPosition.dy, box.maxHeight)),
            onVerticalDragUpdate: (d) =>
                onChangeDb(_dbFromLocalY(d.localPosition.dy, box.maxHeight)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: List.generate(filled, (i) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 2.2),
                  height: 5.6,
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(1.5),
                    border:
                        Border.all(color: edge.withOpacity(0.7), width: 0.4),
                  ),
                );
              }),
            ),
          );
        },
      ),
    );
  }
}

class _MewatiBassLock extends StatefulWidget {
  const _MewatiBassLock();

  @override
  State<_MewatiBassLock> createState() => _MewatiBassLockState();
}

class _MewatiBassLockState extends State<_MewatiBassLock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  StreamSubscription<double>? _sub;
  double _energy = 0;
  double _target = 0;
  int _lastEventMs = 0;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _pulse.addListener(_tick);
    _sub = BassEnergy.stream.listen((v) {
      _target = v;
      _lastEventMs = DateTime.now().millisecondsSinceEpoch;
    });
  }

  void _tick() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastEventMs > 90) {
      _target *= 0.86;
    }
    _energy += (_target - _energy) * 0.38;
    if (_energy < 0.004) _energy = 0;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pulse.removeListener(_tick);
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        return CustomPaint(
          painter: _BassWavePainter(energy: _energy),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'MEWATI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.4,
                    height: 1.1,
                  ),
                ),
                Text(
                  'BASS™',
                  style: TextStyle(
                    color: Color(0xFFF3D59A),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3.2,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BassWavePainter extends CustomPainter {
  final double energy;

  _BassWavePainter({required this.energy});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    final pulse = energy.clamp(0.0, 1.0);
    const gold = Color(0xFFF3D59A);

    canvas.drawCircle(
      c,
      radius,
      Paint()..color = const Color(0xFF12100C).withOpacity(0.92),
    );

    final rim = Paint()
      ..color = gold.withOpacity(0.80)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawCircle(c, radius * 0.96, rim);

    final ring = Paint()
      ..color = gold.withOpacity(0.22 + 0.40 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawCircle(c, radius * (0.78 + 0.02 * pulse), ring);
    canvas.drawCircle(c, radius * (0.62 + 0.03 * pulse), ring);
    canvas.drawCircle(c, radius * (0.48 + 0.03 * pulse), ring);

    if (pulse > 0.03) {
      final wave = Paint()
        ..color = gold.withOpacity(0.20 + 0.50 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      for (final dir in <double>[-1, 1]) {
        for (var i = 0; i < 3; i++) {
          final reach = radius * (0.16 + 0.14 * i + 0.18 * pulse);
          final start = Offset(c.dx + dir * radius * 1.02, c.dy);
          canvas.drawArc(
            Rect.fromCircle(center: start, radius: reach),
            dir < 0 ? -0.85 : math.pi - 0.85,
            1.70,
            false,
            wave,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BassWavePainter oldDelegate) =>
      oldDelegate.energy != energy;
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_themes.dart';
import '../../providers/theme_provider.dart';
import '../../services/equalizer_service.dart';
import '../../services/eq_presets.dart';

class SoundSettingsScreen extends StatelessWidget {
  const SoundSettingsScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final t = themeProvider.theme;
    final radius = t.id == AppThemeId.silverChrome ? 10.0 : 14.0;
    final selectedId = themeProvider.eqPreset;
    final selected = EqPresets.byId(
      EqPresets.drawerIds.contains(selectedId) ? selectedId : 'normal',
    );
    final gains = visualGains(selected);

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
                    icon: Icon(Icons.chevron_left, color: t.textPrimary, size: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'SOUND SETTING',
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
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [_panelTop, _panelBottom],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      border: Border.all(color: const Color(0xFFFFC48A), width: 1.2),
                    ),
                    child: Column(
                      children: [
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
                        SizedBox(
                          height: 168,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: List.generate(5, (i) {
                              return Expanded(
                                child: _WalkmanBand(
                                  filled: barsFor(gains[i]),
                                  fill: _barFill,
                                  edge: _barEdge,
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 10),
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
                        onTap: () {
                          themeProvider.setEqPreset(preset.id);
                          if (EqualizerService().shouldHintHeadphones(preset.id)) {
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
                              color: active ? t.accent : t.textPrimary.withOpacity(0.16),
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

  const _WalkmanBand({
    required this.filled,
    required this.fill,
    required this.edge,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: List.generate(filled, (i) {
          return Container(
            margin: const EdgeInsets.only(bottom: 2.2),
            height: 5.6,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(1.5),
              border: Border.all(color: edge.withOpacity(0.7), width: 0.4),
            ),
          );
        }),
      ),
    );
  }
}
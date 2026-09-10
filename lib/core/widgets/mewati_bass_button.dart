import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/bass_energy.dart';

class MewatiBassButton extends StatefulWidget {
  final double size;
  final bool active;
  final VoidCallback? onPressed;

  const MewatiBassButton({
    super.key,
    this.size = 44,
    this.active = true,
    this.onPressed,
  });

  @override
  State<MewatiBassButton> createState() => _MewatiBassButtonState();
}

class _MewatiBassButtonState extends State<MewatiBassButton>
    with SingleTickerProviderStateMixin {
  static const _gold = Color(0xFFF3D59A);
  static const _edge = Color(0xFFE8C56E);

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
    final s = widget.size;
    return Opacity(
      opacity: widget.active ? 1 : 0.42,
      child: SizedBox(
        width: s,
        height: s,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            return Material(
              color: Colors.transparent,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: widget.onPressed,
                child: CustomPaint(
                  painter: MewatiBassWavePainter(
                      energy: widget.active ? _energy : 0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _edge.withOpacity(0.55 + 0.35 * _energy),
                        width: 1.1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _gold.withOpacity(0.22 + 0.45 * _energy),
                          blurRadius: 8 + 10 * _energy,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class MewatiBassWavePainter extends CustomPainter {
  final double energy;

  MewatiBassWavePainter({required this.energy});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 1.5;
    final pulse = energy.clamp(0.0, 1.0);

    final fill = Paint()..color = const Color(0xFF1A120C).withOpacity(0.92);
    canvas.drawCircle(c, radius, fill);

    final ring = Paint()
      ..color = const Color(0xFFF3D59A).withOpacity(0.35 + 0.25 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(c, radius * 0.42, ring);
    canvas.drawCircle(c, radius * (0.62 + 0.04 * pulse), ring);

    final core = Paint()
      ..color = const Color(0xFFF3D59A).withOpacity(0.55 + 0.45 * pulse);
    canvas.drawCircle(c, radius * (0.12 + 0.05 * pulse), core);

    final bar = Paint()
      ..color = const Color(0xFFF3D59A)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    const ticks = 28;
    for (var i = 0; i < ticks; i++) {
      final a = (i / ticks) * math.pi * 2;
      final wave = (math.sin(a * 3) + 1) / 2;
      final len = pulse < 0.03 ? 0.0 : radius * (0.10 + 0.28 * wave * pulse);
      final inner = radius * 0.70;
      final p1 = Offset(
        c.dx + math.cos(a) * inner,
        c.dy + math.sin(a) * inner,
      );
      final p2 = Offset(
        c.dx + math.cos(a) * (inner + len),
        c.dy + math.sin(a) * (inner + len),
      );
      canvas.drawLine(p1, p2, bar);
    }
  }

  @override
  bool shouldRepaint(covariant MewatiBassWavePainter oldDelegate) =>
      oldDelegate.energy != energy;
}
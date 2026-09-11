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
                  painter: _WooferPainter(
                    energy: widget.active ? _energy : 0,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _gold.withOpacity(0.18 + 0.40 * _energy),
                          blurRadius: 6 + 8 * _energy,
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

class _WooferPainter extends CustomPainter {
  final double energy;

  _WooferPainter({required this.energy});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2 - 1.2;
    final p = energy.clamp(0.0, 1.0);
    const gold = Color(0xFFF3D59A);

    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF16100C));

    final rim = Paint()
      ..color = gold.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawCircle(c, r * 0.92, rim);

    final ring = Paint()
      ..color = gold.withOpacity(0.28 + 0.35 * p)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15;
    canvas.drawCircle(c, r * (0.74 + 0.02 * p), ring);
    canvas.drawCircle(c, r * (0.56 + 0.03 * p), ring);
    canvas.drawCircle(c, r * (0.38 + 0.03 * p), ring);

    canvas.drawCircle(
      c,
      r * (0.16 + 0.06 * p),
      Paint()..color = gold.withOpacity(0.55 + 0.40 * p),
    );

    if (p > 0.04) {
      final wave = Paint()
        ..color = gold.withOpacity(0.25 + 0.45 * p)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round;
      for (final dir in [-1.0, 1.0]) {
        final reach = r * (0.18 + 0.22 * p);
        final start = Offset(c.dx + dir * r * 0.98, c.dy);
        canvas.drawArc(
          Rect.fromCircle(center: start, radius: reach),
          dir < 0 ? -0.7 : 3.14159 - 0.7,
          1.4,
          false,
          wave,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WooferPainter oldDelegate) =>
      oldDelegate.energy != energy;
}
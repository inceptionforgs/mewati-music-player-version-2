import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppHaptics extends StatefulWidget {
  final Widget child;

  const AppHaptics({Key? key, required this.child}) : super(key: key);

  @override
  State<AppHaptics> createState() => _AppHapticsState();
}

class _AppHapticsState extends State<AppHaptics> {
  int? _downMs;
  Offset? _downPos;

  void _onDown(PointerDownEvent e) {
    if (e.kind != PointerDeviceKind.touch) return;
    _downMs = DateTime.now().millisecondsSinceEpoch;
    _downPos = e.position;
  }

  void _onUp(PointerUpEvent e) {
    final t = _downMs;
    final p = _downPos;
    _downMs = null;
    _downPos = null;
    if (t == null || p == null) return;
    final dt = DateTime.now().millisecondsSinceEpoch - t;
    if (dt >= 320) return;
    if ((e.position - p).distance > 22) return;
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onDown,
      onPointerUp: _onUp,
      child: widget.child,
    );
  }
}
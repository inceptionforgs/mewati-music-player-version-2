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
  Offset? _downPos;

  void _onDown(PointerDownEvent e) {
    if (e.kind != PointerDeviceKind.touch) return;
    _downPos = e.position;
    HapticFeedback.selectionClick();
  }

  void _onUp(PointerUpEvent e) {
    _downPos = null;
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
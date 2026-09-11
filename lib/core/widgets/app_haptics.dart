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
  void _onDown(PointerDownEvent e) {
    if (e.kind != PointerDeviceKind.touch) return;
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onDown,
      child: widget.child,
    );
  }
}
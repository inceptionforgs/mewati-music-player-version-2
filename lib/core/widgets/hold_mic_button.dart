import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HoldMicButton extends StatefulWidget {
  static const holdFor = Duration(seconds: 2);

  final VoidCallback onArmed;
  final Color idleColor;
  final Color holdColor;
  final Widget Function(Color color, double progress) builder;
  final String semanticLabel;

  const HoldMicButton({
    Key? key,
    required this.onArmed,
    required this.idleColor,
    required this.holdColor,
    required this.builder,
    this.semanticLabel = 'Voice search',
  }) : super(key: key);

  @override
  State<HoldMicButton> createState() => _HoldMicButtonState();
}

class _HoldMicButtonState extends State<HoldMicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hold;

  @override
  void initState() {
    super.initState();
    _hold = AnimationController(vsync: this, duration: HoldMicButton.holdFor)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          HapticFeedback.mediumImpact();
          widget.onArmed();
          _hold.reset();
        }
      });
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  void _cancel() {
    if (_hold.isAnimating || _hold.value > 0) {
      _hold.animateBack(0, duration: const Duration(milliseconds: 160));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _hold.forward(from: _hold.value),
        onTapUp: (_) => _cancel(),
        onTapCancel: _cancel,
        child: AnimatedBuilder(
          animation: _hold,
          builder: (context, _) {
            final progress = _hold.value;
            final color = Color.lerp(
              widget.idleColor,
              widget.holdColor,
              progress,
            )!;
            return widget.builder(color, progress);
          },
        ),
      ),
    );
  }
}
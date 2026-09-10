import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HoldMicButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          onArmed();
        },
        child: builder(idleColor, 0),
      ),
    );
  }
}
import 'package:flutter/material.dart';

void showMewatiBassToast(BuildContext context, {required bool on}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => IgnorePointer(
      child: Center(
        child: Material(
          color: const Color(0xE61A120C),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Text(
              on ? 'Mewati Baas ON' : 'Mewati Baas OFF',
              style: const TextStyle(
                color: Color(0xFFF3D59A),
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future<void>.delayed(const Duration(milliseconds: 1300), () {
    entry.remove();
  });
}
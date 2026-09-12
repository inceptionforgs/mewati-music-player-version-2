import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CoverColorService {
  CoverColorService._();
  static final CoverColorService instance = CoverColorService._();

  static const _prefix = 'cover_dom_';
  final Map<String, Color> _mem = {};
  final Set<String> _inflight = {};

  String _key(String songId, String? coverUrl) =>
      '$_prefix${songId}_${coverUrl ?? ''}';

  Color? cached(String songId, String? coverUrl) => _mem[_key(songId, coverUrl)];

  Future<Color?> colorFor({
    required String songId,
    required String? coverUrl,
  }) async {
    final key = _key(songId, coverUrl);
    final hit = _mem[key];
    if (hit != null) return hit;
    if (coverUrl == null || coverUrl.isEmpty) return null;

    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt(key);
      if (saved != null) {
        final c = Color(saved);
        _mem[key] = c;
        return c;
      }
    } catch (_) {}

    if (!_inflight.add(key)) return _mem[key];
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        ResizeImage(
          NetworkImage(coverUrl),
          width: 48,
          height: 48,
        ),
        size: const Size(48, 48),
        maximumColorCount: 6,
      );
      final raw = palette.dominantColor?.color ??
          palette.vibrantColor?.color ??
          palette.mutedColor?.color;
      if (raw == null) return null;
      _mem[key] = raw;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(key, raw.value);
      } catch (_) {}
      return raw;
    } catch (_) {
      return null;
    } finally {
      _inflight.remove(key);
    }
  }

  static Color backdrop(Color src, Color fallback) {
    final hsl = HSLColor.fromColor(src);
    return hsl
        .withSaturation(hsl.saturation.clamp(0.20, 0.48))
        .withLightness(0.13)
        .toColor();
  }

  static Color backdropDeep(Color src, Color fallback) {
    final hsl = HSLColor.fromColor(src);
    return hsl
        .withSaturation(hsl.saturation.clamp(0.18, 0.40))
        .withLightness(0.06)
        .toColor();
  }
}
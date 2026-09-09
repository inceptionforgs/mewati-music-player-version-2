import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_themes.dart';
import '../services/equalizer_service.dart';

const _themeIdKey = 'theme_id';
const _customColorKey = 'custom_theme_color';
const _customShadeKey = 'custom_theme_shade';

class ThemeProvider extends ChangeNotifier {
  AppThemeId _themeId = AppThemes.defaultThemeId;
  String _eqPreset = EqualizerService.defaultPresetId;

  Color _customColor = AppThemes.walkmanOrange.accent;
  double _customShade = 0.5;

  AppThemeData? _previewOverride;
  Timer? _previewDebounce;
  AppThemeData? _queuedPreview;

  AppThemeId get themeId => _themeId;
  Color get customColor => _customColor;
  double get customShade => _customShade;
  bool get isPreviewingTheme => _previewOverride != null;

  AppThemeData get theme {
    if (_previewOverride != null) return _previewOverride!;
    if (_themeId == AppThemeId.custom) {
      return AppThemes.buildCustom(_customColor, _customShade);
    }
    return AppThemes.byId(_themeId);
  }

  String get eqPreset => _eqPreset;

  ThemeProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _themeId = AppThemes.defaultThemeId;
      await prefs.setString(_themeIdKey, _themeId.toString());

      final eq = prefs.getString(EqualizerService.presetPrefsKey) ??
          prefs.getString('eq_preset');
      if (eq != null) {
        const hidden = {'beats', 'wow', 'custom'};
        _eqPreset = hidden.contains(eq) ? 'mewati-bass' : eq;
      }

      notifyListeners();

      await EqualizerService().applyPreset(_eqPreset);
    } catch (e) {
      developer.log('Theme load failed: $e', name: 'ThemeProvider');
    }
  }

  Future<void> setTheme(AppThemeId id) async {
    if (id == AppThemeId.custom) {
      return;
    }
    if (_themeId == id && _previewOverride == null) return;
    _themeId = id;
    _previewOverride = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeIdKey, id.toString());
    } catch (e) {
      developer.log('Theme save failed: $e', name: 'ThemeProvider');
    }
  }

  Future<void> setEqPreset(String preset) async {
    if (_eqPreset == preset) return;
    _eqPreset = preset;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(EqualizerService.presetPrefsKey, preset);
      await prefs.setString('eq_preset', preset);
    } catch (e) {
      developer.log('EQ preset save failed: $e', name: 'ThemeProvider');
    }

    await EqualizerService().applyPreset(preset);
  }

  void previewCustomTheme(Color color, double shade) {
    _queuedPreview = AppThemes.buildCustom(color, shade);
    _previewDebounce?.cancel();
    _previewDebounce = Timer(const Duration(milliseconds: 32), () {
      _previewOverride = _queuedPreview;
      notifyListeners();
    });
  }

  void cancelThemePreview() {
    _previewDebounce?.cancel();
    if (_previewOverride == null) return;
    _previewOverride = null;
    notifyListeners();
  }

  Future<void> commitCustomTheme(Color color, double shade) async {
    _previewDebounce?.cancel();
    _customColor = color;
    _customShade = shade;
    _themeId = AppThemeId.custom;
    _previewOverride = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeIdKey, AppThemeId.custom.toString());
      await prefs.setInt(_customColorKey, color.toARGB32());
      await prefs.setDouble(_customShadeKey, shade);
    } catch (e) {
      developer.log('Custom theme save failed: $e', name: 'ThemeProvider');
    }
  }

  Future<void> resetToDefaultTheme() async {
    _previewDebounce?.cancel();
    _previewOverride = null;
    await setTheme(AppThemes.defaultThemeId);
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    super.dispose();
  }
}
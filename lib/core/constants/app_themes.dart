import 'package:flutter/material.dart';

import 'themes/app_theme_data.dart';
import 'themes/app_theme_id.dart';
import 'themes/custom_theme_builder.dart';
import 'themes/cyber_black_theme.dart';
import 'themes/silver_chrome_theme.dart';
import 'themes/walkman_orange_theme.dart';

// Re-exported so every existing `import 'app_themes.dart'` (or
// `'../constants/app_themes.dart'`, etc.) across the app keeps compiling
// unchanged — AppThemeId and AppThemeData still resolve from here.
export 'themes/app_theme_data.dart';
export 'themes/app_theme_id.dart';

/// Registry of all built-in themes plus the custom-theme builder.
class AppThemes {
  static const AppThemeId defaultThemeId = AppThemeId.silverChrome;

  static const AppThemeData walkmanOrange = walkmanOrangeTheme;
  static const AppThemeData cyberBlack = cyberBlackTheme;
  static const AppThemeData silverChrome = silverChromeTheme;

  static const List<AppThemeData> all = [
    walkmanOrange,
    cyberBlack,
    silverChrome,
  ];

  static AppThemeData byId(AppThemeId id) {
    switch (id) {
      case AppThemeId.walkmanOrange:
        return walkmanOrange;
      case AppThemeId.cyberBlack:
        return cyberBlack;
      case AppThemeId.silverChrome:
        return silverChrome;
      case AppThemeId.custom:
        throw UnsupportedError(
          'AppThemeId.custom needs a color+shade — use AppThemes.buildCustom() '
          'or ThemeProvider.theme instead of byId() for this id.',
        );
    }
  }

  /// Thin wrapper so `AppThemes.buildCustom(...)` keeps working
  /// everywhere it's already called (theme_provider.dart, etc).
  static AppThemeData buildCustom(Color color, double shade) =>
      buildCustomTheme(color, shade);
}
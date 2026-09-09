import 'package:flutter/material.dart';
import '../models/singer.dart';
import '../models/song.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/singers/singer_profile_screen.dart';
import '../screens/player/now_playing_screen.dart';
import '../screens/feedback/feedback_screen.dart';
import '../screens/settings/advance_settings_screen.dart';
import '../screens/settings/sound_settings_screen.dart';
import '../screens/drive_mode/drive_mode_screen.dart';
import '../screens/search/search_screen.dart';
import 'route_names.dart';

class AppRouter {
  /// Mini-player lives in [MaterialApp.builder] (sibling of the Navigator),
  /// so [Navigator.of] cannot see a Navigator ancestor. Use this key instead.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case RouteNames.splash:
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );
      case RouteNames.home:
        return MaterialPageRoute(
          builder: (_) => const HomeScreen(),
          settings: settings,
        );
      case RouteNames.singerProfile:
        final singer = settings.arguments;
        if (singer is! Singer) {
          return MaterialPageRoute(
            builder: (_) => const HomeScreen(),
            settings: settings,
          );
        }
        return MaterialPageRoute(
          builder: (_) => SingerProfileScreen(singer: singer),
          settings: settings,
        );
      case RouteNames.nowPlaying:
        return MaterialPageRoute(
          builder: (_) => const NowPlayingScreen(),
          settings: settings,
        );
      case RouteNames.feedback:
        final args = settings.arguments;
        final song = args is Song ? args : null;
        return MaterialPageRoute(
          builder: (_) => FeedbackScreen(song: song),
          settings: settings,
        );
      case RouteNames.advanceSettings:
        final args = settings.arguments;
        final tab = args is int ? args : AdvanceSettingsScreen.equalizerTab;
        return MaterialPageRoute(
          builder: (_) => AdvanceSettingsScreen(initialTabIndex: tab),
          settings: settings,
        );
      case RouteNames.soundSettings:
        return MaterialPageRoute(
          builder: (_) => const SoundSettingsScreen(),
          settings: settings,
        );
      case RouteNames.driveMode:
        return MaterialPageRoute(
          builder: (_) => const DriveModeScreen(),
          settings: settings,
        );
      case RouteNames.search:
        return MaterialPageRoute(
          builder: (_) => const SearchScreen(),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );
    }
  }
}
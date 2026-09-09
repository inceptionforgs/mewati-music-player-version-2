import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../routes/app_router.dart';
import '../../routes/route_names.dart';

class HomeNav {
  HomeNav._();

  static const int songs = 0;
  static const int singers = 1;
  static const int trending = 2;
  static const int favorites = 3;
  static const int downloads = 4;

  static final ValueNotifier<int> tabIndex = ValueNotifier<int>(trending);
  static final ValueNotifier<String?> revealSongId = ValueNotifier<String?>(null);

  static void goTab(int index) {
    tabIndex.value = index.clamp(songs, downloads);
  }

  static void showCurrentSongInList(String? songId) {
    goTab(songs);
    revealSongId.value = songId;
    final nav = AppRouter.navigatorKey.currentState;
    if (nav == null) return;
    nav.popUntil((route) {
      return route.settings.name == RouteNames.home || route.isFirst;
    });
  }
}
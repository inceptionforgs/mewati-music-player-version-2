import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';

import '../../../providers/player_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../constants/themes/app_theme_id.dart';
import 'mini_player_data.dart';
import 'themes/mini_player_cyber_black.dart';
import 'themes/mini_player_silver_chrome.dart';
import 'themes/mini_player_default.dart';

class MiniPlayerBar extends StatelessWidget {
  const MiniPlayerBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final playerProvider = context.read<PlayerProvider>();
    final t = context.watch<ThemeProvider>().theme;

    final song = context.select<PlayerProvider, dynamic>((p) => p.currentSong);
    final hasSong = song != null;
    final isPlaying = context.select<PlayerProvider, bool>((p) => p.isPlaying);
    final isLoading = context.select<PlayerProvider, bool>((p) => p.isLoading);
    final errorMessage =
        context.select<PlayerProvider, String?>((p) => p.errorMessage);
    final loopMode = context.select<PlayerProvider, LoopMode>((p) => p.loopMode);
    final currentQueueIndex =
        context.select<PlayerProvider, int>((p) => p.currentQueueIndex);
    final totalQueueLength =
        context.select<PlayerProvider, int>((p) => p.totalQueueLength);

    if (!hasSong && t.id != AppThemeId.silverChrome) {
      return const SizedBox.shrink();
    }

    final queuePosition =
        (totalQueueLength > 0) ? '${currentQueueIndex + 1}/$totalQueueLength' : '';

    final data = MiniPlayerData(
      song: song,
      theme: t,
      isPlaying: isPlaying,
      isLoading: isLoading,
      errorMessage: errorMessage,
      loopMode: loopMode,
      queuePosition: queuePosition,
      playerProvider: playerProvider,
    );

    switch (t.id) {
      case AppThemeId.cyberBlack:
        return MiniPlayerCyberBlack(data: data);
      case AppThemeId.silverChrome:
        return MiniPlayerSilverChrome(data: data);
      default:
        return MiniPlayerDefault(data: data);
    }
  }
}
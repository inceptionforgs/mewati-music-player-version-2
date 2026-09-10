import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../models/song.dart';
import '../../../../routes/app_router.dart';
import '../../../../routes/route_names.dart';
import '../../../../screens/search/search_screen.dart';
import '../../../../screens/search/voice_search_sheet.dart';
import '../../../../services/app_cache_manager.dart';
import '../../../../core/utils/home_nav.dart';
import '../../../../core/widgets/hold_mic_button.dart';
import '../mini_player_data.dart';

class MiniPlayerSilverChrome extends StatelessWidget {
  final MiniPlayerData data;

  const MiniPlayerSilverChrome({Key? key, required this.data}) : super(key: key);

  Future<void> _openVoice(BuildContext context) async {
    final phrase = await VoiceSearchSheet.show(context);
    if (!context.mounted) return;
    final q = phrase?.trim() ?? '';
    if (q.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SearchScreen(initialQuery: q),
        fullscreenDialog: true,
        settings: const RouteSettings(name: RouteNames.search),
      ),
    );
  }

  void _goHome() {
    HomeNav.goTab(HomeNav.trending);
    AppRouter.navigatorKey.currentState?.popUntil((route) {
      return route.settings.name == RouteNames.home || route.isFirst;
    });
  }

  @override
  Widget build(BuildContext context) {
    final song = data.song is Song ? data.song as Song : null;
    final isPlaying = data.isPlaying;
    final isLoading = data.isLoading;
    final playerProvider = data.playerProvider;
    final cover = song?.coverImageUrl;
    final singer = song?.singerName ?? '';
    final t = data.theme;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return ColoredBox(
      color: t.surface,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (song != null)
              ValueListenableBuilder<Duration>(
                valueListenable: playerProvider.durationNotifier,
                builder: (context, duration, _) {
                  return ValueListenableBuilder<Duration>(
                    valueListenable: playerProvider.positionNotifier,
                    builder: (context, position, __) {
                      final pct = duration.inMilliseconds == 0
                          ? 0.0
                          : (position.inMilliseconds / duration.inMilliseconds)
                              .clamp(0.0, 1.0);
                      return LayoutBuilder(
                        builder: (context, box) {
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (d) {
                              if (duration.inMilliseconds == 0 || box.maxWidth <= 0) {
                                return;
                              }
                              final r = (d.localPosition.dx / box.maxWidth).clamp(0.0, 1.0);
                              playerProvider.seek(Duration(
                                milliseconds: (r * duration.inMilliseconds).round(),
                              ));
                            },
                            child: SizedBox(
                              height: 8,
                              width: double.infinity,
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: SizedBox(
                                  height: 3,
                                  child: Stack(
                                    children: [
                                      const ColoredBox(
                                        color: Color(0xFF1A1F1A),
                                        child: SizedBox.expand(),
                                      ),
                                      FractionallySizedBox(
                                        widthFactor: pct,
                                        heightFactor: 1,
                                        alignment: Alignment.centerLeft,
                                        child: ColoredBox(color: t.accent),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              )
            else
              const SizedBox(height: 3),
            SizedBox(
              height: 64,
              child: Row(
                children: [
                  Expanded(
                    child: ValueListenableBuilder<int>(
                      valueListenable: HomeNav.tabIndex,
                      builder: (context, tab, _) {
                        final homeOn = tab == HomeNav.trending;
                        return InkWell(
                          onTap: _goHome,
                          child: Icon(
                            Icons.home,
                            size: 26,
                            color: homeOn ? t.accent : t.textSecondary,
                          ),
                        );
                      },
                    ),
                  ),
                  if (song != null) ...[
                    GestureDetector(
                      onTap: () => AppRouter.navigatorKey.currentState
                          ?.pushNamed(RouteNames.nowPlaying),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: cover != null && cover.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: cover,
                                  fit: BoxFit.cover,
                                  cacheManager: AppCacheManager.instance,
                                  memCacheWidth: 112,
                                  memCacheHeight: 112,
                                )
                              : ColoredBox(
                                  color: t.background,
                                  child: Icon(Icons.music_note, color: t.accent),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: GestureDetector(
                        onTap: () => AppRouter.navigatorKey.currentState
                            ?.pushNamed(RouteNames.nowPlaying),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: t.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            if (singer.isNotEmpty)
                              Text(
                                singer,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: t.textSecondary,
                                  fontSize: 12,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: isPlaying ? 'Pause' : 'Play',
                      onPressed: isLoading
                          ? null
                          : () => playerProvider.togglePlayPause(),
                      icon: isLoading
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: t.textPrimary,
                              ),
                            )
                          : Icon(
                              isPlaying ? Icons.pause : Icons.play_arrow,
                              color: t.textPrimary,
                              size: 28,
                            ),
                    ),
                  ] else
                    const Spacer(),
                  Expanded(
                    child: HoldMicButton(
                      idleColor: t.textSecondary,
                      holdColor: t.accent,
                      onArmed: () => _openVoice(context),
                      builder: (color, progress) => Icon(
                        Icons.mic,
                        size: 26,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
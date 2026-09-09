import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../models/song.dart';
import '../../../../routes/app_router.dart';
import '../../../../routes/route_names.dart';
import '../../../../services/app_cache_manager.dart';
import '../mini_player_data.dart';

class MiniPlayerSilverChrome extends StatelessWidget {
  final MiniPlayerData data;

  const MiniPlayerSilverChrome({Key? key, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Song song = data.song as Song;
    final isPlaying = data.isPlaying;
    final isLoading = data.isLoading;
    final playerProvider = data.playerProvider;
    final cover = song.coverImageUrl;
    final singer = song.singerName ?? '';
    final t = data.theme;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return ColoredBox(
      color: t.surface,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => AppRouter.navigatorKey.currentState
                      ?.pushNamed(RouteNames.nowPlaying),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 52,
                      height: 52,
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
                const SizedBox(width: 12),
                Expanded(
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
                            fontSize: 16,
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
                              fontSize: 13,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
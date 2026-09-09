import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/formatters.dart';
import '../../models/song.dart';
import '../../services/app_cache_manager.dart';
import '../constants/themes/app_theme_id.dart';

class SongRowData {
  final Song song;
  final bool isNow;
  final bool isPlaying;
  final bool isFav;
  final bool isDownloaded;
  final bool isDownloading;
  final double progress;
  final String? subtitle;
  final bool isLiked;
  final int likeCount;

  const SongRowData({
    required this.song,
    required this.isNow,
    required this.isPlaying,
    required this.isFav,
    required this.isDownloaded,
    required this.isDownloading,
    required this.progress,
    this.subtitle,
    required this.isLiked,
    required this.likeCount,
  });
}

class SongRowActions {
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final VoidCallback onDownload;
  final VoidCallback onCancelDownload;
  final VoidCallback onRemoveDownload;
  final VoidCallback onToggleLike;
  final VoidCallback? onLongPress;

  const SongRowActions({
    required this.onTap,
    required this.onToggleFavorite,
    required this.onDownload,
    required this.onCancelDownload,
    required this.onRemoveDownload,
    required this.onToggleLike,
    this.onLongPress,
  });
}

class SongRow extends StatelessWidget {
  static const double tileHeight = 96;

  final SongRowData data;
  final SongRowActions actions;
  final dynamic t;

  const SongRow({
    Key? key,
    required this.data,
    required this.actions,
    required this.t,
  }) : super(key: key);

  static String _subtitleLine(String? subtitle, Song song) {
    final cat = subtitle ?? (song.category ?? 'Unknown');
    final dur = song.duration;
    if (dur == null || dur <= 0) return cat;
    return '$cat  ·  ${formatDurationSeconds(dur)}';
  }

  @override
  Widget build(BuildContext context) {
    final song = data.song;
    final isNow = data.isNow;
    final isPlaying = data.isPlaying;
    final subtitle = data.subtitle;
    final themeId = t.id as AppThemeId;
    final apple = themeId == AppThemeId.silverChrome;
    final cover = song.coverImageUrl;
    final divider = apple
        ? t.accent.withOpacity(0.18)
        : t.textPrimary.withOpacity(0.12);

    return InkWell(
      onTap: actions.onTap,
      onLongPress: actions.onLongPress,
      child: Semantics(
        button: true,
        selected: isNow,
        label: isNow && isPlaying ? '${song.title}, playing' : song.title,
        child: SizedBox(
          height: tileHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isNow ? t.accent.withOpacity(0.08) : Colors.transparent,
              border: Border(
                bottom: BorderSide(color: divider, width: 0.8),
              ),
            ),
            child: Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: tileHeight,
                      child: cover != null && cover.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: cover,
                              fit: BoxFit.cover,
                              cacheManager: AppCacheManager.instance,
                              memCacheWidth: 192,
                              memCacheHeight: 192,
                              placeholder: (context, url) => ColoredBox(
                                color: t.surface,
                                child: Icon(
                                  Icons.music_note,
                                  color: t.textSecondary,
                                ),
                              ),
                              errorWidget: (context, url, error) => ColoredBox(
                                color: t.surface,
                                child: Icon(
                                  Icons.music_note,
                                  color: t.textSecondary,
                                ),
                              ),
                            )
                          : ColoredBox(
                              color: t.surface,
                              child: Icon(
                                Icons.music_note,
                                color: t.textSecondary,
                              ),
                            ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              song.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: t.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _subtitleLine(subtitle, song),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: t.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (isNow)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 4,
                      color: t.accent,
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
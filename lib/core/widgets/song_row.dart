import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/formatters.dart';
import '../../models/song.dart';
import '../../services/app_cache_manager.dart';
import '../constants/themes/app_theme_id.dart';
import 'download_confirm.dart';

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
  final SongRowData data;
  final SongRowActions actions;
  final dynamic t;

  const SongRow({
    Key? key,
    required this.data,
    required this.actions,
    required this.t,
  }) : super(key: key);

  static double _radius(AppThemeId id) {
    switch (id) {
      case AppThemeId.cyberBlack:
        return 8;
      case AppThemeId.silverChrome:
        return 10;
      default:
        return 14;
    }
  }

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
    final isFav = data.isFav;
    final isDownloaded = data.isDownloaded;
    final isDownloading = data.isDownloading;
    final progress = data.progress;
    final subtitle = data.subtitle;
    final isLiked = data.isLiked;
    final themeId = t.id as AppThemeId;
    final radius = _radius(themeId);
    final deep = themeId == AppThemeId.cyberBlack;
    final apple = themeId == AppThemeId.silverChrome;

    final likeColor = isLiked
        ? (deep ? t.accent : const Color(0xFFFFD700))
        : t.textPrimary.withOpacity(0.75);
    final loveColor = isFav
        ? (deep ? t.accent : Colors.redAccent)
        : t.textPrimary.withOpacity(0.75);
    final dlColor = deep ? t.accent : t.textPrimary.withOpacity(0.75);

    return InkWell(
      onTap: actions.onTap,
      onLongPress: actions.onLongPress,
      child: Container(
        margin: EdgeInsets.zero,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: apple
                  ? t.accent.withOpacity(0.14)
                  : Colors.white.withOpacity(deep ? 0.12 : 0.14),
              width: 1,
            ),
          ),
        ),
        child: Stack(
          children: [
            Container(
              padding: (apple || deep)
                  ? const EdgeInsets.fromLTRB(0, 10, 8, 10)
                  : const EdgeInsets.fromLTRB(14, 15, 8, 10),
              decoration: BoxDecoration(
                color: apple
                    ? null
                    : (deep
                        ? (isNow ? const Color(0xFF1A140F) : Colors.transparent)
                        : (isNow
                            ? t.surface.withOpacity(0.45)
                            : Colors.transparent)),
                gradient: apple
                    ? LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isNow
                            ? const [Color(0xFF152018), Color(0xFF070A08)]
                            : const [Color(0xFF0C100D), Color(0xFF070A08)],
                      )
                    : null,
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: (apple || deep)
                      ? CrossAxisAlignment.stretch
                      : CrossAxisAlignment.center,
                  children: [
                    Semantics(
                      label: isNow && isPlaying ? 'Pause' : 'Play',
                      button: true,
                      child: Container(
                        width: apple ? 86 : (deep ? 72 : 65),
                        height: (apple || deep) ? null : 65,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                              radius - 2 < 0 ? 0 : radius - 2),
                          border: Border.all(
                            color: apple
                                ? t.accent.withOpacity(0.20)
                                : t.textPrimary.withOpacity(0.24),
                            width: apple ? 1 : 2,
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [t.surface, t.background],
                          ),
                        ),
                        child: (song.coverImageUrl != null &&
                                song.coverImageUrl!.isNotEmpty)
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(
                                    radius - 4 < 0 ? 0 : radius - 4),
                                child: CachedNetworkImage(
                                  imageUrl: song.coverImageUrl!,
                                  fit: BoxFit.cover,
                                  cacheManager: AppCacheManager.instance,
                                  memCacheWidth: 128,
                                  memCacheHeight: 128,
                                  placeholder: (context, url) => Icon(
                                    isNow && isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                    color: t.textPrimary,
                                  ),
                                  errorWidget: (context, url, error) => Icon(
                                    isNow && isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                    color: t.textPrimary,
                                  ),
                                ),
                              )
                            : Icon(
                                isNow && isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                color: t.textPrimary,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: apple
                          ? Column(
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
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!deep && isNow)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: t.textPrimary.withOpacity(0.20),
                                        borderRadius: BorderRadius.circular(
                                            radius - 6 < 4 ? 4 : radius - 6),
                                      ),
                                      child: Text(
                                        isPlaying ? 'Ⅱ NOW' : '▶ NOW',
                                        style: TextStyle(
                                          color: t.textPrimary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                                Text(
                                  song.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: t.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _subtitleLine(subtitle, song),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: t.textPrimary.withOpacity(0.70),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Row(
                                  children: [
                                    if (deep) ...[
                                      _DeepPlayButton(
                                        playing: isNow && isPlaying,
                                        onTap: actions.onTap,
                                      ),
                                    ],
                                    Semantics(
                                      label: isFav
                                          ? 'Remove from favorites'
                                          : 'Add to favorites',
                                      button: true,
                                      child: IconButton(
                                        icon: Icon(
                                          isFav
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          color: loveColor,
                                        ),
                                        onPressed: actions.onToggleFavorite,
                                      ),
                                    ),
                                    Semantics(
                                      label: isLiked
                                          ? 'Unlike song'
                                          : 'Like song',
                                      button: true,
                                      child: IconButton(
                                        icon: Icon(
                                          isLiked
                                              ? Icons.thumb_up
                                              : Icons.thumb_up_outlined,
                                          color: likeColor,
                                          size: 20,
                                        ),
                                        onPressed: actions.onToggleLike,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                            minWidth: 40, minHeight: 40),
                                      ),
                                    ),
                                    if (isDownloaded)
                                      Semantics(
                                        label: 'Remove download',
                                        button: true,
                                        child: IconButton(
                                          icon: Icon(Icons.check_circle,
                                              color: deep
                                                  ? t.accent
                                                  : const Color(0xFF4CD964)),
                                          onPressed: actions.onRemoveDownload,
                                        ),
                                      )
                                    else if (isDownloading)
                                      Semantics(
                                        label: 'Cancel download',
                                        button: true,
                                        child: GestureDetector(
                                          onTap: actions.onCancelDownload,
                                          child: SizedBox(
                                            width: 36,
                                            height: 36,
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                CircularProgressIndicator(
                                                  value: (progress > 0 &&
                                                          progress < 1)
                                                      ? progress
                                                      : null,
                                                  strokeWidth: 2.5,
                                                  color: t.textPrimary,
                                                ),
                                                if (progress > 0)
                                                  Text(
                                                    '${(progress * 100).round()}',
                                                    style: TextStyle(
                                                        fontSize: 8.5,
                                                        color: t.textPrimary),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      )
                                    else
                                      Semantics(
                                        label: 'Download song',
                                        button: true,
                                        child: IconButton(
                                          icon: Icon(
                                            Icons.download_outlined,
                                            color: dlColor,
                                          ),
                                          onPressed: () async {
                                            final ok = await confirmDownload(
                                                context, song.title);
                                            if (ok) actions.onDownload();
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                    ),
                    if (apple)
                      _AppleDownload(
                        isDownloaded: isDownloaded,
                        isDownloading: isDownloading,
                        progress: progress,
                        accent: t.accent,
                        text: t.textPrimary,
                        onDownload: () async {
                          final ok =
                              await confirmDownload(context, song.title);
                          if (ok) actions.onDownload();
                        },
                        onCancel: actions.onCancelDownload,
                        onRemove: actions.onRemoveDownload,
                      ),
                  ],
                ),
              ),
            ),
            if (isNow)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 4,
                  color: (deep || apple) ? t.accent : t.textPrimary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AppleDownload extends StatelessWidget {
  final bool isDownloaded;
  final bool isDownloading;
  final double progress;
  final Color accent;
  final Color text;
  final VoidCallback onDownload;
  final VoidCallback onCancel;
  final VoidCallback onRemove;

  const _AppleDownload({
    required this.isDownloaded,
    required this.isDownloading,
    required this.progress,
    required this.accent,
    required this.text,
    required this.onDownload,
    required this.onCancel,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (isDownloaded) {
      return IconButton(
        tooltip: 'Remove download',
        onPressed: onRemove,
        icon: Icon(Icons.check_circle, color: accent),
      );
    }
    if (isDownloading) {
      return GestureDetector(
        onTap: onCancel,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: (progress > 0 && progress < 1) ? progress : null,
                strokeWidth: 2.5,
                color: accent,
              ),
              if (progress > 0)
                Text(
                  '${(progress * 100).round()}',
                  style: TextStyle(fontSize: 8.5, color: text),
                ),
            ],
          ),
        ),
      );
    }
    return IconButton(
      tooltip: 'Download song',
      onPressed: onDownload,
      icon: Icon(Icons.download_outlined, color: accent, size: 26),
    );
  }
}

class _DeepPlayButton extends StatelessWidget {
  final bool playing;
  final VoidCallback onTap;

  const _DeepPlayButton({required this.playing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: playing ? 'Pause' : 'Play',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: playing ? const Color(0xFFFF6600) : Colors.white,
            border: Border.all(color: const Color(0xFFFF6600), width: 2),
          ),
          child: Icon(
            playing ? Icons.pause : Icons.play_arrow,
            color: playing ? Colors.black : const Color(0xFFFF6600),
            size: 20,
          ),
        ),
      ),
    );
  }
}
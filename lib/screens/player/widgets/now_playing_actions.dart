import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/song.dart';
import '../../../providers/favorites_provider.dart';
import '../../../providers/downloads_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../providers/sleep_timer_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/likes_provider.dart';
import '../../../core/constants/themes/app_theme_id.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/home_nav.dart';
import '../../../core/widgets/download_confirm.dart';
import '../../../core/widgets/mewati_bass_button.dart';
import '../../../routes/route_names.dart';
import '../../../services/equalizer_service.dart';
import '../../../services/eq_presets.dart';

class NowPlayingActions extends StatelessWidget {
  final Song song;
  final VoidCallback onTimerTap;
  final VoidCallback onEqualizerTap;

  const NowPlayingActions({
    Key? key,
    required this.song,
    required this.onTimerTap,
    required this.onEqualizerTap,
  }) : super(key: key);

  static Future<void> _toggleMewatiBass(BuildContext context) async {
    final theme = context.read<ThemeProvider>();
    final turningOn = !theme.mewatiBassOn;
    await theme.toggleMewatiBass();
    if (!context.mounted || !turningOn) return;
    if (await EqualizerService().shouldHintHeadphones('mewati-bass')) {
      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(
          content: Text(EqPresets.headphoneHint),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  static void _showFailureSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.grey),
    );
  }

  static Future<void> _toggleFavorite(
      BuildContext context, FavoritesProvider favoritesProvider, Song song) async {
    await favoritesProvider.toggleFavorite(song);
    if (!context.mounted) return;
    if (favoritesProvider.errorMessage != null) {
      _showFailureSnackBar(context, 'Something went wrong. Please try again.');
      favoritesProvider.clearError();
    }
  }

  static Future<void> _toggleLike(
      BuildContext context, LikesProvider likesProvider, String songId) async {
    await likesProvider.toggleLike(songId);
    if (!context.mounted) return;
    if (likesProvider.errorMessage != null) {
      _showFailureSnackBar(context, 'Something went wrong. Please try again.');
    }
  }

  static Future<void> _confirmRemoveDownload(
    BuildContext context,
    DownloadsProvider downloadsProvider,
    Song song,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove download?'),
        content: Text('"${song.title}" will be deleted from your downloads.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    final success = await downloadsProvider.removeDownload(
      song.id,
      audioUrl: song.audioUrl,
    );
    if (!context.mounted) return;
    if (!success) {
      _showFailureSnackBar(context, 'Failed to remove download');
    }
  }

  @override
  Widget build(BuildContext context) {
    final favoritesProvider = context.watch<FavoritesProvider>();
    final downloadsProvider = context.watch<DownloadsProvider>();
    final sleepTimerProvider = context.watch<SleepTimerProvider>();
    final likesProvider = context.watch<LikesProvider>();
    final playerProvider = context.watch<PlayerProvider>();
    final t = context.watch<ThemeProvider>().theme;
    final bassOn = context.watch<ThemeProvider>().mewatiBassOn;

    final isFav = favoritesProvider.isFavoriteSync(song.id);
    final isDownloaded = downloadsProvider.isDownloaded(song.id);
    final isDownloading = downloadsProvider.isDownloading(song.id);
    final isTimerActive = sleepTimerProvider.isActive;
    final isLiked = likesProvider.isLikedSync(song.id);
    final isShuffleOn = playerProvider.shuffleMode;
    final likeCount = likesProvider.likeCounts.containsKey(song.id)
        ? likesProvider.getLikeCountSync(song.id)
        : song.likeCount;

    if (t.id == AppThemeId.silverChrome) {
      return _appleRow(
        context: context,
        t: t,
        song: song,
        isFav: isFav,
        isDownloaded: isDownloaded,
        isDownloading: isDownloading,
        isTimerActive: isTimerActive,
        isLiked: isLiked,
        isShuffleOn: isShuffleOn,
        likeCount: likeCount,
        favoritesProvider: favoritesProvider,
        downloadsProvider: downloadsProvider,
        likesProvider: likesProvider,
        playerProvider: playerProvider,
      );
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(
              isFav ? Icons.favorite : Icons.favorite_border,
              color: isFav ? Colors.redAccent : t.textPrimary.withOpacity(0.75),
              size: 22,
            ),
            onPressed: () => _toggleFavorite(context, favoritesProvider, song),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: MewatiBassButton(
              size: 34,
              active: bassOn,
              onPressed: () => _toggleMewatiBass(context),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                  color: isLiked
                      ? const Color(0xFFFFD700)
                      : t.textPrimary.withOpacity(0.75),
                  size: 22,
                ),
                onPressed: () => _toggleLike(context, likesProvider, song.id),
              ),
              Text(
                formatCount(likeCount),
                style: TextStyle(
                  color: t.textPrimary.withOpacity(0.75),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Semantics(
            label: 'Shuffle',
            button: true,
            child: IconButton(
              icon: Icon(
                Icons.shuffle,
                color: isShuffleOn ? t.accent : t.textPrimary.withOpacity(0.75),
                size: 22,
              ),
              onPressed: () => playerProvider.toggleShuffle(),
            ),
          ),
          const SizedBox(width: 14),
          if (isDownloaded)
            IconButton(
              icon: const Icon(Icons.check_circle,
                  color: Color(0xFF4CD964), size: 22),
              onPressed: () =>
                  _confirmRemoveDownload(context, downloadsProvider, song),
            )
          else if (isDownloading)
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => downloadsProvider.cancelDownload(song.id),
              child: SizedBox(
                width: 36,
                height: 36,
                child: ValueListenableBuilder<Map<String, double>>(
                  valueListenable: downloadsProvider.progressNotifier,
                  builder: (context, progressMap, _) {
                    final progress = progressMap[song.id] ?? 0.0;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 2.5,
                          color: t.textPrimary,
                        ),
                        Text(
                          '${(progress * 100).round()}',
                          style: TextStyle(fontSize: 8.5, color: t.textPrimary),
                        ),
                      ],
                    );
                  },
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.download_outlined,
                  color: t.textPrimary.withOpacity(0.75), size: 22),
              onPressed: () async {
                final ok = await confirmDownload(context, song.title);
                if (!ok || !context.mounted) return;
                try {
                  await downloadsProvider.downloadSong(song);
                } catch (e) {
                  if (!context.mounted) return;
                  _showFailureSnackBar(
                      context, 'Download failed. Please try again.');
                }
              },
            ),
          const SizedBox(width: 14),
          IconButton(
            icon: Icon(
              Icons.timer_outlined,
              color: isTimerActive ? t.accent : t.textPrimary.withOpacity(0.75),
              size: 22,
            ),
            onPressed: onTimerTap,
          ),
          const SizedBox(width: 14),
          IconButton(
            icon: Icon(Icons.equalizer,
                color: t.textPrimary.withOpacity(0.75), size: 22),
            onPressed: onEqualizerTap,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.queue_music,
                color: t.textPrimary.withOpacity(0.75), size: 22),
            tooltip: 'Playing list',
            onPressed: () => HomeNav.showCurrentSongInList(song.id),
          ),
        ],
      ),
    );
  }

  Widget _appleRow({
    required BuildContext context,
    required dynamic t,
    required Song song,
    required bool isFav,
    required bool isDownloaded,
    required bool isDownloading,
    required bool isTimerActive,
    required bool isLiked,
    required bool isShuffleOn,
    required int likeCount,
    required FavoritesProvider favoritesProvider,
    required DownloadsProvider downloadsProvider,
    required LikesProvider likesProvider,
    required PlayerProvider playerProvider,
  }) {
    final muted = t.textPrimary.withOpacity(0.85);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(
            isFav ? Icons.favorite : Icons.favorite_border,
            color: isFav ? Colors.redAccent : muted,
            size: 24,
          ),
          onPressed: () => _toggleFavorite(context, favoritesProvider, song),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: MewatiBassButton(
            size: 34,
            active: context.watch<ThemeProvider>().mewatiBassOn,
            onPressed: () => _toggleMewatiBass(context),
          ),
        ),
        _downloadButton(
            context, t, song, isDownloaded, isDownloading, downloadsProvider),
        IconButton(
          icon: Icon(Icons.drive_eta, color: muted, size: 24),
          tooltip: 'Drive Mode',
          onPressed: () => Navigator.of(context).pushNamed(RouteNames.driveMode),
        ),
        IconButton(
          icon: Icon(Icons.more_horiz, color: muted, size: 26),
          tooltip: 'More',
          onPressed: () => _showAppleOverflow(
            context: context,
            t: t,
            song: song,
            isLiked: isLiked,
            isShuffleOn: isShuffleOn,
            isTimerActive: isTimerActive,
            likeCount: likeCount,
            likesProvider: likesProvider,
            playerProvider: playerProvider,
          ),
        ),
      ],
    );
  }

  Widget _downloadButton(
    BuildContext context,
    dynamic t,
    Song song,
    bool isDownloaded,
    bool isDownloading,
    DownloadsProvider downloadsProvider,
  ) {
    if (isDownloaded) {
      return IconButton(
        icon: const Icon(Icons.check_circle, color: Color(0xFF4CD964), size: 24),
        onPressed: () =>
            _confirmRemoveDownload(context, downloadsProvider, song),
      );
    }
    if (isDownloading) {
      return InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => downloadsProvider.cancelDownload(song.id),
        child: SizedBox(
          width: 36,
          height: 36,
          child: ValueListenableBuilder<Map<String, double>>(
            valueListenable: downloadsProvider.progressNotifier,
            builder: (context, progressMap, _) {
              final progress = progressMap[song.id] ?? 0.0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 2.5,
                    color: t.textPrimary,
                  ),
                  Text(
                    '${(progress * 100).round()}',
                    style: TextStyle(fontSize: 8.5, color: t.textPrimary),
                  ),
                ],
              );
            },
          ),
        ),
      );
    }
    return IconButton(
      icon: Icon(Icons.download_outlined,
          color: t.textPrimary.withOpacity(0.85), size: 24),
      onPressed: () async {
        final ok = await confirmDownload(context, song.title);
        if (!ok || !context.mounted) return;
        try {
          await downloadsProvider.downloadSong(song);
        } catch (e) {
          if (!context.mounted) return;
          _showFailureSnackBar(context, 'Download failed. Please try again.');
        }
      },
    );
  }

  void _showAppleOverflow({
    required BuildContext context,
    required dynamic t,
    required Song song,
    required bool isLiked,
    required bool isShuffleOn,
    required bool isTimerActive,
    required int likeCount,
    required LikesProvider likesProvider,
    required PlayerProvider playerProvider,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: t.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (sheet) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                    color: isLiked ? const Color(0xFFFFD700) : t.textPrimary,
                  ),
                  title: Text(
                    isLiked
                        ? 'Unlike  ·  ${formatCount(likeCount)}'
                        : 'Like  ·  ${formatCount(likeCount)}',
                    style: TextStyle(
                        color: t.textPrimary, fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(sheet);
                    _toggleLike(context, likesProvider, song.id);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.shuffle,
                      color: isShuffleOn ? t.accent : t.textPrimary),
                  title: Text(
                    isShuffleOn ? 'Shuffle on' : 'Shuffle',
                    style: TextStyle(
                        color: t.textPrimary, fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(sheet);
                    playerProvider.toggleShuffle();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.timer_outlined,
                      color: isTimerActive ? t.accent : t.textPrimary),
                  title: Text('Sleep timer',
                      style: TextStyle(
                          color: t.textPrimary, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(sheet);
                    onTimerTap();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.equalizer, color: t.textPrimary),
                  title: Text('Sound Effect',
                      style: TextStyle(
                          color: t.textPrimary, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(sheet);
                    onEqualizerTap();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.queue_music, color: t.textPrimary),
                  title: Text('Playing list',
                      style: TextStyle(
                          color: t.textPrimary, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(sheet);
                    HomeNav.showCurrentSongInList(song.id);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
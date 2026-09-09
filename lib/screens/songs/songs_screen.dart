import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/loading_widget.dart';
import '../../core/widgets/error_widget.dart';
import '../../core/widgets/song_row.dart';
import '../../core/utils/home_nav.dart';
import '../../models/song.dart';
import '../../providers/songs_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/downloads_provider.dart';
import '../../providers/likes_provider.dart';
import '../../providers/theme_provider.dart';
import '../../routes/route_names.dart';

class SongsScreen extends StatefulWidget {
  const SongsScreen({Key? key}) : super(key: key);

  @override
  State<SongsScreen> createState() => _SongsScreenState();
}

class _SongsScreenState extends State<SongsScreen> {
  final ScrollController _scrollController = ScrollController();
  SongsProvider? _songsProvider;
  String? _loadMoreError;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final songsProvider = Provider.of<SongsProvider>(context, listen: false);
      _songsProvider = songsProvider;
      songsProvider.addListener(_onSongsChanged);

      if (songsProvider.allSongs.isEmpty) {
        songsProvider.loadSongs().then((_) {
          if (!mounted) return;
          _loadLikesForCurrentSongs();
        });
      } else {
        _loadLikesForCurrentSongs();
      }
    });

    _scrollController.addListener(_onScroll);
    HomeNav.revealSongId.addListener(_onRevealSong);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onRevealSong();
    });
  }

  void _onSongsChanged() {
    if (!mounted) return;
    _loadLikesForCurrentSongs();
  }

  void _loadLikesForCurrentSongs() {
    final songsProvider = Provider.of<SongsProvider>(context, listen: false);
    if (songsProvider.allSongs.isEmpty) return;
    Provider.of<LikesProvider>(context, listen: false)
        .loadLikesData(songsProvider.allSongs);
  }

  @override
  void dispose() {
    HomeNav.revealSongId.removeListener(_onRevealSong);
    _songsProvider?.removeListener(_onSongsChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _onRevealSong() async {
    final id = HomeNav.revealSongId.value;
    if (id == null || !mounted) return;
    final songsProvider = Provider.of<SongsProvider>(context, listen: false);
    var index = songsProvider.allSongs.indexWhere((s) => s.id == id);
    var guard = 0;
    while (index < 0 && songsProvider.hasMore && guard < 24) {
      guard++;
      await songsProvider.loadMoreSongs();
      if (!mounted) return;
      index = songsProvider.allSongs.indexWhere((s) => s.id == id);
    }
    if (index < 0) {
      HomeNav.revealSongId.value = null;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = (index * SongRow.tileHeight).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOut,
      );
      HomeNav.revealSongId.value = null;
    });
  }

  Future<void> _loadMore() async {
    final songsProvider = Provider.of<SongsProvider>(context, listen: false);
    await songsProvider.loadMoreSongs();
    if (!mounted) return;
    if (songsProvider.errorMessage != null) {
      setState(() => _loadMoreError = songsProvider.errorMessage);
      songsProvider.clearError();
    } else if (_loadMoreError != null) {
      setState(() => _loadMoreError = null);
    }
  }

  void _playSong(List<Song> songs, int index) {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final tappedSong = songs[index];
    if (playerProvider.currentSong?.id == tappedSong.id) {
      playerProvider.togglePlayPause();
      return;
    }
    playerProvider.setPlaylist(
      songs: songs,
      startIndex: index,
    );
  }

  void _openFeedback(Song song) {
    Navigator.of(context).pushNamed(RouteNames.feedback, arguments: song);
  }

  void _showFailureSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.grey),
    );
  }

  Future<void> _toggleFavorite(Song song) async {
    final favoritesProvider =
        Provider.of<FavoritesProvider>(context, listen: false);
    await favoritesProvider.toggleFavorite(song);
    if (!mounted) return;
    if (favoritesProvider.errorMessage != null) {
      _showFailureSnackBar('Something went wrong. Please try again.');
      favoritesProvider.clearError();
    }
  }

  Future<void> _toggleLike(String songId) async {
    final likesProvider = Provider.of<LikesProvider>(context, listen: false);
    await likesProvider.toggleLike(songId);
    if (!mounted) return;
    if (likesProvider.errorMessage != null) {
      _showFailureSnackBar('Something went wrong. Please try again.');
    }
  }

  Future<void> _downloadSong(Song song) async {
    try {
      await Provider.of<DownloadsProvider>(context, listen: false)
          .downloadSong(song);
    } catch (e) {
      if (!mounted) return;
      _showFailureSnackBar('Failed to download song. Please try again.');
    }
  }

  void _cancelDownload(String songId) {
    Provider.of<DownloadsProvider>(context, listen: false).cancelDownload(songId);
  }

  Future<void> _confirmAndRemoveDownload(Song song) async {
    final t = Provider.of<ThemeProvider>(context, listen: false).theme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: t.surface,
        title: Text('Delete download?', style: TextStyle(color: t.textPrimary)),
        content: Text(
          'This will remove "${song.title}" from your downloads.',
          style: TextStyle(color: t.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancel', style: TextStyle(color: t.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFE53935))),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _removeDownload(song);
    }
  }

  Future<void> _removeDownload(Song song) async {
    final downloadsProvider =
        Provider.of<DownloadsProvider>(context, listen: false);
    final success = await downloadsProvider.removeDownload(
      song.id,
      audioUrl: song.audioUrl,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Removed from downloads' : 'Failed to remove download',
        ),
        backgroundColor: success ? const Color(0xFFE53935) : Colors.grey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final songsProvider = context.watch<SongsProvider>();
    final t = context.watch<ThemeProvider>().theme;

    final currentSongId = context.select<PlayerProvider, String?>(
      (p) => p.currentSong?.id,
    );
    final isPlaying = context.select<PlayerProvider, bool>(
      (p) => p.isPlaying,
    );

    final downloadsProvider =
        Provider.of<DownloadsProvider>(context, listen: false);

    if (songsProvider.isLoading && songsProvider.allSongs.isEmpty) {
      return const LoadingWidget(message: AppStrings.loading);
    }

    if (songsProvider.errorMessage != null && songsProvider.allSongs.isEmpty) {
      return AppErrorWidget(
        error: songsProvider.errorMessage,
        onRetry: () => songsProvider.loadSongs(),
      );
    }

    if (songsProvider.filteredSongs.isEmpty && !songsProvider.isLoading) {
      return Center(
        child: Text(AppStrings.noSongsFound,
            style: TextStyle(color: t.textSecondary)),
      );
    }

    final songs = songsProvider.filteredSongs;

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.only(bottom: 16),
      itemCount: songs.length +
          (songsProvider.isLoadingMore || _loadMoreError != null ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == songs.length) {
          if (songsProvider.isLoadingMore) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (_loadMoreError != null) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Text(
                    _loadMoreError!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: t.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _loadMore,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        }

        final song = songs[index];
        final isNow = currentSongId == song.id;
        final isFav = context.select<FavoritesProvider, bool>(
          (p) => p.isFavoriteSync(song.id),
        );
        final isDownloaded = context.select<DownloadsProvider, bool>(
          (p) => p.isDownloaded(song.id),
        );
        final isLiked = context.select<LikesProvider, bool>(
          (p) => p.isLikedSync(song.id),
        );
        final likeCount = context.select<LikesProvider, int>(
          (p) => p.likeCounts.containsKey(song.id)
              ? p.getLikeCountSync(song.id)
              : song.likeCount,
        );

        return ValueListenableBuilder<Map<String, double>>(
          valueListenable: downloadsProvider.progressNotifier,
          builder: (context, progressMap, _) {
            final isDownloading = progressMap.containsKey(song.id);
            final progress = progressMap[song.id] ?? 0.0;

            return SongRow(
              t: t,
              data: SongRowData(
                song: song,
                isNow: isNow,
                isPlaying: isPlaying,
                isFav: isFav,
                isDownloaded: isDownloaded,
                isDownloading: isDownloading,
                progress: progress,
                subtitle: song.singerName ?? 'Unknown Artist',
                isLiked: isLiked,
                likeCount: likeCount,
              ),
              actions: SongRowActions(
                onTap: () => _playSong(songs, index),
                onToggleFavorite: () => _toggleFavorite(song),
                onDownload: () => _downloadSong(song),
                onCancelDownload: () => _cancelDownload(song.id),
                onRemoveDownload: () => _confirmAndRemoveDownload(song),
                onToggleLike: () => _toggleLike(song.id),
                onLongPress: () => _openFeedback(song),
              ),
            );
          },
        );
      },
    );
  }
}
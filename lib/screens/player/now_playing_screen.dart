import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/app_drawer.dart';
import '../../models/song.dart';
import '../../providers/player_provider.dart';
import '../../providers/theme_provider.dart';
import '../../routes/route_names.dart';
import '../../services/cover_color_service.dart';
import 'widgets/album_art.dart';
import 'widgets/now_playing_actions.dart';
import 'widgets/player_controls.dart';
import 'widgets/seek_bar.dart';
import 'widgets/sleep_timer_sheet.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({Key? key}) : super(key: key);

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _drawerEpoch = 0;
  String? _boundId;
  String? _boundCover;
  Color? _artColor;

  void _openSleepTimerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const SleepTimerSheet(),
    );
  }

  void _openEqualizerSettings() {
    Navigator.of(context).pushNamed(RouteNames.soundSettings);
  }

  void _bindSong(Song? song) {
    if (song == null) {
      if (_boundId != null || _artColor != null) {
        setState(() {
          _boundId = null;
          _boundCover = null;
          _artColor = null;
        });
      }
      return;
    }
    final same = _boundId == song.id && _boundCover == song.coverImageUrl;
    if (same && _artColor != null) return;

    final mem = CoverColorService.instance.cached(song.id, song.coverImageUrl);
    _boundId = song.id;
    _boundCover = song.coverImageUrl;
    if (mem != null) {
      if (_artColor != mem) {
        setState(() => _artColor = mem);
      }
      return;
    }

    CoverColorService.instance
        .colorFor(songId: song.id, coverUrl: song.coverImageUrl)
        .then((c) {
      if (!mounted || c == null) return;
      if (_boundId != song.id) return;
      setState(() => _artColor = c);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>().theme;
    final song = context.select<PlayerProvider, Song?>((p) => p.currentSong);
    final errorMessage =
        context.select<PlayerProvider, String?>((p) => p.errorMessage);

    _bindSong(song);

    final top = _artColor != null
        ? CoverColorService.backdrop(_artColor!, t.screenGradient.first)
        : t.screenGradient.first;
    final bottom = _artColor != null
        ? CoverColorService.backdropDeep(_artColor!, t.screenGradient.last)
        : t.screenGradient.last;

    if (song == null) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: t.screenGradient,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.chevron_left,
                            color: t.textPrimary, size: 28),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      Text(
                        'NOW PLAYING',
                        style: TextStyle(
                          color: t.textPrimary.withOpacity(0.75),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 34),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text('No song selected',
                        style: TextStyle(color: t.textSecondary)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: AppDrawer(key: ValueKey(_drawerEpoch)),
      onDrawerChanged: (open) {
        if (!open) setState(() => _drawerEpoch++);
      },
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [top, bottom],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.chevron_left,
                          color: t.textPrimary, size: 28),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    Text(
                      'NOW PLAYING',
                      style: TextStyle(
                        color: t.textPrimary.withOpacity(0.75),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 34),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AlbumArt(song: song, t: t),
                            const SizedBox(height: 22),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: Text(
                                song.title,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: t.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: Text(
                                song.singerName ?? 'Unknown Artist',
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: t.textPrimary.withOpacity(0.72),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 10),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.error_outline,
                                              color: Colors.redAccent,
                                              size: 18),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Unable to play this song',
                                              style: TextStyle(
                                                color: Colors.redAccent,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        errorMessage,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color:
                                              t.textPrimary.withOpacity(0.75),
                                          fontSize: 12,
                                        ),
                                      ),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton.icon(
                                          onPressed: () {
                                            final playerProvider =
                                                context.read<PlayerProvider>();
                                            playerProvider.clearError();
                                            playerProvider.togglePlayPause();
                                          },
                                          icon: const Icon(Icons.refresh,
                                              size: 16),
                                          label: const Text('Retry'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            NowPlayingActions(
                              song: song,
                              onTimerTap: _openSleepTimerSheet,
                              onEqualizerTap: _openEqualizerSettings,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 26),
                child: SeekBar(),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 26),
                child: PlayerControls(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
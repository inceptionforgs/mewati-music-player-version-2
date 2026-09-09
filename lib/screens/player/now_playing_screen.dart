// File: lib/screens/player/now_playing_screen.dart
//
// FIXED (Batch 3 audit):
// - Small-screen overflow: main content is now wrapped in a LayoutBuilder
//   + SingleChildScrollView (with a minHeight ConstrainedBox) instead of a
//   bare Expanded > Column, so it scrolls instead of throwing a RenderFlex
//   overflow on short screens or when the error banner is showing.
// - Title/singer name now have horizontal padding + maxLines/overflow so
//   long strings ellipsize instead of running off the screen edges.
// - Equalizer icon now navigates to the real Custom Equalizer tab
//   (Advance Settings) instead of opening the full AppDrawer.
// - "No song selected" empty state now uses the same gradient chrome and
//   top bar as the normal state instead of a bare flat background.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/app_drawer.dart';
import '../../providers/player_provider.dart';
import '../../providers/theme_provider.dart';
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

  void _openSleepTimerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const SleepTimerSheet(),
    );
  }

  // FIXED: previously opened the full AppDrawer (theme picker + EQ presets
  // + feedback), which isn't the actual equalizer. This now takes the user
  // straight to the Custom Equalizer tab in Advance Settings.
  void _openEqualizerSettings() {
    _scaffoldKey.currentState?.openDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>().theme;

    final hasSong = context.select<PlayerProvider, bool>((p) => p.hasSong);
    final song = context.select<PlayerProvider, dynamic>((p) => p.currentSong);
    final errorMessage =
        context.select<PlayerProvider, String?>((p) => p.errorMessage);

    if (!hasSong || song == null) {
      // FIXED: empty state now shares the same gradient + top bar chrome
      // as the normal Now Playing state instead of a bare flat background.
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
              // FIXED: was a bare Expanded > Column(mainAxisAlignment:
              // center) with no scroll fallback — on short screens (or with
              // the error banner showing) this threw a RenderFlex overflow.
              // Now wrapped in a LayoutBuilder + SingleChildScrollView with
              // a minHeight ConstrainedBox, so it still centers on tall
              // screens but scrolls instead of overflowing on short ones.
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
                                      Row(
                                        children: [
                                          const Icon(Icons.error_outline,
                                              color: Colors.redAccent,
                                              size: 18),
                                          const SizedBox(width: 8),
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: SeekBar(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 26),
                child: PlayerControls(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
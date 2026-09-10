import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/player_provider.dart';
import '../../../../providers/theme_provider.dart';

class SilverChromePlayerControls extends StatelessWidget {
  const SilverChromePlayerControls({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final playerProvider = context.watch<PlayerProvider>();
    final t = context.watch<ThemeProvider>().theme;
    final isLoading = context.select<PlayerProvider, bool>((p) => p.isLoading);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Semantics(
          button: true,
          label: 'Previous',
          child: IconButton(
            icon: Icon(Icons.skip_previous, color: t.textPrimary, size: 32),
            onPressed: () => playerProvider.previous(),
          ),
        ),
        const SizedBox(width: 22),
        Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: t.textPrimary, width: 2),
            color: t.textPrimary.withOpacity(0.08),
          ),
          child: Semantics(
            button: true,
            label: playerProvider.isPlaying ? 'Pause' : 'Play',
            child: isLoading
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(t.textPrimary),
                    ),
                  )
                : IconButton(
                    icon: Icon(
                      playerProvider.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: t.textPrimary,
                      size: 28,
                    ),
                    iconSize: 28,
                    padding: EdgeInsets.zero,
                    onPressed: () => playerProvider.togglePlayPause(),
                  ),
          ),
        ),
        const SizedBox(width: 22),
        Semantics(
          button: true,
          label: 'Next',
          child: IconButton(
            icon: Icon(Icons.skip_next, color: t.textPrimary, size: 32),
            onPressed: () => playerProvider.next(),
          ),
        ),
      ],
    );
  }
}
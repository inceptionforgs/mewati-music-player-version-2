import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mewati_tune_player/core/constants/themes/app_theme_id.dart';
import 'package:mewati_tune_player/core/widgets/song_row.dart';
import 'package:mewati_tune_player/models/song.dart';

class _FakeTheme {
  final Color surface = Colors.grey;
  final Color textPrimary = Colors.white;
  final Color textSecondary = Colors.white70;
  final Color accent = Colors.deepOrange;
  final Color background = Colors.black;
  final AppThemeId id = AppThemeId.walkmanOrange;
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  final song = Song(
    id: 's1',
    title: 'Test Song',
    audioUrl: 'https://example.com/a.mp3',
  );

  testWidgets('shows title and keeps action icons off the row', (tester) async {
    await tester.pumpWidget(_wrap(SongRow(
      t: _FakeTheme(),
      data: SongRowData(
        song: song,
        isNow: true,
        isPlaying: true,
        isFav: false,
        isDownloaded: false,
        isDownloading: false,
        progress: 0,
        isLiked: false,
        likeCount: 3,
      ),
      actions: SongRowActions(
        onTap: () {},
        onToggleFavorite: () {},
        onDownload: () {},
        onCancelDownload: () {},
        onRemoveDownload: () {},
        onToggleLike: () {},
      ),
    )));

    expect(find.text('Test Song'), findsOneWidget);
    expect(find.text('Ⅱ NOW'), findsNothing);
    expect(find.byIcon(Icons.thumb_up_outlined), findsNothing);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
    expect(find.byIcon(Icons.download_outlined), findsNothing);
  });

  testWidgets('liked and favorited state does not put icons on the row',
      (tester) async {
    await tester.pumpWidget(_wrap(SongRow(
      t: _FakeTheme(),
      data: SongRowData(
        song: song,
        isNow: false,
        isPlaying: false,
        isFav: true,
        isDownloaded: true,
        isDownloading: false,
        progress: 0,
        isLiked: true,
        likeCount: 5,
      ),
      actions: SongRowActions(
        onTap: () {},
        onToggleFavorite: () {},
        onDownload: () {},
        onCancelDownload: () {},
        onRemoveDownload: () {},
        onToggleLike: () {},
      ),
    )));

    expect(find.text('Test Song'), findsOneWidget);
    expect(find.byIcon(Icons.thumb_up), findsNothing);
    expect(find.byIcon(Icons.favorite), findsNothing);
    expect(find.byIcon(Icons.check_circle), findsNothing);
  });

  testWidgets('tapping the row invokes onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_wrap(SongRow(
      t: _FakeTheme(),
      data: SongRowData(
        song: song,
        isNow: false,
        isPlaying: false,
        isFav: false,
        isDownloaded: false,
        isDownloading: false,
        progress: 0,
        isLiked: false,
        likeCount: 0,
      ),
      actions: SongRowActions(
        onTap: () => tapped = true,
        onToggleFavorite: () {},
        onDownload: () {},
        onCancelDownload: () {},
        onRemoveDownload: () {},
        onToggleLike: () {},
      ),
    )));

    await tester.tap(find.text('Test Song'));
    expect(tapped, isTrue);
  });
}
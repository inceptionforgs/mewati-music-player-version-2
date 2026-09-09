import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mewati_tune_player/core/constants/themes/app_theme_id.dart';
import 'package:mewati_tune_player/models/song.dart';
import 'package:mewati_tune_player/providers/downloads_provider.dart';
import 'package:mewati_tune_player/providers/favorites_provider.dart';
import 'package:mewati_tune_player/providers/likes_provider.dart';
import 'package:mewati_tune_player/providers/player_provider.dart';
import 'package:mewati_tune_player/screens/search/widgets/search_result_row.dart';

class _FakeTheme {
  final Color surface = Colors.grey;
  final Color textPrimary = Colors.white;
  final Color textSecondary = Colors.white70;
  final Color accent = Colors.deepOrange;
  final Color background = Colors.black;
  final AppThemeId id = AppThemeId.walkmanOrange;
}

void main() {
  final songs = [
    Song(id: '1', title: 'One', audioUrl: 'https://example.com/1.mp3', singerName: 'Singer A'),
    Song(id: '2', title: 'Two', audioUrl: 'https://example.com/2.mp3', singerName: 'Singer B'),
  ];

  Widget buildApp(Song song, int index) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => DownloadsProvider()),
        ChangeNotifierProvider(create: (_) => LikesProvider()),
        ChangeNotifierProvider(create: (_) => PlayerProvider(autoInit: false)),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SearchResultRow(
            song: song,
            t: _FakeTheme(),
            allResults: songs,
            index: index,
          ),
        ),
      ),
    );
  }

  testWidgets('renders the given song title and singer name for its index', (tester) async {
    await tester.pumpWidget(buildApp(songs[1], 1));
    await tester.pump();

    expect(find.text('Two'), findsOneWidget);
    expect(find.text('Singer B'), findsOneWidget);
  });

  testWidgets('renders a different result correctly for a different index', (tester) async {
    await tester.pumpWidget(buildApp(songs[0], 0));
    await tester.pump();

    expect(find.text('One'), findsOneWidget);
    expect(find.text('Singer A'), findsOneWidget);
    expect(find.text('Two'), findsNothing);
  });
}
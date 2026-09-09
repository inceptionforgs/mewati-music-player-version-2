import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_themes.dart';
import '../../core/utils/debouncer.dart';
import '../../core/widgets/error_widget.dart';
import '../../models/song.dart';
import '../../models/singer.dart';
import '../../providers/songs_provider.dart';
import '../../providers/likes_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/app_cache_manager.dart';
import '../../services/singers_service.dart';
import '../singers/singer_profile_screen.dart';
import 'widgets/search_result_row.dart';

enum _SearchItemType { singerHeader, singerRow, songHeader, songRow }

class _SearchListItem {
  final _SearchItemType type;
  final int index;
  const _SearchListItem(this.type, [this.index = 0]);
}

double _cardRadius(AppThemeId id) {
  switch (id) {
    case AppThemeId.cyberBlack:
      return 4;
    case AppThemeId.silverChrome:
      return 10;
    default:
      return 14;
  }
}

class SearchScreen extends StatefulWidget {
  final String? initialQuery;

  const SearchScreen({Key? key, this.initialQuery}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Debouncer _debouncer =
      Debouncer(delay: const Duration(milliseconds: 300));
  final SingersService _singersService = SingersService();

  List<Song> _songResults = [];
  List<Singer> _singerResults = [];
  List<_SearchListItem> _items = const [];
  bool _isSearching = false;
  bool _isLoading = false;
  int _searchGeneration = 0;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    final seed = widget.initialQuery?.trim();
    if (seed != null && seed.isNotEmpty) {
      _searchController.text = seed;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _performSearch(seed);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debouncer.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    _debouncer.run(() {
      if (!mounted) return;
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    final term = query.trim();
    if (term.isEmpty) {
      _searchGeneration++;
      if (!mounted) return;
      setState(() {
        _songResults = [];
        _singerResults = [];
        _items = const [];
        _isSearching = false;
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    final gen = ++_searchGeneration;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final songsProvider = context.read<SongsProvider>();

      List<Song> songs = const [];
      List<Singer> singers = const [];
      Object? songErr;
      Object? singerErr;

      try {
        songs = await songsProvider.searchSongsRemote(term);
      } catch (e) {
        songErr = e;
        songs = songsProvider.searchSongsLocal(term);
      }

      try {
        singers = await _singersService.searchSingers(term);
      } catch (e) {
        singerErr = e;
      }

      if (!mounted || gen != _searchGeneration) return;

      if (songErr != null && singerErr != null && songs.isEmpty && singers.isEmpty) {
        setState(() {
          _songResults = [];
          _singerResults = [];
          _items = const [];
          _isSearching = true;
          _isLoading = false;
          _errorMessage = songErr.toString();
        });
        return;
      }

      setState(() {
        _songResults = songs;
        _singerResults = singers;
        _items = _flatten(singers, songs);
        _isSearching = true;
        _isLoading = false;
        _errorMessage = null;
      });

      final likesProvider = Provider.of<LikesProvider>(context, listen: false);
      likesProvider.loadLikesData(_songResults);
    } catch (e) {
      if (!mounted || gen != _searchGeneration) return;
      setState(() {
        _songResults = [];
        _singerResults = [];
        _items = const [];
        _isSearching = true;
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  List<_SearchListItem> _flatten(List<Singer> singers, List<Song> songs) {
    final items = <_SearchListItem>[];
    if (singers.isNotEmpty) {
      items.add(const _SearchListItem(_SearchItemType.singerHeader));
      for (var i = 0; i < singers.length; i++) {
        items.add(_SearchListItem(_SearchItemType.singerRow, i));
      }
    }
    if (songs.isNotEmpty) {
      items.add(const _SearchListItem(_SearchItemType.songHeader));
      for (var i = 0; i < songs.length; i++) {
        items.add(_SearchListItem(_SearchItemType.songRow, i));
      }
    }
    return items;
  }

  void _retrySearch() {
    _performSearch(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>().theme;
    final radius = _cardRadius(t.id);
    final hasResults = _songResults.isNotEmpty || _singerResults.isNotEmpty;
    final hasError = _errorMessage != null;

    return Scaffold(
      backgroundColor: t.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: t.textPrimary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: BorderRadius.circular(radius),
                        border: Border.all(
                          color: t.textPrimary.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              autofocus: true,
                              style: TextStyle(color: t.textPrimary, fontSize: 14),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                hintText: 'Search songs or singers...',
                                hintStyle: TextStyle(color: t.textSecondary),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          AnimatedBuilder(
                            animation: _searchController,
                            builder: (context, _) {
                              if (_searchController.text.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return IconButton(
                                icon: Icon(Icons.close,
                                    size: 18, color: t.textSecondary),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _searchController.clear(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: t.textPrimary.withOpacity(0.2)),
            if (_isLoading)
              LinearProgressIndicator(minHeight: 2, color: t.accent),
            Expanded(
              child: hasError
                  ? AppErrorWidget(
                      error: _errorMessage,
                      onRetry: _retrySearch,
                    )
                  : !hasResults
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.12),
                                  border: Border.all(color: t.textPrimary, width: 2),
                                ),
                                alignment: Alignment.center,
                                child: Icon(Icons.search, size: 26, color: t.textPrimary),
                              ),
                              const SizedBox(height: 15),
                              Text(
                                _isSearching
                                    ? 'No matches found'
                                    : 'Type to Search',
                                style: TextStyle(
                                  color: t.textPrimary,
                                  fontSize: 22,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (_isSearching)
                                Padding(
                                  padding: const EdgeInsets.only(top: 7),
                                  child: Text(
                                    'No songs or singers matched "${_searchController.text}".',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: t.textSecondary,
                                      fontSize: 13,
                                      height: 1.5,
                                    ),
                                  ),
                                )
                              else
                                Padding(
                                  padding: const EdgeInsets.only(top: 7),
                                  child: Text(
                                    'Find your favorite Mewati songs & singers instantly.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: t.textSecondary,
                                      fontSize: 13,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 16),
                          itemCount: _items.length,
                          itemBuilder: (context, i) {
                            final item = _items[i];
                            switch (item.type) {
                              case _SearchItemType.singerHeader:
                                return Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(19, 18, 19, 9),
                                  child: Text(
                                    'SINGERS (${_singerResults.length})',
                                    style: TextStyle(
                                      color: t.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.35,
                                    ),
                                  ),
                                );
                              case _SearchItemType.singerRow:
                                return _buildSingerResultRow(
                                    _singerResults[item.index], t, radius);
                              case _SearchItemType.songHeader:
                                return Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(19, 18, 19, 9),
                                  child: Text(
                                    'SONGS (${_songResults.length})',
                                    style: TextStyle(
                                      color: t.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.35,
                                    ),
                                  ),
                                );
                              case _SearchItemType.songRow:
                                return SearchResultRow(
                                  song: _songResults[item.index],
                                  t: t,
                                  allResults: _songResults,
                                  index: item.index,
                                );
                            }
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingerResultRow(Singer singer, AppThemeData t, double radius) {
    final initial =
        singer.name.isNotEmpty ? singer.name[0].toUpperCase() : '?';
    return InkWell(
      onTap: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => SingerProfileScreen(singer: singer),
          ),
        );
      },
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: t.surface.withOpacity(0.2),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: t.textPrimary.withOpacity(0.18)),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: t.textPrimary, width: 2),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [t.surface, t.background],
                ),
              ),
              child: (singer.photoUrl != null && singer.photoUrl!.isNotEmpty)
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: singer.photoUrl!,
                        fit: BoxFit.cover,
                        cacheManager: AppCacheManager.instance,
                        memCacheWidth: 160,
                        memCacheHeight: 160,
                        placeholder: (context, url) => Center(
                          child: Text(
                            initial,
                            style: TextStyle(
                              color: t.textPrimary,
                              fontSize: 21,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Center(
                          child: Text(
                            initial,
                            style: TextStyle(
                              color: t.textPrimary,
                              fontSize: 21,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        initial,
                        style: TextStyle(
                          color: t.textPrimary,
                          fontSize: 21,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    singer.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: t.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${singer.songCount ?? 0} songs',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: t.textSecondary),
          ],
        ),
      ),
    );
  }
}
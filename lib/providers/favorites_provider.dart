import 'dart:async';

import 'package:flutter/foundation.dart';
import '../core/utils/error_handler.dart';
import '../models/song.dart';
import '../services/favorites_service.dart';

class FavoritesProvider extends ChangeNotifier {
  final FavoritesService _favoritesService;

  FavoritesProvider({FavoritesService? favoritesService})
      : _favoritesService = favoritesService ?? FavoritesService();

  List<Song> _favoriteSongs = [];
  final Set<String> _favoriteSongIds = {};

  bool _isLoading = false;
  bool _reloadQueued = false;
  String? _errorMessage;

  // Separate generations: one for load operations, one for toggle operations.
  // This prevents a toggle from invalidating an in‑flight load and leaving
  // the UI stuck in loading state (bug A).
  int _loadGeneration = 0;
  final Map<String, int> _toggleGeneration = {};
  final Map<String, Future<void>> _toggleQueue = {};

  List<Song> get favoriteSongs => _favoriteSongs;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool isFavoriteSync(String songId) => _favoriteSongIds.contains(songId);

  Future<void> loadFavorites() async {
    if (_isLoading) {
      _reloadQueued = true;
      return;
    }

    final int myGeneration = ++_loadGeneration;
    _reloadQueued = false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final songs = await _favoritesService.fetchFavoriteSongs();

      if (myGeneration != _loadGeneration) return;

      _favoriteSongs = songs;
      _favoriteSongIds
        ..clear()
        ..addAll(songs.map((s) => s.id));
    } catch (e) {
      if (myGeneration != _loadGeneration) return;
      _favoriteSongs = [];
      _errorMessage = ErrorHandler.getMessage(e);
    } finally {
      if (myGeneration == _loadGeneration) {
        _isLoading = false;
      }
      notifyListeners();
      if (myGeneration == _loadGeneration && _reloadQueued) {
        _reloadQueued = false;
        unawaited(loadFavorites());
      }
    }
  }

  Future<void> toggleFavorite(Song song) {
    final int myGeneration = (_toggleGeneration[song.id] ?? 0) + 1;
    _toggleGeneration[song.id] = myGeneration;

    _errorMessage = null;

    final wasFavorite = _favoriteSongIds.contains(song.id);

    if (wasFavorite) {
      _favoriteSongIds.remove(song.id);
      _favoriteSongs.removeWhere((s) => s.id == song.id);
    } else {
      _favoriteSongIds.add(song.id);
      _favoriteSongs.add(song);
    }
    notifyListeners();

    final prev = _toggleQueue[song.id] ?? Future<void>.value();
    final chained = prev.catchError((_) {}).then((_) async {
      try {
        if (wasFavorite) {
          await _favoritesService.removeFavorite(song.id);
        } else {
          await _favoritesService.addFavorite(song.id);
        }
      } catch (e) {
        if (_toggleGeneration[song.id] != myGeneration) return;
        if (wasFavorite) {
          _favoriteSongIds.add(song.id);
          _favoriteSongs.add(song);
        } else {
          _favoriteSongIds.remove(song.id);
          _favoriteSongs.removeWhere((s) => s.id == song.id);
        }
        _errorMessage = ErrorHandler.getMessage(e);
        notifyListeners();
      }
    });
    _toggleQueue[song.id] = chained;
    return chained;
  }

  Future<bool> isFavorite(String songId) async {
    try {
      return await _favoritesService.isFavorite(songId);
    } catch (e) {
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
import 'package:flutter/foundation.dart';
import '../models/singer.dart';
import '../services/singers_service.dart';
import '../services/local_cache_service.dart';

class SingersProvider extends ChangeNotifier {
  final SingersService _singersService = SingersService();
  final LocalCacheService _cacheService = LocalCacheService();

  List<Singer> _allSingers = [];
  List<Singer> _filteredSingers = [];
  bool _isSearchActive = false;

  int _currentPage = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  static const int _pageSize = 50;

  bool _isLoading = false;
  String? _errorMessage;

  List<Singer> get allSingers => _allSingers;
  List<Singer> get filteredSingers => _filteredSingers;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;

  Future<void> loadSingers() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final firstPage = await _singersService.fetchSingersPage(
        offset: 0,
        limit: _pageSize,
      );
      _allSingers = firstPage;
      if (!_isSearchActive) {
        _filteredSingers = firstPage;
      }
      _currentPage = 0;
      _hasMore = firstPage.length >= _pageSize;

      await _cacheService.cacheSingers(_allSingers);
    } catch (e) {
      final cached = await _cacheService.getCachedSingers();
      if (cached != null && cached.isNotEmpty) {
        _allSingers = cached;
        if (!_isSearchActive) {
          _filteredSingers = cached;
        }
        _hasMore = false;
      } else {
        _allSingers = [];
        if (!_isSearchActive) {
          _filteredSingers = [];
        }
        _errorMessage = e.toString();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreSingers() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = await _singersService.fetchSingersPage(
        offset: (_currentPage + 1) * _pageSize,
        limit: _pageSize,
      );

      if (nextPage.isEmpty) {
        _hasMore = false;
      } else {
        _allSingers.addAll(nextPage);
        if (!_isSearchActive) {
          _filteredSingers = _allSingers;
        }
        _currentPage++;
        _hasMore = nextPage.length >= _pageSize;
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> searchSingers(String query) async {
    _errorMessage = null;
    notifyListeners();

    if (query.trim().isEmpty) {
      _isSearchActive = false;
      _filteredSingers = _allSingers;
      notifyListeners();
      return;
    }

    _isSearchActive = true;
    try {
      final results = await _singersService.searchSingers(query);
      _filteredSingers = results;
    } catch (e) {
      _filteredSingers = searchSingersLocal(query);
      if (_filteredSingers.isEmpty) {
        _errorMessage = e.toString();
      }
    } finally {
      notifyListeners();
    }
  }

  Future<List<Singer>> searchSingersRemote(String query) async {
    return await _singersService.searchSingers(query);
  }

  List<Singer> searchSingersLocal(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return _allSingers.where((s) => s.name.toLowerCase().contains(q)).toList();
  }

  void clearSearch() {
    _isSearchActive = false;
    _filteredSingers = _allSingers;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
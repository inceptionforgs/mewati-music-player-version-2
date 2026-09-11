import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../core/utils/error_handler.dart';
import '../models/song.dart';
import '../services/player_service.dart';
import '../services/system_volume.dart';

class PlayerProvider extends ChangeNotifier {
  final PlayerService _playerService = PlayerService();

  Song? _currentSong;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration? _duration;
  bool _isLoading = false;
  String? _errorMessage;

  final ValueNotifier<Duration> positionNotifier =
      ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<Duration> durationNotifier =
      ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<double> volumeNotifier = ValueNotifier<double>(1.0);

  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<int?>? _currentIndexSubscription;
  StreamSubscription<SystemVolumeEvent>? _systemVolSubscription;

  Song? get currentSong => _currentSong;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration? get duration => _duration;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasSong => _currentSong != null;

  bool get shuffleMode => _playerService.shuffleMode;
  LoopMode get loopMode => _playerService.loopMode;

  int get currentQueueIndex => _playerService.currentIndex;
  int get totalQueueLength => _playerService.playlist.length;

  List<Song> get queue => _playerService.playlist;
  double get volume => _playerService.volume;

  PlayerProvider({bool autoInit = true}) {
    if (autoInit) _init();
  }

  void _init() {
    SystemVolume.get().then((v) {
      volumeNotifier.value = v;
    });
    _systemVolSubscription = SystemVolume.changes.listen((e) {
      volumeNotifier.value = e.value;
    });
    _playerStateSubscription =
        _playerService.playerStateStream.listen((PlayerState state) {
      _isPlaying = state.playing;
      if (state.processingState == ProcessingState.completed) {
        _isPlaying = false;
      }
      notifyListeners();
    });

    _positionSubscription = _playerService.positionStream.listen((Duration pos) {
      _position = pos;
      positionNotifier.value = pos;
    });

    _durationSubscription =
        _playerService.durationStream.listen((Duration? dur) {
      _duration = dur;
      durationNotifier.value = dur ?? Duration.zero;
      notifyListeners();
    });

    _currentIndexSubscription =
        _playerService.currentIndexStream.listen((int? index) {
      if (index == null) return;
      final playlist = _playerService.playlist;
      if (index >= 0 && index < playlist.length) {
        final newSong = playlist[index];
        if (_currentSong?.id != newSong.id) {
          _currentSong = newSong;
          notifyListeners();
        }
      }
    });
  }

  Future<void> setPlaylist(
      {required List<Song> songs, required int startIndex}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _playerService.setPlaylist(songs: songs, startIndex: startIndex);
      _currentSong = _playerService.currentSong;
    } catch (e) {
      _errorMessage = 'Playback failed: ${ErrorHandler.getMessage(e)}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> togglePlayPause() async {
    _errorMessage = null;
    try {
      await _playerService.togglePlayPause();
    } catch (e) {
      _errorMessage = ErrorHandler.getMessage(e);
      notifyListeners();
    }
  }

  Future<void> seek(Duration position) async {
    _errorMessage = null;
    try {
      await _playerService.seek(position);
    } catch (e) {
      _errorMessage = ErrorHandler.getMessage(e);
      notifyListeners();
    }
  }

  Future<void> next() async {
    _errorMessage = null;
    try {
      await _playerService.next();
      final song = _playerService.currentSong;
      if (song != null) {
        _currentSong = song;
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = ErrorHandler.getMessage(e);
      notifyListeners();
    }
  }

  Future<void> previous({bool forceSkip = false}) async {
    _errorMessage = null;
    try {
      await _playerService.previous(forceSkip: forceSkip);
      final song = _playerService.currentSong;
      if (song != null) {
        _currentSong = song;
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = ErrorHandler.getMessage(e);
      notifyListeners();
    }
  }

  Future<void> jumpToQueueIndex(int index) async {
    _errorMessage = null;
    try {
      await _playerService.jumpToQueueIndex(index);
      final song = _playerService.currentSong;
      if (song != null) _currentSong = song;
      notifyListeners();
    } catch (e) {
      _errorMessage = ErrorHandler.getMessage(e);
      notifyListeners();
    }
  }

  void toggleShuffle() {
    _playerService.toggleShuffle();
    notifyListeners();
  }

  Future<void> setLoopMode(LoopMode mode) async {
    _errorMessage = null;
    try {
      await _playerService.setLoopMode(mode);
      notifyListeners();
    } catch (e) {
      _errorMessage = ErrorHandler.getMessage(e);
      notifyListeners();
    }
  }

  Future<void> setVolume(double volume) async {
    volumeNotifier.value = await SystemVolume.set(volume);
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _currentIndexSubscription?.cancel();
    _systemVolSubscription?.cancel();
    positionNotifier.dispose();
    durationNotifier.dispose();
    volumeNotifier.dispose();
    super.dispose();
  }
}
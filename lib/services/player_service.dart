import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/media_config.dart';
import '../core/utils/queue_builder.dart';
import '../models/song.dart';
import 'debug_log_service.dart';
import 'downloads_service.dart';
import 'equalizer_service.dart';
import 'songs_service.dart';

class PlayerService {
  static final PlayerService _instance = PlayerService._internal();
  factory PlayerService() => _instance;

  final AudioPlayer _player = AudioPlayer(
    audioPipeline: AudioPipeline(androidAudioEffects: const []),
  );
  final DownloadsService _downloadsService = DownloadsService();
  final SongsService _songsService = SongsService();

  List<Song> _playlist = [];
  List<Song> _catalog = [];
  int _windowStart = 0;
  ConcatenatingAudioSource? _concatSource;
  Map<String, String> _localPaths = {};
  Future<void> _extendChain = Future<void>.value();
  int _playlistGeneration = 0;
  int _currentIndex = 0;
  bool _shuffleMode = false;
  Timer? _fadeTimer;
  bool _fadeWriteBusy = false;
  double _originalVolume = 1.0;
  int _fadeToken = 0;

  StreamSubscription<int?>? _internalIndexSubscription;
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<ProcessingState>? _processingSubscription;

  String? _playCountTrackedSongId;
  Timer? _playCountTimer;
  Duration _playAccumulated = Duration.zero;
  DateTime? _playSegmentStart;
  bool _countedThisSegment = false;
  static const Duration _playCountThreshold = Duration(seconds: 25);

  static bool _notificationPermissionRequested = false;

  static const int _maxQueueWindow = QueueBuilder.maxQueueWindow;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<int?> get currentIndexStream => _player.currentIndexStream;

  AudioPlayer get player => _player;
  List<Song> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  bool get shuffleMode => _shuffleMode;
  LoopMode get loopMode => _player.loopMode;
  double get volume => _player.volume;

  Song? get currentSong =>
      (_playlist.isNotEmpty && _currentIndex < _playlist.length)
          ? _playlist[_currentIndex]
          : null;

  PlayerService._internal() {
    _internalIndexSubscription = _player.currentIndexStream.listen((index) {
      if (index != null && index >= 0 && index < _playlist.length) {
        _currentIndex = index;
        _handleIndexChanged(_playlist[index]);
        unawaited(_maybeExtendQueue());
        unawaited(_maybeExtendQueueBackward());
      }
    });
    _playingSubscription = _player.playingStream.listen(_onPlayingChanged);
    _processingSubscription = _player.processingStateStream.listen((state) {
      if (state == ProcessingState.ready && _player.playing) {
        _playSegmentStart ??= DateTime.now();
        _armPlayCountTimer();
      } else if (state == ProcessingState.buffering ||
          state == ProcessingState.loading) {
        _pausePlayCountClock();
      }
    });
    _initEqualizer();
  }

  Future<void> _ensureNotificationPermission() async {
    if (_notificationPermissionRequested) return;
    _notificationPermissionRequested = true;
    try {
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
    } catch (e) {
      DebugLogService().warning('Notification permission request failed: $e');
    }
  }

  Future<Map<String, String>> _probeLocalPaths(List<Song> songs) async {
    final prefs = await SharedPreferences.getInstance();
    final downloadedIds =
        prefs.getStringList('downloaded_song_ids')?.toSet() ?? <String>{};
    final localPaths = <String, String>{};
    final checks = <Future<void>>[];
    for (final song in songs) {
      if (!downloadedIds.contains(song.id)) continue;
      checks.add(() async {
        try {
          final candidatePath = await _downloadsService.getLocalSongPath(
            song.id,
            audioUrl: song.audioUrl,
          );
          final file = File(candidatePath);
          if (await file.exists() && await file.length() > 0) {
            localPaths[song.id] = candidatePath;
          }
        } catch (e) {
          debugPrint(
              'PlayerService: local probe failed for "${song.title}": $e');
        }
      }());
    }
    if (checks.isNotEmpty) await Future.wait(checks);
    return localPaths;
  }

  AudioSource _sourceFor(Song song, Map<String, String> localPaths) {
    final mediaItem = MediaItem(
      id: song.id,
      title: song.title,
      artist: song.singerName ?? 'Mewati Artist',
      artUri: (song.coverImageUrl != null && song.coverImageUrl!.isNotEmpty)
          ? Uri.tryParse(song.coverImageUrl!)
          : null,
    );
    final localPath = localPaths[song.id];
    if (localPath != null) {
      return AudioSource.uri(Uri.file(localPath), tag: mediaItem);
    }
    return AudioSource.uri(Uri.parse(song.audioUrl), tag: mediaItem);
  }

  Future<void> setPlaylist({
    required List<Song> songs,
    required int startIndex,
  }) async {
    final gen = ++_playlistGeneration;
    try {
      if (songs.isEmpty) {
        throw Exception('Playlist is empty.');
      }

      final prefs = await SharedPreferences.getInstance();
      if (gen != _playlistGeneration) return;
      final downloadedIds =
          prefs.getStringList('downloaded_song_ids')?.toSet() ?? <String>{};

      final eligibleSongs = songs.where((song) {
        if (downloadedIds.contains(song.id)) return true;
        final allowed = MediaConfig.isAllowedAudioUrl(song.audioUrl);
        if (!allowed) {
          debugPrint(
              'PlayerService: rejecting "${song.title}" — audio URL host not in CDN allowlist.');
        }
        return allowed;
      }).toList();

      if (eligibleSongs.isEmpty) {
        throw Exception(
            'No playable songs found (missing or invalid audio URLs).');
      }

      final remappedStart = QueueBuilder.remapStartIndex(
        original: songs,
        originalStartIndex: startIndex,
        eligible: eligibleSongs,
      );

      late final BuiltQueue built;
      try {
        built = QueueBuilder.build(
          songs: eligibleSongs,
          startIndex: remappedStart,
          locallyAvailableSongIds: downloadedIds,
          windowSize: _maxQueueWindow,
        );
      } on StateError {
        throw Exception(
            'No playable songs found (missing or invalid audio URLs).');
      }

      final localPaths = await _probeLocalPaths(built.songs);
      if (gen != _playlistGeneration) return;

      _catalog = eligibleSongs;
      _localPaths = localPaths;
      _playlist = built.songs;
      _currentIndex = built.startIndex;
      _windowStart = _catalog.isEmpty
          ? 0
          : _catalog.indexWhere((s) => s.id == _playlist.first.id);
      if (_windowStart < 0) _windowStart = 0;

      final audioSources = [
        for (final song in _playlist) _sourceFor(song, localPaths)
      ];

      _concatSource = ConcatenatingAudioSource(children: audioSources);
      await _player.setAudioSource(_concatSource!, initialIndex: _currentIndex);
      if (gen != _playlistGeneration) return;
      await _player.setShuffleModeEnabled(_shuffleMode);
      if (gen != _playlistGeneration) return;

      await _ensureNotificationPermission();
      if (gen != _playlistGeneration) return;

      unawaited(_player.play().catchError((e) {
        debugPrint('PlayerService.play error: $e');
      }));
    } catch (e) {
      if (gen != _playlistGeneration) return;
      throw Exception('Failed to play playlist: ${e.toString()}');
    }
  }

  Future<void> _maybeExtendQueue() {
    _extendChain =
        _extendChain.catchError((_) {}).then((_) => _extendForward());
    return _extendChain;
  }

  Future<void> _maybeExtendQueueBackward() {
    _extendChain =
        _extendChain.catchError((_) {}).then((_) => _extendBackward());
    return _extendChain;
  }

  Future<void> _extendForward() async {
    final concat = _concatSource;
    final catalog = _catalog;
    if (concat == null || catalog.isEmpty) return;
    if (_playlist.length - _currentIndex > 8) return;
    final nextIndex = _windowStart + _playlist.length;
    if (nextIndex >= catalog.length) return;

    try {
      final hi = catalog.length.clamp(0, nextIndex + 20);
      if (hi <= nextIndex) return;
      final slice = catalog.sublist(nextIndex, hi);
      final extraPaths = await _probeLocalPaths(slice);
      if (!identical(concat, _concatSource)) return;
      _localPaths.addAll(extraPaths);
      final extras = [
        for (final song in slice) _sourceFor(song, _localPaths)
      ];
      await concat.addAll(extras);
      if (!identical(concat, _concatSource)) return;
      _playlist.addAll(slice);
    } catch (e) {
      debugPrint('PlayerService.extendQueue: $e');
    }
  }

  Future<void> _extendBackward() async {
    final concat = _concatSource;
    final catalog = _catalog;
    if (concat == null || catalog.isEmpty) return;
    if (_currentIndex > 2 || _windowStart <= 0) return;

    try {
      final lo = (_windowStart - 20).clamp(0, _windowStart);
      if (lo >= _windowStart) return;
      final slice = catalog.sublist(lo, _windowStart);
      final extraPaths = await _probeLocalPaths(slice);
      if (!identical(concat, _concatSource)) return;
      _localPaths.addAll(extraPaths);
      final extras = [
        for (final song in slice) _sourceFor(song, _localPaths)
      ];
      await concat.insertAll(0, extras);
      if (!identical(concat, _concatSource)) return;
      _playlist.insertAll(0, slice);
      _windowStart = lo;
      final playerIdx = _player.currentIndex;
      if (playerIdx != null && playerIdx >= 0 && playerIdx < _playlist.length) {
        _currentIndex = playerIdx;
      } else {
        _currentIndex += slice.length;
      }
    } catch (e) {
      debugPrint('PlayerService.extendQueueBack: $e');
    }
  }

  void _handleIndexChanged(Song song) {
    if (song.id == _playCountTrackedSongId) return;
    _playCountTimer?.cancel();
    _playSegmentStart = null;
    _playAccumulated = Duration.zero;
    _countedThisSegment = false;
    _playCountTrackedSongId = song.id;
    if (_player.playing && _player.processingState == ProcessingState.ready) {
      _playSegmentStart = DateTime.now();
      _armPlayCountTimer();
    }
  }

  void _onPlayingChanged(bool playing) {
    final ready = _player.processingState == ProcessingState.ready;
    if (playing && ready) {
      _playSegmentStart ??= DateTime.now();
      _armPlayCountTimer();
    } else {
      _pausePlayCountClock();
    }
  }

  void _pausePlayCountClock() {
    _playCountTimer?.cancel();
    final started = _playSegmentStart;
    if (started != null) {
      _playAccumulated += DateTime.now().difference(started);
      _playSegmentStart = null;
    }
  }

  void _armPlayCountTimer() {
    _playCountTimer?.cancel();
    final id = _playCountTrackedSongId;
    if (id == null || _countedThisSegment) return;
    final left = _playCountThreshold - _playAccumulated;
    if (left <= Duration.zero) {
      _firePlayCount(id);
      return;
    }
    _playCountTimer = Timer(left, () {
      if (!_player.playing) return;
      if (_player.processingState != ProcessingState.ready) return;
      if (_playCountTrackedSongId != id) return;
      _firePlayCount(id);
    });
  }

  void _firePlayCount(String songId) {
    if (_countedThisSegment) return;
    _countedThisSegment = true;
    _playCountTimer?.cancel();
    final song = currentSong;
    if (song != null && song.id == songId) {
      _trackPlayCount(song);
    } else {
      _songsService.incrementPlayCount(songId);
    }
  }

  void _trackPlayCount(Song song) {
    _songsService.incrementPlayCount(song.id);
  }

  Future<void> _initEqualizer() async {
    try {
      await EqualizerService().init();
    } catch (e) {
      debugPrint("Equalizer init (player) Error: $e");
    }
  }

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      unawaited(_player.play().catchError((e) {
        debugPrint('PlayerService.togglePlayPause play error: $e');
      }));
    }
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> next() async {
    if (_playlist.isEmpty) return;
    unawaited(_maybeExtendQueue());
    await _player.seekToNext();
  }

  Future<void> previous({bool forceSkip = false}) async {
    if (_playlist.isEmpty) return;
    await _maybeExtendQueueBackward();
    if (!forceSkip && _player.position > const Duration(seconds: 3)) {
      await _player.seek(Duration.zero);
      return;
    }
    await _player.seekToPrevious();
  }

  Future<void> jumpToQueueIndex(int index) async {
    if (index < 0 || index >= _playlist.length) return;
    await _player.seek(Duration.zero, index: index);
    if (!_player.playing) {
      unawaited(_player.play().catchError((e) {
        debugPrint('PlayerService.jumpToQueueIndex play error: $e');
      }));
    }
  }

  void toggleShuffle() {
    _shuffleMode = !_shuffleMode;
    _player.setShuffleModeEnabled(_shuffleMode);
  }

  Future<void> setLoopMode(LoopMode mode) async {
    await _player.setLoopMode(mode);
  }

  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume.clamp(0.0, 1.0));
  }

  Future<void> fadeOut(
      {Duration duration = const Duration(seconds: 30)}) async {
    cancelFadeOut();
    final token = ++_fadeToken;
    _originalVolume = _player.volume;
    final steps = max(1, duration.inMilliseconds ~/ 100);
    final volumeStep = _originalVolume / steps;
    int stepCount = 0;

    _fadeTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (token != _fadeToken) {
        timer.cancel();
        return;
      }
      if (_fadeWriteBusy) return;
      stepCount++;
      double newVolume = _originalVolume - (volumeStep * stepCount);
      _fadeWriteBusy = true;
      if (newVolume <= 0.0) {
        timer.cancel();
        unawaited(() async {
          try {
            if (token == _fadeToken) {
              await _player.setVolume(0.0);
              await _player.pause();
              await _player.setVolume(_originalVolume);
            }
          } finally {
            _fadeWriteBusy = false;
          }
        }());
      } else {
        unawaited(_player.setVolume(newVolume).whenComplete(() {
          _fadeWriteBusy = false;
        }));
      }
    });
  }

  void cancelFadeOut() {
    _fadeToken++;
    _fadeTimer?.cancel();
    _fadeTimer = null;
    _player.setVolume(_originalVolume);
  }

  void handleAppDetached() {
    _fadeTimer?.cancel();
    _fadeTimer = null;
  }

  void dispose() {
    _fadeTimer?.cancel();
    _playCountTimer?.cancel();
    _internalIndexSubscription?.cancel();
    _playingSubscription?.cancel();
    _processingSubscription?.cancel();
    _player.dispose();
  }
}
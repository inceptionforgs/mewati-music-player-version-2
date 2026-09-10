import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/downloads_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/local_cache_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _showRetry = false;
  String _errorText = 'Could not connect. Please check your internet.';

  @override
  void initState() {
    super.initState();
    _startSplashAndNavigate();
  }

  Future<bool> _hasOfflineCatalog() async {
    try {
      final cached = await LocalCacheService().getCachedSongs();
      if (cached != null && cached.isNotEmpty) return true;
    } catch (_) {}
    try {
      final downloads =
          Provider.of<DownloadsProvider>(context, listen: false);
      if (downloads.downloadedSongIds.isNotEmpty) return true;
    } catch (_) {}
    return false;
  }

  Future<void> _goHome() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/home');
  }

  Future<void> _startSplashAndNavigate() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      await authProvider.loadCurrentUser().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Startup timed out. Check your internet connection.');
        },
      );
    } catch (e) {
      if (!mounted) return;
      if (await _hasOfflineCatalog()) {
        await _goHome();
        return;
      }
      setState(() {
        _errorText = 'Could not connect. Please check your internet.';
        _showRetry = true;
      });
      return;
    }

    if (!mounted) return;

    if (authProvider.isLoggedIn && authProvider.errorMessage == null) {
      await _goHome();
      return;
    }

    if (await _hasOfflineCatalog()) {
      await _goHome();
      return;
    }

    setState(() {
      _errorText = authProvider.errorMessage ??
          'Could not connect. Please check your internet.';
      _showRetry = true;
    });
  }

  Future<void> _retry() async {
    setState(() {
      _showRetry = false;
    });
    await _startSplashAndNavigate();
  }

  Future<void> _continueOffline() async {
    final t = Provider.of<ThemeProvider>(context, listen: false).theme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: t.surface,
        title: Text('Continue without an account?',
            style: TextStyle(color: t.textPrimary)),
        content: Text(
          'Your favorites, likes, and download history won\'t be available '
          'until you connect and sign in again.',
          style: TextStyle(color: t.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancel', style: TextStyle(color: t.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Continue', style: TextStyle(color: t.accent)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>().theme;

    return Scaffold(
      backgroundColor: t.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.music_note,
                  size: 64,
                  color: t.accent,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Mewati Song Player',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: t.textPrimary,
                ),
              ),
              if (!_showRetry) ...[
                const SizedBox(height: 32),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: t.accent,
                  ),
                ),
              ],
              if (_showRetry) ...[
                const SizedBox(height: 32),
                Text(
                  _errorText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _retry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.accent,
                    foregroundColor: t.textPrimary,
                  ),
                  child: const Text('Retry'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _continueOffline,
                  child: Text(
                    'Continue Offline',
                    style: TextStyle(
                      color: t.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_strings.dart';
import 'core/constants/app_theme.dart';
import 'core/constants/app_dimensions.dart';
import 'core/constants/themes/app_theme_id.dart';
import 'core/widgets/connectivity_banner.dart';
import 'core/widgets/debug_panel.dart';
import 'core/widgets/mini_player/mini_player_bar.dart';
import 'services/downloads_service.dart';
import 'services/player_service.dart';
import 'providers/auth_provider.dart';
import 'providers/player_provider.dart';
import 'providers/songs_provider.dart';
import 'providers/singers_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/downloads_provider.dart';
import 'providers/likes_provider.dart';
import 'providers/sleep_timer_provider.dart';
import 'providers/theme_provider.dart';
import 'routes/app_router.dart';
import 'routes/route_names.dart';

class _MiniPlayerRouteObserver extends NavigatorObserver {
  _MiniPlayerRouteObserver(this.onRouteChanged);

  final ValueChanged<String?> onRouteChanged;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    onRouteChanged(route.settings.name);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    onRouteChanged(previousRoute?.settings.name);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    onRouteChanged(previousRoute?.settings.name);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    onRouteChanged(newRoute?.settings.name);
  }
}

double _miniPlayerHeightFor(AppThemeId id) {
  switch (id) {
    case AppThemeId.cyberBlack:
      return 214.0;
    case AppThemeId.silverChrome:
      return 128.0;
    default:
      return AppDimensions.miniPlayerHeight;
  }
}

double _miniBottomOffset(AppThemeId id, String? routeName) {
  return 0.0;
}

class MewatiTunePlayerApp extends StatefulWidget {
  final AuthProvider? authProvider;
  final DownloadsProvider? downloadsProvider;

  const MewatiTunePlayerApp({
    Key? key,
    this.authProvider,
    this.downloadsProvider,
  }) : super(key: key);

  @override
  State<MewatiTunePlayerApp> createState() => _MewatiTunePlayerAppState();
}

class _MewatiTunePlayerAppState extends State<MewatiTunePlayerApp>
    with WidgetsBindingObserver {
  final ValueNotifier<String?> _currentRouteName = ValueNotifier<String?>(null);
  late final _MiniPlayerRouteObserver _routeObserver;

  late final AuthProvider _authProvider;
  late final FavoritesProvider _favoritesProvider;
  late final LikesProvider _likesProvider;
  late final DownloadsProvider _downloadsProvider;

  @override
  void initState() {
    super.initState();
    _routeObserver = _MiniPlayerRouteObserver(
      (name) {
        _currentRouteName.value = name;
      },
    );
    WidgetsBinding.instance.addObserver(this);

    _authProvider = widget.authProvider ?? AuthProvider();
    _favoritesProvider = FavoritesProvider();
    _likesProvider = LikesProvider();
    _downloadsProvider = widget.downloadsProvider ?? DownloadsProvider();

    _authProvider.onSessionReady = () {
      _favoritesProvider.loadFavorites();
      _likesProvider.clear();
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _currentRouteName.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      PlayerService().handleAppDetached();
      DownloadsService().dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        ChangeNotifierProvider<DownloadsProvider>.value(
          value: _downloadsProvider,
        ),
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
        ChangeNotifierProvider(create: (_) => SongsProvider()),
        ChangeNotifierProvider(create: (_) => SingersProvider()),
        ChangeNotifierProvider<FavoritesProvider>.value(
          value: _favoritesProvider,
        ),
        ChangeNotifierProvider<LikesProvider>.value(value: _likesProvider),
        ChangeNotifierProvider(create: (_) => SleepTimerProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: AppStrings.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.fromAppTheme(themeProvider.theme),
            onGenerateRoute: AppRouter.generateRoute,
            navigatorKey: AppRouter.navigatorKey,
            navigatorObservers: [_routeObserver],
            initialRoute: RouteNames.splash,
            builder: (context, child) {
              return ValueListenableBuilder<String?>(
                valueListenable: _currentRouteName,
                builder: (context, routeName, _) {
                  final hasSong = context.select<PlayerProvider, bool>(
                    (p) => p.hasSong,
                  );
                  final isNowPlaying = routeName == RouteNames.nowPlaying;
                  final isSplash = routeName == RouteNames.splash;
                  final isDriveMode = routeName == RouteNames.driveMode;
                  final isSearch = routeName == RouteNames.search;
                  final isAdvanceSettings =
                      routeName == RouteNames.advanceSettings;
                  final isSoundSettings =
                      routeName == RouteNames.soundSettings;
                  final isFeedback = routeName == RouteNames.feedback;
                  final showMiniPlayer = hasSong &&
                      !isNowPlaying &&
                      !isSplash &&
                      !isDriveMode &&
                      !isSearch &&
                      !isAdvanceSettings &&
                      !isSoundSettings &&
                      !isFeedback;

                  final miniPlayerHeight =
                      _miniPlayerHeightFor(themeProvider.theme.id);
                  final tabLift = _miniBottomOffset(
                    themeProvider.theme.id,
                    routeName,
                  );
                  final applePad = themeProvider.theme.id == AppThemeId.silverChrome
                      ? MediaQuery.paddingOf(context).bottom
                      : 0.0;

                  return Stack(
                    children: [
                      Positioned.fill(
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: showMiniPlayer
                                ? miniPlayerHeight + tabLift + applePad
                                : tabLift,
                          ),
                          child: child ?? const SizedBox.shrink(),
                        ),
                      ),
                      if (showMiniPlayer)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: tabLift,
                          child: SafeArea(
                            top: false,
                            bottom: tabLift == 0 &&
                                themeProvider.theme.id != AppThemeId.silverChrome,
                            child: const MiniPlayerBar(),
                          ),
                        ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: SafeArea(
                          bottom: false,
                          child: const ConnectivityBanner(),
                        ),
                      ),
                      if (kDebugMode) const DebugPanel(),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
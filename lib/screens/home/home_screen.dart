import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/ad_banner_widget.dart';
import '../../core/widgets/app_drawer.dart';
import '../../core/utils/home_nav.dart';
import '../../routes/route_names.dart';
import '../songs/songs_screen.dart';
import '../singers/singers_screen.dart';
import '../trending/trending_screen.dart';
import '../favorites/favorites_screen.dart';
import '../downloads/downloads_screen.dart';
import '../search/search_screen.dart';
import '../search/voice_search_sheet.dart';
import 'widgets/brand_row.dart';
import 'widgets/home_tabs.dart';
import '../../providers/theme_provider.dart';
import '../../core/constants/themes/app_theme_id.dart';

class _KeepAlivePage extends StatefulWidget {
  final Widget child;

  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = HomeNav.trending;
  int _drawerEpoch = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final PageController _pageController;

  final Set<int> _visitedTabs = {};

  static final List<Widget Function()> _screenBuilders = [
    () => const SongsScreen(),
    () => const SingersScreen(),
    () => const TrendingScreen(),
    () => const FavoritesScreen(),
    () => const DownloadsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _markVisited(_currentIndex);
    HomeNav.tabIndex.addListener(_onHomeNavTab);
  }

  @override
  void dispose() {
    HomeNav.tabIndex.removeListener(_onHomeNavTab);
    _pageController.dispose();
    super.dispose();
  }

  void _onHomeNavTab() {
    final index = HomeNav.tabIndex.value;
    if (index == _currentIndex) return;
    if (!mounted) return;
    _onTabSelected(index);
  }

  void _markVisited(int index) {
    _visitedTabs
      ..clear()
      ..add(index);
    if (index > 0) _visitedTabs.add(index - 1);
    if (index < _screenBuilders.length - 1) _visitedTabs.add(index + 1);
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
      _markVisited(index);
    });
    if (HomeNav.tabIndex.value != index) {
      HomeNav.tabIndex.value = index;
    }
    final apple = context.read<ThemeProvider>().theme.id == AppThemeId.silverChrome;
    if (!_pageController.hasClients) return;
    if (apple) {
      _pageController.jumpToPage(index);
    } else {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _markVisited(index);
    });
    if (HomeNav.tabIndex.value != index) {
      HomeNav.tabIndex.value = index;
    }
  }

  void _openSearch({String? query}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SearchScreen(initialQuery: query),
        fullscreenDialog: true,
        settings: const RouteSettings(name: RouteNames.search),
      ),
    );
  }

  Future<void> _openVoiceSearch() async {
    final phrase = await VoiceSearchSheet.show(context);
    if (!mounted) return;
    if (phrase == null || phrase.trim().isEmpty) return;
    _openSearch(query: phrase.trim());
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>().theme;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: t.background,
      drawer: AppDrawer(key: ValueKey(_drawerEpoch)),
      onDrawerChanged: (open) {
        if (!open) setState(() => _drawerEpoch++);
      },
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: t.screenGradient,
          ),
        ),
        child: SafeArea(
          bottom: t.id != AppThemeId.silverChrome,
          child: Column(
            children: [
              BrandRow(
                onMenuTap: _openDrawer,
                onSearchTap: () => _openSearch(),
              ),
              if (t.id != AppThemeId.silverChrome)
                HomeTabs(
                  currentIndex: _currentIndex,
                  onHomeTap: () => _onTabSelected(HomeNav.trending),
                  onVoiceTap: _openVoiceSearch,
                ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _screenBuilders.length,
                  itemBuilder: (context, i) {
                    return _visitedTabs.contains(i)
                        ? _KeepAlivePage(child: _screenBuilders[i]())
                        : const SizedBox.shrink();
                  },
                ),
              ),
              const AdBannerWidget(),
            ],
          ),
        ),
      ),
    );
  }
}
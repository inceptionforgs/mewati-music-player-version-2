import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_themes.dart';
import '../constants/app_strings.dart';
import '../utils/home_nav.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../routes/app_router.dart';
import '../../routes/route_names.dart';
import '../../screens/player/widgets/sleep_timer_sheet.dart';
import '../../services/equalizer_service.dart';
import '../../services/eq_presets.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({Key? key}) : super(key: key);

  static double _cardRadius(AppThemeId id) {
    switch (id) {
      case AppThemeId.cyberBlack:
        return 4;
      case AppThemeId.silverChrome:
        return 10;
      default:
        return 14;
    }
  }

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  bool _musicOpen = false;
  bool _eqOpen = false;
  bool _featOpen = false;

  void _openTree(String id) {
    setState(() {
      final already = id == 'music' && _musicOpen ||
          id == 'eq' && _eqOpen ||
          id == 'feat' && _featOpen;
      _musicOpen = !already && id == 'music';
      _eqOpen = !already && id == 'eq';
      _featOpen = !already && id == 'feat';
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final authProvider = context.watch<AuthProvider>();
    final t = themeProvider.theme;
    final radius = AppDrawer._cardRadius(t.id);

    final bool isLoggedIn = authProvider.isLoggedIn;
    final profile = authProvider.profile;

    final String displayName = isLoggedIn ? 'Mewati Listener' : 'Guest';
    final String avatarLetter = displayName[0].toUpperCase();

    final bool isPremium = profile?.isPremium ?? false;
    final bool isCustomEq = themeProvider.eqPreset == 'custom';

    return Drawer(
      width: 280,
      backgroundColor: t.background,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t.surface,
                    border: Border.all(
                      color: t.textPrimary,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.26),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    avatarLetter,
                    style: TextStyle(
                      color: t.accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      isPremium ? 'VIP Member' : 'Free · Premium soon',
                      style: TextStyle(
                        color: isPremium ? t.accent : t.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Divider(height: 30, color: t.textPrimary.withOpacity(0.15)),

            _DrawerTree(
              label: 'MUSIC',
              color: t.textSecondary,
              accent: t.accent,
              text: t.textPrimary,
              radius: radius,
              surface: t.surface,
              collapsed: true,
              expanded: _musicOpen,
              onToggle: () => _openTree('music'),
              children: [
            _DrawerActionRow(
              icon: Icons.music_note,
              label: AppStrings.navSongs,
              t: t,
              radius: radius,
              onTap: () {
                Navigator.of(context).pop();
                HomeNav.goTab(HomeNav.songs);
              },
            ),
            const SizedBox(height: 8),
            _DrawerActionRow(
              icon: Icons.mic,
              label: AppStrings.navSingers,
              t: t,
              radius: radius,
              onTap: () {
                Navigator.of(context).pop();
                HomeNav.goTab(HomeNav.singers);
              },
            ),
            const SizedBox(height: 8),
            _DrawerActionRow(
              icon: Icons.trending_up,
              label: AppStrings.navTrending,
              t: t,
              radius: radius,
              onTap: () {
                Navigator.of(context).pop();
                HomeNav.goTab(HomeNav.trending);
              },
            ),
            const SizedBox(height: 8),
            _DrawerActionRow(
              icon: Icons.favorite,
              label: AppStrings.navFavorites,
              t: t,
              radius: radius,
              onTap: () {
                Navigator.of(context).pop();
                HomeNav.goTab(HomeNav.favorites);
              },
            ),
            const SizedBox(height: 8),
            _DrawerActionRow(
              icon: Icons.download,
              label: 'Downloaded',
              t: t,
              radius: radius,
              onTap: () {
                Navigator.of(context).pop();
                HomeNav.goTab(HomeNav.downloads);
              },
            ),
              ],
            ),

            const SizedBox(height: 18),
            _DrawerTree(
              label: 'EQUALIZER',
              color: t.textSecondary,
              accent: t.accent,
              text: t.textPrimary,
              radius: radius,
              surface: t.surface,
              collapsed: true,
              expanded: _eqOpen,
              onToggle: () => _openTree('eq'),
              children: [
            ...EqPresets.drawerList.map((preset) {
              final isActive = !isCustomEq && themeProvider.eqPreset == preset.id;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: _DrawerPillRow(
                  radius: radius,
                  isActive: isActive,
                  t: t,
                  onTap: () {
                    themeProvider.setEqPreset(preset.id);
                    if (EqualizerService().shouldHintHeadphones(preset.id)) {
                      final messenger = ScaffoldMessenger.of(context);
                      messenger.clearSnackBars();
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text(EqPresets.headphoneHint),
                          duration: Duration(seconds: 4),
                        ),
                      );
                    }
                  },
                  label: preset.label,
                ),
              );
            }).toList(),
              ],
            ),

            const SizedBox(height: 18),
            _DrawerTree(
              label: 'ADDITIONAL FEATURES',
              color: t.textSecondary,
              accent: t.accent,
              text: t.textPrimary,
              radius: radius,
              surface: t.surface,
              collapsed: true,
              expanded: _featOpen,
              onToggle: () => _openTree('feat'),
              children: [
            _DrawerActionRow(
              icon: Icons.timer_outlined,
              label: AppStrings.sleepTimer,
              t: t,
              radius: radius,
              onTap: () {
                Navigator.of(context).pop();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final ctx = AppRouter.navigatorKey.currentContext;
                  if (ctx == null) return;
                  showModalBottomSheet(
                    context: ctx,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const SleepTimerSheet(),
                  );
                });
              },
            ),
            const SizedBox(height: 8),
            _DrawerActionRow(
              icon: Icons.drive_eta,
              label: 'Drive Mode',
              t: t,
              radius: radius,
              onTap: () {
                final navigator = Navigator.of(context);
                navigator.pop();
                navigator.pushNamed(RouteNames.driveMode);
              },
            ),
            const SizedBox(height: 8),
            _DrawerActionRow(
              icon: Icons.feedback_outlined,
              label: 'Report us',
              t: t,
              radius: radius,
              onTap: () {
                final navigator = Navigator.of(context);
                navigator.pop();
                navigator.pushNamed(RouteNames.feedback);
              },
            ),
              ],
            ),

            const SizedBox(height: 18),
            _SectionTitle(label: 'ABOUT US', color: t.textSecondary),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: t.textPrimary.withOpacity(0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.appName,
                    style: TextStyle(
                      color: t.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppStrings.appVersion,
                    style: TextStyle(color: t.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Designed for premium audio experience with offline mode support.',
                    style: TextStyle(color: t.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '© 2026 Mewati Beats Inc.',
                    style: TextStyle(
                      color: t.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerTree extends StatelessWidget {
  final String label;
  final Color color;
  final Color accent;
  final Color text;
  final Color surface;
  final double radius;
  final bool collapsed;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  const _DrawerTree({
    required this.label,
    required this.color,
    required this.accent,
    required this.text,
    required this.surface,
    required this.radius,
    required this.collapsed,
    required this.expanded,
    required this.onToggle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    if (!collapsed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(label: label, color: color),
          const SizedBox(height: 10),
          ...children,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(radius),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: expanded ? accent.withOpacity(0.38) : surface,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: expanded ? accent : text.withOpacity(0.15),
                width: expanded ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: expanded ? const Color(0xFF1C1912) : color,
                      fontSize: expanded ? 12 : 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  color: expanded ? const Color(0xFF1C1912) : accent,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionTitle({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
      ),
    );
  }
}

class _DrawerPillRow extends StatelessWidget {
  final double radius;
  final bool isActive;
  final dynamic t;
  final VoidCallback onTap;
  final String label;
  final Widget? leading;

  const _DrawerPillRow({
    required this.radius,
    required this.isActive,
    required this.t,
    required this.onTap,
    required this.label,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.08) : t.surface,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: isActive ? t.accent : t.textPrimary.withOpacity(0.18),
          ),
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isActive ? t.accent : t.textPrimary.withOpacity(0.7),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? t.accent : Colors.white.withOpacity(0.5),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: t.accent.withOpacity(0.7),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final dynamic t;
  final double radius;
  final VoidCallback onTap;

  const _DrawerActionRow({
    required this.icon,
    required this.label,
    required this.t,
    required this.radius,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: t.textPrimary.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, color: t.textPrimary.withOpacity(0.8), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: t.textPrimary.withOpacity(0.8),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: t.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}
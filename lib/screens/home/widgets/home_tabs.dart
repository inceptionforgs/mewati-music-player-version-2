import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/themes/app_theme_id.dart';
import '../../../core/utils/home_nav.dart';
import '../../../providers/player_provider.dart';
import '../../../providers/theme_provider.dart';

class HomeTabs extends StatelessWidget {
  final int currentIndex;
  final VoidCallback onHomeTap;
  final VoidCallback onVoiceTap;

  const HomeTabs({
    Key? key,
    required this.currentIndex,
    required this.onHomeTap,
    required this.onVoiceTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>().theme;
    final homeOn = currentIndex == HomeNav.trending;

    if (t.id == AppThemeId.silverChrome) {
      final playing = context.select<PlayerProvider, bool>((p) => p.hasSong);
      final inset = playing ? 0.0 : MediaQuery.of(context).padding.bottom;
      return Container(
        height: 66 + inset,
        padding: EdgeInsets.only(bottom: inset),
        decoration: BoxDecoration(
          color: t.surface,
        ),
        child: Row(
          children: [
            _AppleIcon(
              icon: Icons.home,
              label: 'Home',
              selected: homeOn,
              colorOn: t.accent,
              colorOff: t.textSecondary,
              onTap: onHomeTap,
            ),
            _AppleIcon(
              icon: Icons.mic,
              label: 'Voice search',
              selected: false,
              colorOn: t.accent,
              colorOff: t.textSecondary,
              onTap: onVoiceTap,
            ),
          ],
        ),
      );
    }

    return Container(
      height: 53,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: t.textPrimary.withOpacity(0.18), width: 2),
        ),
      ),
      child: Row(
        children: [
          _SimpleIcon(
            icon: Icons.home,
            label: 'Home',
            selected: homeOn,
            color: t.textPrimary,
            onTap: onHomeTap,
          ),
          _SimpleIcon(
            icon: Icons.mic,
            label: 'Voice search',
            selected: false,
            color: t.textPrimary,
            onTap: onVoiceTap,
          ),
        ],
      ),
    );
  }
}

class _AppleIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color colorOn;
  final Color colorOff;
  final VoidCallback onTap;

  const _AppleIcon({
    required this.icon,
    required this.label,
    required this.selected,
    required this.colorOn,
    required this.colorOff,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          child: Icon(
            icon,
            size: 39,
            color: selected ? colorOn : colorOff,
          ),
        ),
      ),
    );
  }
}

class _SimpleIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _SimpleIcon({
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          child: Icon(
            icon,
            size: 28,
            color: selected ? color : color.withOpacity(0.45),
          ),
        ),
      ),
    );
  }
}
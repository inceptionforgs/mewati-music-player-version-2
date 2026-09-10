import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/themes/app_theme_id.dart';
import '../../../providers/theme_provider.dart';

class BrandRow extends StatelessWidget {
  final VoidCallback onMenuTap;
  final VoidCallback onSearchTap;

  const BrandRow({
    Key? key,
    required this.onMenuTap,
    required this.onSearchTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>().theme;
    final apple = t.id == AppThemeId.silverChrome;

    if (apple) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.menu, color: t.textPrimary, size: 26),
                onPressed: onMenuTap,
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.search, color: t.textPrimary, size: 26),
                onPressed: onSearchTap,
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(8, apple ? 8 : 6, 8, apple ? 8 : 0),
      child: SizedBox(
        height: apple ? 56 : 48,
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.menu, color: t.textPrimary, size: apple ? 28 : 24),
              onPressed: onMenuTap,
            ),
            Icon(Icons.music_note, color: t.accent, size: apple ? 28 : 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppStrings.appName,
                style: TextStyle(
                  color: t.textPrimary,
                  fontSize: apple ? 22 : 20,
                  fontWeight: apple ? FontWeight.w500 : FontWeight.w600,
                  fontStyle: apple ? FontStyle.normal : FontStyle.italic,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: Icon(Icons.search, color: t.textPrimary, size: apple ? 28 : 24),
              onPressed: onSearchTap,
            ),
          ],
        ),
      ),
    );
  }
}
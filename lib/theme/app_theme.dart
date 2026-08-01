import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Polices (08_UI_UX_DESIGN_SYSTEM.md) : Silkscreen pour titres/AppBar/badges,
/// JetBrains Mono pour le corps de texte. ⚠️ Ne jamais utiliser NType82 de Nothing —
/// police propriétaire.
class AppTheme {
  static ThemeData get light => _base(Brightness.light, AppColors.lightBg, Colors.black);
  static ThemeData get dark => _base(Brightness.dark, AppColors.darkBg, AppColors.accentTextOnDark);

  static ThemeData _base(Brightness brightness, Color background, Color errorTextColor) {
    final base = ThemeData(brightness: brightness, useMaterial3: true, scaffoldBackgroundColor: background);
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(primary: AppColors.accent, error: AppColors.accent),
      textTheme: GoogleFonts.jetBrainsMonoTextTheme(base.textTheme),
      appBarTheme: base.appBarTheme.copyWith(
        titleTextStyle: GoogleFonts.silkscreen(fontSize: 18, color: base.textTheme.titleLarge?.color),
      ),
    );
  }
}

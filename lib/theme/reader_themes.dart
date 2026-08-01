import 'package:flutter/material.dart';

import 'app_colors.dart';

enum ReaderTheme { clair, sombre, liseuse }
// AMOLED / Nord / Gruvbox / Catppuccin : V3 (07_READER_AUDIOBOOK.md).

class ReaderThemeColors {
  final Color background;
  final Color text;
  const ReaderThemeColors({required this.background, required this.text});
}

const readerThemeColors = {
  ReaderTheme.clair: ReaderThemeColors(background: Color(0xFFFFFFFF), text: Color(0xFF0A0A0A)),
  ReaderTheme.sombre: ReaderThemeColors(background: Color(0xFF0A0A0A), text: Color(0xFFE0E0E0)),
  ReaderTheme.liseuse: ReaderThemeColors(background: AppColors.sepiaBg, text: AppColors.sepiaText),
};

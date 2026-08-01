class WindowsPathValidator {
  static const int legacyMax = 260;
  static const int longPathMax = 32767;

  static String? validate(String path, {bool longPathSupport = false}) {
    if (path.isEmpty) return 'path.empty';
    if (path.length > (longPathSupport ? longPathMax : legacyMax)) return 'path.too_long';
    for (final seg in path.split(RegExp(r'[\\/]+'))) {
      if (seg.isEmpty) continue;
      if (seg.endsWith(' ') || seg.endsWith('.')) return 'path.trailing_dot_or_space';
    }
    return null; // FilenameSanitizer gère déjà les caractères interdits et noms réservés
  }
}

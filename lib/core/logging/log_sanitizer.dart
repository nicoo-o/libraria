/// Voir docs/restructuration_claude.md, chapitre 03 (§ Sanitization des logs).
/// Branché dans `AppLogger` directement (pas seulement à l'export du rapport de
/// diagnostic) — le rapport de diagnostic partage les logs tels quels via `share_plus`.
class LogSanitizer {
  static final _patterns = [
    RegExp(
      r'(api[_-]?key|token|password|secret|passphrase)["\s]*[:=]["\s]*[^&\s"]+',
      caseSensitive: false,
    ),
    RegExp(r'Bearer\s+[A-Za-z0-9._-]+'),
    RegExp(r'Basic\s+[A-Za-z0-9+/=]+'),
    RegExp(r'https?://[^:/]+:[^@/]+@'),
  ];

  static String sanitize(String s) {
    var out = s;
    for (final p in _patterns) {
      out = out.replaceAll(p, '[REDACTED]');
    }
    return out;
  }
}

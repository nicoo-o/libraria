import 'dart:io';
import 'package:path/path.dart' as p;

class FilenameSanitizer {
  static final _forbidden = RegExp(r'[<>:"/\\|?*\x00-\x1f]');
  static const _maxLen = 100;
  static const _reservedWindows = {
    'CON', 'PRN', 'AUX', 'NUL',
    'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
    'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9',
  };

  static String sanitize(String name) {
    var s = name.replaceAll(_forbidden, '_').replaceAll('..', '_').trim();
    if (s.isEmpty) s = 'file_${DateTime.now().millisecondsSinceEpoch}';
    final upper = s.toUpperCase().split('.').first;
    if (_reservedWindows.contains(upper)) s = '_$s';
    if (s.length > _maxLen) s = s.substring(0, _maxLen);
    return s;
  }

  /// Dernière ligne de défense : le chemin final doit résoudre dans le dossier attendu.
  static bool isWithinSandbox(String filePath, String sandboxDir) {
    final resolved = p.normalize(File(filePath).absolute.path);
    final sandbox = p.normalize(Directory(sandboxDir).absolute.path);
    return p.isWithin(sandbox, resolved) || resolved == sandbox;
  }
}

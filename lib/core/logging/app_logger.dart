import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'log_rotator.dart';
import 'log_sanitizer.dart';

enum LogLevel { debug, info, warn, error }

class _LogEntry {
  final DateTime time;
  final LogLevel level;
  final String module;
  final String message;
  _LogEntry(this.time, this.level, this.module, this.message);

  @override
  String toString() =>
      '${time.toIso8601String()} [${level.name.toUpperCase()}] [$module] $message';
}

/// Journalisation locale uniquement — zéro télémétrie automatique, zéro SDK tiers
/// (Sentry, Crashlytics), voir ADR-006. Chaque ligne passe par `LogSanitizer` avant
/// d'entrer dans le buffer, pas seulement à la lecture.
///
/// [Chapitre 12, NF-059 — trou comblé] En plus du buffer mémoire (borné à
/// `_maxEntries`, déjà auto-purgeant), chaque ligne est maintenant append-ée
/// à un fichier persistant si `AppLogger.init()` a été appelé (voir
/// main.dart) — utile pour un rapport de diagnostic couvrant une session
/// précédente, pas seulement les 5000 dernières lignes en mémoire de la
/// session en cours. `LogRotator` (jusqu'ici un stub jamais appelé, voir
/// audit V1) est maintenant réellement déclenché, tous les
/// `_rotationCheckInterval` écritures, pour que ce fichier ne grossisse pas
/// indéfiniment.
class AppLogger {
  static final ListQueue<_LogEntry> _buffer = ListQueue();
  static const _maxEntries = 5000;

  static File? _logFile;
  static final LogRotator _rotator = LogRotator();
  static int _writesSinceRotationCheck = 0;
  static const _rotationCheckInterval = 200;

  /// À appeler une fois au démarrage (main()), avant tout log si possible.
  /// Sans cet appel, `AppLogger` reste utilisable (buffer mémoire seul,
  /// comportement identique à avant ce correctif) — juste rien n'est écrit
  /// sur disque, et `LogRotator` n'a donc rien à purger.
  static Future<void> init(Directory logDirectory) async {
    if (!await logDirectory.exists()) {
      await logDirectory.create(recursive: true);
    }
    _logFile = File('${logDirectory.path}/libraria.log');
  }

  static void debug(String message, {required String module}) =>
      _log(LogLevel.debug, module, message);

  static void info(String message, {required String module}) =>
      _log(LogLevel.info, module, message);

  static void warn(String message, {required String module, Object? error}) =>
      _log(LogLevel.warn, module, error == null ? message : '$message | $error');

  static void error(
    String message, {
    required String module,
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _log(LogLevel.error, module, error == null ? message : '$message | $error');

  static void _log(LogLevel level, String module, String message) {
    final sanitized = LogSanitizer.sanitize(message);
    final entry = _LogEntry(DateTime.now(), level, module, sanitized);
    _buffer.addLast(entry);
    while (_buffer.length > _maxEntries) {
      _buffer.removeFirst();
    }
    // ignore: avoid_print
    print(_buffer.last);
    unawaited(_appendToFile(entry));
  }

  static Future<void> _appendToFile(_LogEntry entry) async {
    final file = _logFile;
    if (file == null) return;
    try {
      await file.writeAsString('${entry.toString()}\n', mode: FileMode.append, flush: false);
      _writesSinceRotationCheck++;
      if (_writesSinceRotationCheck >= _rotationCheckInterval) {
        _writesSinceRotationCheck = 0;
        await _rotator.rotateIfNeeded(file);
      }
    } catch (_) {
      // Silencieux : l'écriture de logs ne doit jamais faire planter l'appelant
      // (principe déjà appliqué à LogSanitizer/ChecksumVerifier).
    }
  }

  /// Utilisé par `DiagnosticReportService` (lib/core/diagnostics/).
  static Future<List<String>> readRecentLogs({int maxLines = 2000}) async {
    return _buffer.toList().reversed.take(maxLines).map((e) => e.toString()).toList();
  }
}

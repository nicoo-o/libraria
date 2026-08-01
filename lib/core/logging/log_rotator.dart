import 'dart:io';

/// NF-059 (docs/restructuration_claude.md, chapitre 12.6) — trou comblé :
/// jusqu'ici ce fichier était un stub (`throw UnimplementedError`), jamais
/// appelé par `AppLogger` (voir audit V1). `AppLogger` écrit maintenant
/// chaque ligne dans un fichier persistant en plus du buffer mémoire (voir
/// app_logger.dart) ; ce fichier peut grossir indéfiniment sans purge — c'est
/// ce que cette classe corrige.
class LogRotator {
  LogRotator({this.maxSizeBytes = 5 * 1024 * 1024, this.maxAgeDays = 30});

  final int maxSizeBytes;
  final int maxAgeDays;

  /// Purge par taille : si `file` dépasse `maxSizeBytes`, ne garde que sa
  /// moitié la plus récente. [Principe déjà établi ailleurs — "streaming
  /// over buffering"] On ne charge jamais tout le fichier en mémoire : on ne
  /// lit que la portion qu'on va conserver (`maxSizeBytes ~/ 2` derniers
  /// octets), comme pour `ChecksumVerifier`/`CoverProcessor`.
  ///
  /// [Limitation V1 documentée, pas un oubli] `maxAgeDays` n'est pas
  /// appliqué ligne par ligne (nécessiterait de parser l'horodatage de
  /// chaque entrée) — la coupure par taille suffit en pratique pour un usage
  /// V1 mono-utilisateur, où le fichier de log reste de toute façon petit
  /// (voir `_rotationCheckInterval` dans app_logger.dart).
  Future<void> rotateIfNeeded(File file) async {
    if (!await file.exists()) return;
    final length = await file.length();
    if (length <= maxSizeBytes) return;

    final raf = await file.open();
    try {
      final keepFrom = length - (maxSizeBytes ~/ 2);
      await raf.setPosition(keepFrom < 0 ? 0 : keepFrom);
      final remaining = await raf.read(length - (keepFrom < 0 ? 0 : keepFrom));
      // Repartir juste après la première fin de ligne pour ne pas couper une
      // entrée de log au milieu.
      final newlineIndex = remaining.indexOf(10); // '\n'
      final trimmed = newlineIndex >= 0 ? remaining.sublist(newlineIndex + 1) : remaining;
      await raf.close();
      await file.writeAsBytes(trimmed, flush: true);
    } catch (_) {
      // Une rotation ratée ne doit jamais faire planter AppLogger — au pire
      // le fichier continue de grossir jusqu'à la prochaine tentative.
      try {
        await raf.close();
      } catch (_) {}
    }
  }
}

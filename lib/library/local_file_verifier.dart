import 'dart:io';

import '../core/models/library_item.dart';
import 'library_repository.dart';

/// Tâche périodique de vérification des fichiers locaux (09_TESTS_CI.md,
/// `Workmanager` toutes les 12h sur Android, timer in-app au démarrage sur Windows).
/// Pose `is_missing = 1` si le fichier n'existe plus à `local_path`, sans jamais
/// supprimer l'entrée — c'est le badge « manquant » + le flux `relink()` qui gèrent
/// la suite (08_UI_UX_DESIGN_SYSTEM.md).
class LocalFileVerifier {
  LocalFileVerifier(this._repository);
  final LibraryRepository _repository;

  Future<int> verifyAll() async {
    final items = await _repository.getAll();
    var missingCount = 0;
    for (final item in items) {
      if (await _isMissing(item)) missingCount++;
    }
    return missingCount;
  }

  Future<bool> _isMissing(LibraryItem item) async {
    final path = item.localPath;
    if (path == null) return false; // jamais téléchargé localement — pas "manquant", juste absent

    // [Correctif] `path` peut être un fichier (EPUB, M4B) OU un dossier
    // (audiobook LibriVox extrait — AudiobookZipExtractor, Partie 4) : vérifier
    // les deux, `File(path).exists()` seul renvoie systématiquement false pour
    // un dossier et marquerait à tort tout audiobook multi-fichiers "manquant".
    final exists = await File(path).exists() || await Directory(path).exists();
    if (exists) return false;

    if (!item.isMissing) {
      await _repository.markMissing(item.id);
    }
    return true;
  }
}

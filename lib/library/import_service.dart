import 'dart:io';

import '../core/integrity/checksum_verifier.dart';
import 'library_repository.dart';

/// Import local (V1 : « Ouvrir avec... » + import manuel de fichiers EPUB/MP3/M4B).
/// La détection de doublon par hash (MES_PROPOSITIONS_LIBRARIA.md #2) est déjà
/// câblée ici ; le scan récursif de dossier (chapitre 12, NF-093) réutilise
/// exactement ce chemin, fichier par fichier.
class ImportService {
  ImportService(this._repository);
  final LibraryRepository _repository;

  Future<ImportResult> importFile(String filePath) async {
    final sha = await ChecksumVerifier.computeStreaming(File(filePath));
    final duplicate = await _repository.findByContentHash(sha);
    if (duplicate != null) {
      return ImportResult.duplicate(existing: duplicate);
    }
    throw UnimplementedError(
      'ImportService.importFile() — après vérification du doublon : ZipBombGuard.check() '
      'si EPUB, FilenameSanitizer pour la destination, puis repository.saveItem(). '
      'Voir 03_SECURITE.md et 04_BASE_DE_DONNEES.md.',
    );
  }
}

class ImportResult {
  final bool isDuplicate;
  final Object? existing;
  ImportResult.duplicate({required this.existing}) : isDuplicate = true;
  ImportResult.imported() : isDuplicate = false, existing = null;
}

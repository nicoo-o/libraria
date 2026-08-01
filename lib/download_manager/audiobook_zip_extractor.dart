import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

/// [Correctif Partie 4] LibriVox distribue chaque livre en un UNIQUE fichier
/// `.zip` contenant les MP3 séparés par chapitre (`url_zip_file`, voir
/// `LibrivoxSource`), alors qu'`AudioPlayerScreen` (Partie 6) attend un DOSSIER
/// contenant ces MP3 directement (`Directory(item.localPath).list()`). Avant ce
/// correctif, rien n'ouvrait jamais ce `.zip` après téléchargement : il était
/// passé tel quel à `just_audio`, qui ne sait pas décoder une archive — la
/// lecture échouait pour tout audiobook LibriVox, alors même que le
/// téléchargement lui-même réussissait.
class AudiobookZipExtractor {
  /// Décompresse [zipPath] dans un dossier voisin (même chemin, sans
  /// l'extension `.zip`), puis supprime le zip. `extractFileToDisk` (package
  /// `archive_io`, déjà une dépendance du projet pour `ZipBombGuard`) protège
  /// nativement contre le zip-slip (entrées `../..` résolvant hors du dossier
  /// de sortie). Retourne le chemin du dossier extrait.
  static Future<String> extract(String zipPath) async {
    final destDir = p.withoutExtension(zipPath);
    await Directory(destDir).create(recursive: true);
    await extractFileToDisk(zipPath, destDir);
    await File(zipPath).delete();
    return destDir;
  }
}

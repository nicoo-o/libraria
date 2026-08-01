import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:libraria/download_manager/audiobook_zip_extractor.dart';

/// [Régression] Ce test couvre directement le bug trouvé lors de la revue de la
/// Partie 4 : LibriVox livre chaque audiobook en un UNIQUE `.zip` contenant les
/// MP3 séparés par chapitre. Avant `AudiobookZipExtractor`, ce `.zip` était
/// téléchargé mais jamais ouvert — `AudioPlayerScreen` (Partie 6) s'attend à
/// trouver un DOSSIER de MP3 à `item.localPath`, et recevait un fichier `.zip`
/// que `just_audio` ne sait pas décoder. La lecture échouait systématiquement
/// pour tout audiobook LibriVox, alors que le téléchargement réussissait.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('audiobook_zip_extractor_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// Construit un .zip contenant [fileCount] faux MP3 (contenu bidon — seule la
  /// présence/absence des fichiers importe pour ce test, pas leur lisibilité
  /// audio réelle).
  Future<String> buildFakeAudiobookZip(String zipPath, {int fileCount = 3}) async {
    final sourceDir = await Directory(p.join(tempDir.path, 'source')).create();
    final encoder = ZipFileEncoder()..create(zipPath);
    for (var i = 1; i <= fileCount; i++) {
      final file = File(p.join(sourceDir.path, 'chapter_$i.mp3'));
      await file.writeAsBytes(List<int>.filled(1024, i)); // contenu bidon non-vide
      await encoder.addFile(file, p.basename(file.path));
    }
    await encoder.close();
    return zipPath;
  }

  test('extrait chaque MP3 du zip dans un dossier voisin et supprime le zip', () async {
    final zipPath = p.join(tempDir.path, 'Lewis Carroll — Alice in Wonderland.zip');
    await buildFakeAudiobookZip(zipPath, fileCount: 3);

    final destDir = await AudiobookZipExtractor.extract(zipPath);

    // Le dossier retourné est bien celui qu'AudioPlayerScreen ira lister.
    expect(destDir, p.withoutExtension(zipPath));
    expect(await Directory(destDir).exists(), isTrue);

    final extractedFiles = await Directory(destDir)
        .list()
        .where((e) => e.path.endsWith('.mp3'))
        .toList();
    expect(extractedFiles, hasLength(3));

    // Le .zip source ne doit plus traîner sur le disque après extraction —
    // sinon on double l'espace utilisé pour rien (le zip + les MP3 extraits).
    expect(await File(zipPath).exists(), isFalse);
  });

  test('le contenu extrait est lisible et correspond au contenu original', () async {
    final zipPath = p.join(tempDir.path, 'test.zip');
    await buildFakeAudiobookZip(zipPath, fileCount: 1);

    final destDir = await AudiobookZipExtractor.extract(zipPath);

    final extracted = File(p.join(destDir, 'chapter_1.mp3'));
    expect(await extracted.exists(), isTrue);
    expect(await extracted.length(), 1024);
  });
}

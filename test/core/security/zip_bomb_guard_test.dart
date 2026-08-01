import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:libraria/core/errors/exceptions.dart';
import 'package:libraria/core/security/zip_bomb_guard.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zip_bomb_guard_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<String> buildZip(
    String zipPath, {
    required bool includeMimetype,
    List<int>? extraFileContent,
    int compressionLevel = 6,
  }) async {
    final encoder = ZipFileEncoder()..create(zipPath);

    if (includeMimetype) {
      final mimetypeFile = File(p.join(tempDir.path, 'mimetype'));
      await mimetypeFile.writeAsString('application/epub+zip');
      await encoder.addFile(mimetypeFile, 'mimetype', 0); // non compressé, comme un vrai EPUB
    }

    if (extraFileContent != null) {
      final contentFile = File(p.join(tempDir.path, 'content.xhtml'));
      await contentFile.writeAsBytes(extraFileContent);
      await encoder.addFile(contentFile, 'OEBPS/content.xhtml', compressionLevel);
    }

    await encoder.close();
    return zipPath;
  }

  test('accepte un EPUB valide (entrée mimetype présente, taille raisonnable)', () async {
    final zipPath = p.join(tempDir.path, 'valid.epub');
    await buildZip(
      zipPath,
      includeMimetype: true,
      extraFileContent: 'Un chapitre de test, pas très long.'.codeUnits,
    );

    await expectLater(ZipBombGuard.check(zipPath), completes);
  });

  test('rejette une archive sans entrée mimetype (pas un EPUB valide)', () async {
    final zipPath = p.join(tempDir.path, 'no_mimetype.zip');
    await buildZip(
      zipPath,
      includeMimetype: false,
      extraFileContent: 'Contenu quelconque'.codeUnits,
    );

    await expectLater(
      ZipBombGuard.check(zipPath),
      throwsA(isA<CorruptedFileException>()),
    );
  });

  // [Sécurité] Contenu hautement compressible (zéros) → ratio de compression
  // énorme une fois décompressé, signature typique d'une zip bomb. Le fichier
  // sur disque reste minuscule ; c'est justement tout l'intérêt de l'attaque.
  test('rejette une archive dont le ratio de décompression est suspect (zip bomb)', () async {
    final zipPath = p.join(tempDir.path, 'bomb.epub');
    // ~5 Mo de zéros compressent en quelques centaines d'octets à un niveau 9 —
    // largement au-dessus du ratio maximal (200) autorisé par ZipBombGuard.
    final highlyCompressible = List<int>.filled(5 * 1024 * 1024, 0);
    await buildZip(
      zipPath,
      includeMimetype: true,
      extraFileContent: highlyCompressible,
      compressionLevel: 9,
    );

    await expectLater(
      ZipBombGuard.check(zipPath),
      throwsA(isA<CorruptedFileException>()),
    );
  });
}

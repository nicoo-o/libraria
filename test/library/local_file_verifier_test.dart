import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:libraria/core/models/library_item.dart';
import 'package:libraria/core/models/media_type.dart';
import 'package:libraria/library/library_repository.dart';
import 'package:libraria/library/local_file_verifier.dart';
import 'package:libraria/library/migrations/migrations.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tempDir;
  late LibraryRepository repository;
  late LocalFileVerifier verifier;

  late Database db;
  setUp(() async {
    tempDir =
        await Directory.systemTemp.createTemp('local_file_verifier_test_');
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    for (final stmt in splitSqlStatements(fullSchemaV17)) {
      await db.execute(stmt);
    }
    repository = LibraryRepository(db);
    verifier = LocalFileVerifier(repository);
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  LibraryItem buildItem({required String id, String? localPath}) => LibraryItem(
        id: id,
        title: 'Titre $id',
        mediaType: MediaType.book,
        localPath: localPath,
        addedAt: DateTime.now(),
      );

  test('marque manquant un item dont le fichier local a disparu', () async {
    final missingPath = p.join(tempDir.path, 'ce-fichier-n-existe-pas.epub');
    await repository.saveItem(buildItem(id: 'a', localPath: missingPath));

    final missingCount = await verifier.verifyAll();

    expect(missingCount, 1);
    final reloaded = await repository.getById('a');
    expect(reloaded!.isMissing, isTrue);
  });

  test('ne touche pas un item dont le fichier local existe toujours', () async {
    final existingFile = File(p.join(tempDir.path, 'present.epub'));
    await existingFile.writeAsString('contenu bidon');
    await repository.saveItem(buildItem(id: 'b', localPath: existingFile.path));

    final missingCount = await verifier.verifyAll();

    expect(missingCount, 0);
    final reloaded = await repository.getById('b');
    expect(reloaded!.isMissing, isFalse);
  });

  // [Régression] Un audiobook LibriVox extrait (AudiobookZipExtractor, Partie 4)
  // a un `local_path` qui pointe vers un DOSSIER, pas un fichier. `File(path)
  // .exists()` renvoie systématiquement false pour un dossier — sans vérifier
  // aussi `Directory(path).exists()`, tout audiobook aurait été marqué "manquant"
  // à chaque vérification périodique, alors que ses fichiers sont bien présents.
  test(
      'ne marque pas manquant un audiobook dont local_path est un dossier existant',
      () async {
    final audiobookDir =
        await Directory(p.join(tempDir.path, 'audiobook_extrait')).create();
    await File(p.join(audiobookDir.path, 'chapter_1.mp3'))
        .writeAsString('contenu bidon');
    await repository.saveItem(
      LibraryItem(
        id: 'c',
        title: 'Un audiobook',
        mediaType: MediaType.audiobook,
        localPath: audiobookDir.path,
        addedAt: DateTime.now(),
      ),
    );

    final missingCount = await verifier.verifyAll();

    expect(missingCount, 0);
    final reloaded = await repository.getById('c');
    expect(reloaded!.isMissing, isFalse);
  });

  test('ignore un item jamais téléchargé localement (local_path null)',
      () async {
    await repository.saveItem(buildItem(id: 'd', localPath: null));

    final missingCount = await verifier.verifyAll();

    expect(missingCount, 0);
  });
}

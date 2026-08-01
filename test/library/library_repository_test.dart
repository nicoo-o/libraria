import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:libraria/core/models/library_item.dart';
import 'package:libraria/core/models/media_type.dart';
import 'package:libraria/library/library_repository.dart';
import 'package:libraria/library/migrations/migrations.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tempDir;
  late LibraryRepository repo;
  late Database db;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('library_repository_test_');
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    for (final stmt in splitSqlStatements(fullSchemaV17)) {
      await db.execute(stmt);
    }
    repo = LibraryRepository(db);
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  LibraryItem buildItem(
          {required String id, String? localPath, String? coverPath}) =>
      LibraryItem(
        id: id,
        title: 'Titre $id',
        mediaType: MediaType.book,
        localPath: localPath,
        coverPath: coverPath,
        addedAt: DateTime.now(),
      );

  test('saveItem() puis getById() retrouve exactement le même item', () async {
    await repo.saveItem(buildItem(id: 'a'));
    final reloaded = await repo.getById('a');
    expect(reloaded, isNotNull);
    expect(reloaded!.title, 'Titre a');
  });

  test('getAll() exclut par défaut les items supprimés (deleted_at non null)',
      () async {
    await repo.saveItem(buildItem(id: 'a'));
    await repo.saveItem(buildItem(id: 'b'));
    await repo.softDelete('b');

    final active = await repo.getAll();
    expect(active.map((i) => i.id), ['a']);

    final withDeleted = await repo.getAll(includeDeleted: true);
    expect(withDeleted.map((i) => i.id).toSet(), {'a', 'b'});
  });

  test(
      'softDelete() rend l\'item visible dans getTrash() mais plus dans getAll()',
      () async {
    await repo.saveItem(buildItem(id: 'a'));
    await repo.softDelete('a');

    expect(await repo.getAll(), isEmpty);
    final trash = await repo.getTrash();
    expect(trash.map((i) => i.id), ['a']);
  });

  test('restore() sort l\'item de la corbeille et le remet dans getAll()',
      () async {
    await repo.saveItem(buildItem(id: 'a'));
    await repo.softDelete('a');
    await repo.restore('a');

    expect(await repo.getTrash(), isEmpty);
    final active = await repo.getAll();
    expect(active.map((i) => i.id), ['a']);
  });

  // [Régression ADR-011] Avant correctif, purgeDeletedOlderThan() ne supprimait
  // QUE la ligne DB — les fichiers physiques (livre + couverture) restaient
  // orphelins sur le disque indéfiniment.
  test(
      'purgeDeletedOlderThan() supprime aussi le fichier ET la couverture physiques',
      () async {
    final bookFile = File(p.join(tempDir.path, 'book.epub'))
      ..writeAsStringSync('contenu');
    final coverFile = File(p.join(tempDir.path, 'cover.jpg'))
      ..writeAsStringSync('contenu');

    await repo.saveItem(buildItem(
        id: 'a', localPath: bookFile.path, coverPath: coverFile.path));
    await repo.softDelete('a');
    // [Régression] La ligne cover_cache_index doit être nettoyée IMMÉDIATEMENT
    // par la purge, pas seulement "au prochain passage LRU" comme c'était le
    // cas avant correctif.
    await db.insert('cover_cache_index', {
      'filename': p.basename(coverFile.path),
      'size_bytes': 7,
      'accessed_at': DateTime.now().millisecondsSinceEpoch,
    });

    // Simule une suppression il y a 31 jours (au-delà du seuil de 30j) en
    // réécrivant directement deleted_at — softDelete() pose "maintenant".
    await repo.saveItem(
      LibraryItem(
        id: 'a',
        title: 'Titre a',
        mediaType: MediaType.book,
        localPath: bookFile.path,
        coverPath: coverFile.path,
        addedAt: DateTime.now(),
        deletedAt: DateTime.now().subtract(const Duration(days: 31)),
      ),
    );

    await repo.purgeDeletedOlderThan(const Duration(days: 30));

    expect(await repo.getById('a'), isNull,
        reason: 'la ligne DB doit avoir disparu');
    expect(await bookFile.exists(), isFalse,
        reason: 'le fichier livre doit avoir été supprimé du disque');
    expect(await coverFile.exists(), isFalse,
        reason: 'le fichier couverture doit avoir été supprimé du disque');
    final coverIndexRows = await db.query(
      'cover_cache_index',
      where: 'filename = ?',
      whereArgs: [p.basename(coverFile.path)],
    );
    expect(coverIndexRows, isEmpty,
        reason: 'la ligne cover_cache_index doit être nettoyée immédiatement');
  });

  test(
      'purgeDeletedOlderThan() épargne les éléments supprimés depuis moins longtemps que le seuil',
      () async {
    final bookFile = File(p.join(tempDir.path, 'book.epub'))
      ..writeAsStringSync('contenu');
    await repo.saveItem(buildItem(id: 'a', localPath: bookFile.path));
    await repo
        .softDelete('a'); // supprimé "maintenant", bien en-deçà de 30 jours

    await repo.purgeDeletedOlderThan(const Duration(days: 30));

    expect(await repo.getById('a'), isNotNull,
        reason: 'trop récent pour être purgé');
    expect(await bookFile.exists(), isTrue);
  });

  test(
      'purgeDeletedOlderThan() gère un local_path qui est un DOSSIER (audiobook extrait)',
      () async {
    final audiobookDir =
        await Directory(p.join(tempDir.path, 'audiobook')).create();
    await File(p.join(audiobookDir.path, 'chapter_1.mp3'))
        .writeAsString('contenu');

    await repo.saveItem(
      LibraryItem(
        id: 'a',
        title: 'Audiobook',
        mediaType: MediaType.audiobook,
        localPath: audiobookDir.path,
        addedAt: DateTime.now(),
        deletedAt: DateTime.now().subtract(const Duration(days: 31)),
      ),
    );

    await repo.purgeDeletedOlderThan(const Duration(days: 30));

    expect(await audiobookDir.exists(), isFalse);
  });
}

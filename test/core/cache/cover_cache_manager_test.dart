import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:libraria/core/cache/cover_cache_manager.dart';
import 'package:libraria/library/migrations/migrations.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tempDir;
  late CoverCacheManager cache;

  setUp(() async {
    tempDir =
        await Directory.systemTemp.createTemp('cover_cache_manager_test_');
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    for (final stmt in splitSqlStatements(fullSchemaV17)) {
      await db.execute(stmt);
    }
    cache = CoverCacheManager(db, tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> writeFile(String filename, int sizeBytes) async {
    await File(p.join(tempDir.path, filename))
        .writeAsBytes(List<int>.filled(sizeBytes, 0));
  }

  test('put() retourne le chemin absolu du fichier indexé', () async {
    await writeFile('a.jpg', 100);
    final path = await cache.put('a.jpg', 100);
    expect(path, p.join(tempDir.path, 'a.jpg'));
  });

  test('n\'évince rien tant que maxSizeBytes n\'est pas dépassé', () async {
    await writeFile('a.jpg', 1000);
    await cache.put('a.jpg', 1000);
    expect(await File(p.join(tempDir.path, 'a.jpg')).exists(), isTrue);
  });

  // [Régression] Couvre le stub UnimplementedError d'origine : sans une vraie
  // implémentation, cover_cache_index grossirait indéfiniment et les fichiers
  // ne seraient jamais nettoyés du disque.
  test(
      'évince le fichier le moins récemment accédé quand maxSizeBytes est dépassé',
      () async {
    // maxSizeBytes est une constante de classe (200 Mo) — on simule le
    // dépassement avec des tailles qui, cumulées, le dépassent largement.
    final overSize = (CoverCacheManager.maxSizeBytes / 2).ceil() + 1024;

    await writeFile('old.jpg', overSize);
    await cache.put('old.jpg', overSize); // accessed_at le plus ancien

    // Précision temporelle : garantir un accessed_at strictement postérieur.
    await Future<void>.delayed(const Duration(milliseconds: 5));

    await writeFile('new.jpg', overSize);
    await cache.put(
        'new.jpg', overSize); // pousse le total au-delà de maxSizeBytes

    expect(await File(p.join(tempDir.path, 'old.jpg')).exists(), isFalse,
        reason: 'le plus ancien doit être évincé en premier');
    expect(await File(p.join(tempDir.path, 'new.jpg')).exists(), isTrue,
        reason: 'le plus récent doit rester en cache');
  });

  test('touch() rafraîchit accessed_at pour éviter une éviction prématurée',
      () async {
    // Taille ≈ 1/3 de la capacité : deux couvertures tiennent ensemble, une
    // troisième force l'éviction de la moins récemment accédée. (Avec des
    // tailles > 1/2 de la capacité, une seule couverture tiendrait à la fois et
    // le dernier `put` évincerait toujours l'autre, quel que soit `touch()`.)
    final size = (CoverCacheManager.maxSizeBytes / 3).ceil() + 1024;

    await writeFile('touched.jpg', size);
    await cache.put('touched.jpg', size); // accessed_at le plus ancien

    await Future<void>.delayed(const Duration(milliseconds: 5));
    await writeFile('other.jpg', size);
    await cache.put('other.jpg', size);

    // touch() remet touched.jpg au sommet du LRU : elle devient plus récente
    // qu'other.jpg, qui n'a pas été retouchée depuis son put initial.
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await cache.touch('touched.jpg');

    await Future<void>.delayed(const Duration(milliseconds: 5));
    await writeFile('newer.jpg', size);
    await cache.put('newer.jpg', size); // 3 fichiers > maxSizeBytes → éviction

    expect(await File(p.join(tempDir.path, 'touched.jpg')).exists(), isTrue,
        reason: 'touch() aurait dû protéger ce fichier de l\'éviction');
    expect(await File(p.join(tempDir.path, 'other.jpg')).exists(), isFalse,
        reason: 'la couverture non retouchée doit être évincée à la place');
  });
}

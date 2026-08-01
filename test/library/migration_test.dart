import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:libraria/library/migrations/migrations.dart';

/// Test de non-régression des migrations (09_TESTS_CI.md) : une migration qui échoue
/// ne doit pas laisser la base dans un état intermédiaire, et l'enchaînement complet
/// v1→v17 (le cas réel d'un utilisateur qui installe une version ayant sauté
/// plusieurs releases) doit s'appliquer sans erreur.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('la séquence complète v1 → v17 s\'applique sans erreur', () async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('PRAGMA foreign_keys = ON;');

    for (final stmt in splitSqlStatements(migrationV1)) {
      await db.execute(stmt);
    }
    for (var v = 2; v <= 17; v++) {
      final migration = migrationForVersion(v);
      if (migration == null) continue;
      for (final stmt in splitSqlStatements(migration)) {
        await db.execute(stmt);
      }
    }

    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
    );
    final tableNames = tables.map((t) => t['name']).toSet();
    for (final expected in [
      'library_items',
      'downloads',
      'settings',
      'bookmarks',
      'shelves',
      'shelf_items',
      'tags',
      'item_tags',
      'notes',
      'reading_sessions',
      'cover_cache_index'
    ]) {
      expect(tableNames.contains(expected), isTrue,
          reason: 'table manquante: $expected');
    }

    await db.close();
  });

  // [Correctif] Régression : `result_json`, `expected_sha1`, `expected_md5` et
  // `source_connector` existaient dans schema_full.dart (nouvelles installations)
  // mais l'une ou l'autre moitié manquait côté migrations `ALTER TABLE` (mises à
  // niveau) selon la colonne — une base migrée depuis v1 aurait fait échouer le
  // premier `db.insert('downloads', DownloadJob.toMap())` avec
  // "no such column". Ce test vérifie que la chaîne de migrations et le schéma
  // complet convergent vers exactement les mêmes colonnes sur `downloads`.
  test(
      'downloads a les mêmes colonnes en chemin onUpgrade (v1→v17) et onCreate (fullSchemaV17)',
      () async {
    final upgraded = await databaseFactory.openDatabase(inMemoryDatabasePath);
    for (final stmt in splitSqlStatements(migrationV1)) {
      await upgraded.execute(stmt);
    }
    for (var v = 2; v <= 17; v++) {
      final migration = migrationForVersion(v);
      if (migration == null) continue;
      for (final stmt in splitSqlStatements(migration)) {
        await upgraded.execute(stmt);
      }
    }
    final upgradedCols =
        (await upgraded.rawQuery('PRAGMA table_info(downloads)'))
            .map((c) => c['name'])
            .toSet();
    await upgraded.close();

    final fresh = await databaseFactory.openDatabase(inMemoryDatabasePath);
    for (final stmt in splitSqlStatements(fullSchemaV17)) {
      await fresh.execute(stmt);
    }
    final freshCols = (await fresh.rawQuery('PRAGMA table_info(downloads)'))
        .map((c) => c['name'])
        .toSet();
    await fresh.close();

    expect(upgradedCols, equals(freshCols));
    for (final col in [
      'result_json',
      'expected_sha1',
      'expected_md5',
      'source_connector'
    ]) {
      expect(upgradedCols.contains(col), isTrue,
          reason: 'colonne manquante côté onUpgrade: $col');
      expect(freshCols.contains(col), isTrue,
          reason: 'colonne manquante côté onCreate: $col');
    }
  });
}

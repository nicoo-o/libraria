import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:libraria/library/migrations/migrations.dart';

/// [Partie 8.1] Ce test vérifie une hypothèse écrite en commentaire dans
/// `database_helper.dart` ("sqflite ne persiste pas la nouvelle version si
/// onUpgrade lève — pas besoin de db.transaction() imbriqué, onUpgrade
/// s'exécute déjà dans une transaction implicite") mais qui n'avait jamais été
/// vérifiée par un test réel. Si ce test échoue, l'hypothèse est fausse et
/// `onUpgrade` doit être explicitement enveloppé dans `db.transaction()` dans
/// database_helper.dart — c'est le test le plus important à faire tourner en
/// premier avant de faire confiance au reste de la Partie 2.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('migration_rollback_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('une migration qui échoue à mi-chemin ne modifie ni la version ni le schéma persistés', () async {
    // Fichier réel sur disque (pas inMemoryDatabasePath) — nécessaire pour
    // fermer puis rouvrir la même base et vérifier ce qui a VRAIMENT été
    // persisté, par-delà la connexion en cours.
    final dbPath = p.join(tempDir.path, 'rollback_test.db');

    // 1. Créer la base à la version 1.
    var db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          for (final stmt in splitSqlStatements(migrationV1)) {
            await db.execute(stmt);
          }
        },
      ),
    );
    await db.close();

    // 2. Rouvrir en demandant la version 2, avec une migration qui ajoute
    //    d'abord une colonne valide PUIS échoue sur une instruction invalide —
    //    exactement le scénario "migration qui échoue à mi-chemin".
    Object? caughtError;
    try {
      db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 2,
          onUpgrade: (db, oldVersion, newVersion) async {
            await db.execute('ALTER TABLE library_items ADD COLUMN should_not_survive TEXT;');
            await db.execute('CECI N\'EST PAS DU SQL VALIDE;'); // provoque l'échec
          },
        ),
      );
    } catch (e) {
      caughtError = e;
    }
    expect(caughtError, isNotNull, reason: 'la migration invalide aurait dû lever une exception');

    // 3. Rouvrir normalement (sans onUpgrade) pour inspecter ce qui a
    //    réellement survécu, indépendamment de la connexion précédente.
    final inspect = await databaseFactory.openDatabase(dbPath);
    final version = await inspect.getVersion();
    final columns =
        (await inspect.rawQuery('PRAGMA table_info(library_items)')).map((c) => c['name']).toSet();
    await inspect.close();

    expect(version, 1, reason: 'user_version ne doit PAS être passé à 2 : la migration a échoué');
    expect(
      columns.contains('should_not_survive'),
      isFalse,
      reason: 'la colonne ajoutée AVANT l\'instruction invalide doit être annulée (rollback), '
          'pas laissée en état intermédiaire',
    );
  });
}

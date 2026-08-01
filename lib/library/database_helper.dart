
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../core/logging/app_logger.dart';
import 'migrations/migrations.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static const _dbName = 'libraria.db';
  static const _dbVersion = 17;

  static Future<Database>? _dbFuture;

  static Future<Database> get database {
    return _dbFuture ??= _openWithRetry();
  }

  /// [Correctif] SQLITE_BUSY intermittent sur "BEGIN EXCLUSIVE" observe sur
  /// une partie des lancements a froid (~75% dans nos tests), avant meme que
  /// PRAGMA busy_timeout ne puisse s'appliquer -- l'echec survient sur la
  /// transaction interne que sqflite utilise pour verifier/poser la version
  /// du schema, en amont de onConfigure. Cause exacte encore incertaine
  /// (contention emulateur au cold start probable), mais sans consequence
  /// destructrice puisque rien n'a encore ete ecrit a ce stade -- on peut
  /// donc retenter l'ouverture complete sans risque de corruption.
  ///
  /// Corrige aussi un bug latent : _dbFuture ??= _initDatabase() mettait en
  /// cache un Future ECHOUE de facon permanente en cas d'erreur -- tout appel
  /// suivant a DatabaseHelper.database aurait rethrow la meme exception a
  /// l'infini, sans jamais retenter, jusqu'au redemarrage complet du process.
  /// On reinitialise _dbFuture a null en cas d'echec definitif pour permettre
  /// un vrai nouvel essai plus tard (ex: prochain acces depuis l'UI).
  static Future<Database> _openWithRetry({int maxAttempts = 4}) async {
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await _initDatabase();
      } catch (e) {
        final isBusy = e.toString().contains('SQLITE_BUSY') ||
            e.toString().contains('database is locked');
        if (!isBusy || attempt == maxAttempts) {
          _dbFuture = null;
          rethrow;
        }
        AppLogger.info(
          'Ouverture DB: SQLITE_BUSY, nouvelle tentative ($attempt/$maxAttempts)',
          module: 'DB_INIT',
        );
        await Future.delayed(Duration(milliseconds: 300 * attempt));
      }
    }
    _dbFuture = null;
    throw StateError('Unreachable');
  }

  /// Execute une instruction SQL en ignorant silencieusement (avec log) les
  /// erreurs liees au module FTS5 quand il est absent du build SQLite du device
  /// (certaines images d'emulateur/Android ne le compilent pas). Sans ce garde-fou,
  /// l'absence de FTS5 ferait planter TOUT le schema (notes_fts + ses 3 triggers),
  /// alors que le reste de l'app doit rester utilisable -- seule la recherche
  /// plein texte des notes sera indisponible sur ces devices.
  static Future<bool> _safeExecute(DatabaseExecutor db, String stmt) async {
    try {
      await db.execute(stmt);
      return true;
    } catch (e, st) {
      final msg = e.toString();
      if (msg.contains('fts5') || msg.contains('notes_fts')) {
        AppLogger.error(
          'Instruction FTS5 ignoree (module fts5 indisponible sur ce device)',
          module: 'DB_INIT',
          error: e,
          stackTrace: st,
        );
        return false;
      }
      rethrow;
    }
  }

  /// [Correctif] SQLite ne verifie pas qu'une table referencee dans le corps
  /// d'un trigger existe au moment du CREATE TRIGGER -- seulement quand le
  /// trigger se declenche reellement. Donc si notes_fts echoue (fts5 absent),
  /// les 3 triggers notes_ai/au/ad qui la referencent se creent quand meme
  /// sans erreur, et l'app plante plus tard (ex: cascade ON DELETE) des qu'un
  /// trigger tente d'ecrire dans une table qui n'existe pas. On saute donc
  /// explicitement toute instruction liee a notes_fts des que la creation de
  /// la table elle-meme a echoue, avant meme de tenter de l'executer.
  static bool _skipIfFtsDependent(String stmt, bool ftsUnavailable) {
    return ftsUnavailable && stmt.contains('notes_fts');
  }

  static Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
        await db.rawQuery('PRAGMA journal_mode = WAL;');
        await db.rawQuery('PRAGMA busy_timeout = 5000;');
      },
      onCreate: (db, version) async {
        var ftsUnavailable = false;
        for (final stmt in splitSqlStatements(fullSchemaV17)) {
          if (_skipIfFtsDependent(stmt, ftsUnavailable)) {
            AppLogger.info(
              'Instruction liee a notes_fts ignoree (fts5 indisponible)',
              module: 'DB_INIT',
            );
            continue;
          }
          if (!await _safeExecute(db, stmt)) ftsUnavailable = true;
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        for (var v = oldVersion + 1; v <= newVersion; v++) {
          final migration = migrationForVersion(v);
          if (migration == null) continue;
          AppLogger.info('Migration v$v: start', module: 'DB_MIGRATION');
          try {
            var ftsUnavailable = false;
            for (final stmt in splitSqlStatements(migration)) {
              if (_skipIfFtsDependent(stmt, ftsUnavailable)) {
                AppLogger.info(
                  'Instruction liee a notes_fts ignoree (fts5 indisponible)',
                  module: 'DB_MIGRATION',
                );
                continue;
              }
              if (!await _safeExecute(db, stmt)) ftsUnavailable = true;
            }
            AppLogger.info('Migration v$v: success', module: 'DB_MIGRATION');
          } catch (e, st) {
            AppLogger.error('Migration v$v: failed', module: 'DB_MIGRATION', error: e, stackTrace: st);
            rethrow;
          }
        }
      },
    );
  }
}

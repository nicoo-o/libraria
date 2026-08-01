import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../core/integrity/checksum_verifier.dart';
import '../core/logging/app_logger.dart';

/// Sauvegarde locale manuelle (chapitre 12, NF-061 + NF-062) — trou comblé :
/// l'audit V1 avait trouvé qu'aucun module de sauvegarde n'existait, pas même
/// NF-061 qui devait précéder NF-062 ("rien à vérifier puisque rien ne
/// produit d'archive").
///
/// [Périmètre — respecte la spec du chapitre 12, pas plus] Le tableau NF-061
/// documente explicitement « zip DB + couvertures, sans WebDAV ». L'archive
/// contient donc :
///   - la base SQLite complète (bibliothèque, réglages, signets, notes, tags,
///     étagères — tout y vit déjà, voir settings_repository.dart)
///   - le cache de couvertures (`covers/`)
/// PAS les fichiers EPUB/audio eux-mêmes : potentiellement des gigaoctets,
/// explicitement hors du périmètre documenté. Une sauvegarde ne remplace pas
/// la présence des fichiers sources sur l'appareil ou leurs sources d'origine
/// (Gutenberg/Internet Archive/LibriVox/Standard Ebooks restent
/// re-téléchargeables).
class BackupService {
  BackupService({required this.db, required this.coversDirPath});

  final Database db;
  final String coversDirPath;

  /// Crée l'archive de sauvegarde et son fichier `.sha256` associé (NF-062).
  Future<BackupResult> createBackup() async {
    // [Correctif — cohérence WAL] La DB tourne en `PRAGMA journal_mode=WAL`
    // (voir database_helper.dart) : une partie des écritures récentes peut
    // encore résider uniquement dans le fichier `-wal` annexe, pas dans
    // `libraria.db` lui-même. Copier seulement `libraria.db` sans checkpoint
    // produirait une sauvegarde potentiellement amputée des toutes dernières
    // écritures. `TRUNCATE` force l'écriture de tout le WAL dans le fichier
    // principal puis le vide, pour une copie fiable de tout ce qui a été
    // committé jusqu'ici.
    await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE);');

    final backupDir = await _backupDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final archiveFile = File(p.join(backupDir.path, 'libraria_backup_$timestamp.zip'));

    final encoder = ZipFileEncoder();
    encoder.create(archiveFile.path);
    try {
      final dbFile = File(db.path);
      if (await dbFile.exists()) {
        await encoder.addFile(dbFile, 'library.db');
      }

      final coversDir = Directory(coversDirPath);
      if (await coversDir.exists()) {
        // includeDirName: true => les entrées gardent le préfixe "covers/"
        // dans l'archive, pour qu'une future restauration sache où les
        // remettre sans ambiguïté avec library.db à la racine.
        await encoder.addDirectory(coversDir, includeDirName: true);
      }
    } finally {
      await encoder.close();
    }

    // NF-062 : checksum SHA-256 de l'archive produite, écrit à côté d'elle —
    // réutilise ChecksumVerifier (déjà utilisé pour le relink de fichiers,
    // media_detail_screen.dart) plutôt que de recoder le hachage.
    final sha256Hex = await ChecksumVerifier.computeStreaming(archiveFile);
    final checksumFile = File('${archiveFile.path}.sha256');
    await checksumFile.writeAsString(sha256Hex);

    AppLogger.info(
      'Sauvegarde créée : ${p.basename(archiveFile.path)}',
      module: 'BACKUP',
    );

    return BackupResult(archiveFile: archiveFile, checksumFile: checksumFile, sha256: sha256Hex);
  }

  /// Vérifie qu'une archive de sauvegarde n'a pas été corrompue/modifiée
  /// depuis sa création, en recalculant son SHA-256 et en le comparant au
  /// fichier `.sha256` produit par `createBackup()` (NF-062).
  Future<bool> verifyBackup(File archiveFile) async {
    final checksumFile = File('${archiveFile.path}.sha256');
    if (!await archiveFile.exists() || !await checksumFile.exists()) return false;
    final expected = (await checksumFile.readAsString()).trim().toLowerCase();
    final actual = (await ChecksumVerifier.computeStreaming(archiveFile)).toLowerCase();
    return expected == actual;
  }

  /// Liste les sauvegardes existantes, la plus récente d'abord — utilisé par
  /// l'écran Réglages (aucune nouvelle table : juste un scan du dossier,
  /// comme documenté pour NF-065 si cet historique est étendu plus tard).
  Future<List<BackupEntry>> listBackups() async {
    final dir = await _backupDirectory();
    if (!await dir.exists()) return [];
    final entries = <BackupEntry>[];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.zip')) {
        final stat = await entity.stat();
        entries.add(BackupEntry(file: entity, sizeBytes: stat.size, createdAt: stat.modified));
      }
    }
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  Future<Directory> _backupDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(dir.path, 'backups'));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }
}

class BackupResult {
  BackupResult({required this.archiveFile, required this.checksumFile, required this.sha256});
  final File archiveFile;
  final File checksumFile;
  final String sha256;
}

class BackupEntry {
  BackupEntry({required this.file, required this.sizeBytes, required this.createdAt});
  final File file;
  final int sizeBytes;
  final DateTime createdAt;
}

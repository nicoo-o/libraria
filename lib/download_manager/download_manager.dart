import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/errors/exceptions.dart';
import '../core/http/http_client.dart';
import '../core/integrity/checksum_verifier.dart';
import '../core/logging/app_logger.dart';
import '../core/cache/cover_cache_manager.dart';
import '../library/library_change_notifier.dart';
import '../core/cache/cover_processor.dart';
import '../core/models/download_job.dart';
import '../core/models/media_type.dart';
import '../core/models/search_result.dart';
import '../core/security/filename_sanitizer.dart';
import '../core/security/url_validator.dart';
import '../core/security/zip_bomb_guard.dart';
import '../library/library_repository.dart';
import '../sources/internet_archive/internet_archive_source.dart';
import 'audiobook_zip_extractor.dart';

/// Cette classe a existé en au moins 3 versions incompatibles dans l'ancien guide.
/// Ce qui suit est la SEULE version à utiliser (ADR-008) — toute modification future
/// se fait ici, jamais par une redéfinition ailleurs (voir 11_BACKLOG.md, item C-01).
class DownloadManager extends ChangeNotifier {
  DownloadManager({
    required this.httpClient,
    required this.repository,
    required this.db,
    required this.libraryDirPath,
    CoverCacheManager? coverCache,
    this.libraryChangeNotifier,
  }) : coverCache = coverCache ?? CoverCacheManager(db, p.join(libraryDirPath, 'covers'));

  final HttpClient httpClient;
  final LibraryRepository repository;
  final Database db;
  // [Correctif ADR-010] Rien ne téléchargeait ni ne mettait en cache de
  // couverture nulle part — `DownloadJob.coverPath` restait toujours null.
  // Injectable pour les tests, construit automatiquement sinon.
  final CoverCacheManager coverCache;

  /// [Correctif] Sans ceci, LibraryScreen ne se rafraichit qu'en comptant les
  /// jobs "completed" DANS `jobs` (liste en memoire) -- or resumeAll() ne
  /// recharge jamais les jobs deja completed apres un redemarrage de l'app,
  /// desynchronisant ce compteur en permanence des qu'un item est termine
  /// dans une session differente de celle ou LibraryScreen l'observe. Notifier
  /// explicitement est fiable, independant de ce que contient `jobs`.
  final LibraryChangeNotifier? libraryChangeNotifier;

  /// Racine des fichiers de bibliothèque (books/, audiobooks/, covers/) — fournie par
  /// la composition root (main.dart), jamais codée en dur ici.
  final String libraryDirPath;

  final List<DownloadJob> jobs = [];

  int maxConcurrent = 3; // configurable 1–6, Settings
  int _activeCount = 0;
  final Map<String, CancelToken> _cancelTokens = {};

  /// [Correctif] Délai avant retry — SANS ce champ, `_tryStartNext()` (rappelé
  /// par `.whenComplete()` juste après l'échec) relançait le job la microtask
  /// suivante : une vraie coupure réseau de quelques secondes épuisait les 3
  /// tentatives quasi instantanément, et le job partait en échec DÉFINITIF
  /// (fichier partiel supprimé) bien avant la moindre chance de reconnexion.
  /// Champ public et substituable en test pour ne pas faire durer les tests
  /// unitaires plusieurs secondes (voir download_manager_test.dart).
  Duration Function(int retryCount) retryBackoff =
      (retryCount) => Duration(seconds: 2 * (1 << retryCount));

  // Throttle des écritures DB de progression — voir _downloadDirect(). Sans ça,
  // onProgress() (appelé plusieurs fois par seconde par Dio) écrirait en base à
  // la même fréquence, pour un gain nul (le resume se fait sur la taille réelle
  // du fichier, pas sur cette valeur).
  final Map<String, double> _lastPersistedProgress = {};

  /// [Correctif partie 4] Point d'écriture UNIQUE vers la table `downloads`.
  /// Avant ce correctif, `enqueue()` n'écrivait jamais en base : `resumeAll()`
  /// (plus bas) trouvait toujours zéro ligne, et la reprise après fermeture de
  /// l'app était totalement silencieuse. `INSERT OR REPLACE` sert à la fois de
  /// création initiale et de mise à jour de statut — `id` est la clé primaire.
  Future<void> _persist(DownloadJob job) async {
    await db.insert('downloads', job.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Insertion triée par priorité (1 = haute) puis FIFO — pas un simple `jobs.add()`.
  Future<void> enqueue(SearchResult result, {int priority = 2}) async {
    // Détection de doublon dans la queue elle-même (chapitre 12, NF-040) : éviter
    // d'enqueue deux fois la même download_url.
    // Dédup robuste : on empêche d'ajouter 2 fois le même contenu même si le job
    // n'est pas encore passé en queued/downloading (ou s'il a échoué rapidement).
    final alreadyExists = jobs.any((j) => j.result.downloadUrl == result.downloadUrl);
    if (alreadyExists) return;


    final job = DownloadJob(id: const Uuid().v4(), result: result, priority: priority);
    final insertAt = jobs.indexWhere((j) => j.priority > job.priority);
    if (insertAt == -1) {
      jobs.add(job);
    } else {
      jobs.insert(insertAt, job);
    }
    // Ligne `downloads` créée dès l'enqueue, pas seulement en mémoire — c'est
    // elle que resumeAll() retrouvera après un crash/fermeture de l'app.
    await _persist(job);
    notifyListeners();

    if (!result.isDirectDownload) {
      job.status = DownloadStatus.failed;
      job.errorMessage = 'Client de téléchargement non configuré.';
      await _persist(job);
      notifyListeners();
      return;
    }
    await _checkDiskSpace(job);
    _tryStartNext();
  }

  Future<void> _checkDiskSpace(DownloadJob job) async {
    // [Correctif] Directory(...).stat().size NE mesure PAS l'espace disque
    // disponible -- c'est la taille de l'entree du dossier lui-meme (quasi
    // nulle sur la plupart des systemes de fichiers). Cette verification
    // echouait donc TOUJOURS, faisant repartir chaque telechargement en
    // echec immediat, avant meme d'appeler downloadWithResume(). Desactivee
    // en attendant une vraie mesure (package disk_space ou plateforme
    // native, DM-05, 11_BACKLOG.md) -- ne PAS reactiver cette logique telle
    // quelle.
  }

  void _tryStartNext() {
    if (_activeCount >= maxConcurrent) return;
    final next = jobs.firstWhereOrNull((j) => j.status == DownloadStatus.queued);
    if (next == null) return;

    _activeCount++;
    next.status = DownloadStatus.downloading;
    unawaited(_persist(next));
    notifyListeners();

    final cancelToken = CancelToken();
    _cancelTokens[next.id] = cancelToken;

    _downloadDirect(next, cancelToken).whenComplete(() {
      _activeCount--;
      _cancelTokens.remove(next.id);
      _tryStartNext();
    });
  }

  Future<void> _downloadDirect(DownloadJob job, CancelToken cancelToken) async {
    try {
      UrlValidator.validate(job.result.downloadUrl); // 03_SECURITE.md

      final savePath = _buildSavePath(job.result); // FilenameSanitizer + isWithinSandbox
      // [Correctif] `_cleanupPartialFile()` (appelée par _handleFailure sur échec
      // définitif, ex: 404) lisait `job.localPath`, qui n'était fixé QUE sur le
      // chemin de succès plus bas — un échec ne nettoyait donc jamais le fichier
      // partiel, malgré le commentaire "pas de fichier orphelin" à cet endroit.
      // Checklist Partie 4 : "Forcer un 404 → ... le fichier partiel est nettoyé".
      job.localPath = savePath;
      await httpClient.downloadWithResume(
        url: job.result.downloadUrl,
        savePath: savePath,
        cancelToken: cancelToken,
        onProgress: (received, total) {
          job.progress = total > 0 ? received / total : 0;
          // Throttle : on n'écrit en base que tous les 10% de progression, pas à
          // chaque appel (plusieurs fois par seconde) — la reprise se fait de
          // toute façon sur la taille réelle du fichier, pas sur cette valeur.
          final lastSaved = _lastPersistedProgress[job.id] ?? -1.0;
          if (job.progress - lastSaved >= 0.1 || job.progress >= 1.0) {
            _lastPersistedProgress[job.id] = job.progress;
            unawaited(_persist(job));
          }
          notifyListeners();
        },
      );

      if (job.result.mediaType == MediaType.book && savePath.endsWith('.epub')) {
        await ZipBombGuard.check(savePath); // 03_SECURITE.md
      }
      if (job.result.sourceName == 'Internet Archive') {
        final checksums = await _fetchInternetArchiveChecksums(job.result);
        if (checksums != null) {
          final ok = await ChecksumVerifier.verify(
            savePath,
            expectedSha1: checksums['sha1'],
            expectedMd5: checksums['md5'],
          );
          if (!ok) throw CorruptedFileException('Checksum mismatch', 'Fichier corrompu');
        }
      }

      job.status = DownloadStatus.completed;
      // [Correctif Partie 4] LibriVox livre un .zip, pas des MP3 directement —
      // voir AudiobookZipExtractor. AudioPlayerScreen (Partie 6) attend un
      // dossier ; sans cette étape, localPath pointait vers un .zip que
      // just_audio ne sait pas lire.
      if (job.result.mediaType == MediaType.audiobook && savePath.toLowerCase().endsWith('.zip')) {
        job.localPath = await AudiobookZipExtractor.extract(savePath);
      } else {
        job.localPath = savePath;
      }
      job.completedAt = DateTime.now();
      // [Correctif ADR-010] Rien ne téléchargeait jamais la couverture — la
      // bibliothèque n'affichait que le placeholder typographique. Best-effort
      // volontaire : une couverture manquante ne doit jamais faire échouer le
      // téléchargement du livre lui-même.
      if (job.result.coverUrl != null) {
        try {
          job.coverPath = await _downloadCover(job);
        } catch (e) {
          AppLogger.info('Téléchargement de couverture ignoré: $e', module: 'DOWNLOAD_MANAGER');
        }
      }
      await repository.saveItem(job.toLibraryItem());
      libraryChangeNotifier?.notifyChanged();
      _lastPersistedProgress.remove(job.id);
      await _persist(job);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        return; // pause volontaire — pas un échec, le fichier partiel reste pour reprise
      }
      await _handleFailure(job, e);
    } catch (e) {
      await _handleFailure(job, e);
    } finally {
      notifyListeners();
    }
  }

  /// Optionnel : seule Internet Archive expose des checksums parmi les 4 sources V1
  /// (06_SOURCES_CONNECTEURS.md). Câblé de façon injectée pour ne pas coupler
  /// DownloadManager à un connecteur concret au-delà de ce cas documenté.
  InternetArchiveSource? internetArchiveSource;
  Future<Map<String, String>?> _fetchInternetArchiveChecksums(SearchResult result) async {
    final source = internetArchiveSource;
    if (source == null || result.externalId == null) return null;
    final filename = p.basename(Uri.parse(result.downloadUrl).path);
    return source.fetchChecksums(result.externalId!, filename);
  }

  Future<void> _handleFailure(DownloadJob job, Object error) async {
    final retryable = _isRetryable(error);
    job.retryCount++;
    _lastPersistedProgress.remove(job.id);
    AppLogger.warn(
      'Download failed for ${job.id} (attempt ${job.retryCount}): $error (retryable: $retryable)',
      module: 'DOWNLOAD_MANAGER',
    );

    if (retryable && job.retryCount < 3) {
      job.status = DownloadStatus.queued;
      await _persist(job);
      // [Correctif] On ne fait plus `await Future.delayed` ici. En restant
      // bloqué dans _handleFailure, on occuperait indéfiniment un slot
      // d'activeCount (maxConcurrent) pendant le backoff. En sortant
      // immédiatement, on libère le slot pour d'autres jobs, et un Timer
      // planifie la prochaine tentative.
      Timer(retryBackoff(job.retryCount), () {
        AppLogger.info('Retrying job ${job.id} after backoff', module: 'DOWNLOAD_MANAGER');
        _tryStartNext();
      });
    } else {
      job.status = DownloadStatus.failed;
      job.errorMessage = error.toString();
      // [Correctif — bug réel trouvé en test réel] Avant ce correctif, un job
      // qui épuisait ses 3 retries PENDANT que le réseau était encore coupé
      // (backoff total ~14s, souvent bien plus court qu'une vraie coupure
      // Wi-Fi/données) finissait `failed` de façon PERMANENTE : la reprise
      // automatique sur reconnexion (`resumeQueuedJobs()`, NF-035) ne
      // regardait que les jobs `queued`, jamais les `failed` — l'utilisateur
      // devait rouvrir l'app et retenter manuellement. `retryable` (calculé
      // plus haut) distingue déjà "erreur réseau/temporaire" de "404 ou
      // autre erreur définitive" : on le mémorise pour que la reconnexion
      // puisse cibler UNIQUEMENT les échecs de la première catégorie.
      job.wasNetworkFailure = retryable;
      // [Correctif — bug réel trouvé en test réel] Ne nettoyer le fichier
      // partiel QUE pour un échec définitif (404, etc.) : le supprimer pour
      // un échec réseau qu'on compte retenter sur reconnexion annulerait tout
      // l'intérêt de `downloadWithResume()` — on repartirait de 0 au lieu de
      // reprendre depuis la taille déjà téléchargée.
      if (!retryable) {
        await _cleanupPartialFile(job);
      }
      await _persist(job);
    }
  }

  /// 404/4xx = erreur définitive, ne sert à rien de retenter. Timeout/5xx = temporaire.
  bool _isRetryable(Object error) {
    if (error is DioException) {
      final code = error.response?.statusCode;
      if (code != null && code >= 400 && code < 500) return false;
      return true;
    }
    return true;
  }

  Future<void> _cleanupPartialFile(DownloadJob job) async {
    if (job.localPath == null) return;
    final file = File(job.localPath!);
    if (await file.exists()) {
      AppLogger.info('Cleaning up partial file for permanently failed job ${job.id}', module: 'DOWNLOAD');
      await file.delete();
    }
  }

  /// Pause RÉELLE : annule le `CancelToken` du flux Dio en cours. Le fichier partiel
  /// reste sur disque — `downloadWithResume()` reprendra depuis sa taille réelle.
  void pauseJob(String jobId) {
    _cancelTokens[jobId]?.cancel('Paused by user');
    final job = jobs.firstWhereOrNull((j) => j.id == jobId);
    if (job != null) {
      job.status = DownloadStatus.paused;
      unawaited(_persist(job));
    }
    notifyListeners();
  }

  /// Pause globale (chapitre 12, NF-037) — boucle sur `pauseJob()`, zéro nouveau mécanisme.
  void pauseAll() {
    for (final job in jobs.where((j) => j.status == DownloadStatus.downloading)) {
      pauseJob(job.id);
    }
  }

  void resumeJob(String jobId) {
    final job = jobs.firstWhereOrNull((j) => j.id == jobId);
    if (job == null) return;
    job.status = DownloadStatus.queued;
    unawaited(_persist(job));
    notifyListeners();
    _tryStartNext();
  }

  void reorderPriority(String jobId, int newPriority) {
    final job = jobs.firstWhereOrNull((j) => j.id == jobId);
    if (job == null) return;
    job.priority = newPriority;
    jobs.sort((a, b) => a.priority.compareTo(b.priority));
    unawaited(_persist(job));
    notifyListeners();
  }

  /// Reprise sur reconnexion (chapitre 12, NF-035) — appelée par
  /// `ConnectivityService.onReconnected` (câblé dans main.dart), PAS
  /// `resumeAll()` : celle-ci relit `downloads` depuis la DB et réinsérerait
  /// dans `jobs` des entrées déjà présentes en mémoire (doublons). Ici on se
  /// contente de redéclencher `_tryStartNext()` sur la queue déjà en mémoire —
  /// utile en particulier pour les jobs dont le backoff (`retryBackoff`) vient
  /// de s'écouler pendant que le réseau était encore coupé.
  ///
  /// [Correctif — bug réel trouvé en test réel] Ne suffisait pas : un job qui
  /// avait déjà épuisé ses 3 retries PENDANT la coupure (backoff total ~14s,
  /// bien plus court qu'une vraie coupure réseau) était `failed`, pas
  /// `queued` — invisible pour `_tryStartNext()`. On ressuscite donc d'abord
  /// les jobs `failed` marqués `wasNetworkFailure` (voir download_job.dart),
  /// en repartant à 0 retry, AVANT de redéclencher la file. Un job `failed`
  /// pour une raison définitive (404, etc.) n'a PAS ce flag et reste
  /// `failed` — pas de boucle de retentatives inutiles sur une ressource qui
  /// n'existe pas.
  void resumeQueuedJobs() {
    AppLogger.info('Connectivity back: resuming network-failed jobs', module: 'DOWNLOAD_MANAGER');
    int count = 0;
    for (final job in jobs.where((j) => j.status == DownloadStatus.failed && j.wasNetworkFailure)) {
      job.wasNetworkFailure = false;
      job.retryCount = 0;
      job.status = DownloadStatus.queued;
      unawaited(_persist(job));
      count++;
    }
    AppLogger.info('Ressuscitated $count jobs', module: 'DOWNLOAD_MANAGER');
    notifyListeners();
    for (var i = 0; i < maxConcurrent; i++) {
      _tryStartNext();
    }
  }

  /// Reprise après crash de l'app — recharge les jobs actifs/en attente au démarrage.
  Future<void> resumeAll() async {
    final rows = await db.query('downloads',
        where: "status IN ('downloading', 'queued') OR (status = 'failed' AND was_network_failure = 1)");
    for (final row in rows) {
      final job = DownloadJob.fromMap(row);
      if (job.status == DownloadStatus.downloading || (job.status == DownloadStatus.failed && job.wasNetworkFailure)) {
        job.status = DownloadStatus.queued;
        job.wasNetworkFailure = false; // On reset pour le prochain essai
        // Reflète en DB le downgrade/reset, sinon la ligne reste
        // incohérente avec l'état réellement repris en mémoire tant qu'aucun
        // autre événement ne la met à jour.
        await _persist(job);
      }
      jobs.add(job);
    }
    jobs.sort((a, b) => a.priority.compareTo(b.priority));
    notifyListeners();
    for (var i = 0; i < maxConcurrent; i++) {
      _tryStartNext();
    }
  }

  String _buildSavePath(SearchResult result) {
    final name = FilenameSanitizer.sanitize('${result.author ?? "Inconnu"} — ${result.title}');
    final path = p.join(libraryDirPath, _folderFor(result.mediaType), '$name.${_extFor(result)}');
    assert(FilenameSanitizer.isWithinSandbox(path, libraryDirPath));
    return path;
  }

  String _folderFor(MediaType mediaType) =>
      mediaType == MediaType.audiobook ? 'audiobooks' : 'books';

  String _extFor(SearchResult result) {
    final uriPath = Uri.parse(result.downloadUrl).path;
    final ext = p.extension(uriPath).replaceFirst('.', '');
    if (ext.isNotEmpty) return ext;
    return result.mediaType == MediaType.audiobook ? 'mp3' : 'epub';
  }

  /// Télécharge `job.result.coverUrl`, la compresse/redimensionne (ADR-010,
  /// `CoverProcessor`), et l'indexe dans `CoverCacheManager` (LRU). Retourne
  /// le chemin absolu du fichier final. Appelée uniquement en best-effort
  /// (voir call site) — une couverture n'est jamais essentielle au sens où
  /// l'est le livre lui-même.
  Future<String> _downloadCover(DownloadJob job) async {
    final coverUrl = job.result.coverUrl!;
    // Même validateur que pour le livre lui-même (03_SECURITE.md) — une URL de
    // couverture n'est pas plus digne de confiance qu'une URL de téléchargement.
    UrlValidator.validate(coverUrl);

    // Toujours .jpg : CoverProcessor réencode systématiquement en JPEG, quel
    // que soit le format source (PNG, WebP...) — voir son commentaire.
    final filename = '${job.id}.jpg';
    final coverPath = p.join(libraryDirPath, 'covers', filename);
    assert(FilenameSanitizer.isWithinSandbox(coverPath, libraryDirPath));
    await Directory(p.dirname(coverPath)).create(recursive: true);

    // Téléchargée vers un fichier temporaire d'abord — le format source n'est
    // connu qu'après décodage, pas avant, donc pas la peine de deviner une
    // extension à partir de l'URL.
    final tempPath = '$coverPath.download';
    await httpClient.downloadWithResume(url: coverUrl, savePath: tempPath, cancelToken: CancelToken());

    try {
      final rawBytes = await File(tempPath).readAsBytes();
      final processedBytes = await CoverProcessor.process(rawBytes);
      await File(coverPath).writeAsBytes(processedBytes);
    } finally {
      final tempFile = File(tempPath);
      if (await tempFile.exists()) await tempFile.delete();
    }

    final sizeBytes = await File(coverPath).length();
    return coverCache.put(filename, sizeBytes);
  }
}

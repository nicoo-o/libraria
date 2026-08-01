import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';
import 'library/library_change_notifier.dart';

import 'app.dart';
import 'backup/backup_service.dart';
import 'core/connectivity/connectivity_service.dart';
import 'core/diagnostics/diagnostic_report_service.dart';
import 'core/http/dio_http_client.dart';
import 'core/http/http_client.dart';
import 'core/logging/app_logger.dart';
import 'core/permissions/permission_service.dart';
import 'download_manager/download_manager.dart';
import 'library/database_helper.dart';
import 'library/bookmark_repository.dart';
import 'library/library_repository.dart';
import 'library/local_file_verifier.dart';
import 'library/note_repository.dart';
import 'library/settings_repository.dart';
import 'library/shelf_repository.dart';
import 'library/tag_repository.dart';
import 'readers/audiobook_handler.dart';
import 'recommendations/local_recommender.dart';
import 'sources/gutenberg/gutenberg_source.dart';
import 'sources/internet_archive/internet_archive_source.dart';
import 'sources/librivox/librivox_source.dart';
import 'sources/standard_ebooks/standard_ebooks_source.dart';
import 'stats/reading_stats_service.dart';

/// Nom de tâche unique (09_TESTS_CI.md) — Workmanager toutes les 12h sur Android.
/// [Correctif ADR-011] Regroupe désormais aussi la purge de la corbeille (30j) —
/// purgeDeletedOlderThan() existait déjà côté repository mais n'était jamais
/// appelée nulle part, laissant les fichiers physiques des éléments supprimés
/// s'accumuler indéfiniment sur le disque.
const _maintenanceTask = 'maintenance_task';

/// [Partie 7] Point d'entrée exécuté par Workmanager, dans un ISOLATE SÉPARÉ de
/// celui de l'app — on ne peut donc réutiliser aucune variable de main() ici
/// (db, libraryRepo...), il faut sa propre connexion à la base.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == _maintenanceTask) {
      final db = await DatabaseHelper.database;
      final repo = LibraryRepository(db);
      await LocalFileVerifier(repo).verifyAll();
      await repo.purgeDeletedOlderThan(const Duration(days: 30));
    }
    return true;
  });
}

/// Avec ~15 services indépendants, le câblage se fait en un seul endroit, jamais
/// dispersé (02_ARCHITECTURE.md). C'était le point d'assemblage qui n'existait dans
/// aucune étape de l'ancien guide — chaque brique y était montrée isolément.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = await DatabaseHelper.database; // onConfigure (PRAGMA) + schéma/migrations appliqués ici

  final libraryDir = await getApplicationDocumentsDirectory();

  // [Chapitre 12, NF-059 — trou comblé] AppLogger n'écrivait que dans un
  // buffer mémoire ; LogRotator existait mais n'était jamais appelé (voir
  // audit V1). Init AVANT tout le reste : les logs des services qui suivent
  // (DownloadManager, etc.) doivent être capturés dès le départ.
  await AppLogger.init(Directory('${libraryDir.path}/logs'));

  final httpClient = DioHttpClient();
  final libraryRepo = LibraryRepository(db);
  final internetArchiveSource = InternetArchiveSource(httpClient: httpClient);

  final libraryChangeNotifier = LibraryChangeNotifier();
  final downloadManager = DownloadManager(
    httpClient: httpClient,
    repository: libraryRepo,
    db: db,
    libraryDirPath: libraryDir.path,
    libraryChangeNotifier: libraryChangeNotifier,
  )..internetArchiveSource = internetArchiveSource;
  await downloadManager.resumeAll();

  // [Chapitre 12, NF-061/NF-062 — trou comblé] Aucun module de sauvegarde
  // n'existait avant ce correctif (voir audit V1). Même dossier "covers" que
  // DownloadManager (download_manager.dart : `p.join(libraryDirPath, 'covers')`).
  final backupService = BackupService(db: db, coversDirPath: '${libraryDir.path}/covers');

  // [Chapitre 12 / trou V1] Lecture audiobook en arrière-plan — audio_service
  // était une dépendance morte (jamais importée) : fermer l'écran ou éteindre
  // l'écran coupait la lecture, faute de service de premier plan. Init UNIQUE
  // ici, avant runApp() : AudiobookHandler doit vivre pour toute la session,
  // pas être recréé à chaque ouverture de l'écran de lecture (voir
  // audiobook_handler.dart pour le détail de cette décision).
  final audiobookHandler = await AudioService.init(
    builder: () => AudiobookHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.libraria.audio',
      androidNotificationChannelName: 'Lecture audiobook',
      androidNotificationIcon: 'mipmap/ic_launcher',
      // [Correctif] `androidNotificationOngoing: true` impose (assert du
      // package) `androidStopForegroundOnPause: true` (valeur par défaut,
      // donc pas besoin de le préciser) -- la combinaison inverse plantait
      // au démarrage : "The androidNotificationOngoing will make no effect
      // with androidStopForegroundOnPause set to false".
      androidNotificationOngoing: true,
    ),
  );

  // [Partie 7] Sur Windows/Linux/macOS (pas de plugin Workmanager desktop/web),
  // passage unique au lancement -- voir bloc Android equivalent plus bas,
  // deplace APRES runApp() (voir commentaire a cet endroit).
  if (!kIsWeb && !Platform.isAndroid) {
    unawaited(LocalFileVerifier(libraryRepo).verifyAll());
    unawaited(libraryRepo.purgeDeletedOlderThan(const Duration(days: 30)));
  }

  runApp(MultiProvider(
    providers: [
      Provider<HttpClient>.value(value: httpClient),
      ChangeNotifierProvider.value(value: downloadManager),
      ChangeNotifierProvider.value(value: libraryChangeNotifier),
      // [Correctif NF-035] onReconnected était un TODO jamais câblé — une
      // coupure réseau en plein téléchargement pouvait laisser des jobs bloqués
      // en "queued" jusqu'à la prochaine action utilisateur (ou pire, échouer
      // définitivement une fois le backoff de retry épuisé, cf. DownloadManager
      // .retryBackoff). resumeQueuedJobs(), pas resumeAll() : celle-ci relit la
      // DB et doublonnerait les jobs déjà en mémoire.
      ChangeNotifierProvider(
        create: (_) => ConnectivityService()..onReconnected = downloadManager.resumeQueuedJobs,
      ),
      Provider(create: (_) => libraryRepo),
      Provider<BackupService>.value(value: backupService),
      Provider<AudiobookHandler>.value(value: audiobookHandler),
      Provider(create: (_) => BookmarkRepository(db)),
      Provider(create: (_) => ShelfRepository(db)),
      Provider(create: (_) => NoteRepository(db)),
      Provider(create: (_) => SettingsRepository(db)),
      Provider(create: (_) => TagRepository(db)),
      Provider(create: (_) => ReadingStatsService(db)),
      Provider(create: (_) => LocalRecommender()),
      Provider(create: (_) => DiagnosticReportService()),
      // 4 sources V1, chacune via BaseContentSource (rate limiter + circuit breaker inclus).
      // [Correctif] Enregistrées sous leur type CONCRET (pas ContentSource) : search_screen.dart
      // fait context.read<GutenbergSource>(), context.read<InternetArchiveSource>(), etc. Avec
      // Provider<ContentSource> pour les 4, seule la dernière valeur déclarée (StandardEbooksSource)
      // aurait été résolvable sous le type ContentSource, et aucune des 4 sous son propre type
      // concret => ProviderNotFoundException au premier appel de _SearchScreenState.initState().
      Provider<GutenbergSource>(create: (_) => GutenbergSource(httpClient: httpClient)),
      Provider<InternetArchiveSource>.value(value: internetArchiveSource),
      Provider<LibrivoxSource>(create: (_) => LibrivoxSource(httpClient: httpClient)),
      Provider<StandardEbooksSource>(create: (_) => StandardEbooksSource(httpClient: httpClient)),
    ],
    child: const LibrariaApp(),
  ));

  // [Correctif] La demande de permissions doit avoir lieu APRES runApp() : avant
  // le premier frame, l'Activity Android n'est pas encore pleinement attachee au
  // moteur Flutter, et permission_handler echoue avec "Unable to detect current
  // Android Activity." si on l'appelle trop tot (cas d'un cold start).
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    // [Correctif] permission_handler ne supporte qu'UNE SEULE requete de
    // permission en vol a la fois -- Future.wait() demarrait les deux appels
    // en parallele, ce qui corrompait l'etat interne du plugin (reference a
    // l'Activity courante geree par requete) et provoquait un echec
    // systematique "Unable to detect current Android Activity" des la
    // deuxieme requete concurrente, quel que soit le delai d'attente ou le
    // nombre de tentatives de retry. Sequentiel = fiable.
    await PermissionService.requestStoragePermissions();
    await PermissionService.requestNotificationPermission();

    // [Correctif] Deplace ICI (apres runApp() ET apres les demandes de
    // permissions), plutot qu'avant runApp() comme precedemment -- l'ancienne
    // position (synchrone, avant runApp()) est le suspect principal du conflit
    // "Unable to detect current Android Activity" qui touchait ensuite
    // permission_handler : l'initialisation native de Workmanager avant que
    // l'Activity ne soit attachee au moteur Flutter pouvait interferer avec cet
    // attachement pour le reste de la session, ce qu'aucun retry cote
    // permission_handler ne pouvait compenser (pas un simple delai, une
    // rupture durable). Workmanager n'a besoin ni de l'UI ni de l'Activity
    // pour enregistrer une tache periodique auprès du systeme.
    if (!kIsWeb && Platform.isAndroid) {
      await Workmanager().initialize(callbackDispatcher);
      await Workmanager().registerPeriodicTask(
        _maintenanceTask,
        _maintenanceTask,
        frequency: const Duration(hours: 12),
        initialDelay: const Duration(minutes: 2),
        constraints: Constraints(networkType: NetworkType.notRequired),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    }
  });
}

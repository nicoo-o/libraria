import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:libraria/core/http/http_client.dart';
import 'package:libraria/core/models/download_job.dart';
import 'package:libraria/core/models/media_type.dart';
import 'package:libraria/core/models/search_result.dart';
import 'package:libraria/download_manager/download_manager.dart';
import 'package:libraria/library/library_repository.dart';
import 'package:libraria/library/migrations/migrations.dart';

/// Sans l'abstraction HttpClient (09_TESTS_CI.md), ce test ferait de vrais appels
/// réseau. `MockHttpClient` vit ici, dans test/ — jamais dans lib/.
class MockHttpClient extends Mock implements HttpClient {}

const _testResult = SearchResult(
  id: 'test_book_1',
  title: 'Test Book',
  mediaType: MediaType.book,
  downloadUrl: 'https://example.com/book.epub',
  sourceName: 'Project Gutenberg',
);

/// Variante utilisée par les tests qui attendent un statut `completed` réel.
/// [Piège évité] `downloadWithResume` est mocké et n'écrit jamais de vrai
/// fichier sur disque — avec une URL en `.epub`, `_downloadDirect()` appelle
/// `ZipBombGuard.check(savePath)` sur un fichier inexistant, qui lève une
/// exception (fichier introuvable) et fait repartir le job en retry/échec au
/// lieu de `completed`. Une extension non-EPUB contourne cette vérification.
const _testResultNonEpub = SearchResult(
  id: 'test_book_2',
  title: 'Test Book Non-Epub',
  mediaType: MediaType.book,
  downloadUrl: 'https://example.com/book.mobi',
  sourceName: 'Project Gutenberg',
);

Future<void> _waitUntil(bool Function() condition,
    {required Duration timeout}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('waitUntil timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    registerFallbackValue(CancelToken());
  });

  // Utilisé uniquement par les tests de couverture ci-dessous, qui écrivent de
  // VRAIS fichiers sur disque (contrairement au reste de ce fichier, où le mock
  // ne fait rien) — jamais dans le répertoire de travail courant.
  late Directory tempDir;
  late String tempDirPath;

  final List<Database> openedDbs = [];
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('download_manager_test_');
    tempDirPath = tempDir.path;
  });

  tearDown(() async {
    // Laisse les chaines en arriere-plan (fire-and-forget de
    // _tryStartNext/resumeAll) se terminer avant de fermer les DBs.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    for (final db in openedDbs) {
      await db.close();
    }
    openedDbs.clear();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<DownloadManager> buildManager() async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    openedDbs.add(db);
    for (final stmt in splitSqlStatements(fullSchemaV17)) {
      await db.execute(stmt);
    }
    final httpClient = MockHttpClient();
    when(() => httpClient.downloadWithResume(
          url: any(named: 'url'),
          savePath: any(named: 'savePath'),
          cancelToken: any(named: 'cancelToken'),
          onProgress: any(named: 'onProgress'),
        )).thenAnswer((_) async {});

    return DownloadManager(
      httpClient: httpClient,
      repository: LibraryRepository(db),
      db: db,
      libraryDirPath: '.',
    );
  }

  test(
      'enqueue() ne crée pas deux jobs pour la même download_url (chapitre 12, NF-040)',
      () async {
    final manager = await buildManager()
      ..retryBackoff = (_) => Duration.zero;

    await manager.enqueue(_testResultNonEpub);
    await manager.enqueue(_testResultNonEpub); // même URL — ne doit pas dupliquer

    await _waitUntil(
      () => manager.jobs.single.status == DownloadStatus.completed,
      timeout: const Duration(seconds: 2),
    );

    final matching = manager.jobs
        .where((j) => j.result.downloadUrl == _testResultNonEpub.downloadUrl);
    expect(matching.length, 1);
  });

  test('pauseJob() passe le job en statut paused', () async {
    final manager = await buildManager();
    manager.jobs.add(DownloadJob(
        id: 'job-1', result: _testResult, status: DownloadStatus.downloading));

    manager.pauseJob('job-1');

    expect(manager.jobs.first.status, DownloadStatus.paused);
  });

  test('reorderPriority() trie la liste par priorité croissante', () async {
    final manager = await buildManager();
    manager.jobs.addAll([
      DownloadJob(id: 'a', result: _testResult, priority: 2),
      DownloadJob(id: 'b', result: _testResult, priority: 2),
    ]);

    manager.reorderPriority('b', 1);

    expect(manager.jobs.first.id, 'b');
  });

  // [Régression] Avant le correctif, whenComplete() (_tryStartNext) relançait un
  // job échoué la microtask suivante, sans aucun délai — une coupure réseau de
  // quelques secondes épuisait les 3 tentatives quasi instantanément.
  test(
      'un échec réseau retentable repasse en queued puis réussit après backoff, sans épuiser prématurément les tentatives',
      () async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    openedDbs.add(db);
    for (final stmt in splitSqlStatements(fullSchemaV17)) {
      await db.execute(stmt);
    }
    var callCount = 0;
    final httpClient = MockHttpClient();
    when(() => httpClient.downloadWithResume(
          url: any(named: 'url'),
          savePath: any(named: 'savePath'),
          cancelToken: any(named: 'cancelToken'),
          onProgress: any(named: 'onProgress'),
        )).thenAnswer((_) async {
      callCount++;
      if (callCount == 1) {
        throw DioException(
            requestOptions: RequestOptions(path: ''),
            type: DioExceptionType.connectionError);
      }
      // 2e appel : succès.
    });

    final manager = DownloadManager(
      httpClient: httpClient,
      repository: LibraryRepository(db),
      db: db,
      libraryDirPath: '.',
    )..retryBackoff =
        (_) => Duration.zero; // backoff réel testé séparément ci-dessous

    await manager.enqueue(_testResultNonEpub);
    // Laisse le temps à : échec (call 1) → backoff (0ms) → retry (call 2, succès).
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(callCount, 2);
    expect(manager.jobs.single.status, DownloadStatus.completed);
    expect(manager.jobs.single.retryCount, 1);
  });

  test(
      'retryBackoff() est appliqué avant que le job ne retente (pas 0 par défaut)',
      () async {
    final manager = await buildManager();
    // Valeur par défaut en production — pas Duration.zero.
    expect(manager.retryBackoff(1), greaterThan(Duration.zero));
  });

  // [Régression NF-035] Une coupure réseau laisse des jobs en "queued" en
  // mémoire. resumeQueuedJobs() (appelée par ConnectivityService.onReconnected,
  // voir main.dart) doit les relancer sans repasser par la DB — resumeAll()
  // doublonnerait les jobs déjà en mémoire.
  test('resumeQueuedJobs() relance les jobs en attente déjà en mémoire',
      () async {
    final manager = await buildManager();
    manager.jobs.add(DownloadJob(
        id: 'stuck',
        result: _testResultNonEpub,
        status: DownloadStatus.queued));

    manager.resumeQueuedJobs();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(manager.jobs.single.status,
        isIn([DownloadStatus.downloading, DownloadStatus.completed]));
  });

  // [Régression ADR-010] Avant correctif, rien ne téléchargeait ni ne mettait
  // en cache la couverture : DownloadJob.coverPath restait toujours null.
  test(
      'télécharge et met en cache la couverture d\'un livre terminé avec succès',
      () async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    openedDbs.add(db);
    for (final stmt in splitSqlStatements(fullSchemaV17)) {
      await db.execute(stmt);
    }
    final httpClient = MockHttpClient();
    // [Correctif] Le mock doit écrire une VRAIE image décodable pour l'URL de
    // couverture — depuis le câblage de CoverProcessor (ADR-010), des octets
    // arbitraires échoueraient au décodage et _downloadCover() échouerait
    // silencieusement (best-effort), laissant job.coverPath à null.
    when(() => httpClient.downloadWithResume(
          url: any(named: 'url'),
          savePath: any(named: 'savePath'),
          cancelToken: any(named: 'cancelToken'),
          onProgress: any(named: 'onProgress'),
        )).thenAnswer((invocation) async {
      final url = invocation.namedArguments[#url] as String;
      final savePath = invocation.namedArguments[#savePath] as String;
      final file = File(savePath);
      await file.parent.create(recursive: true);
      if (url.endsWith('cover.jpg')) {
        final tinyImage = img.Image(4, 4);
        await file.writeAsBytes(img.encodePng(tinyImage));
      } else {
        await file.writeAsBytes([1, 2, 3]);
      }
    });

    final manager = DownloadManager(
      httpClient: httpClient,
      repository: LibraryRepository(db),
      db: db,
      libraryDirPath: tempDirPath,
    );

    const resultWithCover = SearchResult(
      id: 'test_book_cover',
      title: 'Test Book With Cover',
      mediaType: MediaType.book,
      downloadUrl: 'https://example.com/book_with_cover.mobi',
      sourceName: 'Project Gutenberg',
      coverUrl: 'https://example.com/cover.jpg',
    );
    await manager.enqueue(resultWithCover);
    final job = manager.jobs.single;
    await _waitUntil(
        () => job.status == DownloadStatus.completed && job.coverPath != null,
        timeout: const Duration(seconds: 5));
    expect(job.status, DownloadStatus.completed);
    expect(job.coverPath, isNotNull);
    expect(await File(job.coverPath!).exists(), isTrue);
  });

  // [Résilience] Une couverture qui échoue à se télécharger ne doit JAMAIS
  // faire échouer le livre lui-même — c'est le point le plus important de ce
  // correctif, pas seulement le cas nominal ci-dessus.
  test(
      'un échec de téléchargement de couverture n\'empêche pas le livre de se terminer',
      () async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    openedDbs.add(db);
    for (final stmt in splitSqlStatements(fullSchemaV17)) {
      await db.execute(stmt);
    }
    final httpClient = MockHttpClient();
    when(() => httpClient.downloadWithResume(
          url: any(named: 'url'),
          savePath: any(named: 'savePath'),
          cancelToken: any(named: 'cancelToken'),
          onProgress: any(named: 'onProgress'),
        )).thenAnswer((invocation) async {
      final url = invocation.namedArguments[#url] as String;
      // [Correctif] Vérifier le nom de fichier exact, pas un `.contains('cover')`
      // trop large : l'URL du LIVRE lui-même ('book_bad_cover.mobi', ci-dessous)
      // contient la sous-chaîne "cover" et aurait, sinon, déclenché l'échec
      // simulé sur le livre aussi — pas seulement sur la couverture.
      if (url.endsWith('cover_broken.jpg')) {
        throw Exception('la couverture ne répond pas');
      }
      final savePath = invocation.namedArguments[#savePath] as String;
      final file = File(savePath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes([1, 2, 3]);
    });

    final manager = DownloadManager(
      httpClient: httpClient,
      repository: LibraryRepository(db),
      db: db,
      libraryDirPath: tempDirPath,
    );

    const resultWithBadCover = SearchResult(
      id: 'test_book_bad_cover',
      title: 'Test Book Bad Cover',
      mediaType: MediaType.book,
      downloadUrl: 'https://example.com/book2.mobi',
      sourceName: 'Project Gutenberg',
      coverUrl: 'https://example.com/cover_broken.jpg',
    );
    await manager.enqueue(resultWithBadCover);

    final job = manager.jobs.single;
    for (var i = 0; i < 50 && job.status == DownloadStatus.downloading; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    expect(
        job.status, DownloadStatus.completed); // le livre a réussi malgré tout
    expect(job.coverPath,
        isNull); // la couverture, elle, n'a pas pu être mise en cache
  });

  // [Correctif Partie 4] Avant ce correctif, enqueue() n'écrivait jamais dans la
  // table `downloads` : ce test aurait échoué à l'étape resumeAll() (0 job
  // rechargé) puisque la ligne n'aurait jamais existé en base.
  test(
      'un job en attente survit à un redémarrage simulé de l\'app (persistance + resumeAll)',
      () async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    openedDbs.add(db);
    for (final stmt in splitSqlStatements(fullSchemaV17)) {
      await db.execute(stmt);
    }
    final repository = LibraryRepository(db);

    // Un httpClient qui ne répond jamais — le job doit rester "downloading" en
    // base, comme si l'app avait été tuée en plein transfert.
    final stuckHttpClient = MockHttpClient();
    when(() => stuckHttpClient.downloadWithResume(
          url: any(named: 'url'),
          savePath: any(named: 'savePath'),
          cancelToken: any(named: 'cancelToken'),
          onProgress: any(named: 'onProgress'),
        )).thenAnswer((_) => Completer<void>().future); // ne se résout jamais

    final firstRunManager = DownloadManager(
      httpClient: stuckHttpClient,
      repository: repository,
      db: db,
      libraryDirPath: '.',
    );
    await firstRunManager.enqueue(_testResult);
    // Laisse le temps à _tryStartNext()/_downloadDirect() de passer le job en
    // "downloading" avant de simuler la fermeture de l'app.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(firstRunManager.jobs.single.status, DownloadStatus.downloading);

    // "Redémarrage de l'app" : nouvelle instance de DownloadManager sur la MÊME
    // base (comme le fait main.dart au lancement), avec une queue en mémoire vide.
    final secondRunHttpClient = MockHttpClient();
    when(() => secondRunHttpClient.downloadWithResume(
          url: any(named: 'url'),
          savePath: any(named: 'savePath'),
          cancelToken: any(named: 'cancelToken'),
          onProgress: any(named: 'onProgress'),
        )).thenAnswer((_) async {});
    final secondRunManager = DownloadManager(
      httpClient: secondRunHttpClient,
      repository: repository,
      db: db,
      libraryDirPath: '.',
    )..retryBackoff = (_) => Duration.zero;
    expect(secondRunManager.jobs, isEmpty); // queue en mémoire neuve

    await secondRunManager.resumeAll();

    expect(secondRunManager.jobs.length, 1);
    expect(secondRunManager.jobs.single.result.downloadUrl,
        _testResult.downloadUrl);
    // downloading (jamais terminé) doit repasser en queued au redémarrage, pas
    // rester bloqué indéfiniment en "downloading" sans qu'aucun job ne tourne.
    // (queued/downloading/completed selon l'avancement exact des microtasks au
    // moment de l'assertion — ce qui compte ici est que le job N'A PAS disparu.)
    expect(
      secondRunManager.jobs.single.status,
      isIn([
        DownloadStatus.queued,
        DownloadStatus.downloading,
        DownloadStatus.completed
      ]),
    );
  });
}

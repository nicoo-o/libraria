import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:libraria/app.dart';
import 'package:libraria/core/connectivity/connectivity_service.dart';
import 'package:libraria/core/http/http_client.dart';
import 'package:libraria/download_manager/download_manager.dart';
import 'package:libraria/backup/backup_service.dart';
import 'package:libraria/library/library_change_notifier.dart';
import 'package:libraria/library/library_repository.dart';
import 'package:libraria/library/settings_repository.dart';
import 'package:libraria/core/models/library_item.dart';
import 'package:dio/dio.dart';
import 'package:libraria/sources/gutenberg/gutenberg_source.dart';
import 'package:libraria/sources/internet_archive/internet_archive_source.dart';
import 'package:libraria/sources/librivox/librivox_source.dart';
import 'package:libraria/sources/standard_ebooks/standard_ebooks_source.dart';

class _TestLibraryRepository extends LibraryRepository {
  _TestLibraryRepository(super.db);

  @override
  Future<List<LibraryItem>> getAll({bool includeDeleted = false}) async => [];
}

class _TestSettingsRepository extends SettingsRepository {
  _TestSettingsRepository(super.db);

  final Map<String, String> _values = {};

  @override
  Future<String?> getValue(String key) async => _values[key];

  @override
  Future<void> setValue(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<bool> isSourceEnabled(String sourceId) async {
    final value = await getValue('source_enabled_$sourceId');
    return value != 'false';
  }

  @override
  Future<void> setSourceEnabled(String sourceId, bool enabled) async {
    await setValue('source_enabled_$sourceId', enabled.toString());
  }
}

class MockConnectivity extends Mock implements Connectivity {}

/// [Correctif] `LibraryScreen` observe désormais `DownloadManager` (voir
/// app.dart : IndexedStack + rafraîchissement après téléchargement, Partie 5) —
/// sans provider pour ce type, ce test échouait avec ProviderNotFoundException.
/// Les deux méthodes ne sont jamais appelées par ce test (aucun téléchargement
/// n'est déclenché), un simple UnimplementedError suffit.
class _UnusedHttpClient implements HttpClient {
  @override
  Future<Map<String, dynamic>> get(String url,
          {Map<String, dynamic>? queryParameters}) =>
      throw UnimplementedError();

  @override
  Future<List<dynamic>> getList(String url,
          {Map<String, dynamic>? queryParameters}) =>
      throw UnimplementedError();

  @override
  Future<void> downloadWithResume({
    required String url,
    required String savePath,
    required CancelToken cancelToken,
    void Function(int received, int total)? onProgress,
  }) =>
      throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;

  testWidgets('shows the empty library screen', (WidgetTester tester) async {
    tester.platformDispatcher.localeTestValue = const Locale('fr');
    tester.platformDispatcher.localesTestValue = const [Locale('fr')];
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final db =
        await databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath);
    final repository = _TestLibraryRepository(db);
    final downloadManager = DownloadManager(
      httpClient: _UnusedHttpClient(),
      repository: repository,
      db: db,
      libraryDirPath: '.',
    );
    // [Correctif] Avec IndexedStack (app.dart, Partie 5), les 4 onglets sont
    // construits dès le premier pump, pas seulement l'onglet actif — SearchScreen
    // a donc aussi besoin de ses 4 sources dans l'arbre de providers ici, même si
    // ce test ne teste que l'onglet Bibliothèque.
    final httpClient = _UnusedHttpClient();

    // [Correctif] app.dart affiche désormais une bannière hors-ligne (Partie 7)
    // alimentée par ConnectivityService, construit dès que _RootNavigation se
    // monte — un vrai `Connectivity()` toucherait le canal de plateforme,
    // absent en `flutter test` (MissingPluginException). D'où le seam de
    // ConnectivityService({connectivity}) et ce mock.
    final mockConnectivity = MockConnectivity();
    when(() => mockConnectivity.checkConnectivity())
        .thenAnswer((_) async => [ConnectivityResult.wifi]);
    when(() => mockConnectivity.onConnectivityChanged)
        .thenAnswer((_) => const Stream<List<ConnectivityResult>>.empty());
    final connectivityService =
        ConnectivityService(connectivity: mockConnectivity);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<LibraryRepository>.value(value: repository),
          ChangeNotifierProvider<LibraryChangeNotifier>.value(
              value: LibraryChangeNotifier()),
          ChangeNotifierProvider<DownloadManager>.value(value: downloadManager),
          ChangeNotifierProvider<ConnectivityService>.value(
              value: connectivityService),
          Provider<SettingsRepository>.value(
              value: _TestSettingsRepository(db)),
          Provider<BackupService>.value(
              value: BackupService(db: db, coversDirPath: '.')),
          Provider<GutenbergSource>(
              create: (_) => GutenbergSource(httpClient: httpClient)),
          Provider<InternetArchiveSource>(
              create: (_) => InternetArchiveSource(httpClient: httpClient)),
          Provider<LibrivoxSource>(
              create: (_) => LibrivoxSource(httpClient: httpClient)),
          Provider<StandardEbooksSource>(
              create: (_) => StandardEbooksSource(httpClient: httpClient)),
        ],
        child: const LibrariaApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('Bibliothèque'), findsWidgets);
    expect(find.byType(RefreshIndicator), findsOneWidget);

    await db.close();
  });
}

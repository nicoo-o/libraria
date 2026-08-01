import 'package:dio/dio.dart';

/// Abstraction — jamais de `Dio` directement dans le code métier (sources, DownloadManager,
/// écrans). Sans cette abstraction, `flutter test` ferait de vrais appels réseau : tests
/// lents, instables, qui échouent en CI sans connexion. Voir 09_TESTS_CI.md.
///
/// `DioHttpClient` (implémentation de production) est dans `dio_http_client.dart`.
/// Une `MockHttpClient` (mocktail) vit dans `test/`, jamais dans `lib/`.
abstract class HttpClient {
  Future<Map<String, dynamic>> get(String url, {Map<String, dynamic>? queryParameters});

  /// [Correctif] `get()` ne sait renvoyer qu'un objet JSON (`Map`). Or
  /// `standardebooks.org/ebooks.json` (StandardEbooksSource) répond avec un
  /// TABLEAU JSON à la racine — `get()` levait `ParsingException` à chaque
  /// appel, silencieusement rattrapée par le fallback OPDS (qui retourne
  /// volontairement une liste vide) : la recherche Standard Ebooks ne
  /// renvoyait donc jamais aucun résultat. Méthode dédiée pour ce cas, plutôt
  /// que d'affaiblir le typage de `get()` pour tout le monde.
  Future<List<dynamic>> getList(String url, {Map<String, dynamic>? queryParameters});

  Future<void> downloadWithResume({
    required String url,
    required String savePath,
    required CancelToken cancelToken,
    void Function(int received, int total)? onProgress,
  });
}

import 'dart:convert';
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../errors/exceptions.dart';
import '../security/url_validator.dart';
import 'http_client.dart';

/// Implémentation de production de [HttpClient]. Deux garanties de sécurité que
/// docs/restructuration_claude.md (chapitre 03) impose explicitement :
/// - les redirections HTTP ne sont JAMAIS suivies automatiquement par Dio
///   (`followRedirects: false`) — chaque hop est revalidé manuellement contre
///   `UrlValidator`, pour empêcher un serveur compromis de rediriger vers une IP
///   privée après une validation initiale passée (SSRF) ;
/// - `downloadWithResume` écrit en flux (`openRead`/`RandomAccessFile`), jamais
///   `readAsBytes()` sur un fichier qui peut dépasser quelques Mo.
class DioHttpClient implements HttpClient {
  DioHttpClient() : _dio = Dio(BaseOptions(followRedirects: false)) {
    // Validation de certificat volontairement stricte par défaut — voir
    // core/security/certificate_validator.dart pour l'opt-in explicite LAN/local.
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = io.HttpClient();
      client.badCertificateCallback = (cert, host, port) => false;
      return client;
    };
  }

  final Dio _dio;

  @override
  Future<Map<String, dynamic>> get(String url, {Map<String, dynamic>? queryParameters}) async {
    final response = await getWithSafeRedirects(url, queryParameters: queryParameters);
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    if (data is String) return jsonDecode(data) as Map<String, dynamic>;
    throw ParsingException('Unexpected response type: ${data.runtimeType}', 'Réponse invalide');
  }

  @override
  Future<List<dynamic>> getList(String url, {Map<String, dynamic>? queryParameters}) async {
    final response = await getWithSafeRedirects(url, queryParameters: queryParameters);
    final data = response.data;
    if (data is List) return data;
    if (data is String) return jsonDecode(data) as List<dynamic>;
    throw ParsingException('Unexpected response type: ${data.runtimeType}', 'Réponse invalide');
  }

  /// Revalidation d'URL à CHAQUE hop de redirection — voir 03_SECURITE.md.
  Future<Response> getWithSafeRedirects(
    String url, {
    Map<String, dynamic>? queryParameters,
    int maxHops = 3,
  }) async {
    var currentUrl = url;
    for (var hop = 0; hop <= maxHops; hop++) {
      UrlValidator.validate(currentUrl);
      final response = await _dio.get(
        currentUrl,
        queryParameters: hop == 0 ? queryParameters : null,
        options: Options(followRedirects: false, validateStatus: (s) => s != null && s < 400),
      );
      final loc = response.headers.value('location');
      final isRedirect = response.statusCode == 301 ||
          response.statusCode == 302 ||
          response.statusCode == 307;
      if (isRedirect && loc != null) {
        currentUrl = Uri.parse(currentUrl).resolve(loc).toString();
        continue;
      }
      return response;
    }
    throw NetworkException('Too many redirects', 'Trop de redirections');
  }
  /// Reprise HTTP par `Range` — voir 05_DOWNLOAD_MANAGER.md.
  @override
  Future<void> downloadWithResume({
    required String url,
    required String savePath,
    required CancelToken cancelToken,
    void Function(int received, int total)? onProgress,
  }) async {
    final file = io.File(savePath);
    await file.parent.create(recursive: true);
    int startByte = await file.exists() ? await file.length() : 0;

    // [Correctif] Resolution des redirections INLINE, en reutilisant la requete
    // de streaming elle-meme -- PAS de HEAD separee (_resolveRedirects, retire) :
    // certains endpoints de telechargement dynamique (ex. archive.org/zip_dir.php,
    // qui genere un zip a la volee) ne supportent pas HEAD du tout et ferment la
    // connexion brutalement ("Connection closed before full header was received"),
    // faisant echouer TOUT telechargement via ce type d'URL. Meme garantie de
    // securite (revalidation UrlValidator a chaque hop, 03_SECURITE.md), mais sur
    // la vraie requete GET/stream plutot qu'une probe HEAD separee.
    var currentUrl = url;
    late Response<ResponseBody> response;
    for (var hop = 0; hop <= 3; hop++) {
      UrlValidator.validate(currentUrl);
      response = await _dio.get<ResponseBody>(
        currentUrl,
        cancelToken: cancelToken,
        options: Options(
          headers: startByte > 0 ? {'Range': 'bytes=$startByte-'} : null,
          responseType: ResponseType.stream,
          followRedirects: false,
          validateStatus: (s) => s != null && (s < 400),
        ),
      );
      final loc = response.headers.value('location');
      final isRedirect = response.statusCode == 301 ||
          response.statusCode == 302 ||
          response.statusCode == 307;
      if (isRedirect && loc != null) {
        currentUrl = Uri.parse(currentUrl).resolve(loc).toString();
        continue;
      }
      break;
    }

    final serverHonoredRange = response.statusCode == 206;
    if (startByte > 0 && !serverHonoredRange) {
      startByte = 0;
      await file.writeAsBytes([]);
    }

    final raf = await file.open(mode: startByte > 0 ? io.FileMode.append : io.FileMode.write);
    final total = int.tryParse(response.headers.value('content-length') ?? '0') ?? 0;
    int received = startByte;

    try {
      await for (final chunk in response.data!.stream) {
        await raf.writeFrom(chunk);
        received += chunk.length;
        onProgress?.call(received, startByte + total);
      }
    } finally {
      await raf.close();
    }
  }
}

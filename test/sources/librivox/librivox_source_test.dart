import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:libraria/core/http/http_client.dart';
import 'package:libraria/core/models/media_type.dart';
import 'package:libraria/sources/librivox/librivox_source.dart';

class MockHttpClient extends Mock implements HttpClient {}

/// Extrait réaliste de https://librivox.org/api/feed/audiobooks/?format=json —
/// `url_zip_file` est un unique .zip contenant tous les MP3 du livre (voir
/// AudiobookZipExtractor, qui dépend justement de ce format en `.zip`).
const _librivoxFixture = {
  'books': [
    {
      'id': '1234',
      'title': 'Alice\'s Adventures in Wonderland',
      'url_zip_file': 'https://www.archive.org/download/alice_1234/alice_1234_librivox_64kb_mp3.zip',
      'coverart_jpg': 'https://archive.org/services/img/alice_1234',
      'authors': [
        {'display_name': 'Lewis Carroll'},
      ],
    },
    {
      // Livre sans url_zip_file (livre incomplet côté API) — doit être ignoré,
      // pas planter le parsing des autres.
      'id': '5678',
      'title': 'Livre incomplet',
      'url_zip_file': '',
      'authors': <Map<String, dynamic>>[],
    },
  ],
};

void main() {
  late MockHttpClient httpClient;
  late LibrivoxSource source;

  setUp(() {
    httpClient = MockHttpClient();
    source = LibrivoxSource(httpClient: httpClient);
  });

  test('doSearch() mappe le livre vers un SearchResult audiobook pointant vers le .zip', () async {
    when(() => httpClient.get(
          any(),
          queryParameters: any(named: 'queryParameters'),
        )).thenAnswer((_) async => _librivoxFixture);

    final result = await source.doSearch('alice');

    expect(result.items, hasLength(1));
    final item = result.items.single;
    expect(item.title, "Alice's Adventures in Wonderland");
    expect(item.author, 'Lewis Carroll');
    expect(item.mediaType, MediaType.audiobook);
    // [Régression] C'est CE champ qui doit être un .zip : AudiobookZipExtractor
    // (download_manager/audiobook_zip_extractor.dart) ne se déclenche que si
    // DownloadManager voit un mediaType audiobook + un downloadUrl en .zip.
    expect(item.downloadUrl, endsWith('.zip'));
  });

  test('doSearch() ignore les livres sans url_zip_file plutôt que de planter', () async {
    when(() => httpClient.get(
          any(),
          queryParameters: any(named: 'queryParameters'),
        )).thenAnswer((_) async => _librivoxFixture);

    final result = await source.doSearch('alice');

    expect(result.items.any((r) => r.title == 'Livre incomplet'), isFalse);
  });
}

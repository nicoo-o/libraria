import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:libraria/core/http/http_client.dart';
import 'package:libraria/sources/standard_ebooks/standard_ebooks_source.dart';

class MockHttpClient extends Mock implements HttpClient {}

/// Extrait réaliste de https://standardebooks.org/ebooks.json — la racine est
/// un TABLEAU, pas un objet. C'est exactement la forme qui faisait échouer
/// `HttpClient.get()` (typé `Map<String, dynamic>`) en silence.
const _ebooksJsonFixture = [
  {
    'url': '/ebooks/jane-austen/pride-and-prejudice',
    'title': 'Pride and Prejudice',
    'author': 'Jane Austen',
  },
  {
    'url': '/ebooks/herman-melville/moby-dick',
    'title': 'Moby-Dick',
    'author': 'Herman Melville',
  },
];

void main() {
  late MockHttpClient httpClient;
  late StandardEbooksSource source;

  setUp(() {
    httpClient = MockHttpClient();
    source = StandardEbooksSource(httpClient: httpClient);
  });

  // [Régression] Avant le correctif, `_searchJson()` appelait `httpClient.get()`
  // (qui ne sait renvoyer qu'un `Map`) sur un endpoint dont la racine est un
  // tableau : `get()` levait systématiquement une exception, absorbée par le
  // `catch` de `doSearch()`, qui retombait sur le fallback OPDS — une liste
  // VIDE, sans jamais remonter d'erreur visible. Ce test échouerait
  // immédiatement si `getList()` n'était pas utilisé.
  test('doSearch() trouve un livre correspondant à la requête (racine JSON = tableau)', () async {
    when(() => httpClient.getList('https://standardebooks.org/ebooks.json'))
        .thenAnswer((_) async => _ebooksJsonFixture);

    final result = await source.doSearch('pride');

    expect(result.items, hasLength(1));
    expect(result.items.single.title, 'Pride and Prejudice');
    expect(result.items.single.author, 'Jane Austen');
    expect(
      result.items.single.downloadUrl,
      'https://standardebooks.org/ebooks/jane-austen/pride-and-prejudice/downloads/epub',
    );
  });

  test('doSearch() filtre aussi par auteur, insensible à la casse', () async {
    when(() => httpClient.getList('https://standardebooks.org/ebooks.json'))
        .thenAnswer((_) async => _ebooksJsonFixture);

    final result = await source.doSearch('MELVILLE');

    expect(result.items, hasLength(1));
    expect(result.items.single.title, 'Moby-Dick');
  });

  test('doSearch() retourne une liste vide sans lever d\'exception si rien ne correspond', () async {
    when(() => httpClient.getList('https://standardebooks.org/ebooks.json'))
        .thenAnswer((_) async => _ebooksJsonFixture);

    final result = await source.doSearch('un titre qui n\'existe pas du tout');

    expect(result.items, isEmpty);
  });

  // Si getList() échoue vraiment (réseau down, etc.), le fallback OPDS (stub
  // volontaire V1, liste vide) doit prendre le relais SANS laisser
  // l'exception remonter jusqu'à l'appelant.
  test('retombe sur le fallback OPDS (liste vide) si getList() échoue réellement', () async {
    when(() => httpClient.getList('https://standardebooks.org/ebooks.json'))
        .thenThrow(Exception('network down'));

    final result = await source.doSearch('peu importe');

    expect(result.items, isEmpty);
  });
}

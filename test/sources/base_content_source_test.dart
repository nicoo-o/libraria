import 'package:flutter_test/flutter_test.dart';

import 'package:libraria/core/network/circuit_breaker.dart';
import 'package:libraria/sources/base_content_source.dart';
import 'package:libraria/sources/content_source.dart';

class _FakeSource extends BaseContentSource {
  _FakeSource(this._behavior);
  final Future<SourceSearchResult> Function() _behavior;

  @override
  String get id => 'fake';
  @override
  String get displayName => 'Fake Source';

  @override
  Future<SourceSearchResult> doSearch(String query, {int? page, int? limit}) => _behavior();
}

void main() {
  test('circuitState reste closed tant qu\'il n\'y a pas 5 échecs consécutifs', () async {
    var calls = 0;
    final source = _FakeSource(() async {
      calls++;
      return const SourceSearchResult(items: []);
    });

    await source.search('test');
    expect(source.circuitState, CircuitState.closed);
    expect(calls, 1);
  });

  // TODO : test d'ouverture du circuit après 5 échecs (mock d'exception réseau
  // répétée), et test de repassage half-open après openDuration — voir
  // 06_SOURCES_CONNECTEURS.md.
}

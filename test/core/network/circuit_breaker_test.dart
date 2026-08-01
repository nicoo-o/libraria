import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:libraria/core/errors/exceptions.dart';
import 'package:libraria/core/network/circuit_breaker.dart';

void main() {
  test('reste closed tant que le seuil d\'échecs n\'est pas atteint', () async {
    final breaker = CircuitBreaker(failureThreshold: 3, openDuration: const Duration(seconds: 60));

    for (var i = 0; i < 2; i++) {
      await expectLater(() => breaker.call(() => Future<void>.error(Exception('boom'))), throwsException);
    }

    expect(breaker.state, CircuitState.closed);
  });

  test('passe à open dès que le seuil d\'échecs est atteint', () async {
    final breaker = CircuitBreaker(failureThreshold: 3, openDuration: const Duration(seconds: 60));

    for (var i = 0; i < 3; i++) {
      await expectLater(() => breaker.call(() => Future<void>.error(Exception('boom'))), throwsException);
    }

    expect(breaker.state, CircuitState.open);
  });

  test('rejette immédiatement (SourceException) tant que le circuit est open', () async {
    final breaker = CircuitBreaker(failureThreshold: 1, openDuration: const Duration(seconds: 60));
    await expectLater(() => breaker.call(() => Future<void>.error(Exception('boom'))), throwsException);
    expect(breaker.state, CircuitState.open);

    var actionCalled = false;
    await expectLater(
      () => breaker.call(() async {
        actionCalled = true;
      }),
      throwsA(isA<SourceException>()),
    );
    // L'action elle-même ne doit JAMAIS être appelée circuit ouvert — c'est
    // tout l'intérêt du circuit breaker (épargner une source déjà en difficulté).
    expect(actionCalled, isFalse);
  });

  test('un succès referme le circuit et remet le compteur d\'échecs à zéro', () async {
    final breaker = CircuitBreaker(failureThreshold: 2, openDuration: const Duration(seconds: 60));
    await expectLater(() => breaker.call(() => Future<void>.error(Exception('boom'))), throwsException);
    expect(breaker.state, CircuitState.closed); // 1 échec sur 2 : toujours closed

    final result = await breaker.call(() async => 'ok');
    expect(result, 'ok');
    expect(breaker.state, CircuitState.closed);
  });

  // [Régression] `retry-after` était vérifié en `!= null` mais sa VALEUR n'était
  // jamais utilisée : le circuit retombait toujours sur `openDuration` fixe,
  // contredisant le commentaire "Respecte Retry-After". Ce test échouerait sans
  // le correctif (le circuit resterait ouvert alors qu'on avance au-delà de
  // `openDuration` mais en-deçà d'un Retry-After plus long).
  test('un 429 avec Retry-After garde le circuit ouvert plus longtemps que openDuration si besoin', () async {
    final breaker = CircuitBreaker(failureThreshold: 5, openDuration: const Duration(milliseconds: 50));

    final response = Response<void>(
      requestOptions: RequestOptions(path: ''),
      statusCode: 429,
      headers: Headers.fromMap({
        'retry-after': ['1'], // 1 seconde — plus long que openDuration (50ms)
      }),
    );
    await expectLater(
      () => breaker.call(() => Future<void>.error(
            DioException(requestOptions: RequestOptions(path: ''), response: response),
          )),
      throwsException,
    );
    expect(breaker.state, CircuitState.open);

    // openDuration (50ms) est dépassée, mais pas le Retry-After (1s) — le
    // circuit doit rester ouvert : sans le correctif, il repasserait à
    // half-open ici (bug), laissant passer une requête vers une source qui a
    // explicitement demandé d'attendre plus longtemps.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await expectLater(
      () => breaker.call(() async => 'ne devrait pas être appelé'),
      throwsA(isA<SourceException>()),
    );
    expect(breaker.state, CircuitState.open);
  });

  test('un 429 sans Retry-After retombe sur le comportement par seuil d\'échecs standard', () async {
    final breaker = CircuitBreaker(failureThreshold: 1, openDuration: const Duration(seconds: 60));

    final response = Response<void>(
      requestOptions: RequestOptions(path: ''),
      statusCode: 429,
      headers: Headers(), // pas de retry-after
    );
    await expectLater(
      () => breaker.call(() => Future<void>.error(
            DioException(requestOptions: RequestOptions(path: ''), response: response),
          )),
      throwsException,
    );

    expect(breaker.state, CircuitState.open);
  });
}

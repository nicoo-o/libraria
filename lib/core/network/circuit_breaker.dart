import 'package:dio/dio.dart';

import '../errors/exceptions.dart';

enum CircuitState { closed, open, halfOpen }

class CircuitBreaker {
  CircuitState state = CircuitState.closed;
  int _failures = 0;
  DateTime? _openedAt;
  // [Correctif] Le commentaire plus bas disait "Respecte Retry-After plutôt que
  // la durée fixe par défaut" mais la valeur du header n'était en réalité
  // JAMAIS utilisée — seulement vérifiée en `!= null`. `call()` retombait
  // toujours sur `openDuration` fixe. Ce champ porte la durée effective quand
  // un Retry-After a été fourni et parsé avec succès.
  Duration? _retryAfterOverride;
  final int failureThreshold;
  final Duration openDuration;

  CircuitBreaker({this.failureThreshold = 5, this.openDuration = const Duration(seconds: 60)});

  Future<T> call<T>(Future<T> Function() action) async {
    if (state == CircuitState.open) {
      final effectiveDuration = _retryAfterOverride ?? openDuration;
      if (DateTime.now().difference(_openedAt!) > effectiveDuration) {
        state = CircuitState.halfOpen;
        _retryAfterOverride = null;
      } else {
        throw SourceException('Circuit open', 'Source temporairement indisponible');
      }
    }
    try {
      final result = await action();
      _failures = 0;
      state = CircuitState.closed;
      _retryAfterOverride = null;
      return result;
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        // Respecte Retry-After plutôt que la durée fixe par défaut, quand le
        // serveur en fournit un et qu'il est interprétable.
        final override = _parseRetryAfter(e.response?.headers.value('retry-after'));
        if (override != null) {
          _openedAt = DateTime.now();
          _retryAfterOverride = override;
          state = CircuitState.open;
          rethrow;
        }
      }
      _onFailure();
      rethrow;
    } catch (_) {
      _onFailure();
      rethrow;
    }
  }

  /// Retry-After (RFC 7231) : soit un nombre de secondes (format le plus
  /// courant chez les APIs rencontrées ici), soit une HTTP-date. Le format
  /// HTTP-date (ex. "Wed, 21 Oct 2015 07:28:00 GMT") n'est pas couvert — `DateTime
  /// .tryParse` attend de l'ISO 8601 — auquel cas on retombe sur `openDuration`
  /// via `_onFailure()`, jamais sur une exception.
  Duration? _parseRetryAfter(String? header) {
    if (header == null) return null;
    final seconds = int.tryParse(header.trim());
    if (seconds != null && seconds >= 0) return Duration(seconds: seconds);
    final date = DateTime.tryParse(header);
    if (date != null) {
      final diff = date.difference(DateTime.now());
      return diff.isNegative ? Duration.zero : diff;
    }
    return null;
  }

  void _onFailure() {
    _failures++;
    if (_failures >= failureThreshold) {
      state = CircuitState.open;
      _openedAt = DateTime.now();
      _retryAfterOverride = null; // ouverture par seuil d'échecs : durée par défaut, pas de Retry-After ici
    }
  }
}

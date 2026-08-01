import '../core/network/circuit_breaker.dart';
import '../core/network/rate_limiter.dart';
import '../core/security/url_validator.dart';
import 'content_source.dart';

/// Gardes de sécurité automatiques : un nouveau connecteur ne peut pas les oublier
/// puisqu'il en hérite plutôt que d'implémenter `ContentSource` directement.
/// CONTRIBUTING.md impose : tout nouveau connecteur étend `BaseContentSource`, jamais
/// `ContentSource` directement (06_SOURCES_CONNECTEURS.md).
abstract class BaseContentSource implements ContentSource {
  final RateLimiter _rateLimiter = RateLimiter(maxPerWindow: 30, window: const Duration(seconds: 60));
  final CircuitBreaker _circuitBreaker =
      CircuitBreaker(failureThreshold: 5, openDuration: const Duration(seconds: 60));

  /// Exposé pour l'UI — distinguer « aucun résultat » de « source indisponible »
  /// (08_UI_UX_DESIGN_SYSTEM.md, UX-01).
  CircuitState get circuitState => _circuitBreaker.state;

  @override
  Future<SourceSearchResult> search(String query, {int? page, int? limit}) async {
    await _rateLimiter.acquire(id);
    return _circuitBreaker.call(() async {
      final results = await doSearch(query, page: page, limit: limit);
      for (final r in results.items) {
        UrlValidator.validate(r.downloadUrl);
      }
      return results;
    });
  }

  /// Implémenté par chaque connecteur concret.
  Future<SourceSearchResult> doSearch(String query, {int? page, int? limit});

  /// À appeler aussi pour tout appel HTTP additionnel (ex. `fetchChecksums` sur
  /// Internet Archive) — pas seulement `search()` — pour que le rate limiting couvre
  /// tous les appels.
  Future<T> rateLimited<T>(Future<T> Function() action) async {
    await _rateLimiter.acquire(id);
    return action();
  }
}

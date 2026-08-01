/// Cache mémoire des résultats de recherche récents (chapitre 12, NF-073) — TTL court,
/// jamais persisté en base : évite un re-fetch identique dans la même session, pas un
/// mécanisme d'offline.
class SearchCache {
  final _entries = <String, _CacheEntry>{};
  final Duration ttl;

  SearchCache({this.ttl = const Duration(minutes: 5)});

  T? get<T>(String key) {
    final entry = _entries[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.storedAt) > ttl) {
      _entries.remove(key);
      return null;
    }
    return entry.value as T;
  }

  void put(String key, Object value) {
    _entries[key] = _CacheEntry(value, DateTime.now());
  }
}

class _CacheEntry {
  final Object value;
  final DateTime storedAt;
  _CacheEntry(this.value, this.storedAt);
}

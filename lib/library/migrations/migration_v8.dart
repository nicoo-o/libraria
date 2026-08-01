/// v8 — Cache des couvertures (LRU disque).
const String migrationV8 = '''
CREATE TABLE IF NOT EXISTS cover_cache_index (
  filename TEXT PRIMARY KEY, size_bytes INTEGER NOT NULL, accessed_at INTEGER NOT NULL
);
''';

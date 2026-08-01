/// v7 — Sessions de lecture (base des statistiques, V3).
const String migrationV7 = '''
CREATE TABLE IF NOT EXISTS reading_sessions (
  id TEXT PRIMARY KEY, item_id TEXT NOT NULL, started_at INTEGER NOT NULL,
  ended_at INTEGER, pages_read INTEGER DEFAULT 0,
  FOREIGN KEY (item_id) REFERENCES library_items(id) ON DELETE CASCADE
);
''';

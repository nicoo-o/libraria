/// v6 — Notes et surlignages (CFI réel).
const String migrationV6 = '''
CREATE TABLE IF NOT EXISTS notes (
  id TEXT PRIMARY KEY, item_id TEXT NOT NULL, cfi TEXT NOT NULL,
  color TEXT NOT NULL DEFAULT '#FFEB3B', text TEXT, note TEXT, created_at INTEGER NOT NULL,
  FOREIGN KEY (item_id) REFERENCES library_items(id) ON DELETE CASCADE
);
''';

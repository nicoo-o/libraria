/// v5 — Étagères.
const String migrationV5 = '''
CREATE TABLE IF NOT EXISTS shelves (
  id TEXT PRIMARY KEY, name TEXT NOT NULL, color TEXT, position INTEGER DEFAULT 0
);
CREATE TABLE IF NOT EXISTS shelf_items (
  shelf_id TEXT NOT NULL, item_id TEXT NOT NULL, position INTEGER DEFAULT 0,
  PRIMARY KEY (shelf_id, item_id),
  FOREIGN KEY (shelf_id) REFERENCES shelves(id) ON DELETE CASCADE,
  FOREIGN KEY (item_id)  REFERENCES library_items(id) ON DELETE CASCADE
);
''';

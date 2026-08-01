/// v2 — Suivi de progression téléchargement + retries.
const String migrationV2 = '''
ALTER TABLE downloads ADD COLUMN save_path TEXT;
ALTER TABLE downloads ADD COLUMN progress REAL DEFAULT 0.0;
ALTER TABLE downloads ADD COLUMN priority INTEGER DEFAULT 2;
ALTER TABLE downloads ADD COLUMN error_message TEXT;
ALTER TABLE downloads ADD COLUMN retry_count INTEGER DEFAULT 0;
ALTER TABLE downloads ADD COLUMN last_retry_at INTEGER;
ALTER TABLE downloads ADD COLUMN completed_at INTEGER;
ALTER TABLE downloads ADD COLUMN library_item_id TEXT REFERENCES library_items(id);
CREATE INDEX IF NOT EXISTS idx_downloads_status ON downloads(status);
''';

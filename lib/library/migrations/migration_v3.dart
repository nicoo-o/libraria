/// v3 — Enrichissement des métadonnées de library_items.
const String migrationV3 = '''
ALTER TABLE library_items ADD COLUMN cover_path TEXT;
ALTER TABLE library_items ADD COLUMN source_name TEXT;
ALTER TABLE library_items ADD COLUMN source_url TEXT;
ALTER TABLE library_items ADD COLUMN last_opened_at INTEGER;
ALTER TABLE library_items ADD COLUMN read_progress REAL DEFAULT 0.0;
ALTER TABLE library_items ADD COLUMN is_favorite INTEGER DEFAULT 0;
ALTER TABLE library_items ADD COLUMN notes TEXT;
ALTER TABLE library_items ADD COLUMN year INTEGER;
ALTER TABLE library_items ADD COLUMN genre TEXT;
ALTER TABLE library_items ADD COLUMN rating REAL;
ALTER TABLE library_items ADD COLUMN duration_s INTEGER;
ALTER TABLE library_items ADD COLUMN description TEXT;
ALTER TABLE library_items ADD COLUMN cover_url TEXT;
ALTER TABLE library_items ADD COLUMN external_id TEXT;
CREATE INDEX IF NOT EXISTS idx_library_items_media_type  ON library_items(media_type);
CREATE INDEX IF NOT EXISTS idx_library_items_last_opened ON library_items(last_opened_at);
''';

/// Schéma complet, état final (v17) — utilisé par `onCreate` pour toute NOUVELLE
/// installation.
///
/// Note de correction : l'exemple `onCreate` de docs/restructuration_claude.md
/// (chapitre 04) exécute littéralement `migrationV1` seul, qui ne contenait
/// historiquement que 3 tables — sur une installation neuve, `onUpgrade` ne se
/// déclenche jamais (la DB est créée directement à `_dbVersion`), donc les tables
/// ajoutées par v2-v17 n'existeraient jamais. Ce fichier corrige ce gap : `onCreate`
/// applique désormais le schéma complet en une fois ; les fichiers `migration_v2.dart`
/// à `migration_v17.dart` restent la référence historique et servent réellement
/// à `onUpgrade` pour les installations existantes qui montent de version.
///
/// [Correctif] `source_connector` manquait ici alors qu'ajoutée par migration_v14 —
/// une installation neuve n'avait jamais cette colonne, contrairement à une
/// installation mise à niveau. Ajoutée ci-dessous pour que les deux chemins
/// (onCreate / onUpgrade) convergent vers le même schéma final.
const String fullSchemaV17 = '''
-- Bibliothèque
CREATE TABLE IF NOT EXISTS library_items (
  id              TEXT PRIMARY KEY,
  title           TEXT NOT NULL,
  author          TEXT,
  media_type      TEXT NOT NULL,
  local_path      TEXT,
  cover_path      TEXT,
  source_name     TEXT,
  source_url      TEXT,
  added_at        INTEGER NOT NULL,
  last_opened_at  INTEGER,
  read_progress   REAL    DEFAULT 0.0,
  last_cfi        TEXT,
  is_favorite     INTEGER DEFAULT 0,
  notes           TEXT,
  year            INTEGER, genre TEXT, rating REAL, duration_s INTEGER,
  description     TEXT, cover_url TEXT, external_id TEXT,
  is_missing      INTEGER NOT NULL DEFAULT 0,
  last_verified_at INTEGER,
  deleted_at      INTEGER,
  content_sha256  TEXT,
  series_name     TEXT,
  read_count      INTEGER NOT NULL DEFAULT 0,
  playback_speed_pref REAL
);
CREATE INDEX IF NOT EXISTS idx_library_items_media_type   ON library_items(media_type);
CREATE INDEX IF NOT EXISTS idx_library_items_last_opened  ON library_items(last_opened_at);
CREATE INDEX IF NOT EXISTS idx_items_missing              ON library_items(is_missing);
CREATE INDEX IF NOT EXISTS idx_items_deleted              ON library_items(deleted_at);

-- Téléchargements (queue + historique) — schéma guide Partie 2.1
CREATE TABLE IF NOT EXISTS downloads (
  id TEXT PRIMARY KEY, library_item_id TEXT, title TEXT NOT NULL, download_url TEXT NOT NULL,
  save_path TEXT, status TEXT NOT NULL, progress REAL DEFAULT 0.0, priority INTEGER DEFAULT 2,
  error_message TEXT, created_at INTEGER NOT NULL, completed_at INTEGER,
  retry_count INTEGER DEFAULT 0, last_retry_at INTEGER,
  result_json TEXT,         -- SearchResult complet sérialisé (resume après crash)
  expected_sha1 TEXT, expected_md5 TEXT, -- checksums Internet Archive (si fournis)
  source_connector TEXT,    -- v14 : identifiant du connecteur d'origine (NF-033/041)
  was_network_failure INTEGER DEFAULT 0, -- v17 : reprise automatique sur reconnexion
  FOREIGN KEY (library_item_id) REFERENCES library_items(id)
);
CREATE INDEX IF NOT EXISTS idx_downloads_status ON downloads(status);

-- Paramètres clé-valeur (jamais de credential en clair — voir 03_SECURITE.md)
CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT NOT NULL);

-- Signets/annotations
CREATE TABLE IF NOT EXISTS bookmarks (
  id TEXT PRIMARY KEY, item_id TEXT NOT NULL, location TEXT NOT NULL,
  text TEXT, note TEXT, color INTEGER DEFAULT 0, created_at INTEGER NOT NULL,
  FOREIGN KEY (item_id) REFERENCES library_items(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_bookmarks_item ON bookmarks(item_id);

-- Étagères (collections nommées) — is_smart/smart_rule : chapitre 12, NF-003
CREATE TABLE IF NOT EXISTS shelves (
  id TEXT PRIMARY KEY, name TEXT NOT NULL, color TEXT, position INTEGER DEFAULT 0,
  is_smart INTEGER NOT NULL DEFAULT 0, smart_rule TEXT
);
CREATE TABLE IF NOT EXISTS shelf_items (
  shelf_id TEXT NOT NULL, item_id TEXT NOT NULL, position INTEGER DEFAULT 0,
  PRIMARY KEY (shelf_id, item_id),
  FOREIGN KEY (shelf_id) REFERENCES shelves(id) ON DELETE CASCADE,
  FOREIGN KEY (item_id)  REFERENCES library_items(id) ON DELETE CASCADE
);

-- Tags libres (transverses, complètent les étagères — v11)
CREATE TABLE IF NOT EXISTS tags (
  id INTEGER PRIMARY KEY AUTOINCREMENT, label TEXT NOT NULL UNIQUE COLLATE NOCASE,
  color INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS item_tags (
  item_id TEXT NOT NULL REFERENCES library_items(id) ON DELETE CASCADE,
  tag_id  INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  PRIMARY KEY (item_id, tag_id)
);
CREATE INDEX IF NOT EXISTS idx_item_tags_tag ON item_tags(tag_id);

-- Notes et surlignages (avec CFI réel — voir 07_READER_AUDIOBOOK.md)
CREATE TABLE IF NOT EXISTS notes (
  id TEXT PRIMARY KEY, item_id TEXT NOT NULL, cfi TEXT NOT NULL,
  color TEXT NOT NULL DEFAULT '#FFEB3B', text TEXT, note TEXT, created_at INTEGER NOT NULL,
  FOREIGN KEY (item_id) REFERENCES library_items(id) ON DELETE CASCADE
);

-- Recherche plein texte dans les notes (v12)
CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(
  body, content='notes', content_rowid='rowid', tokenize='unicode61 remove_diacritics 2'
);
CREATE TRIGGER IF NOT EXISTS notes_ai AFTER INSERT ON notes BEGIN
  INSERT INTO notes_fts(rowid, body) VALUES (new.rowid, new.text);
END;
CREATE TRIGGER IF NOT EXISTS notes_ad AFTER DELETE ON notes BEGIN
  INSERT INTO notes_fts(notes_fts, rowid, body) VALUES('delete', old.rowid, old.text);
END;
CREATE TRIGGER IF NOT EXISTS notes_au AFTER UPDATE ON notes BEGIN
  INSERT INTO notes_fts(notes_fts, rowid, body) VALUES('delete', old.rowid, old.text);
  INSERT INTO notes_fts(rowid, body) VALUES (new.rowid, new.text);
END;

-- Sessions de lecture (statistiques locales, V3)
CREATE TABLE IF NOT EXISTS reading_sessions (
  id TEXT PRIMARY KEY, item_id TEXT NOT NULL, started_at INTEGER NOT NULL,
  ended_at INTEGER, pages_read INTEGER DEFAULT 0,
  FOREIGN KEY (item_id) REFERENCES library_items(id) ON DELETE CASCADE
);

-- Cache des couvertures (LRU, cache disque)
CREATE TABLE IF NOT EXISTS cover_cache_index (
  filename TEXT PRIMARY KEY, size_bytes INTEGER NOT NULL, accessed_at INTEGER NOT NULL
);
''';

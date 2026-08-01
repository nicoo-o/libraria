/// v1 — Schéma initial historique (3 tables : library_items minimal, downloads, settings).
/// Référence historique uniquement — une installation neuve utilise `schema_full.dart`
/// (voir la note de correction dans ce fichier). Ceci reste utile pour comprendre
/// l'évolution du schéma et pour un éventuel outil de migration depuis une très
/// ancienne version externe (pre-restructuration).
const String migrationV1 = '''
CREATE TABLE IF NOT EXISTS library_items (
  id TEXT PRIMARY KEY, title TEXT NOT NULL, author TEXT, media_type TEXT NOT NULL,
  local_path TEXT, added_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS downloads (
  id TEXT PRIMARY KEY, title TEXT NOT NULL, download_url TEXT NOT NULL,
  status TEXT NOT NULL, created_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT NOT NULL);
''';

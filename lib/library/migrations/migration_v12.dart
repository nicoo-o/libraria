/// v12 — Recherche plein texte (FTS5) dans les notes.
const String migrationV12 = '''
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
''';

/// v15 — Chapitre 12 (NF-003, étagères intelligentes).
const String migrationV15 = '''
ALTER TABLE shelves ADD COLUMN is_smart INTEGER NOT NULL DEFAULT 0;
ALTER TABLE shelves ADD COLUMN smart_rule TEXT;
''';

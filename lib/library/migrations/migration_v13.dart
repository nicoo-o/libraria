/// v13 — Chapitre 12 (NF-002 séries, NF compteur de relecture). Groupée : deux
/// colonnes de deux features différentes qui n'avaient aucune raison d'être séparées
/// (règle R3'', voir 12.12 dans restructuration_claude.md).
const String migrationV13 = '''
ALTER TABLE library_items ADD COLUMN series_name TEXT;
ALTER TABLE library_items ADD COLUMN read_count INTEGER NOT NULL DEFAULT 0;
''';

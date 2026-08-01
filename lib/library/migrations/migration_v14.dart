/// v14 — Chapitre 12 (NF-023 vitesse audio par livre, NF-033/041 source du job).
const String migrationV14 = '''
ALTER TABLE library_items ADD COLUMN playback_speed_pref REAL;
ALTER TABLE downloads ADD COLUMN source_connector TEXT;
''';

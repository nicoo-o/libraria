/// v10 — Position de lecture précise (CFI), au-delà du pourcentage seul.
/// Le pourcentage dérive dès que la taille de police ou le thème change — le même
/// pourcentage ne correspond plus au même paragraphe (07_READER_AUDIOBOOK.md).
const String migrationV10 = '''
ALTER TABLE library_items ADD COLUMN last_cfi TEXT;
''';

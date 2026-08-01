/// v16 — [Correctif cohérence schéma] `result_json`, `expected_sha1` et
/// `expected_md5` existaient dans `schema_full.dart` (utilisé par `onCreate` pour
/// toute NOUVELLE installation) mais n'avaient jamais été ajoutées par une migration
/// `ALTER TABLE` : une installation EXISTANTE qui montait de version via `onUpgrade`
/// (v1 → v15) ne les obtenait donc jamais. `DownloadJob.toMap()` (core/models/
/// download_job.dart) écrit pourtant systématiquement ces trois clés — tout
/// `db.insert('downloads', job.toMap())` sur une base ainsi mise à niveau aurait
/// levé « DatabaseException: no such column » dès le premier téléchargement.
const String migrationV16 = '''
ALTER TABLE downloads ADD COLUMN result_json TEXT;
ALTER TABLE downloads ADD COLUMN expected_sha1 TEXT;
ALTER TABLE downloads ADD COLUMN expected_md5 TEXT;
''';

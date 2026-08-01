import 'package:sqflite/sqflite.dart';

/// Repository cle-valeur generique sur la table `settings` (schema_full.dart).
/// Utilise pour toute preference utilisateur simple qui ne merite pas sa
/// propre table dediee (ex: mode de lecture EPUB prefere, page par page ou
/// defilement -- voir epub_reader_screen.dart).
class SettingsRepository {
  SettingsRepository(this._db);
  final Database _db;

  Future<String?> getValue(String key) async {
    final rows = await _db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setValue(String key, String value) async {
    await _db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// [Correctif — bug réel trouvé en test réel] Activer/désactiver une des 4
  /// sources V1 de base (Gutenberg, Internet Archive, LibriVox, Standard
  /// Ebooks) individuellement : aucun mécanisme n'existait dans Réglages
  /// pour ça — seules les sources ÉTENDUES (GitHub Edition,
  /// `ExtendedSourcesSettings`) avaient un tel toggle. Activé par défaut
  /// (absence de ligne en base == activé) pour ne rien changer au
  /// comportement existant tant que l'utilisateur ne désactive rien.
  Future<bool> isSourceEnabled(String sourceId) async {
    final v = await getValue('source_enabled_$sourceId');
    return v != 'false';
  }

  Future<void> setSourceEnabled(String sourceId, bool enabled) =>
      setValue('source_enabled_$sourceId', enabled.toString());
}
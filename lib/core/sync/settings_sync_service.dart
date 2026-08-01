/// Chiffrement Argon2id + AES-256-GCM (03_SECURITE.md) — réutilisé tel quel pour la
/// sauvegarde complète de la bibliothèque, jamais réimplémenté ailleurs.
class SettingsSyncService {
  static Future<List<int>> encrypt(String plaintextJson, String passphrase) async {
    throw UnimplementedError(
      'SettingsSyncService.encrypt() — Argon2id + AES-256-GCM, V2 (03_SECURITE.md). '
      'Les clés API ne doivent JAMAIS être incluses par défaut — opt-in explicite requis.',
    );
  }

  static Future<String> decrypt(List<int> encrypted, String passphrase) async {
    throw UnimplementedError('SettingsSyncService.decrypt() — symétrique de encrypt().');
  }
}

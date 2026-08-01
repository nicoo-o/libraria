/// Interface de destination de sauvegarde (V2 — WebDAV chiffré, 03_SECURITE.md).
abstract class SyncBackend {
  Future<void> upload(String filename, List<int> encryptedBytes);
  Future<List<int>> download(String filename);
}

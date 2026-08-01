/// Sync du payload de progression multi-appareils (V3, 04_BASE_DE_DONNEES.md).
/// Purge les références mortes avant envoi — voir buildSyncPayload() dans la doc.
class ProgressSyncService {
  Future<Map<String, dynamic>> buildSyncPayload(List<String> existingItemIds) async {
    throw UnimplementedError(
      'ProgressSyncService.buildSyncPayload() — V3, purger les entrées dont l\'item_id '
      'n\'existe plus localement (04_BASE_DE_DONNEES.md, §Sync).',
    );
  }
}

/// Recommandation locale par similarité de tags/genre (indice de Jaccard) — pas de
/// service cloud, pas de collecte de données (00_VISION_ET_PORTEE.md). Étendu au
/// cross-média en V3 (chapitre 12, NF-098).
class LocalRecommender {
  /// Indice de Jaccard entre deux ensembles de tags/genres — |A∩B| / |A∪B|.
  double jaccardSimilarity(Set<String> a, Set<String> b) {
    if (a.isEmpty && b.isEmpty) return 0.0;
    final intersection = a.intersection(b).length;
    final union = a.union(b).length;
    return union == 0 ? 0.0 : intersection / union;
  }

  Future<List<String>> recommendFor(String itemId) async {
    throw UnimplementedError(
      'LocalRecommender.recommendFor() — comparer les tags/genre de itemId contre le '
      'reste de la bibliothèque via jaccardSimilarity(), trier décroissant. '
      'Voir 11_BACKLOG.md, item PF-03.',
    );
  }
}

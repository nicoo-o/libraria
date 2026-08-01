/// Paramètres d'une recherche transverse aux 4 sources (06_SOURCES_CONNECTEURS.md).
class SearchQuery {
  final String text;
  final int page;
  final int limit;
  final Set<String>? sourceIds; // filtre par source d'origine (chapitre 12, NF-071)

  const SearchQuery({
    required this.text,
    this.page = 1,
    this.limit = 20,
    this.sourceIds,
  });
}

import '../core/models/search_result.dart';

/// Signature pagination-aware — la SEULE version valable (ADR-005, 01_DECISIONS.md).
/// Les 4 connecteurs V1 s'écrivent directement contre elle, pas de migration à faire
/// plus tard.
abstract class ContentSource {
  String get id;
  String get displayName;
  Future<SourceSearchResult> search(String query, {int? page, int? limit});
}

class SourceSearchResult {
  final List<SearchResult> items;
  final int? totalCount;
  final bool hasMore;
  const SourceSearchResult({required this.items, this.totalCount, this.hasMore = false});
}

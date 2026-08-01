import 'package:flutter/material.dart';

import '../core/network/circuit_breaker.dart';
import '../l10n/app_localizations.dart';
import '../sources/base_content_source.dart';

/// Barre de recherche transverse aux 4 sources (06_SOURCES_CONNECTEURS.md).
class UniversalSearchBar extends StatelessWidget {
  const UniversalSearchBar({super.key, required this.onSubmitted});
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        hintText: AppLocalizations.of(context).searchHint,
        prefixIcon: const Icon(Icons.search),
        border: const OutlineInputBorder(),
      ),
      onSubmitted: onSubmitted,
    );
  }
}

/// États vides — distingue « aucun résultat » de « source(s) indisponible(s) » grâce
/// au circuit breaker de chaque `ContentSource` (08_UI_UX_DESIGN_SYSTEM.md, UX-01,
/// et chapitre 12, NF-069).
///
/// Non utilisé actuellement : `search_screen.dart` réimplémente la même logique
/// localement dans `_buildEmptyState()` plutôt que d'utiliser ce widget.
class SearchEmptyState extends StatelessWidget {
  const SearchEmptyState({super.key, required this.sources, required this.onRetry});
  final List<BaseContentSource> sources;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final degraded = sources.where((s) => s.circuitState == CircuitState.open).toList();

    if (degraded.isNotEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.searchSourcesUnavailable(degraded.map((s) => s.displayName).join(', ')),
            textAlign: TextAlign.center,
          ),
          TextButton(onPressed: onRetry, child: Text(l10n.retry)),
        ],
      );
    }
    return Text(l10n.searchNoResults);
  }
}

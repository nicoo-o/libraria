import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/network/circuit_breaker.dart';
import '../core/models/search_result.dart';
import '../download_manager/download_manager.dart';
import '../l10n/app_localizations.dart';
import '../library/library_change_notifier.dart';
import '../library/library_repository.dart';
import '../library/settings_repository.dart';
import '../sources/base_content_source.dart';
import '../sources/content_source.dart';
import '../sources/internet_archive/internet_archive_source.dart';
import '../sources/librivox/librivox_source.dart';
import '../sources/standard_ebooks/standard_ebooks_source.dart';

import '../sources/gutenberg/gutenberg_source.dart';


import '../widgets/universal_search_bar.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  bool _loading = false;
  String _lastQuery = '';
  List<SearchResult> _results = [];

  late final List<ContentSource> _sources;
  late final List<BaseContentSource> _baseSources;

  // [Chapitre 12, NF-075 — trou comblé] Badge « déjà possédé » dans les
  // résultats de recherche. Comparaison par titre+auteur normalisés — pas de
  // content_sha256 (inconnu avant téléchargement, donc inexploitable ici).
  Set<String> _libraryKeys = {};
  int _lastLibraryChangeVersion = 0;

  @override
  void initState() {
    super.initState();
    // 4 sources V1 (câblage en Provider dans main.dart)
    // Chaque source V1 étend BaseContentSource => circuitState exploitable.
    _sources = [
      context.read<GutenbergSource>(),
      context.read<InternetArchiveSource>(),
      context.read<LibrivoxSource>(),
      context.read<StandardEbooksSource>(),
    ];



    _baseSources = _sources.whereType<BaseContentSource>().toList();
    unawaited(_loadLibraryKeys());
  }

  Future<void> _loadLibraryKeys() async {
    final items = await context.read<LibraryRepository>().getAll();
    if (!mounted) return;
    setState(() {
      _libraryKeys = items.map((i) => _ownershipKey(i.title, i.author)).toSet();
    });
  }

  /// Clé de rapprochement titre+auteur — en minuscules et sans espaces
  /// superflus pour absorber les petites variations de casse/espacement
  /// entre le catalogue d'une source et le titre déjà enregistré en base.
  String _ownershipKey(String title, String? author) {
    return '${title.trim().toLowerCase()}|${(author ?? '').trim().toLowerCase()}';
  }

  Future<void> _runSearch(String query) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _lastQuery = query;
      _results = [];
    });

    // [Correctif — bug réel trouvé en test réel] Aucun moyen de désactiver
    // une des 4 sources V1 de base n'existait dans Réglages — une source
    // désactivée continuait d'apparaître dans les résultats malgré tout,
    // faute de filtre ici. `isSourceEnabled` par défaut à `true` : ne change
    // rien tant que l'utilisateur n'a rien désactivé dans Réglages.
    final settings = context.read<SettingsRepository>();
    final activeSources = <ContentSource>[];
    for (final s in _sources) {
      final enabled = s is BaseContentSource ? await settings.isSourceEnabled(s.id) : true;
      if (enabled) activeSources.add(s);
    }

    final results = await Future.wait(
      activeSources.map(
        (s) => s.search(query, limit: 20).catchError((_) => const SourceSearchResult(items: [])),
      ),
    );

    final merged = results.expand((r) => r.items).toList();
    if (!mounted) return;
    setState(() {
      _results = merged;
      _loading = false;
    });
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context);
    final degraded = _baseSources
        .where((s) => s.circuitState == CircuitState.open)
        .toList();

    if (degraded.isNotEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            l10n.searchSourcesUnavailable(degraded.map((s) => s.displayName).join(', ')),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _lastQuery.isEmpty ? null : () => _runSearch(_lastQuery),
            child: Text(l10n.retry),
          ),
        ],
      );
    }

    return Center(child: Text(l10n.searchNoResults));
  }

  /// [Chapitre 12, NF-069 — trou comblé] Statut live des sources — jusqu'ici
  /// `circuitState` était déjà exposé par `BaseContentSource` (exactement
  /// pour cet usage, voir son commentaire "Exposé pour l'UI") mais rien ne
  /// l'affichait avant que la recherche ne renvoie zéro résultat
  /// (`_buildEmptyState`). Cette ligne de puces est visible en permanence,
  /// avant même la première recherche.
  Widget _buildSourceStatusRow() {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final source in _baseSources)
          Tooltip(
            message: '${source.displayName} — ${_sourceStatusLabel(l10n, source.circuitState)}',
            child: Chip(
              avatar: Icon(_sourceStatusIcon(source.circuitState), size: 16, color: _sourceStatusColor(source.circuitState)),
              label: Text(source.displayName),
              visualDensity: VisualDensity.compact,
            ),
          ),
      ],
    );
  }

  IconData _sourceStatusIcon(CircuitState state) => switch (state) {
        CircuitState.closed => Icons.check_circle,
        CircuitState.halfOpen => Icons.sync,
        CircuitState.open => Icons.error,
      };

  Color _sourceStatusColor(CircuitState state) => switch (state) {
        CircuitState.closed => Colors.green,
        CircuitState.halfOpen => Colors.orange,
        CircuitState.open => Colors.red,
      };

  String _sourceStatusLabel(AppLocalizations l10n, CircuitState state) => switch (state) {
        CircuitState.closed => l10n.sourceStatusAvailable,
        CircuitState.halfOpen => l10n.sourceStatusRecovering,
        CircuitState.open => l10n.sourceStatusUnavailable,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // [Chapitre 12, NF-075] Un téléchargement peut se terminer pendant que
    // cet écran reste monté (IndexedStack, comme LibraryScreen) — sans cette
    // observation, un livre tout juste téléchargé continuerait d'apparaître
    // « nouveau » dans une recherche ultérieure au sein de la même session.
    final libraryChangeVersion = context.watch<LibraryChangeNotifier>().version;
    if (libraryChangeVersion != _lastLibraryChangeVersion) {
      _lastLibraryChangeVersion = libraryChangeVersion;
      unawaited(_loadLibraryKeys());
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSearch)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            UniversalSearchBar(onSubmitted: _runSearch),
            const SizedBox(height: 12),
            _buildSourceStatusRow(),
            const SizedBox(height: 16),
            if (_loading) const LinearProgressIndicator(),
            const SizedBox(height: 16),
            Expanded(
              child: _results.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, i) {
                        final r = _results[i];
                        final alreadyOwned = _libraryKeys.contains(_ownershipKey(r.title, r.author));
                        return ListTile(
                          leading: r.coverUrl == null
                              ? null
                              : Image.network(
                                  r.coverUrl!,
                                  width: 40,
                                  height: 60,
                                  fit: BoxFit.cover,
                                ),
                          title: Text(r.title),
                          subtitle: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${r.author ?? ''}${r.author != null ? ' · ' : ''}${r.sourceName}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (alreadyOwned) ...[
                                const SizedBox(width: 6),
                                // [Chapitre 12, NF-075 — trou comblé] Badge
                                // « déjà possédé » — aucun rapprochement
                                // content_sha256/titre+auteur n'existait
                                // contre les résultats de recherche (audit).
                                Tooltip(
                                  message: l10n.searchAlreadyOwned,
                                  child: Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
                                ),
                              ],
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.download),
                            onPressed: () => context
                                .read<DownloadManager>()
                                .enqueue(r),
                            tooltip: l10n.downloadTooltip,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}


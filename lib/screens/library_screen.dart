import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/download_job.dart';
import '../core/models/library_item.dart';
import '../download_manager/download_manager.dart';
import '../l10n/app_localizations.dart';
import '../library/library_change_notifier.dart';
import '../library/library_repository.dart';
import '../widgets/cover_placeholder.dart';
import 'media_detail_screen.dart';

/// Accueil de l'app (navigation library-first, 02_ARCHITECTURE.md — `_index`
/// commence toujours à 0 sur cet écran).
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late Future<List<LibraryItem>> _items;
  int _lastCompletedCount = 0;
  int _lastLibraryChangeVersion = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _items = context.read<LibraryRepository>().getAll();
  }

  @override
  Widget build(BuildContext context) {
    // [Correctif] Avec IndexedStack (app.dart), cet écran reste monté en
    // permanence : sans ceci, `_items` figé depuis initState() ne montrait
    // jamais un livre tout juste téléchargé sans redémarrer l'app. On observe
    // DownloadManager (déjà un ChangeNotifier fourni par main.dart) et on ne
    // relance la requête que lorsque le nombre de jobs "completed" augmente —
    // pas à chaque tick de progression, pour ne pas marteler la DB.
    final completedCount =
        context.watch<DownloadManager>().jobs.where((j) => j.status == DownloadStatus.completed).length;
    if (completedCount != _lastCompletedCount) {
      _lastCompletedCount = completedCount;
      _refresh();
    }

    // [Correctif] TrashScreen.restore() n'a aucun lien direct avec cet ecran
    // (IndexedStack les garde montes independamment) -- sans cette observation,
    // un item restaure depuis la Corbeille ne reapparaissait jamais ici.
    final libraryChangeVersion = context.watch<LibraryChangeNotifier>().version;
    if (libraryChangeVersion != _lastLibraryChangeVersion) {
      _lastLibraryChangeVersion = libraryChangeVersion;
      _refresh();
    }

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).navLibrary)),
      body: FutureBuilder<List<LibraryItem>>(
        future: _items,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final items = snapshot.data!;
          if (items.isEmpty) {
            // [Correctif — bug réel trouvé en test réel] RefreshIndicator a
            // besoin d'un enfant scrollable pour détecter le geste de swipe ;
            // un simple Center() ne le déclenche jamais. CustomScrollView +
            // AlwaysScrollableScrollPhysics couvre aussi ce cas vide.
            return RefreshIndicator(
              onRefresh: () async => setState(_refresh),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverFillRemaining(
                    child: Center(child: Text(AppLocalizations.of(context).libraryEmptyState)),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            // [Correctif — bug réel trouvé en test réel] Le pull-to-refresh
            // n'existait tout simplement pas : le GridView n'était enveloppé
            // dans aucun RefreshIndicator, donc le swipe vers le bas ne
            // déclenchait rien de visible ni de fonctionnel.
            onRefresh: () async => setState(_refresh),
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              physics: const AlwaysScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final item = items[i];
                return InkWell(
                  // [Correctif] Aucune navigation n'existait vers MediaDetailScreen —
                  // les lecteurs EPUB/audiobook (Partie 6) étaient inatteignables
                  // depuis l'UI. `.then((_) => _refresh())` : au retour du lecteur,
                  // `read_progress`/`last_cfi` viennent d'être mis à jour en DB.
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => MediaDetailScreen(item: item)))
                      .then((_) => setState(_refresh)),
                  child: CoverPlaceholder(
                    title: item.title,
                    author: item.author,
                    mediaType: item.mediaType,
                    coverPath: item.coverPath,
                    // [Correctif — bug réel trouvé en test réel] `readProgress`
                    // n'était jamais transmis à CoverPlaceholder (voir son
                    // commentaire) : la colonne `read_progress` était bien à
                    // jour en DB mais rien ne l'affichait nulle part.
                    readProgress: item.readProgress,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

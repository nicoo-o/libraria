import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/integrity/checksum_verifier.dart';
import '../core/models/library_item.dart';
import '../core/models/media_type.dart';
import '../l10n/app_localizations.dart';
import '../library/library_change_notifier.dart';
import '../library/library_repository.dart';
import '../readers/audio_player_screen.dart';
import '../readers/epub_reader_screen.dart';
import '../widgets/undo_snackbar.dart';

class MediaDetailScreen extends StatefulWidget {
  const MediaDetailScreen({super.key, required this.item});
  final LibraryItem item;

  @override
  State<MediaDetailScreen> createState() => _MediaDetailScreenState();
}

class _MediaDetailScreenState extends State<MediaDetailScreen> {
  bool _relinking = false;
  // [Correctif] widget.item est fige au moment ou MediaDetailScreen a ete
  // construit -- si le lecteur (EpubReaderScreen/AudioPlayerScreen) met a
  // jour lastCfi en base pendant la lecture, cet objet en memoire ne le sait
  // jamais. Consequence : rouvrir le lecteur depuis ce meme MediaDetailScreen
  // (sans repasser par la Bibliotheque) repartait sur l'ancien lastCfi
  // perime, malgre une base de donnees a jour. _currentItem est rafraichi
  // explicitement au retour du lecteur (voir _openReader ci-dessous) pour
  // que chaque reouverture reparte de la derniere position reelle.
  late LibraryItem _currentItem;

  @override
  void initState() {
    super.initState();
    _currentItem = widget.item;
  }

  Future<void> _confirmDelete() async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.mediaDetailDeleteConfirmTitle),
        content: Text(l10n.mediaDetailDeleteConfirmBody(widget.item.title)),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.mediaDetailDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // [Correctif — corbeille] Aucun bouton ne permettait jusqu'ici de
    // supprimer un ouvrage nulle part dans l'UI, malgré softDelete() déjà
    // écrit côté repository (ADR-011, 2 paliers : corbeille 30j puis purge).
    final repository = context.read<LibraryRepository>();
    // [Correctif — bug réel trouvé en test réel] `LibraryScreen`/`TrashScreen`
    // ne se rafraîchissent QUE sur `LibraryChangeNotifier.notifyChanged()`
    // (IndexedStack, écrans montés en permanence — voir leurs commentaires
    // respectifs). Cet écran ne l'appelait jamais : après un Annuler réussi,
    // le livre restauré restait invisible en bibliothèque tant qu'on ne
    // forçait pas un rafraîchissement manuel (pull-to-refresh inexistant,
    // voir library_screen.dart).
    final libraryChangeNotifier = context.read<LibraryChangeNotifier>();
    await repository.softDelete(widget.item.id);
    libraryChangeNotifier.notifyChanged();
    if (mounted) navigator.pop();

    // [Chapitre 12, NF-085] Bouton « Annuler » générique 5s — l'audit V1
    // avait trouvé des SnackBar (corbeille, relink) mais aucune n'avait de
    // SnackBarAction, pas un seul bouton Annuler nulle part dans l'app.
    // L'item reste de toute façon protégé 30 jours par la corbeille
    // (ADR-011) : ce bouton évite juste à l'utilisateur de devoir rouvrir la
    // Corbeille pour un retour en arrière immédiat après une suppression.
    showUndoSnackBar(
      messenger,
      message: l10n.mediaDetailDeletedUndo(widget.item.title),
      undoLabel: l10n.undo,
      onUndo: () async {
        await repository.restore(widget.item.id);
        libraryChangeNotifier.notifyChanged();
      },
    );
  }

  /// Marquage « Lu » manuel (chapitre 12, NF-006) — trou comblé : jusqu'ici
  /// aucun bouton, aucune méthode ne posait `read_progress = 1.0` (voir
  /// audit). Rafraîchit `_currentItem` comme _openReader() le fait déjà pour
  /// que le reste de l'écran (bouton, éventuel badge) reflète l'état à jour.
  Future<void> _markAsRead() async {
    final repository = context.read<LibraryRepository>();
    await repository.markAsRead(widget.item.id);
    if (!mounted) return;
    final refreshed = await repository.getById(widget.item.id);
    if (refreshed != null && mounted) {
      setState(() => _currentItem = refreshed);
    }
  }

  Future<void> _relinkFile() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: widget.item.mediaType == MediaType.audiobook ? ['mp3', 'm4b'] : ['epub'],
    );
    final path = result?.files.single.path;
    if (path == null || !mounted) return;

    setState(() => _relinking = true);
    try {
      final newSha = await ChecksumVerifier.computeStreaming(File(path));
      if (!mounted) return;
      await context.read<LibraryRepository>().relink(widget.item.id, newPath: path, newSha: newSha);
      if (mounted) messenger.showSnackBar(SnackBar(content: Text(l10n.mediaDetailRelinkSuccess)));
    } finally {
      if (mounted) setState(() => _relinking = false);
    }
  }

  /// Ouvre le lecteur puis, au retour, relit l'item depuis la base pour
  /// recuperer le lastCfi/readProgress reellement a jour (voir commentaire
  /// sur _currentItem plus haut pour le detail du bug corrige).
  Future<void> _openReader() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _currentItem.mediaType == MediaType.audiobook
          ? AudioPlayerScreen(item: _currentItem)
          : EpubReaderScreen(item: _currentItem),
    ));
    if (!mounted) return;
    final refreshed = await context.read<LibraryRepository>().getById(_currentItem.id);
    if (refreshed != null && mounted) {
      setState(() => _currentItem = refreshed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final item = _currentItem;
    return Scaffold(
      appBar: AppBar(
        title: Text(item.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.mediaDetailDelete,
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.author ?? l10n.mediaDetailUnknownAuthor, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            if (item.isMissing) ...[
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onErrorContainer),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.mediaDetailMissingFile,
                          style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _relinking ? null : _relinkFile,
                icon: _relinking
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.link),
                label: Text(l10n.mediaDetailRelink),
              ),
              const SizedBox(height: 16),
            ],
            ElevatedButton(
              onPressed: item.isMissing ? null : _openReader,
              child: Text(l10n.mediaDetailOpen),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: item.readProgress >= 1.0 ? null : _markAsRead,
              icon: Icon(item.readProgress >= 1.0 ? Icons.check_circle : Icons.check_circle_outline),
              label: Text(item.readProgress >= 1.0 ? l10n.mediaDetailMarkedAsRead : l10n.mediaDetailMarkAsRead),
            ),
          ],
        ),
      ),
    );
  }
}

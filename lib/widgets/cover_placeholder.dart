import 'dart:io';

import 'package:flutter/material.dart';

import '../core/models/media_type.dart';
import '../l10n/app_localizations.dart';

/// Typographique + icône de type de média — initiale du titre, couleur dérivée du
/// hash du titre, icône discrète (menu_book / headphones) en coin pour distinguer
/// livres et audiobooks dans une grille mixte, sans perdre le rendu typographique
/// (08_UI_UX_DESIGN_SYSTEM.md).
///
/// [Correctif ADR-010] `coverPath` (optionnel) affiche la couverture réellement
/// mise en cache par `DownloadManager`/`CoverCacheManager` quand elle existe.
/// `errorBuilder` retombe silencieusement sur le rendu typographique si le
/// fichier a disparu (purge LRU, item manquant...) plutôt que de planter.
class CoverPlaceholder extends StatelessWidget {
  const CoverPlaceholder({
    super.key,
    required this.title,
    this.author,
    required this.mediaType,
    this.coverPath,
    this.readProgress,
  });

  final String title;
  final String? author;
  final MediaType mediaType;
  final String? coverPath;

  /// [Correctif — bug réel trouvé en test réel] `readProgress` n'était même
  /// pas un paramètre de ce widget : la barre de progression "visible sur
  /// les items déjà commencés" décrite dans la doc n'existait tout
  /// simplement pas dans le code, contrairement à ce que suggérait le nom
  /// de la colonne `read_progress` (bien lue/écrite en DB, juste jamais
  /// affichée). `null` ou `0.0` -> pas de barre (livre pas commencé).
  final double? readProgress;

  Color _colorFromHash(String s) {
    final hue = (s.hashCode.abs() % 360).toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.55, 0.35).toColor();
  }

  IconData get _mediaIcon => mediaType == MediaType.audiobook ? Icons.headphones : Icons.menu_book;

  Widget _typographicPlaceholder(String initial) {
    return Container(
      decoration: BoxDecoration(
        color: _colorFromHash(title),
        border: Border.all(color: Colors.black12),
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              initial,
              style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          Positioned(
            right: 6,
            bottom: 6,
            child: Icon(_mediaIcon, size: 16, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initial = title.isNotEmpty ? title[0].toUpperCase() : '?';
    final path = coverPath;
    final progress = readProgress;
    final showProgress = progress != null && progress > 0.0 && progress < 1.0;
    return Semantics(
      label: author != null ? '$title, $author' : title,
      image: true,
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: Stack(
          children: [
            Positioned.fill(
              child: path == null
                  ? _typographicPlaceholder(initial)
                  : Image.file(
                      File(path),
                      fit: BoxFit.cover,
                      // Fichier disparu (purge LRU, item déplacé...) : jamais un
                      // crash, juste le repli typographique habituel.
                      errorBuilder: (context, error, stackTrace) => _typographicPlaceholder(initial),
                    ),
            ),
            if (showProgress)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ClipRRect(
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: Colors.black.withValues(alpha: 0.35),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Badge OFFLINE — fond orange, texte blanc (08_UI_UX_DESIGN_SYSTEM.md).
class OfflineBadge extends StatelessWidget {
  const OfflineBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(12)),
      child: Text(
        AppLocalizations.of(context).offlineBadge,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}

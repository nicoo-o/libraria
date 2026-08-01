import 'package:flutter/material.dart';

/// SnackBar générique avec bouton « Annuler » à durée fixe de 5s (chapitre 12,
/// NF-085). Trou comblé — l'audit V1 avait trouvé des SnackBar déjà en place
/// (corbeille, relink) mais aucune n'avait de `SnackBarAction` : pas un seul
/// bouton Annuler nulle part dans l'app.
///
/// [Décision] Un simple helper plutôt qu'un widget dédié : les écrans qui
/// suppriment/déplacent quelque chose ont déjà tous un `ScaffoldMessenger`
/// sous la main (voir media_detail_screen.dart) — inutile d'ajouter une
/// couche supplémentaire pour un SnackBar standard.
void showUndoSnackBar(
  ScaffoldMessengerState messenger, {
  required String message,
  required String undoLabel,
  required VoidCallback onUndo,
}) {
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 5),
      action: SnackBarAction(label: undoLabel, onPressed: onUndo),
    ),
  );
}

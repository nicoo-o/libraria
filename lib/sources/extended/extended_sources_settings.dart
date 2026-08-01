import 'package:flutter/foundation.dart';

import 'build_flags.dart';

/// État runtime des toggles pour chaque source étendue.
///
/// Persistance : à brancher sur `sqflite` (table `settings`, colonne `key/value`)
/// dans la même migration que le reste des préférences (voir R3, MES_PROPOSITIONS).
/// Pour l'instant : in-memory, réinitialisé à chaque lancement — c'est volontaire
/// tant que la migration n'a pas atterri, un toggle non persisté est préférable
/// à un toggle silencieusement inactif.
///
/// Toute activation passe par [enable]/[disable] : jamais de mutation directe
/// depuis l'UI, pour garder un seul point à instrumenter (log, audit, futur
/// consentement explicite).
class ExtendedSourcesSettings extends ChangeNotifier {
  ExtendedSourcesSettings();

  final Map<String, bool> _enabled = <String, bool>{};

  /// True si la source [sourceId] est utilisable *maintenant* :
  /// build GitHub Edition ET toggle utilisateur ON.
  bool isEnabled(String sourceId) {
    if (!kExtendedSourcesAvailable) return false;
    return _enabled[sourceId] ?? false;
  }

  void setEnabled(String sourceId, bool value) {
    if (!kExtendedSourcesAvailable) return;
    _enabled[sourceId] = value;
    notifyListeners();
    // TODO (P1) : persister via sqflite (table `settings`), même migration que
    // les toggles de la Partie 1 de MES_PROPOSITIONS.
  }
}

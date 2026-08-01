/// Serveur OPDS SORTANT (Libraria expose son catalogue en local) — V2, hors périmètre
/// V1 (02_ARCHITECTURE.md). Ce n'est PAS un `ContentSource` : c'est l'inverse
/// (Libraria comme fournisseur, pas consommateur).
///
/// Avertissement UX à prévoir dès l'implémentation (08_UI_UX_DESIGN_SYSTEM.md) :
/// premier lancement sur Windows → prompt pare-feu Windows Defender, à expliquer
/// sous le Switch d'activation dans Réglages.
class OpdsServer {
  Future<void> start({int port = 8080}) {
    throw UnimplementedError('OpdsServer.start() — V2, voir 02_ARCHITECTURE.md et 10_ROADMAP.md.');
  }

  Future<void> stop() {
    throw UnimplementedError('OpdsServer.stop() — V2.');
  }
}

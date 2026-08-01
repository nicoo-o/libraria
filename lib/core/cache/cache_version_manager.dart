/// Invalide les caches dépendants du contenu de la bibliothèque quand celle-ci change
/// (ex. cache des recommandations locales — PF-03, 11_BACKLOG.md) plutôt que de les
/// recalculer à chaque affichage.
class CacheVersionManager {
  int _version = 0;
  int get version => _version;
  void bump() => _version++;
}

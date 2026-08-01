/// Flag de compilation pour la « GitHub Edition » de Libraria.
///
/// Deux artefacts Android sont produits (voir ADR-014, restructuration_claude.md) :
///   * Play Store Edition — build par défaut, `EXTENDED_SOURCES=false`.
///     Le code des sources étendues est présent mais inatteignable : le registre
///     renvoie une liste vide, l'écran Paramètres n'affiche pas la section.
///   * GitHub Edition — build avec `flutter build apk --dart-define=EXTENDED_SOURCES=true`.
///     Les sources étendues sont *disponibles* mais restent **désactivées par défaut**
///     à l'exécution (voir [ExtendedSourcesSettings]).
///
/// Une constante `const bool.fromEnvironment(...)` est évaluée à la compilation :
/// avec `false`, le tree-shaker de Dart supprime effectivement le code des sources
/// étendues du binaire final. C'est ce qui distingue les deux releases sur le plan
/// juridique — pas juste un interrupteur UI.
const bool kExtendedSourcesAvailable = bool.fromEnvironment(
  'EXTENDED_SOURCES',
  defaultValue: false,
);

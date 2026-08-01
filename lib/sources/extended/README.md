# `lib/sources/extended/` — GitHub Edition uniquement

Sources activables **derrière deux verrous** (voir ADR-014 dans `docs/restructuration_claude.md`) :

1. **Compile-time** : `--dart-define=EXTENDED_SOURCES=true` doit être passé au build.
   Sans ça, `kExtendedSourcesAvailable == false` et le tree-shaker Dart supprime
   ces classes du binaire.
2. **Runtime** : `ExtendedSourcesSettings.setEnabled(id, true)` — toggle utilisateur,
   **OFF par défaut** même en GitHub Edition.

Sources concernées : Anna's Archive, Z-Library, Library Genesis, Sci-Hub.

Ne jamais utiliser ces classes directement dans du code partagé avec la Play Store
Edition. Toutes les branches conditionnelles passent par `ExtendedSourcesRegistry`
qui renvoie `[]` sur Play Store.

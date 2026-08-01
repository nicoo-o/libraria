# Contribuer à Libraria

## Avant de commencer

```bash
flutter pub get
flutter analyze
flutter test
```

Les trois doivent passer sans erreur avant toute pull request. `flutter pub get`
est aussi ce qui génère `lib/l10n/app_localizations.dart` (i18n, voir plus bas) —
si ce fichier semble manquant, c'est presque toujours qu'il faut relancer
`flutter pub get`, pas un bug.

## Ajouter une nouvelle source

Tout nouveau connecteur étend `BaseContentSource`, jamais `ContentSource`
directement — sinon le rate limiting, le circuit breaker et la validation
d'URL ne s'appliquent pas (voir `lib/sources/base_content_source.dart`).

Si la source lit un endpoint dont la racine JSON est un **tableau** (pas un
objet), utiliser `HttpClient.getList()`, pas `HttpClient.get()` — c'est
précisément le bug qui rendait la recherche Standard Ebooks muette avant
correctif (`lib/sources/standard_ebooks/standard_ebooks_source.dart`).

Deux emplacements possibles selon l'édition ciblée (ADR-014) :
- `lib/sources/<name>/` — source « V1 », embarquée dans les deux éditions
  (Play Store ET GitHub). Réservée aux catalogues au statut juridique non
  ambigu (domaine public, licences libres, prêt légal).
- `lib/sources/extended/` — source « GitHub Edition only ». Ajouter la classe
  *et* l'enregistrer dans `ExtendedSourcesRegistry.allAvailable`. Toggle OFF
  par défaut, code retiré du binaire Play Store par le tree-shaker
  (`kExtendedSourcesAvailable`, `lib/sources/extended/build_flags.dart`).

## Sources à statut variable

- **Anna's Archive**, **Z-Library**, **Library Genesis**, **Sci-Hub** : GitHub
  Edition uniquement (`lib/sources/extended/`), désactivées par défaut. Voir
  ADR-014 dans `docs/restructuration_claude.md`. Ne jamais les ajouter à
  `lib/sources/<name>/`, ce serait les livrer par erreur au Play Store.
- Tout connecteur nécessitant de contourner un DRM : hors périmètre, quelle
  que soit l'édition.

## Convention de dossiers

`lib/core/`, `lib/sources/`, `lib/download_manager/`, `lib/library/`,
`lib/readers/`, `lib/screens/`, `lib/l10n/` — voir `docs/`. Tout code reçu
d'un outil externe est renommé pour s'y conformer avant d'être intégré.

## Base de données et migrations

Toute modification de schéma nécessite **deux** changements en parallèle,
jamais un seul :
1. Une nouvelle `lib/library/migrations/migration_vN.dart` (`ALTER TABLE`,
   appliquée aux installations existantes via `onUpgrade`)
2. La mise à jour de `lib/library/migrations/schema_full.dart` (utilisée par
   `onCreate` pour les nouvelles installations)

Bumper `_dbVersion` dans `database_helper.dart` et ajouter le `case N` dans
`migrations.dart`. `test/library/migration_test.dart` vérifie que les deux
chemins (`onUpgrade` cumulé et `fullSchemaVN`) convergent vers exactement les
mêmes colonnes — un des deux oublié fait échouer ce test, c'est voulu (c'est
exactement le bug trouvé et corrigé sur la table `downloads` : `result_json`/
`expected_sha1`/`expected_md5` existaient côté `onCreate` mais jamais côté
`onUpgrade`, et inversement pour `source_connector`).

## i18n

Toute chaîne visible par l'utilisateur passe par `AppLocalizations`
(`lib/l10n/app_fr.arb` = langue source, `lib/l10n/app_en.arb` = traduction),
jamais une chaîne en dur dans un widget. Ajouter la clé dans les **deux**
fichiers `.arb` (même clé, avec `@description` dans le template français) puis
relancer `flutter pub get` pour régénérer `AppLocalizations`.

Attention au cycle de vie : `AppLocalizations.of(context)` n'est pas sûr à
appeler depuis `initState()` (dépendance InheritedWidget pas encore établie).
Si une valeur calculée tôt doit produire un message localisé plus tard, stocker
la CAUSE (un enum, une exception) plutôt que le texte traduit, et ne choisir le
texte qu'au moment de `build()` — voir `EpubReaderScreen`/`AudioPlayerScreen`
pour un exemple de ce motif.

## Couverture de test

≥ 80 % global, vérifié en CI (`very_good_coverage`). Un nouveau fichier dans
`lib/core/security/`, `lib/core/network/` ou `lib/core/integrity/` sans test
associé fait échouer la CI mécaniquement (règle volontaire — voir
`test/core/`).

## Golden tests

`test/goldens/` — après avoir ajouté ou modifié un widget visuel qui y est
couvert, régénérer la baseline avant de committer :

```bash
flutter test --update-goldens test/goldens
```

Sinon le job `golden-tests` de la CI échoue en comparant à une image obsolète.

## Avant de publier une release

- [ ] `flutter test --coverage` ≥ 80 %
- [ ] CI verte sur les 4 jobs (analyze-and-test, golden-tests, build-android-playstore,
      build-android-github ; build-windows si la release Windows est concernée)
- [ ] Le `.aab` du Play Store est **toujours** buildé sans
      `--dart-define=EXTENDED_SOURCES=true`. Ne pas se tromper de commande,
      sinon suspension de compte Play Console quasi immédiate.
- [ ] `applicationId` distinct entre éditions Play Store et GitHub — **non
      configuré à ce jour** (`android/app/build.gradle.kts` utilise encore le
      placeholder `com.example.libraria`) : à personnaliser avec votre propre
      nom de domaine avant toute publication réelle, sinon les deux éditions
      ne peuvent pas être installées côte à côte et Google rejette
      généralement les soumissions au nom de domaine `example.com`.

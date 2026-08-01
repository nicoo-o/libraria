# Libraria

Bibliothèque personnelle numérique pour livres et audiobooks. Voir `docs/` pour la référence complète — ce README ne fait que démarrer le projet.

## Ce que contient ce zip

- La structure `lib/` complète telle que définie dans `docs/restructuration_claude.md` (chapitre 02 — Architecture).
- Le code **déjà écrit et fonctionnel** pour les briques qui étaient entièrement spécifiées dans la doc : sécurité (`core/security/`), réseau (`core/network/`), intégrité (`core/integrity/`), exceptions, `DownloadManager`, `ContentSource`/`BaseContentSource`, schéma DB + migrations v1-v15.
- Des **stubs commentés** pour le reste (écrans, connecteurs concrets, repositories UI) — chaque stub référence le chapitre de la doc à lire avant de le remplir, et lève `UnimplementedError` plutôt que de faire semblant de marcher.
- `docs/` contient les 3 documents de référence tels quels (`restructuration_claude.md`, `MES_PROPOSITIONS_LIBRARIA.md`, `GUIDE_PAS_A_PAS_LIBRARIA.md`) — pas de copie-collé partiel, les fichiers complets.

Ce zip ne contient **pas** les dossiers `android/`, `ios/`, `windows/` — ils sont générés par Flutter lui-même (étape 2 ci-dessous), les regénérer à la main n'aurait aucune valeur.

## Démarrage (VS Code)

1. Dézippe ce dossier, ouvre-le dans VS Code (`code .`), installe l'extension **Flutter** si ce n'est pas déjà fait.
2. Dans un terminal, à la racine du projet :
   ```bash
   flutter create --platforms=android,windows .
   ```
   Cette commande ajoute les dossiers `android/` et `windows/` **sans toucher** à `lib/`, `pubspec.yaml` ou `test/` déjà présents (elle ne régénère que ce qui manque).
3. ```bash
   flutter pub get
   ```
4. Ouvre `lib/main.dart`, lance en `F5` (ou `flutter run -d windows` / `flutter run -d <device-android>`).

À ce stade l'app démarre, affiche l'écran Bibliothèque (vide), et la base SQLite se crée avec le schéma v1-v15 au premier lancement — mais la plupart des écrans et connecteurs sont encore des stubs (voir plus bas).

## Permissions à ajouter manuellement après `flutter create`

Une fois `android/app/src/main/AndroidManifest.xml` généré, ajoute (voir `docs/restructuration_claude.md`, chapitre 07) :

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_VISUAL_USER_SELECTED" /> <!-- 14+ -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" /> <!-- 15+ -->
```

Et dans `<application ...>` (durcissement, chapitre 03) :

```xml
android:allowBackup="false" android:extractNativeLibs="false"
```

## Par où commencer à coder (ordre recommandé)

Suit `GUIDE_PAS_A_PAS_LIBRARIA.md` dans `docs/` pour l'ordre détaillé. En résumé, dans l'ordre du chapitre 10 (Roadmap) :

1. **P0** — déjà fait dans ce squelette : `DownloadManager`/`ContentSource` consolidés, `CorruptedFileException`, PRAGMA, migrations v1-v15 sans collision, convention de dossiers.
2. **P1** — écrire les 4 connecteurs concrets (`lib/sources/*/`, stubs présents avec la signature exacte), brancher `epub_view` dans `lib/readers/epub_reader_screen.dart`, `just_audio`/`audio_service` dans `lib/readers/audio_player_screen.dart`, remplir les écrans (`lib/screens/`).
3. Composer tout dans `lib/main.dart` (déjà écrit — à étendre au fur et à mesure que les repositories/services prennent forme).

## Tests

`test/` contient les emplacements des tests critiques mentionnés au chapitre 09 (tests par propriétés sur `FilenameSanitizer`/`UrlValidator`, test de migration v1→v15, tests goldens) — à compléter en même temps que le code correspondant, pas après (sinon le seuil CI de 80 % échoue mécaniquement).

```bash
flutter test --coverage
```

## Deux éditions Android + Windows (ADR-014)

À partir du même dépôt, trois artefacts sont produits :

```bash
# Play Store Edition (Android) — 4 sources V1 uniquement
flutter build appbundle --release \
  --obfuscate --split-debug-info=build/symbols/playstore/

# GitHub Edition (Android) — V1 + sources étendues (Anna's Archive, Z-Library,
# Libgen, Sci-Hub), toutes désactivées par défaut, activables une par une
# depuis Paramètres.
flutter build apk --release \
  --dart-define=EXTENDED_SOURCES=true \
  --obfuscate --split-debug-info=build/symbols/github/

# Windows — même posture que la GitHub Edition
flutter build windows --release \
  --dart-define=EXTENDED_SOURCES=true
```

Le flag `EXTENDED_SOURCES` est évalué à la compilation : sans lui, les classes
sous `lib/sources/extended/` sont retirées du binaire par le tree-shaker Dart.
Détails et raisonnement : ADR-014 dans `docs/restructuration_claude.md` (qui
*supersede* ADR-002).

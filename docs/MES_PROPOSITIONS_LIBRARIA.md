# Propositions — 40 fonctionnalités pour Libraria

> Document séparé de `12_NOUVELLES_FONCTIONNALITES.md` (qui analyse les 30 propositions externes). Ici, mes propres idées, filtrées par mes propres règles, choisies parce qu'elles exploitent des données et des mécanismes **déjà présents** dans le projet plutôt que d'en ajouter de nouveaux. Toutes s'appuient sur la structure réelle (`sqflite`, `Provider`/`ChangeNotifier`, dossiers plats `lib/core/`, `lib/library/`, `lib/stats/`...) — voir `02_ARCHITECTURE.md`.
>
> **Mise à jour** : 30 propositions supplémentaires en partie 2, avec des règles assouplies sur deux points précis (R1 et R2) qui étaient trop strictes pour couvrir des idées légitimes — voir la note en tête de la Partie 2.

---

## Partie 1 — Les 10 premières (règles d'origine, inchangées)

## Mes règles de filtrage (R1-R5)

Différentes des 4 critères du document externe, plus strictes sur un point précis : **la donnée avant la fonctionnalité**. La bibliothèque de quelqu'un qui utilise Libraria depuis 6 mois contient déjà des sessions de lecture, des hash de fichiers, des notes, un historique de téléchargements — la plupart des idées listées ici ne font qu'exploiter ce qui existe déjà, sans rien demander de plus à l'utilisateur.

- **R1 — Zéro nouvelle dépendance non triviale.** Pas de ML, pas de cloud, pas de nouveau package si un existant (`sqflite`, `just_audio`, `flutter_tts`, `fl_chart`, `flutter_local_notifications`, `path_provider`, `file_picker`, `crypto`) suffit. Si une feature a besoin d'un package qui n'est pas déjà dans le pubspec du projet, elle n'est pas ici.
- **R2 — Construite sur des données déjà en base.** Aucune fonctionnalité ci-dessous n'oblige l'utilisateur à saisir quoi que ce soit de nouveau pour en tirer de la valeur dès le premier jour. Tout part de `library_items`, `reading_sessions`, `downloads`, `notes` ou `content_sha256`, qui existent déjà.
- **R3 — Une feature = une migration maximum.** Si une idée a besoin de 2 migrations ou d'un schéma "au cas où", elle est simplifiée ou écartée. Pas de colonnes spéculatives.
- **R4 — Testable en CI sans jugement humain.** Chaque feature doit avoir au moins un test qui ne dépend pas d'un "ça a l'air bien" — un calcul, un flag, un fichier généré, vérifiables par assertion.
- **R5 — Réversible sans perte de données.** Un `Switch` dans les paramètres doit pouvoir désactiver la feature sans supprimer ni corrompre les données déjà produites (notes, sessions, hash...).

Ce ne sont **pas** des règles de "sécurité" ou d'"architecture" (déjà couvertes par les ADR) — ce sont des règles de **coût réel pour un solo-dev qui doit aussi finir ses études**.

---

## Tableau récapitulatif

| # | Feature | Nouvelle migration ? | Nouveau package ? | Effort estimé |
|---|---|---|---|---|
| 1 | Reprendre où j'en étais (accueil) | Non | Non | 2-3 jours |
| 2 | Détection de doublons à l'import | Non | Non (réutilise `crypto`) | 3-4 jours |
| 3 | Étagère "À reprendre ou abandonner" | Non | Non | 2 jours |
| 4 | Export de citations multi-livres par tag | Non | Non | 3 jours |
| 5 | Frise de lecture par livre | Non | Non (`fl_chart` déjà prévu Partie 10) | 2 jours |
| 6 | Rappel de lecture local (notification) | Non (1 colonne `settings`) | Non (`flutter_local_notifications` déjà présent) | 2-3 jours |
| 7 | Panier "à ranger" (fichiers sans étagère) | Non | Non | 1-2 jours |
| 8 | Estimation d'espace disque avant import en masse | Non | Non | 2 jours |
| 9 | Résumé hebdomadaire local (template, pas de LLM) | Non | Non | 2-3 jours |
| 10 | Verrouillage de l'app par code PIN | 1 (`settings` seulement) | `flutter_secure_storage` | 3-4 jours |

Total estimé : **3-4 semaines** pour les 10 réunies — comparable à une seule des features rejetées du document externe (recherche sémantique, HyperRésumé).

---

## 1. Reprendre où j'en étais

**Problème réel** : `LibraryScreen` (accueil) montre toute la bibliothèque, pas ce que la personne était en train de lire hier. `library_items.last_opened_at` et `read_progress`/`last_cfi` existent déjà et ne sont utilisés qu'au moment d'ouvrir un livre, jamais pour l'accueil.

```dart
// lib/library/library_repository.dart (extension)
Future<List<LibraryItem>> getRecentlyOpened({int limit = 3}) async {
  final rows = await _db.query('library_items',
      where: 'last_opened_at IS NOT NULL AND deleted_at IS NULL',
      orderBy: 'last_opened_at DESC', limit: limit);
  return rows.map(LibraryItem.fromMap).toList();
}
```

UI : un bandeau horizontal en haut de `library_screen.dart`, avant la grille complète — 3 cartes avec barre de progression, tap = reprise directe à `last_cfi`.

**Test (R4)** : insérer 3 items avec des `last_opened_at` différents, vérifier l'ordre retourné.

---

## 2. Détection de doublons à l'import

**Problème réel** : rien n'empêche d'importer deux fois le même fichier (deux téléchargements séparés, ou import manuel après téléchargement). `content_sha256` (v10) existe déjà pour la vérification d'intégrité — il permet aussi de détecter un doublon *avant* de l'ajouter.

```dart
// lib/library/import_service.dart (extension)
Future<LibraryItem?> findDuplicateByHash(String filePath) async {
  final hash = await ChecksumVerifier.computeStreaming(File(filePath));
  final rows = await _db.query('library_items', where: 'content_sha256 = ? AND deleted_at IS NULL',
      whereArgs: [hash]);
  return rows.isEmpty ? null : LibraryItem.fromMap(rows.first);
}
```

UI : avant d'ajouter un fichier importé manuellement (`file_picker`, déjà présent), si `findDuplicateByHash` renvoie un résultat → dialogue "Déjà dans ta bibliothèque : *{titre}*, ajouté le {date}. Importer quand même ?".

**Test (R4)** : importer deux fois le même fichier binaire, vérifier que le second déclenche la détection.

---

## 3. Étagère "À reprendre ou abandonner"

**Problème réel** : une bibliothèque personnelle accumule des livres commencés puis oubliés. `read_progress` entre 5 % et 95 % + `last_opened_at` vieux de plus de 60 jours identifie ces livres sans rien demander à personne.

```dart
// lib/library/library_repository.dart (extension)
Future<List<LibraryItem>> getStalledReads({int staleDays = 60}) async {
  final threshold = DateTime.now().subtract(Duration(days: staleDays)).millisecondsSinceEpoch;
  final rows = await _db.query('library_items',
      where: 'read_progress > 0.05 AND read_progress < 0.95 AND last_opened_at < ? AND deleted_at IS NULL',
      whereArgs: [threshold]);
  return rows.map(LibraryItem.fromMap).toList();
}
```

C'est une **vue calculée**, pas une étagère stockée : aucune table, aucune migration, cohérent avec R3. Un bouton "Archiver" sur chaque carte pose `deleted_at` (corbeille à 2 paliers déjà existante, ADR-011) — aucun nouveau mécanisme de suppression.

**Test (R4)** : items avec des combinaisons progress/date variées, vérifier le filtre exact (bornes incluses/exclues).

---

## 4. Export de citations multi-livres, filtré par tag

**Problème réel** : la Partie 10 exporte les citations livre par livre. Quelqu'un qui prend des notes de lecture pour un sujet précis (ex. tag "philosophie-stoïcienne" sur plusieurs livres) doit exporter chaque livre séparément et fusionner à la main.

```dart
// lib/export/annotation_exporter.dart (extension de la Partie 10)
Future<String> exportByTag(String tagLabel) async {
  final itemIds = await _tags.getItemIdsForTag(tagLabel); // TagRepository déjà existant, Partie 9
  final buffer = StringBuffer()..writeln('# Citations — tag "$tagLabel"\n');
  for (final id in itemIds) {
    final item = await _library.getById(id);
    final notes = await _notes.getByItem(id);
    if (notes.isEmpty) continue;
    buffer.writeln('## ${item.title}');
    for (final n in notes) { buffer.writeln('> ${n.text ?? ""}\n'); }
  }
  return buffer.toString();
}
```

Réutilise `TagRepository` et `AnnotationExporter` (Partie 9 et 10) — zéro nouveau composant, juste une nouvelle méthode de croisement.

**Test (R4)** : 2 livres partageant un tag, un livre sans ce tag → vérifier qu'il est bien exclu de l'export.

---

## 5. Frise de lecture par livre

**Problème réel** : les statistiques de la Partie 10 sont globales (streak, moyenne). Pour un livre précis, `reading_sessions` contient déjà l'historique complet des sessions mais rien ne l'affiche par livre.

```dart
// lib/stats/reading_stats_service.dart (extension)
Future<List<ReadingSession>> getSessionsForItem(String itemId) async {
  final rows = await _db.query('reading_sessions', where: 'item_id = ?',
      whereArgs: [itemId], orderBy: 'started_at ASC');
  return rows.map(ReadingSession.fromMap).toList();
}
```

UI : dans `media_detail_screen.dart`, un petit graphique en barres (`fl_chart`, déjà ajouté en Partie 10) montrant les pages lues session par session — utile pour voir "j'ai lu ce livre en 3 soirées" vs "je le traîne depuis 8 mois".

**Test (R4)** : sessions insérées pour 2 livres différents, vérifier qu'aucune fuite entre les deux dans le résultat filtré.

---

## 6. Rappel de lecture local

**Problème réel** : `flutter_local_notifications` est déjà une dépendance (V1, notifications de fin de téléchargement) mais n'est jamais utilisé pour encourager à revenir lire. Zéro serveur, zéro compte — juste une notification programmée localement si aucune session n'a été loggée depuis N jours.

```dart
// lib/stats/reading_reminder_service.dart
class ReadingReminderService {
  final Database _db;
  ReadingReminderService(this._db);

  Future<bool> shouldRemind({int inactivityDays = 3}) async {
    final threshold = DateTime.now().subtract(Duration(days: inactivityDays)).millisecondsSinceEpoch;
    final rows = await _db.rawQuery(
        'SELECT COUNT(*) as c FROM reading_sessions WHERE started_at >= ?', [threshold]);
    return (rows.first['c'] as int) == 0;
  }

  Future<void> scheduleIfNeeded() async {
    if (await shouldRemind()) {
      await LocalNotificationService.show( // wrapper déjà existant pour les téléchargements, Partie 4
        title: 'Ta bibliothèque t\'attend',
        body: 'Ça fait un moment — une page ou deux ?',
      );
    }
  }
}
```

Un seul réglage stocké dans `settings` (table clé-valeur déjà existante, pas de migration) : `reminders_enabled` (0/1), respecte R5 (désactivable sans perte de données).

**Test (R4)** : base avec une session vieille de 5 jours → `shouldRemind()` doit renvoyer `true` ; avec une session d'hier → `false`.

---

## 7. Panier "à ranger"

**Problème réel** : un fichier téléchargé puis jamais assigné à une étagère se noie dans la bibliothèque générale. `shelf_items` (v5) sait déjà quels items sont dans une étagère — l'absence dans cette table identifie déjà ce qui "traîne".

```dart
// lib/library/shelf_repository.dart (extension)
Future<List<LibraryItem>> getUnshelvedItems() async {
  final rows = await _db.rawQuery('''
    SELECT li.* FROM library_items li
    LEFT JOIN shelf_items si ON li.id = si.item_id
    WHERE si.item_id IS NULL AND li.deleted_at IS NULL
    ORDER BY li.added_at DESC
  ''');
  return rows.map(LibraryItem.fromMap).toList();
}
```

Vue calculée (R3 respecté), aucune nouvelle table. Une bannière discrète sur l'accueil : "12 livres pas encore rangés" avec accès direct à la liste.

**Test (R4)** : un item dans une étagère, un item sans → vérifier que seul le second apparaît.

---

## 8. Estimation d'espace disque avant import en masse

**Problème réel** : le backlog du projet a déjà identifié (`DM-05`) la vérification d'espace disque *avant chaque téléchargement individuel*. Rien ne prévient si une file de 20 téléchargements va saturer le disque avant même de commencer.

```dart
// lib/download_manager/download_manager.dart (extension)
Future<bool> hasEnoughSpaceForQueue(List<DownloadJob> pendingJobs) async {
  final totalEstimated = pendingJobs.fold<int>(0, (sum, j) => sum + (j.estimatedSizeBytes ?? 0));
  final free = await DiskSpaceChecker.getFreeBytes(); // déjà utilisé par DM-05, un seul job
  return free > totalEstimated * 1.1; // marge de 10%
}
```

Vient compléter DM-05 (déjà dans la roadmap P1) sans créer de nouveau service — même `DiskSpaceChecker`, appelé sur la file entière plutôt qu'un seul job.

**Test (R4)** : file simulée dont la taille dépasse l'espace disponible simulé → `false` ; en dessous → `true`.

---

## 9. Résumé hebdomadaire local (texte généré par template, pas d'IA)

**Problème réel** : les 30 features externes proposaient un "HyperRésumé" par IA — rejeté (voir `12_NOUVELLES_FONCTIONNALITES.md`). Il existe une version à coût zéro et à risque zéro : un résumé d'activité, pas de contenu, généré par un simple template à partir des agrégations déjà calculées en Partie 10.

```dart
// lib/stats/weekly_digest_service.dart
class WeeklyDigestService {
  final ReadingStatsService _stats;
  final LibraryRepository _library;
  WeeklyDigestService(this._stats, this._library);

  Future<String> buildDigest() async {
    final summary = await _stats.getSummary();
    final newItems = await _library.countAddedSince(DateTime.now().subtract(const Duration(days: 7)));
    final buffer = StringBuffer()
      ..writeln('Cette semaine : ${summary.totalSessions} session(s) de lecture, '
          '${summary.totalPagesRead} page(s) au total.')
      ..writeln(summary.currentStreakDays > 1
          ? 'Série en cours : ${summary.currentStreakDays} jours.'
          : 'Pas de série active — une session aujourd\'hui pour en relancer une ?')
      ..writeln('$newItems nouveau(x) livre(s) ajouté(s) à la bibliothèque.');
    return buffer.toString();
  }
}
```

Aucun modèle, aucune génération de texte "intelligente" — des phrases fixes avec des chiffres réels injectés dedans. Zéro risque d'hallucination, contrairement à un résumé par LLM local.

**Test (R4)** : données connues en base → vérifier que les chiffres dans le texte généré correspondent exactement aux agrégations calculées séparément.

---

## 10. Verrouillage de l'app par code PIN

**Problème réel** : dans un contexte familial/partagé (ordinateur commun, tablette prêtée), rien n'empêche quelqu'un d'ouvrir Libraria et de voir toute la bibliothèque ou l'historique de lecture de quelqu'un d'autre. C'est la seule feature ici qui ajoute une dépendance — `flutter_secure_storage`, un package de stockage sécurisé standard (Keychain/Keystore), pas un package exotique.

```dart
// lib/core/security/app_lock_service.dart
class AppLockService {
  static const _storage = FlutterSecureStorage();
  static const _pinKey = 'app_lock_pin_hash';

  Future<void> setPin(String pin) async {
    final hash = sha256.convert(utf8.encode(pin)).toString(); // jamais le PIN en clair, même en local
    await _storage.write(key: _pinKey, value: hash);
  }

  Future<bool> verify(String pin) async {
    final stored = await _storage.read(key: _pinKey);
    if (stored == null) return true; // pas de verrou configuré
    return sha256.convert(utf8.encode(pin)).toString() == stored;
  }

  Future<bool> isEnabled() async => (await _storage.read(key: _pinKey)) != null;
  Future<void> disable() async => _storage.delete(key: _pinKey); // R5 : réversible, ne touche à rien d'autre
}
```

Un écran `AppLockScreen` intercepte l'app au démarrage (dans `main.dart`, avant `runApp`) si `isEnabled()` est vrai. Respecte R5 : désactiver le verrou ne supprime ni bibliothèque ni historique, juste le hash du PIN.

**Test (R4)** : `setPin('1234')` puis `verify('1234')` → `true` ; `verify('0000')` → `false`.

---

## Ce que ces 10 propositions n'incluent pas, volontairement

Pas de recommandations "intelligentes", pas de résumés générés par IA, pas de réseau social local — pas parce que ces idées sont mauvaises, mais parce qu'elles ne passent pas R1 (dépendance ML/réseau non triviale) ou R2 (elles créent de la donnée au lieu d'exploiter celle qui existe). Si l'usage réel de Libraria après la V3 montre qu'il manque justement ce genre de fonctionnalité, ce sera un choix à faire consciemment plus tard — pas un raccourci pris maintenant pour faire un catalogue de 30 idées.

---

## Partie 2 — 30 propositions supplémentaires, règles assouplies

### Ce qui change dans les règles, et pourquoi

En pratique, R1 et R2 (version stricte) écartaient des idées légitimes juste parce qu'elles demandaient un tout petit paquet bien maintenu, ou un tout petit input utilisateur ponctuel. Je garde l'esprit (pas de ML, pas de cloud, pas de collecte de données lourde) mais je précise :

- **R1'** — *Zéro dépendance ML/cloud/exotique. Un package Dart/Flutter pur, populaire, sans plugin natif complexe, est accepté s'il remplace du code que je réécrirais moins bien moi-même.* (Ex. : `csv` pour l'import/export tabulaire, `flutter_secure_storage` pour un secret local — tous deux vérifiés sur pub.dev, tous deux à usage unique et précis.)
- **R2'** — *La donnée déjà en base reste la priorité, mais un input ponctuel de l'utilisateur est acceptable si la feature reste utile sans lui (dégradation gracieuse) et ne bloque rien.* (Ex. : renommer un signet — si l'utilisateur ne le fait jamais, le signet fonctionne quand même avec un nom par défaut.)
- **R3, R4, R5 inchangées** — toujours 1-2 migrations maximum (jamais spéculatif), toujours un test automatisable, toujours réversible sans perte de données.

### Tableau récapitulatif (11-40)

| # | Feature | Catégorie | Migration | Nouveau package |
|---|---|---|---|---|
| 11 | Renommer et trier les signets | Lecture | Non (`bookmarks` existe déjà, v4) | Non |
| 12 | Minuteur "Pomodoro" de lecture | Lecture | Non | Non |
| 13 | Suivre la taille de texte système (accessibilité OS) | Lecture | Non | Non |
| 14 | Légende personnalisable par couleur de surlignage | Lecture | Non | Non |
| 15 | Recherche transverse dans les notes/citations | Lecture | Non (`notes_fts`, v12) | Non |
| 16 | Export citations en texte brut (.txt) | Lecture | Non | Non |
| 17 | Table des matières EPUB cliquable améliorée | Lecture | Non | Non |
| 18 | Badge "aussi disponible en audio" | Lecture | Non | Non |
| 19 | Vitesse de lecture audio mémorisée par livre | Lecture | Oui (1 colonne) | Non |
| 20 | Reprise automatique de la dernière piste au lancement | Lecture | Non | Non |
| 21 | Filtre "jamais ouvert" | Bibliothèque | Non | Non |
| 22 | Tri par "temps de lecture restant estimé" | Bibliothèque | Non | Non |
| 23 | Fusion manuelle de doublons existants | Bibliothèque | Non | Non |
| 24 | Export CSV de toute la bibliothèque | Bibliothèque | Non | `csv` |
| 25 | Import CSV de corrections de métadonnées en masse | Bibliothèque | Non | `csv` (déjà ajouté en #24) |
| 26 | Recherche avancée combinée (tags + étagères + type) | Bibliothèque | Non | Non |
| 27 | Badge "ajouté récemment" (< 7 jours) | Bibliothèque | Non | Non |
| 28 | Compteur de relectures | Bibliothèque | Oui (1 colonne) | Non |
| 29 | Comparaison mensuelle des statistiques | Statistiques | Non | Non |
| 30 | Record personnel ("meilleur jour de lecture") | Statistiques | Non | Non |
| 31 | Répartition de la bibliothèque par genre (camembert) | Statistiques | Non | Non (`fl_chart` déjà là) |
| 32 | Temps d'écoute audiobook cumulé | Statistiques | Non | Non |
| 33 | Historique des téléchargements consultable/filtrable | Téléchargements | Non | Non |
| 34 | Purge automatique des téléchargements échoués anciens | Téléchargements | Non | Non |
| 35 | Reprise groupée après reconnexion réseau | Téléchargements | Non | Non |
| 36 | Rapport d'espace disque utilisé par Libraria | Téléchargements | Non | Non |
| 37 | Écran "Quoi de neuf" après mise à jour (changelog local) | Maintenance | Non | Non |
| 38 | Raccourcis clavier lecteur (Windows) | UX | Non | Non |
| 39 | Mini-lecteur audio persistant (mini player) | UX | Non | Non |
| 40 | Réordonner les onglets de navigation | UX | Non (`settings`) | Non |

**28 des 30 nouvelles idées passent sans nouveau package** (seul `csv` apparaît, pour deux features complémentaires) — ce qui confirme que la version stricte des règles écartait surtout des idées à input ponctuel, pas des idées coûteuses.

---

### 11. Renommer et trier les signets

`bookmarks` (v4) existe déjà mais n'a pas d'UI de gestion dédiée — juste la création à la volée pendant la lecture. Ajouter un écran de liste avec renommage (`note` déjà présent dans la table) et réordonnancement.

```dart
// lib/library/bookmark_repository.dart (extension)
Future<void> rename(String bookmarkId, String newLabel) =>
    _db.update('bookmarks', {'note': newLabel}, where: 'id = ?', whereArgs: [bookmarkId]);
```

**Dégradation gracieuse (R2')** : un signet jamais renommé garde son libellé par défaut ("Page X") — la feature n'est jamais bloquante.

---

### 12. Minuteur "Pomodoro" de lecture

Un minuteur 25 min lecture / 5 min pause, purement local, qui ouvre/ferme automatiquement une `reading_session` (v6) au lieu de laisser l'utilisateur oublier de la clore.

```dart
// lib/stats/pomodoro_reading_timer.dart
class PomodoroReadingTimer extends ChangeNotifier {
  Timer? _timer;
  Duration remaining = const Duration(minutes: 25);
  bool isBreak = false;

  void start(String itemId, ReadingSessionRepository sessions) {
    sessions.startSession(itemId); // ouvre la session existante, rien de nouveau
    _tick(itemId, sessions);
  }
  void _tick(String itemId, ReadingSessionRepository sessions) {
    _timer = Timer.periodic(const Duration(minutes: 1), (t) {
      remaining -= const Duration(minutes: 1);
      if (remaining <= Duration.zero) {
        isBreak = !isBreak;
        remaining = isBreak ? const Duration(minutes: 5) : const Duration(minutes: 25);
        if (isBreak) sessions.endSession(itemId);
      }
      notifyListeners();
    });
  }
}
```

**Test (R4)** : après 25 minutes simulées, `isBreak` doit passer à `true` et `endSession` doit avoir été appelé exactement une fois.

---

### 13. Suivre la taille de texte système

`MediaQuery.textScaleFactorOf(context)` (ou `TextScaler` depuis Flutter récent) est déjà exposé par le framework — un simple `Switch` "Suivre les réglages d'accessibilité du système" dans les paramètres du lecteur, complémentaire au réglage manuel déjà prévu (`07_READER_AUDIOBOOK.md`, accessibilité). Zéro dépendance, zéro migration.

---

### 14. Légende personnalisable par couleur de surlignage

`notes.color` (déjà un champ TEXT) stocke une couleur hex, mais rien ne permet de dire "le jaune = citation importante, le vert = à vérifier". Une simple table de correspondance en `settings` (clé-valeur, déjà existante) : `highlight_legend` → JSON `{"#FFEB3B": "Important", "#8BC34A": "À vérifier"}`.

---

### 15. Recherche transverse dans les notes/citations

`notes_fts` existe depuis la v12 mais n'est utilisé nulle part dans l'UI actuelle (uniquement prévu pour la recherche, jamais branché à un écran). Un simple `SearchDelegate` sur `notes_fts` :

```dart
Future<List<Note>> searchNotes(String query) async {
  final rows = await _db.rawQuery(
      'SELECT notes.* FROM notes_fts JOIN notes ON notes.rowid = notes_fts.rowid '
      'WHERE notes_fts MATCH ?', [query]);
  return rows.map(Note.fromMap).toList();
}
```

---

### 16. Export citations en texte brut

Complément direct de l'export Markdown (Partie 10) — même `AnnotationExporter`, juste une seconde méthode `exportToPlainText()` sans la syntaxe Markdown, pour les personnes qui collent leurs citations dans un traitement de texte simple.

---

### 17. Table des matières EPUB cliquable améliorée

`epub_view` (ADR-007) expose déjà la table des matières du fichier — actuellement non branchée à une UI de navigation. Ajouter un tiroir latéral (`Drawer`) listant les chapitres, tap = saut direct. Zéro nouvelle dépendance, la donnée existe déjà dans le parsing EPUB.

---

### 18. Badge "aussi disponible en audio"

Si un livre existe en `book` ET `audiobook` dans `library_items` avec le même titre/auteur (correspondance simple, pas de ML), afficher un badge sur la carte du livre papier renvoyant vers la version audio.

```dart
Future<LibraryItem?> findAudioVersion(LibraryItem book) async {
  final rows = await _db.query('library_items',
      where: 'title = ? AND author = ? AND media_type = ? AND id != ? AND deleted_at IS NULL',
      whereArgs: [book.title, book.author, 'audiobook', book.id]);
  return rows.isEmpty ? null : LibraryItem.fromMap(rows.first);
}
```

---

### 19. Vitesse de lecture audio mémorisée par livre

Actuellement la vitesse de lecture audio est probablement un réglage global. Une colonne `playback_speed REAL DEFAULT 1.0` sur `library_items` (1 migration, respecte R3) permet de retenir "ce livre je l'écoute à 1.5x, cet autre à 1.0x".

```sql
-- migration_v14.dart
ALTER TABLE library_items ADD COLUMN playback_speed REAL DEFAULT 1.0;
```

---

### 20. Reprise automatique de la dernière piste au lancement

Au démarrage de l'app (composition root, `main.dart`), si un audiobook était en cours de lecture à la fermeture précédente (déjà su via `last_opened_at` + `media_type = 'audiobook'` + `read_progress < 1.0`), proposer un mini-bandeau "Reprendre {titre}" — pas de lancement automatique du son (ce serait intrusif), juste une proposition en un tap.

---

### 21. Filtre "jamais ouvert"

`added_at IS NOT NULL AND last_opened_at IS NULL` — vue calculée d'une ligne de SQL, utile pour retrouver les livres accumulés jamais commencés. Aucune table, aucune dépendance.

---

### 22. Tri par "temps de lecture restant estimé"

Utilise la vitesse moyenne de lecture (déjà calculable via `reading_sessions`, Partie 10) combinée à `read_progress` et à une estimation de longueur du livre (nombre de pages si disponible, sinon `duration_s` pour l'audio) :

```dart
double estimateRemainingMinutes(LibraryItem item, double avgPagesPerMinute) {
  final remainingProgress = 1.0 - item.readProgress;
  // Approximation volontairement simple — pas de prétention de précision à la seconde près.
  return (remainingProgress * 300) / avgPagesPerMinute; // 300 pages = hypothèse moyenne livre
}
```

---

### 23. Fusion manuelle de doublons existants

Complète la détection de doublons à l'import (proposition #2, Partie 1) pour les doublons qui existent déjà dans la bibliothèque (avant que cette détection n'existe). Un écran "Doublons potentiels" qui groupe par `content_sha256` identique, avec un bouton "Fusionner" qui transfère `notes`/`bookmarks`/`shelf_items` de l'entrée B vers l'entrée A avant de supprimer B (dans une transaction SQLite unique — pas de suppression partielle en cas d'erreur).

```dart
Future<void> mergeDuplicates(String keepId, String removeId) async {
  await _db.transaction((txn) async {
    await txn.update('notes', {'item_id': keepId}, where: 'item_id = ?', whereArgs: [removeId]);
    await txn.update('bookmarks', {'item_id': keepId}, where: 'item_id = ?', whereArgs: [removeId]);
    await txn.update('shelf_items', {'item_id': keepId}, where: 'item_id = ?', whereArgs: [removeId]);
    await txn.delete('library_items', where: 'id = ?', whereArgs: [removeId]);
  });
}
```

---

### 24-25. Export/Import CSV (métadonnées de bibliothèque)

Le seul ajout de dépendance de cette Partie 2, justifié par R1' : réécrire un parseur CSV maison serait moins fiable que le package `csv` (1,71M téléchargements, maintenu, licence MIT, zéro plugin natif — vérifié sur pub.dev).

```dart
// lib/library/csv_export_service.dart
class CsvExportService {
  Future<String> exportLibraryCsv(List<LibraryItem> items) {
    final rows = [
      ['id', 'title', 'author', 'media_type', 'genre', 'year', 'rating'],
      ...items.map((i) => [i.id, i.title, i.author ?? '', i.mediaType.name, i.genre ?? '', i.year ?? '', i.rating ?? '']),
    ];
    return Future.value(const ListToCsvConverter().convert(rows));
  }
}
```

L'import (#25) réutilise le même parseur en sens inverse, avec une validation stricte : seules les colonnes `genre`, `year`, `rating`, `author` sont modifiables en masse (jamais `id`, jamais `local_path` — pas question de réassigner un fichier via CSV).

---

### 26. Recherche avancée combinée

Écran de recherche unique combinant `WHERE media_type = ? AND id IN (SELECT item_id FROM item_tags WHERE tag_id = ?) AND id IN (SELECT item_id FROM shelf_items WHERE shelf_id = ?)` — assemblage de clauses déjà existantes (tags v11, étagères v5), pas de nouveau mécanisme de recherche.

---

### 27. Badge "ajouté récemment"

`added_at > (now - 7 jours)` — un `Container` avec un badge coloré sur la carte, calculé à l'affichage, zéro stockage.

---

### 28. Compteur de relectures

Une colonne `read_count INTEGER DEFAULT 0` sur `library_items` (1 migration), incrémentée quand `read_progress` repasse de ~1.0 à une valeur basse après une relecture volontaire (détectée par l'utilisateur via un bouton "Relire depuis le début", pas par heuristique automatique — plus fiable et plus simple).

```sql
-- migration_v15.dart (ou fusionnée avec v14 si les deux sortent ensemble — max 2 migrations, R3)
ALTER TABLE library_items ADD COLUMN read_count INTEGER DEFAULT 0;
```

---

### 29. Comparaison mensuelle des statistiques

Extension de `ReadingStatsService` (Partie 10) : agrégation `reading_sessions` groupée par mois, comparaison mois courant vs mois précédent (pages lues, nombre de sessions).

---

### 30. Record personnel

`SELECT date(started_at/1000,'unixepoch') as d, SUM(pages_read) as p FROM reading_sessions GROUP BY d ORDER BY p DESC LIMIT 1` — une requête, affichée comme carte "record" dans `StatsScreen` (Partie 10).

---

### 31. Répartition par genre (camembert)

`SELECT genre, COUNT(*) FROM library_items WHERE deleted_at IS NULL GROUP BY genre` → `PieChart` (`fl_chart`, déjà ajouté en Partie 10, aucune dépendance supplémentaire).

---

### 32. Temps d'écoute audiobook cumulé

`duration_s * read_progress` sommé sur tous les items `media_type = 'audiobook'` — complète les statistiques de pages (qui ne concernent que l'écrit) avec une mesure équivalente pour l'audio.

---

### 33. Historique des téléchargements consultable

La table `downloads` (existante depuis la V1) contient déjà tout l'historique mais `queue_screen.dart` n'affiche probablement que la file active. Un onglet "Historique" avec filtre par `status` (`completed`/`failed`/`cancelled`) et par date — zéro nouvelle donnée, juste une UI de consultation.

---

### 34. Purge automatique des téléchargements échoués anciens

`DELETE FROM downloads WHERE status = 'failed' AND created_at < ?` (seuil configurable, ex. 30 jours) — nettoie la table sans toucher à la corbeille de la bibliothèque (ADR-011 concerne les *livres*, pas les entrées de file de téléchargement, donc pas de conflit).

---

### 35. Reprise groupée après reconnexion réseau

`ConnectivityService` est déjà prévu dans la structure des modules (`lib/core/connectivity/`). Un simple listener qui appelle `downloadManager.resumeAll()` quand la connectivité repasse de "hors ligne" à "en ligne" — zéro nouveau composant, juste un branchement entre deux services qui existent déjà séparément.

---

### 36. Rapport d'espace disque utilisé par Libraria

`SELECT SUM(size_bytes)` sur les fichiers locaux référencés (à ajouter comme champ calculé, pas stocké, via `File(path).lengthSync()` en tâche de fond) — affiché dans l'écran de diagnostic existant (Partie 9.4), à côté des logs.

---

### 37. Écran "Quoi de neuf" après mise à jour

`PackageInfo.fromPlatform()` est déjà utilisé (diagnostic, Partie 9). Comparer la version stockée en `settings` à la version actuelle au démarrage ; si différente, afficher un écran statique de changelog (texte codé en dur par version, pas de fetch réseau) puis mettre à jour la valeur stockée.

---

### 38. Raccourcis clavier lecteur (Windows)

`RawKeyboardListener` (ou `Focus`/`KeyboardListener` selon la version de Flutter) déjà disponible nativement — flèches gauche/droite pour changer de page, `F11` pour le plein écran, `Espace` pour lecture/pause en audio. Zéro package, pertinent puisque Windows est une cible officielle du projet (ADR-001).

---

### 39. Mini-lecteur audio persistant

Une barre fine en bas de l'écran (au-dessus de la navigation) visible dès qu'un audiobook est en cours, peu importe l'écran affiché — `just_audio` expose déjà `player.playerStateStream` en continu, il suffit d'un `Consumer` global dans le `Scaffold` racine plutôt que localisé à `AudioPlayerScreen`.

---

### 40. Réordonner les onglets de navigation

Un tableau `[String]` d'ordre stocké en `settings` (clé `nav_order`), lu au démarrage pour construire la liste de `NavigationDestination` (Partie 2 du guide) dans l'ordre choisi. Réversible par un bouton "Réinitialiser l'ordre" (R5).

---

## Bilan des 40 propositions

| | Partie 1 (10) | Partie 2 (30) | Total |
|---|---|---|---|
| Nouvelles migrations | 0 | 2 (`playback_speed`, `read_count`) | 2 |
| Nouveaux packages | 1 (`flutter_secure_storage`) | 1 (`csv`) | 2 |
| Features à zéro coût d'infra (vue calculée / requête sur données existantes) | 7/10 | 24/30 | 31/40 |

Le rapport ne change pas fondamentalement entre les deux parties : même en assouplissant R1/R2, l'écrasante majorité des idées qui tiennent debout dans ce projet sont des **requêtes différentes sur des données qui existent déjà**, pas de nouveaux systèmes. C'est cohérent avec le diagnostic de la section 12 de `restructuration_claude.md` : le risque du document externe n'était pas "trop d'idées", c'était "des idées qui inventent une architecture parallèle au lieu de lire celle qui existe".

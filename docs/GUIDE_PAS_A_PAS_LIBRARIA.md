# Guide pas-à-pas — Coder Libraria (Flutter, Android + Windows)

> **Refonte complète.** Ce guide remplace toutes les versions précédentes et leurs addendums. Chaque étape contient le code **final** — pas une version à corriger trois étapes plus loin. Pour le « pourquoi » de chaque décision, voir `/docs` (notamment `01_DECISIONS.md`). Ce document répond au « comment, dans quel ordre ».
>
> **Teste après chaque partie avant de passer à la suivante.** Chaque partie se termine par une checklist de validation.

## Table des matières

- Partie 0 — Mise en place
- Partie 1 — Fondations (sécurité, erreurs, réseau)
- Partie 2 — Base de données
- Partie 3 — Sources de contenu
- Partie 4 — Gestionnaire de téléchargements
- Partie 5 — Bibliothèque et recherche (UI)
- Partie 6 — Lecteurs EPUB et audiobook
- Partie 7 — Démarrage, connectivité, composition finale
- Partie 8 — Tests et CI/CD
- Partie 9 — Fonctionnalités V2 (étagères, tags, notes, OPDS sortant, sauvegarde, diagnostic)
- Partie 10 — Perspectives V3+ (pointeur vers la roadmap, pas de code détaillé)

---

# Partie 0 — Mise en place

## 0.1 Outils

```bash
# Flutter SDK : https://docs.flutter.dev/get-started/install/windows
flutter doctor
flutter config --enable-windows-desktop
# Android Studio : SDK + émulateur seulement
# VS Code : extensions Flutter + Dart officielles
git --version
```

`flutter doctor` doit afficher ✓ pour Flutter, Android toolchain, Windows.

**Validation avant de continuer** : crée un mini-projet séparé, charge un EPUB avec `epub_view`. Si ça marche en 2h → continue. Sinon, voir ADR-001 (`/docs/01_DECISIONS.md`) pour la réévaluation Qt6.

## 0.2 Créer le repo et le projet

```bash
git clone https://github.com/<ton-user>/libraria.git
cd libraria
flutter create --platforms=android,windows --org com.tonnom .
flutter run -d windows   # doit afficher l'app Counter par défaut
git add . && git commit -m "chore: init flutter project" && git push

mkdir -p .github/workflows .github/ISSUE_TEMPLATE
```

## 0.3 Dépendances — toutes, dès le départ

Pas de dépendance ajoutée « en cours de route » dans ce guide — tout ce dont V1+V2 a besoin est listé ici une fois, pour éviter l'éparpillement qui a causé la fragmentation de l'ancien guide.

```yaml
# pubspec.yaml
name: libraria
environment:
  sdk: '>=3.3.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter

  # Réseau
  dio: ^5.4.0

  # État
  provider: ^6.1.1

  # UI / polices
  google_fonts: ^6.1.0
  qr_flutter: ^4.1.0

  # Stockage
  path_provider: ^2.1.2
  sqflite: ^2.3.0
  path: ^1.8.3
  shared_preferences: ^2.2.2
  flutter_secure_storage: ^9.0.0

  # Sécurité / intégrité
  crypto: ^3.0.3
  archive: ^3.4.10

  # Utilitaires
  uuid: ^4.3.3
  logger: ^2.0.0
  collection: ^1.18.0
  intl: ^0.19.0

  # Lecteurs
  epub_view: ^4.2.0
  just_audio: ^0.9.36
  audio_service: ^0.18.12

  # Permissions et fallback
  permission_handler: ^11.3.0
  url_launcher: ^6.2.5

  # Images
  image: ^4.2.0
  cached_network_image: ^3.3.1

  # Fichiers
  file_picker: ^8.0.0
  share_plus: ^9.0.0
  package_info_plus: ^8.0.0

  # OPDS sortant (V2)
  shelf: ^1.4.1
  shelf_router: ^1.1.4
  network_info_plus: ^5.0.3

  # Tâches périodiques (V2 — vérification fichiers manquants)
  workmanager: ^0.5.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.0
  flutter_lints: ^3.0.0
  golden_toolkit: ^0.15.0
  glados: ^1.1.2

flutter:
  generate: true
```

```yaml
# l10n.yaml (racine)
arb-dir: lib/l10n
template-arb-file: app_fr.arb
output-localization-file: app_localizations.dart
```

```bash
flutter pub get
```

## 0.4 Structure de dossiers — convention unique

```bash
mkdir -p lib/core/{models,http,logging,errors,security,network,integrity,cache,diagnostics,connectivity,metadata,sync}
mkdir -p lib/sources/{gutenberg,internet_archive,librivox,standard_ebooks,opds}
mkdir -p lib/download_manager
mkdir -p lib/library/migrations
mkdir -p lib/readers
mkdir -p lib/server lib/export lib/stats lib/recommendations
mkdir -p lib/screens lib/widgets lib/theme lib/l10n
mkdir -p test/core/{security,network,integrity} test/sources test/download_manager test/library test/goldens
mkdir -p installer
```

**Toute contribution future (la tienne ou un outil externe) respecte cette arborescence** — c'est la convention décrite dans `/docs/README.md`, et son non-respect est ce qui a causé l'essentiel des problèmes trouvés dans l'audit précédent.

## 0.5 Permissions — toutes les versions Android dès le départ

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

<!-- Android 13+ (API 33+) -->
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />

<!-- Android 14 (API 34) : sélection partielle de photos -->
<uses-permission android:name="android.permission.READ_MEDIA_VISUAL_USER_SELECTED" />

<!-- Android 15 (API 35) : types de service de premier plan obligatoires -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />

<!-- Fallback Android < 13 -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="29" />

<!-- Service de premier plan : lecteur audio -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />

<application
    android:allowBackup="false"
    android:extractNativeLibs="false"
    ...>
    <!-- Service de téléchargement en arrière-plan (V2, flutter_downloader ou équivalent) -->
    <service
        android:name=".DownloadForegroundService"
        android:foregroundServiceType="dataSync"
        android:exported="false" />
</application>
```

```dart
// lib/core/permissions/permission_service.dart
import 'package:permission_handler/permission_handler.dart';
import '../logging/app_logger.dart';

class PermissionService {
  static Future<bool> requestStoragePermissions() async {
    final imagesStatus = await Permission.photos.request();
    if (imagesStatus.isLimited) {
      // Android 14+ : accès partiel accordé — suffisant, on ne gère que les couvertures
      // qu'on télécharge nous-mêmes, pas besoin d'un accès complet à la galerie.
      AppLogger.info('Accès image partiel accordé (Android 14+)', module: 'PERMISSIONS');
    }
    final audioStatus = await Permission.audio.request();
    return audioStatus.isGranted || imagesStatus.isGranted || imagesStatus.isLimited;
  }

  static Future<bool> requestNotificationPermission() async =>
      (await Permission.notification.request()).isGranted;
}
```

### ✅ Checklist Partie 0
- [ ] `flutter doctor` propre
- [ ] Projet créé, tourne sur Windows et un émulateur Android
- [ ] Toutes les dépendances installées sans conflit de version
- [ ] Arborescence créée

---

# Partie 1 — Fondations

## 1.1 Design system

```dart
// lib/theme/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  static const accent = Color(0xFFD71921);            // rouge dot-matrix
  static const accentTextOnDark = Color(0xFFFF4D4D);  // texte/erreur sur fond sombre uniquement —
                                                        // #D71921 ne passe pas le contraste AA (≈3,8:1)
                                                        // pour du texte normal sur #0A0A0A (voir docs/08)
  static const lightBg = Color(0xFFFAFAFA);
  static const lightText = Color(0xFF0A0A0A);
  static const darkBg = Color(0xFF0A0A0A);
  static const darkText = Color(0xFFFAFAFA);
  static const offline = Color(0xFFFF9800);
  static const error = Color(0xFFD32F2F);
  static const success = Color(0xFF388E3C);
  static const double spacing = 8.0;
}
```

```dart
// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get light => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.lightBg,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.accent, brightness: Brightness.light),
        textTheme: _textTheme(AppColors.lightText),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.lightBg, foregroundColor: AppColors.lightText, elevation: 0,
          titleTextStyle: GoogleFonts.silkscreen(color: AppColors.lightText, fontSize: 18),
        ),
      );

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.darkBg,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.accent, brightness: Brightness.dark),
        textTheme: _textTheme(AppColors.darkText),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.darkBg, foregroundColor: AppColors.darkText, elevation: 0,
          titleTextStyle: GoogleFonts.silkscreen(color: AppColors.darkText, fontSize: 18),
        ),
      );

  static TextTheme _textTheme(Color color) => TextTheme(
        titleLarge: GoogleFonts.silkscreen(color: color, fontSize: 18),
        titleMedium: GoogleFonts.silkscreen(color: color, fontSize: 14),
        bodyMedium: GoogleFonts.jetBrainsMono(color: color, fontSize: 14),
        bodySmall: GoogleFonts.jetBrainsMono(color: color, fontSize: 12),
      );
}
```

```dart
// lib/theme/reader_themes.dart
class ReaderTheme {
  final Color background; final Color textColor; final String name;
  const ReaderTheme({required this.background, required this.textColor, required this.name});

  static const light = ReaderTheme(background: Color(0xFFFFFFFF), textColor: Color(0xFF0A0A0A), name: 'Clair');
  static const dark  = ReaderTheme(background: Color(0xFF0A0A0A), textColor: Color(0xFFE0E0E0), name: 'Sombre');
  static const sepia = ReaderTheme(background: Color(0xFFF4ECD8), textColor: Color(0xFF3B2A1A), name: 'Liseuse');
  static const all = [light, dark, sepia]; // AMOLED/Nord/Gruvbox/Catppuccin en V3
}
```

⚠️ Ne jamais utiliser NType82 de Nothing (police propriétaire) — Silkscreen et JetBrains Mono (Google Fonts, libres) seulement.

## 1.2 Logging — structuré, sanitizé, avec rotation dès le départ

```dart
// lib/core/logging/log_sanitizer.dart
class LogSanitizer {
  static final _patterns = [
    RegExp(r'(api[_-]?key|token|password|secret|passphrase)["\s]*[:=]["\s]*[^&\s"]+', caseSensitive: false),
    RegExp(r'Bearer\s+[A-Za-z0-9._-]+'),
    RegExp(r'Basic\s+[A-Za-z0-9+/=]+'),
    RegExp(r'https?://[^:/]+:[^@/]+@'),
  ];
  static String sanitize(String s) {
    var out = s;
    for (final p in _patterns) { out = out.replaceAll(p, '[REDACTED]'); }
    return out;
  }
}
```

```dart
// lib/core/logging/log_rotator.dart
import 'dart:io';
import 'package:path/path.dart';

class LogRotator {
  static const maxBytes = 5 * 1024 * 1024; // 5 Mo

  static Future<void> rotateIfNeeded(String logPath) async {
    final f = File(logPath);
    if (!await f.exists() || await f.length() <= maxBytes) return;
    final dir = dirname(logPath);
    final old = File(join(dir, 'app.log.1'));
    if (await old.exists()) await old.delete();
    await f.rename(join(dir, 'app.log.1'));
    await File(logPath).create();
  }
}
```

```dart
// lib/core/logging/app_logger.dart
import 'package:logger/logger.dart';
import 'log_sanitizer.dart';

class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(methodCount: 2, errorMethodCount: 8, lineLength: 120, colors: true, printEmojis: true),
  );

  // La sanitization s'applique ICI, à l'écriture — pas seulement à l'export du rapport
  // de diagnostic (Partie 9) — sinon le fichier de log brut sur disque contient déjà
  // d'éventuelles clés API ou passphrases en clair.
  static void debug(String msg, {String? module}) => _logger.d('[${module ?? "?"}] ${LogSanitizer.sanitize(msg)}');
  static void info(String msg, {String? module}) => _logger.i('[${module ?? "?"}] ${LogSanitizer.sanitize(msg)}');
  static void warn(String msg, {String? module, Object? error}) =>
      _logger.w('[${module ?? "?"}] ${LogSanitizer.sanitize(msg)}', error: error);
  static void error(String msg, {String? module, Object? error, StackTrace? stackTrace}) =>
      _logger.e('[${module ?? "?"}] ${LogSanitizer.sanitize(msg)}', error: error, stackTrace: stackTrace);

  /// Utilisé par le rapport de diagnostic (Partie 9) — lit uniquement le fichier actif.
  static Future<String> readRecentLogs({int maxLines = 2000}) async {
    // Implémentation : lire le fichier de log actif (chemin via path_provider),
    // retourner les maxLines dernières lignes. Le contenu est déjà sanitizé à l'écriture.
    return '';
  }
}
```

## 1.3 Modèles de base — avec tous les champs dès le départ

```dart
// lib/core/models/media_type.dart
enum MediaType { book, audiobook, movie, series, anime, music }

extension MediaTypeExtension on MediaType {
  String get displayName => switch (this) {
        MediaType.book => 'Livre', MediaType.audiobook => 'Audiobook', MediaType.movie => 'Film',
        MediaType.series => 'Série', MediaType.anime => 'Anime', MediaType.music => 'Musique',
      };
}
```

```dart
// lib/core/models/search_result.dart
import 'media_type.dart';

class SearchResult {
  final String id; final String title; final String? author;
  final MediaType mediaType; final String sourceName; final String downloadUrl;
  final bool isDirectDownload; final String? coverUrl; final String? description;

  const SearchResult({
    required this.id, required this.title, this.author, required this.mediaType,
    required this.sourceName, required this.downloadUrl, required this.isDirectDownload,
    this.coverUrl, this.description,
  });

  Map<String, dynamic> toJson() => {
        'id': id, 'title': title, 'author': author, 'mediaType': mediaType.name,
        'sourceName': sourceName, 'downloadUrl': downloadUrl, 'isDirectDownload': isDirectDownload,
        'coverUrl': coverUrl, 'description': description,
      };

  factory SearchResult.fromJson(Map<String, dynamic> j) => SearchResult(
        id: j['id'], title: j['title'], author: j['author'],
        mediaType: MediaType.values.byName(j['mediaType']), sourceName: j['sourceName'],
        downloadUrl: j['downloadUrl'], isDirectDownload: j['isDirectDownload'] ?? true,
        coverUrl: j['coverUrl'], description: j['description'],
      );
}

class SourceSearchResult {
  final List<SearchResult> items; final int? totalCount; final bool hasMore;
  const SourceSearchResult({required this.items, this.totalCount, this.hasMore = false});
}
```

```dart
// lib/core/models/download_job.dart
import 'dart:convert';
import 'search_result.dart';

enum DownloadStatus { queued, downloading, paused, completed, failed }

class DownloadJob {
  final String id; final SearchResult result;
  DownloadStatus status; double progress; int priority; // 1=haute, 2=normale (défaut), 3=basse
  int retryCount; String? localPath; String? coverPath; String? errorMessage; DateTime? completedAt;
  /// Checksums récupérés séparément (Internet Archive uniquement) — mutables car SearchResult
  /// est immutable et construit avant que ces valeurs n'existent (récupérées au téléchargement,
  /// pas à la recherche). Ne JAMAIS les mettre sur SearchResult, voir audit S-02.
  String? expectedSha1; String? expectedMd5;

  DownloadJob({
    required this.id, required this.result, this.status = DownloadStatus.queued,
    this.progress = 0.0, this.priority = 2, this.retryCount = 0,
    this.localPath, this.coverPath, this.errorMessage, this.completedAt, this.expectedSha1, this.expectedMd5,
  });

  /// [Correctif audit A-01] La version précédente faisait `result: map['result']` —
  /// la table `downloads` n'a jamais eu de colonne `result`, ce champ était toujours
  /// `null` alors que `result` est `required`. La reprise après crash plantait dès
  /// qu'une ligne existait réellement en base (masqué par le bug C-03 qui empêchait
  /// toute ligne d'exister). Le SearchResult complet est maintenant sérialisé en JSON
  /// dans la colonne `result_json` (voir schéma DB, Partie 2.1) et désérialisé ici.
  factory DownloadJob.fromMap(Map<String, dynamic> map) => DownloadJob(
        id: map['id'], result: SearchResult.fromJson(jsonDecode(map['result_json'] as String)),
        status: DownloadStatus.values.byName(map['status']),
        progress: (map['progress'] as num?)?.toDouble() ?? 0.0, priority: map['priority'] ?? 2,
        retryCount: map['retry_count'] ?? 0, localPath: map['save_path'],
        expectedSha1: map['expected_sha1'], expectedMd5: map['expected_md5'],
      );
}
```

```dart
// lib/core/models/library_item.dart
import 'media_type.dart';

class LibraryItem {
  final String id; final String title; final String? author; final MediaType mediaType;
  final String? localPath; final String? coverPath; final String? sourceName;
  final DateTime addedAt; final DateTime? lastOpenedAt;
  final double readProgress;     // barre de progression (%)
  final String? lastCfi;         // position EXACTE de reprise (EPUB CFI) — read_progress seul ne suffit pas
  final bool isFavorite; final String? notes;
  final bool isMissing;          // fichier local introuvable (vérification périodique, Partie 9)
  final DateTime? deletedAt;     // corbeille soft (30 jours), null = actif
  final String? contentSha256;   // vérifie qu'un fichier "relié" correspond bien à l'original

  const LibraryItem({
    required this.id, required this.title, this.author, required this.mediaType,
    this.localPath, this.coverPath, this.sourceName, required this.addedAt,
    this.lastOpenedAt, this.readProgress = 0.0, this.lastCfi, this.isFavorite = false,
    this.notes, this.isMissing = false, this.deletedAt, this.contentSha256,
  });

  LibraryItem copyWith({double? readProgress, String? lastCfi, bool? isFavorite, DateTime? lastOpenedAt}) =>
      LibraryItem(
        id: id, title: title, author: author, mediaType: mediaType, localPath: localPath,
        coverPath: coverPath, sourceName: sourceName, addedAt: addedAt,
        lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt, readProgress: readProgress ?? this.readProgress,
        lastCfi: lastCfi ?? this.lastCfi, isFavorite: isFavorite ?? this.isFavorite,
        notes: notes, isMissing: isMissing, deletedAt: deletedAt, contentSha256: contentSha256,
      );

  /// [Correctif — revérification finale] Utilisée par LibraryExporter.exportJson() (Partie 9.3),
  /// qui appelait i.toMap() sans que cette méthode n'ait jamais existé sur le modèle —
  /// seule LibraryRepository._toMap() existait, et elle est privée au repository.
  Map<String, dynamic> toMap() => {
        'id': id, 'title': title, 'author': author, 'mediaType': mediaType.name,
        'localPath': localPath, 'coverPath': coverPath, 'sourceName': sourceName,
        'addedAt': addedAt.toIso8601String(), 'lastOpenedAt': lastOpenedAt?.toIso8601String(),
        'readProgress': readProgress, 'lastCfi': lastCfi, 'isFavorite': isFavorite,
        'isMissing': isMissing, 'contentSha256': contentSha256,
      };
}
```

## 1.4 Hiérarchie d'exceptions — complète dès le départ

```dart
// lib/core/errors/exceptions.dart
abstract class LibrariaException implements Exception {
  final String technical; final String userMessage;
  LibrariaException(this.technical, this.userMessage);
}

class NetworkException extends LibrariaException { NetworkException(super.t, super.u); }
class SourceException extends LibrariaException { SourceException(super.t, super.u); }
class DiskFullException extends LibrariaException { DiskFullException(super.t, super.u); }
class ParsingException extends LibrariaException { ParsingException(super.t, super.u); }
class CorruptedFileException extends LibrariaException { CorruptedFileException(super.t, super.u); }
```

**Toute nouvelle exception future doit être ajoutée ici, jamais utilisée ailleurs sans y être déclarée** — c'est exactement l'erreur trouvée dans l'audit (`CorruptedFileException` utilisée sans jamais avoir été définie).

## 1.5 Sécurité réseau

```dart
// lib/core/security/url_validator.dart
class UrlValidator {
  static const _allowedSchemes = {'http', 'https'};
  static const _blockedHosts = {'localhost', '127.0.0.1', '0.0.0.0', '::1'};

  static Uri validate(String url, {bool allowPrivateNetwork = false}) {
    final uri = Uri.tryParse(url);
    if (uri == null) throw NetworkException('Invalid URL', 'URL invalide');
    if (!_allowedSchemes.contains(uri.scheme)) {
      throw NetworkException('Forbidden scheme: ${uri.scheme}', 'Schéma non autorisé');
    }
    if (!allowPrivateNetwork && (_blockedHosts.contains(uri.host) || isPrivateIp(uri.host))) {
      throw NetworkException('Forbidden host: ${uri.host}', 'Hôte non autorisé pour cette source');
    }
    return uri;
  }

  static bool isPrivateIp(String host) {
    final parts = host.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((p) => p == null)) return false;
    final a = parts[0]!, b = parts[1]!;
    return a == 10 || (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 168);
  }
}

// lib/core/security/certificate_validator.dart
class CertificateValidator {
  static bool shouldAllowSelfSigned({required Uri uri, required bool userOptIn}) {
    if (!userOptIn) return false;
    if (uri.host == 'localhost' || uri.host.endsWith('.local')) return true;
    if (UrlValidator.isPrivateIp(uri.host)) return true;
    return false; // jamais pour un service Internet public
  }
}
```

## 1.6 Sécurité fichiers

```dart
// lib/core/security/filename_sanitizer.dart
import 'dart:io';
import 'package:path/path.dart' as p;

class FilenameSanitizer {
  static final _forbidden = RegExp(r'[<>:"/\\|?*\x00-\x1f]');
  static const _maxLen = 100;
  static final _reservedWindows = {
    'CON','PRN','AUX','NUL','COM1','COM2','COM3','COM4','COM5','COM6','COM7','COM8','COM9',
    'LPT1','LPT2','LPT3','LPT4','LPT5','LPT6','LPT7','LPT8','LPT9',
  };

  static String sanitize(String name) {
    var s = name.replaceAll(_forbidden, '_').replaceAll('..', '_').trim();
    if (s.isEmpty) s = 'file_${DateTime.now().millisecondsSinceEpoch}';
    final upper = s.toUpperCase().split('.').first;
    if (_reservedWindows.contains(upper)) s = '_$s';
    if (s.length > _maxLen) s = s.substring(0, _maxLen);
    return s;
  }

  static bool isWithinSandbox(String filePath, String sandboxDir) {
    final resolved = p.normalize(File(filePath).absolute.path);
    final sandbox = p.normalize(Directory(sandboxDir).absolute.path);
    return p.isWithin(sandbox, resolved) || resolved == sandbox;
  }
}

// lib/core/security/windows_path_validator.dart
class WindowsPathValidator {
  static const int legacyMax = 260;
  static const int longPathMax = 32767;

  static String? validate(String path, {bool longPathSupport = false}) {
    if (path.isEmpty) return 'path.empty';
    if (path.length > (longPathSupport ? longPathMax : legacyMax)) return 'path.too_long';
    for (final seg in path.split(RegExp(r'[\\/]+'))) {
      if (seg.isEmpty) continue;
      if (seg.endsWith(' ') || seg.endsWith('.')) return 'path.trailing_dot_or_space';
    }
    return null; // caractères interdits/noms réservés déjà gérés par FilenameSanitizer
  }
}
```

```dart
// lib/core/security/zip_bomb_guard.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:archive/archive_io.dart';
import '../errors/exceptions.dart';

class ZipBombGuard {
  static const _maxRatio = 200;
  static const _maxUncompressedBytes = 200 * 1024 * 1024;

  /// Décompression en flux + isolate dédié (compute()) — jamais readAsBytes() ni
  /// decodeBytes() sur le thread principal : un fichier de plusieurs centaines de
  /// Mo chargé entier en RAM est un risque réel d'OOM et de gel de l'UI.
  static Future<void> check(String filePath) => compute(_checkInIsolate, filePath);

  static Future<void> _checkInIsolate(String filePath) async {
    final compressed = await File(filePath).length();
    final inputStream = InputFileStream(filePath);
    final archive = ZipDecoder().decodeStream(inputStream);

    var uncompressed = 0; var mimetypeFound = false;
    for (final entry in archive) {
      uncompressed += entry.size;
      if (uncompressed > _maxUncompressedBytes) {
        throw CorruptedFileException('ZIP bomb suspected', 'Fichier EPUB corrompu ou suspect');
      }
      if (entry.name == 'mimetype') mimetypeFound = true;
    }
    if (compressed > 0 && uncompressed / compressed > _maxRatio) {
      throw CorruptedFileException('ZIP bomb ratio', 'Fichier EPUB corrompu ou suspect');
    }
    if (!mimetypeFound) throw CorruptedFileException('Not a valid EPUB', 'Fichier invalide');
  }
}
```

## 1.7 Vérification d'intégrité

```dart
// lib/core/integrity/checksum_verifier.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';

class ChecksumVerifier {
  /// Hachage en flux chunké dans un isolate dédié — jamais le fichier entier en mémoire.
  static Future<bool> verify(String filePath, {String? expectedSha1, String? expectedMd5}) {
    if (expectedSha1 == null && expectedMd5 == null) return Future.value(true);
    return compute(_verifyInIsolate, {'path': filePath, 'sha1': expectedSha1, 'md5': expectedMd5});
  }

  static Future<bool> _verifyInIsolate(Map<String, String?> args) async {
    final file = File(args['path']!);
    // [Correctif audit S-01] La vérification MD5 était un commentaire ("même principe
    // que sha1") sans aucune implémentation réelle : si seul expectedMd5 était fourni
    // (sha1 absent), la fonction retournait toujours `true` sans avoir rien vérifié.
    if (args['sha1'] != null) {
      final output = AccumulatorSink<Digest>();
      final sink = sha1.startChunkedConversion(output);
      await for (final chunk in file.openRead()) { sink.add(chunk); }
      sink.close();
      if (output.events.single.toString().toLowerCase() != args['sha1']!.toLowerCase()) return false;
    }
    if (args['md5'] != null) {
      final output = AccumulatorSink<Digest>();
      final sink = md5.startChunkedConversion(output);
      await for (final chunk in file.openRead()) { sink.add(chunk); }
      sink.close();
      if (output.events.single.toString().toLowerCase() != args['md5']!.toLowerCase()) return false;
    }
    return true;
  }
}
```

## 1.8 Rate limiting et circuit breaker

```dart
// lib/core/network/rate_limiter.dart
import 'dart:collection';

class RateLimiter {
  final int maxPerWindow; final Duration window;
  final _calls = <String, Queue<DateTime>>{};
  RateLimiter({this.maxPerWindow = 30, this.window = const Duration(seconds: 60)});

  Future<void> acquire(String sourceId) async {
    final now = DateTime.now();
    final queue = _calls.putIfAbsent(sourceId, () => Queue());
    while (queue.isNotEmpty && now.difference(queue.first) > window) { queue.removeFirst(); }
    if (queue.length >= maxPerWindow) {
      final waitMs = window.inMilliseconds - now.difference(queue.first).inMilliseconds;
      if (waitMs > 0) await Future.delayed(Duration(milliseconds: waitMs));
    }
    queue.add(DateTime.now());
  }
}
```

```dart
// lib/core/network/circuit_breaker.dart
import 'package:dio/dio.dart';
import '../errors/exceptions.dart';

enum CircuitState { closed, open, halfOpen }

class CircuitBreaker {
  CircuitState state = CircuitState.closed;
  int _failures = 0; DateTime? _openedAt;
  final int failureThreshold; final Duration openDuration;
  CircuitBreaker({this.failureThreshold = 5, this.openDuration = const Duration(seconds: 60)});

  Future<T> call<T>(Future<T> Function() action) async {
    if (state == CircuitState.open) {
      if (DateTime.now().difference(_openedAt!) > openDuration) { state = CircuitState.halfOpen; }
      else { throw SourceException('Circuit open', 'Source temporairement indisponible'); }
    }
    try {
      final result = await action();
      _failures = 0; state = CircuitState.closed;
      return result;
    } on DioException catch (e) {
      if (e.response?.statusCode == 429 && e.response?.headers.value('retry-after') != null) {
        _openedAt = DateTime.now(); state = CircuitState.open;
      } else { _onFailure(); }
      rethrow;
    } catch (_) { _onFailure(); rethrow; }
  }

  void _onFailure() {
    _failures++;
    if (_failures >= failureThreshold) { state = CircuitState.open; _openedAt = DateTime.now(); }
  }
}
```

## 1.9 HttpClient — abstraction, redirections sûres, reprise

```dart
// lib/core/http/http_client.dart
import 'package:dio/dio.dart';

abstract class HttpClient {
  Future<dynamic> get(String url, {Map<String, dynamic>? queryParameters, Map<String, String>? headers,
      CancelToken? cancelToken, Duration? timeout});
  Future<dynamic> post(String url, {dynamic data, Map<String, dynamic>? queryParameters,
      Map<String, String>? headers, String? contentType});
  Future<void> downloadWithResume({required String url, required String savePath,
      required CancelToken cancelToken, void Function(int received, int total)? onProgress});
  /// [Ajouté — correctif audit A-03] Octets bruts, pour les couvertures (CoverProcessor) —
  /// pas de décodage JSON contrairement à get().
  Future<List<int>> getBytes(String url);
}
```

```dart
// lib/core/http/dio_http_client.dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'http_client.dart';
import '../security/url_validator.dart';
import '../errors/exceptions.dart';

class DioHttpClient implements HttpClient {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 60),
    followRedirects: false, // géré manuellement — voir getWithSafeRedirects()
  ))..httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => HttpClient()
        ..maxConnectionsPerHost = 6
        ..idleTimeout = const Duration(seconds: 15));

  @override
  Future<dynamic> get(String url, {Map<String, dynamic>? queryParameters, Map<String, String>? headers,
      CancelToken? cancelToken, Duration? timeout}) async {
    // [Correctif audit C-01] queryParameters DOIT être transmis — sans lui, 3 des 4
    // connecteurs V1 (Gutenberg, Internet Archive, LibriVox) envoient leur terme de
    // recherche dans le vide et reçoivent la liste complète non filtrée en retour.
    final response = await getWithSafeRedirects(url, queryParameters: queryParameters, headers: headers);
    return response.data;
  }

  /// Revalide l'URL à CHAQUE hop de redirection — sans ça, un serveur compromis peut
  /// répondre à une requête légitime par un 302 vers une IP privée (SSRF), et la
  /// validation initiale de UrlValidator ne couvrirait jamais ce second hop.
  Future<Response> getWithSafeRedirects(String url,
      {Map<String, dynamic>? queryParameters, Map<String, String>? headers, int maxHops = 3}) async {
    var currentUrl = url;
    for (var hop = 0; hop <= maxHops; hop++) {
      UrlValidator.validate(currentUrl);
      final response = await _dio.get(currentUrl,
          // queryParameters uniquement sur la requête initiale — un hop de redirection
          // a déjà sa propre query string complète dans son URL cible.
          queryParameters: hop == 0 ? queryParameters : null,
          options: Options(headers: headers, followRedirects: false, validateStatus: (s) => s != null && s < 400));
      final loc = response.headers.value('location');
      if ({301, 302, 307}.contains(response.statusCode) && loc != null) { currentUrl = loc; continue; }
      return response;
    }
    throw NetworkException('Too many redirects', 'Trop de redirections');
  }

  @override
  Future<dynamic> post(String url, {dynamic data, Map<String, dynamic>? queryParameters,
      Map<String, String>? headers, String? contentType}) async {
    final response = await _dio.post(url, data: data, queryParameters: queryParameters,
        options: Options(headers: headers, contentType: contentType));
    return response.data;
  }

  @override
  Future<List<int>> getBytes(String url) async {
    UrlValidator.validate(url);
    final response = await _dio.get<List<int>>(url, options: Options(responseType: ResponseType.bytes));
    return response.data ?? [];
  }

  @override
  Future<void> downloadWithResume({required String url, required String savePath,
      required CancelToken cancelToken, void Function(int received, int total)? onProgress, int maxHops = 3}) async {
    final file = File(savePath);
    int startByte = await file.exists() ? await file.length() : 0;

    final response = await _dio.get<ResponseBody>(url, cancelToken: cancelToken,
        options: Options(
          headers: startByte > 0 ? {'Range': 'bytes=$startByte-'} : null,
          responseType: ResponseType.stream,
          followRedirects: false,
        ));

    // [Correctif audit C-05] Sans cette vérification, une redirection (fréquente sur les
    // CDN comme celui d'Internet Archive) n'était ni suivie ni rejetée : le corps de la
    // réponse de redirection (HTML, quelques octets) était écrit sur disque comme si
    // c'était le fichier, puis le job marqué "completed" — un échec silencieux pire
    // qu'un crash, puisqu'il a l'air d'avoir réussi.
    if ({301, 302, 307, 308}.contains(response.statusCode)) {
      final location = response.headers.value('location');
      if (location == null) throw NetworkException('Redirect without location', 'Erreur réseau');
      if (maxHops <= 0) throw NetworkException('Too many redirects', 'Trop de redirections');
      UrlValidator.validate(location); // revalider AVANT de suivre, même logique que getWithSafeRedirects
      return downloadWithResume(url: location, savePath: savePath, cancelToken: cancelToken,
          onProgress: onProgress, maxHops: maxHops - 1);
    }
    if (response.statusCode != null && response.statusCode! >= 400) {
      throw NetworkException('HTTP ${response.statusCode}', 'Téléchargement échoué');
    }

    final serverHonoredRange = response.statusCode == 206;
    if (startByte > 0 && !serverHonoredRange) { startByte = 0; await file.writeAsBytes([]); }

    final raf = await file.open(mode: startByte > 0 ? FileMode.append : FileMode.write);
    final total = int.tryParse(response.headers.value('content-length') ?? '0') ?? 0;
    int received = startByte;
    try {
      await for (final chunk in response.data!.stream) {
        await raf.writeFrom(chunk);
        received += chunk.length;
        onProgress?.call(received, startByte + total);
      }
    } finally { await raf.close(); }
  }
}
```

```dart
// test/core/http/mock_http_client.dart — implémentation de test, utilisée partout ailleurs
class MockHttpClient implements HttpClient { /* mocktail ou implémentation manuelle */ }
```

### ✅ Checklist Partie 1
- [ ] `flutter analyze` sans erreur sur tous les fichiers `core/`
- [ ] Test unitaire sur `UrlValidator.validate()` : accepte http(s) public, rejette IP privée/scheme interdit
- [ ] Test unitaire sur `FilenameSanitizer.sanitize()` : jamais de `..`, jamais de séparateur de chemin
- [ ] `LibrariaException` et ses 5 sous-classes compilent, aucune autre exception utilisée ailleurs dans le code sans être déclarée ici

---

# Partie 2 — Base de données

## 2.1 Schéma complet (V1+V2 dès le départ, pas en migrations dispersées)

Toutes les tables nécessaires à V1 et V2 sont créées d'un coup à `onCreate` — pas de migration séquentielle artificielle pour des fonctionnalités qu'on sait déjà vouloir construire. Seules les vraies évolutions futures (V3+) passeront par `onUpgrade`.

```sql
-- lib/library/migrations/migration_v1.dart — schéma complet V1+V2
CREATE TABLE IF NOT EXISTS library_items (
  id              TEXT PRIMARY KEY,
  title           TEXT NOT NULL,
  author          TEXT,
  media_type      TEXT NOT NULL,
  local_path      TEXT,
  cover_path      TEXT,
  source_name     TEXT,
  source_url      TEXT,
  added_at        INTEGER NOT NULL,
  last_opened_at  INTEGER,
  read_progress   REAL    DEFAULT 0.0,
  last_cfi        TEXT,
  is_favorite     INTEGER DEFAULT 0,
  notes           TEXT,
  year INTEGER, genre TEXT, rating REAL, duration_s INTEGER,
  description TEXT, cover_url TEXT, external_id TEXT,
  is_missing       INTEGER NOT NULL DEFAULT 0,
  last_verified_at INTEGER,
  deleted_at       INTEGER,
  content_sha256   TEXT
);
CREATE INDEX IF NOT EXISTS idx_library_items_media_type  ON library_items(media_type);
CREATE INDEX IF NOT EXISTS idx_library_items_last_opened ON library_items(last_opened_at);
CREATE INDEX IF NOT EXISTS idx_items_missing             ON library_items(is_missing);
CREATE INDEX IF NOT EXISTS idx_items_deleted             ON library_items(deleted_at);

CREATE TABLE IF NOT EXISTS downloads (
  id TEXT PRIMARY KEY, library_item_id TEXT, title TEXT NOT NULL, download_url TEXT NOT NULL,
  save_path TEXT, status TEXT NOT NULL, progress REAL DEFAULT 0.0, priority INTEGER DEFAULT 2,
  error_message TEXT, created_at INTEGER NOT NULL, completed_at INTEGER,
  retry_count INTEGER DEFAULT 0, last_retry_at INTEGER,
  result_json TEXT,      -- [Correctif audit A-01] SearchResult complet sérialisé — sans ça,
                          -- resumeAll() ne peut pas reconstruire le job après un crash
  expected_sha1 TEXT, expected_md5 TEXT, -- [Correctif audit S-02] checksums Internet Archive
  FOREIGN KEY (library_item_id) REFERENCES library_items(id)
);
CREATE INDEX IF NOT EXISTS idx_downloads_status ON downloads(status);

CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT NOT NULL);

CREATE TABLE IF NOT EXISTS bookmarks (
  id TEXT PRIMARY KEY, item_id TEXT NOT NULL, location TEXT NOT NULL,
  text TEXT, note TEXT, color INTEGER DEFAULT 0, created_at INTEGER NOT NULL,
  FOREIGN KEY (item_id) REFERENCES library_items(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_bookmarks_item ON bookmarks(item_id);

CREATE TABLE IF NOT EXISTS shelves (id TEXT PRIMARY KEY, name TEXT NOT NULL, color TEXT, position INTEGER DEFAULT 0);
CREATE TABLE IF NOT EXISTS shelf_items (
  shelf_id TEXT NOT NULL, item_id TEXT NOT NULL, position INTEGER DEFAULT 0,
  PRIMARY KEY (shelf_id, item_id),
  FOREIGN KEY (shelf_id) REFERENCES shelves(id) ON DELETE CASCADE,
  FOREIGN KEY (item_id) REFERENCES library_items(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS tags (
  id INTEGER PRIMARY KEY AUTOINCREMENT, label TEXT NOT NULL UNIQUE COLLATE NOCASE,
  color INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS item_tags (
  item_id TEXT NOT NULL REFERENCES library_items(id) ON DELETE CASCADE,
  tag_id  INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  PRIMARY KEY (item_id, tag_id)
);
CREATE INDEX IF NOT EXISTS idx_item_tags_tag ON item_tags(tag_id);

CREATE TABLE IF NOT EXISTS notes (
  id TEXT PRIMARY KEY, item_id TEXT NOT NULL, cfi TEXT NOT NULL,
  color TEXT NOT NULL DEFAULT '#FFEB3B', text TEXT, note TEXT, created_at INTEGER NOT NULL,
  FOREIGN KEY (item_id) REFERENCES library_items(id) ON DELETE CASCADE
);
CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(
  body, content='notes', content_rowid='rowid', tokenize='unicode61 remove_diacritics 2'
);
CREATE TRIGGER IF NOT EXISTS notes_ai AFTER INSERT ON notes BEGIN
  INSERT INTO notes_fts(rowid, body) VALUES (new.rowid, new.text);
END;
CREATE TRIGGER IF NOT EXISTS notes_ad AFTER DELETE ON notes BEGIN
  INSERT INTO notes_fts(notes_fts, rowid, body) VALUES('delete', old.rowid, old.text);
END;
CREATE TRIGGER IF NOT EXISTS notes_au AFTER UPDATE ON notes BEGIN
  INSERT INTO notes_fts(notes_fts, rowid, body) VALUES('delete', old.rowid, old.text);
  INSERT INTO notes_fts(rowid, body) VALUES (new.rowid, new.text);
END;

CREATE TABLE IF NOT EXISTS reading_sessions (
  id TEXT PRIMARY KEY, item_id TEXT NOT NULL, started_at INTEGER NOT NULL,
  ended_at INTEGER, pages_read INTEGER DEFAULT 0,
  FOREIGN KEY (item_id) REFERENCES library_items(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS cover_cache_index (
  filename TEXT PRIMARY KEY, size_bytes INTEGER NOT NULL, accessed_at INTEGER NOT NULL
);
```

**Pourquoi tout d'un coup plutôt qu'en 12 migrations comme avant** : la version précédente du guide créait une nouvelle migration à chaque nouvelle fonctionnalité ajoutée au fil du temps — ça a fini par produire une collision de numéro de version entre deux fonctionnalités ajoutées par des sessions différentes. Puisqu'on sait déjà, en planifiant V1+V2 ensemble, que toutes ces tables seront nécessaires, on les crée en une fois. `onUpgrade` reste disponible et correctement câblé pour les vraies évolutions futures (V3+, schéma encore inconnu aujourd'hui).

## 2.2 Connexion — PRAGMA dès le départ

```dart
// lib/library/database_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'migrations/migration_v1.dart';
import '../core/logging/app_logger.dart';

class DatabaseHelper {
  static const _dbName = 'libraria.db';
  static const _dbVersion = 1; // prochaine vraie évolution de schéma → 2, via onUpgrade
  static Database? _db;

  static Future<Database> get database async => _db ??= await _initDatabase();

  static Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        // SANS CES DEUX LIGNES : tous les ON DELETE CASCADE du schéma sont silencieusement
        // INACTIFS (comportement par défaut de SQLite), et les écritures concurrentes
        // (position audio /10s + lecture UI bibliothèque) se bloquent mutuellement.
        await db.execute('PRAGMA foreign_keys = ON;');
        await db.execute('PRAGMA journal_mode = WAL;');
      },
      onCreate: (db, version) async {
        for (final stmt in migrationV1.split(';')) {
          final s = stmt.trim();
          if (s.isNotEmpty) await db.execute(s);
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        for (var v = oldVersion + 1; v <= newVersion; v++) {
          final migration = _migrationForVersion(v);
          if (migration == null) continue;
          AppLogger.info('Migration v$v: start', module: 'DB_MIGRATION');
          try {
            for (final stmt in migration.split(';')) {
              final s = stmt.trim();
              if (s.isNotEmpty) await db.execute(s);
            }
            AppLogger.info('Migration v$v: success', module: 'DB_MIGRATION');
          } catch (e, st) {
            AppLogger.error('Migration v$v: failed', module: 'DB_MIGRATION', error: e, stackTrace: st);
            // Pas de db.transaction() imbriqué ici : onUpgrade s'exécute déjà dans une
            // transaction implicite chez sqflite — l'imbriquer lève une erreur "Cannot
            // start a transaction within a transaction". rethrow suffit : sqflite ne
            // persiste pas la nouvelle version si onUpgrade lève.
            rethrow;
          }
        }
      },
    );
  }

  /// V3+ : ajouter ici un cas par nouvelle version (ex: case 2: return migrationV2).
  static String? _migrationForVersion(int v) => null;
}
```

## 2.3 Repositories

```dart
// lib/library/library_repository.dart
class LibraryRepository {
  final Database _db;
  LibraryRepository(this._db);

  Future<void> saveItem(LibraryItem item) => _db.insert('library_items', _toMap(item),
      conflictAlgorithm: ConflictAlgorithm.replace);

  Future<List<LibraryItem>> getAllActive() => _db
      .query('library_items', where: 'deleted_at IS NULL', orderBy: 'added_at DESC')
      .then((rows) => rows.map(_fromMap).toList());

  Future<List<LibraryItem>> getRecentlyOpened({int limit = 20}) => _db
      .query('library_items', where: 'last_opened_at IS NOT NULL AND deleted_at IS NULL',
          orderBy: 'last_opened_at DESC', limit: limit)
      .then((rows) => rows.map(_fromMap).toList());

  Future<void> updatePosition(String id, {required double readProgress, String? lastCfi}) => _db.update(
      'library_items', {'read_progress': readProgress, if (lastCfi != null) 'last_cfi': lastCfi},
      where: 'id = ?', whereArgs: [id]);

  Future<List<String>> getAllIds() => _db
      .query('library_items', columns: ['id'], where: 'deleted_at IS NULL')
      .then((rows) => rows.map((r) => r['id'] as String).toList());

  /// [Ajouté — correctif audit A-04] Appelée par LocalFileVerifier (Partie 5.6),
  /// manquait à l'appel et empêchait la compilation.
  Future<void> markMissing(String id, {required bool isMissing}) => _db.update('library_items',
      {'is_missing': isMissing ? 1 : 0, 'last_verified_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?', whereArgs: [id]);

  /// [Ajouté — correctif audit A-04] Appelée par la fonction relink() (Partie 5.6),
  /// manquait à l'appel et empêchait la compilation.
  Future<void> relink(String id, {required String newPath, required String newSha}) => _db.update(
      'library_items', {'local_path': newPath, 'content_sha256': newSha, 'is_missing': 0},
      where: 'id = ?', whereArgs: [id]);

  Map<String, dynamic> _toMap(LibraryItem i) => {
        'id': i.id, 'title': i.title, 'author': i.author, 'media_type': i.mediaType.name,
        'local_path': i.localPath, 'cover_path': i.coverPath, 'source_name': i.sourceName,
        'added_at': i.addedAt.millisecondsSinceEpoch, 'last_opened_at': i.lastOpenedAt?.millisecondsSinceEpoch,
        'read_progress': i.readProgress, 'last_cfi': i.lastCfi, 'is_favorite': i.isFavorite ? 1 : 0,
        'is_missing': i.isMissing ? 1 : 0, 'content_sha256': i.contentSha256,
      };

  LibraryItem _fromMap(Map<String, dynamic> m) => LibraryItem(
        id: m['id'], title: m['title'], author: m['author'],
        mediaType: MediaType.values.byName(m['media_type']), localPath: m['local_path'],
        coverPath: m['cover_path'], sourceName: m['source_name'],
        addedAt: DateTime.fromMillisecondsSinceEpoch(m['added_at']),
        lastOpenedAt: m['last_opened_at'] != null ? DateTime.fromMillisecondsSinceEpoch(m['last_opened_at']) : null,
        readProgress: m['read_progress'] ?? 0.0, lastCfi: m['last_cfi'],
        isFavorite: m['is_favorite'] == 1, isMissing: m['is_missing'] == 1,
        contentSha256: m['content_sha256'],
      );
}
```

```dart
// lib/library/shelf_repository.dart
class ShelfRepository {
  final Database _db;
  ShelfRepository(this._db);
  Future<void> createShelf(String id, String name, {String? color}) =>
      _db.insert('shelves', {'id': id, 'name': name, 'color': color, 'position': 0});
  Future<void> addItemToShelf(String shelfId, String itemId) => _db.insert('shelf_items',
      {'shelf_id': shelfId, 'item_id': itemId, 'position': 0}, conflictAlgorithm: ConflictAlgorithm.ignore);
  Future<List<Map<String, dynamic>>> getShelves() => _db.query('shelves', orderBy: 'position ASC');

  /// [Correctif — revérification finale] reorder()/moveUp()/moveDown() étaient appelées
  /// depuis l'UI de réordonnancement des étagères (Partie 5.8) sans jamais avoir été
  /// définies ici — ne compilait pas tel quel.
  Future<void> reorder(int oldIndex, int newIndex) async {
    final shelves = await getShelves();
    final ids = shelves.map((s) => s['id'] as String).toList();
    final id = ids.removeAt(oldIndex);
    ids.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, id);
    await _applyOrder(ids);
  }

  Future<void> moveUp(String shelfId) async {
    final shelves = await getShelves();
    final ids = shelves.map((s) => s['id'] as String).toList();
    final i = ids.indexOf(shelfId);
    if (i <= 0) return;
    ids.removeAt(i);
    ids.insert(i - 1, shelfId);
    await _applyOrder(ids);
  }

  Future<void> moveDown(String shelfId) async {
    final shelves = await getShelves();
    final ids = shelves.map((s) => s['id'] as String).toList();
    final i = ids.indexOf(shelfId);
    if (i == -1 || i >= ids.length - 1) return;
    ids.removeAt(i);
    ids.insert(i + 1, shelfId);
    await _applyOrder(ids);
  }

  Future<void> _applyOrder(List<String> orderedIds) async {
    final batch = _db.batch();
    for (var i = 0; i < orderedIds.length; i++) {
      batch.update('shelves', {'position': i}, where: 'id = ?', whereArgs: [orderedIds[i]]);
    }
    await batch.commit(noResult: true);
  }
}

// lib/library/tag_repository.dart
class TagRepository {
  final Database _db;
  TagRepository(this._db);
  Future<int> upsertTag(String label, {int color = 0}) async {
    await _db.insert('tags', {'label': label, 'color': color, 'created_at': DateTime.now().millisecondsSinceEpoch},
        conflictAlgorithm: ConflictAlgorithm.ignore);
    final row = await _db.query('tags', where: 'label = ?', whereArgs: [label]);
    return row.first['id'] as int;
  }
  Future<void> attach(String itemId, int tagId) => _db.insert('item_tags',
      {'item_id': itemId, 'tag_id': tagId}, conflictAlgorithm: ConflictAlgorithm.ignore);
  Future<List<String>> autocomplete(String prefix, {int limit = 8}) => _db
      .query('tags', columns: ['label'], where: 'label LIKE ?', whereArgs: ['$prefix%'], limit: limit)
      .then((rows) => rows.map((r) => r['label'] as String).toList());
}

// lib/library/note_repository.dart
class NoteRepository {
  final Database _db;
  NoteRepository(this._db);
  Future<void> addNote(String id, String itemId, String cfi, {String? text, String? note}) => _db.insert(
      'notes', {'id': id, 'item_id': itemId, 'cfi': cfi, 'text': text, 'note': note,
        'created_at': DateTime.now().millisecondsSinceEpoch});

  Future<List<Map<String, dynamic>>> searchNotes(String query, {int limit = 50}) => _db.rawQuery('''
    SELECT n.id, n.item_id, snippet(notes_fts, 0, '<mark>', '</mark>', '…', 12) AS snippet,
           bm25(notes_fts) AS rank
    FROM notes_fts JOIN notes n ON n.rowid = notes_fts.rowid
    WHERE notes_fts MATCH ? ORDER BY rank LIMIT ?
  ''', [_escapeFts(query), limit]);

  String _escapeFts(String q) => q.split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty).map((t) => '"${t.replaceAll('"', '""')}"*').join(' ');
}
```

### ✅ Checklist Partie 2
- [ ] `PRAGMA foreign_keys` confirmé actif (`PRAGMA foreign_keys;` retourne 1 après ouverture)
- [ ] Supprimer un `library_item` de test cascade bien vers `bookmarks`/`notes`/`shelf_items`
- [ ] Test de migration : une migration qui échoue ne bumpe pas `user_version`
- [ ] Recherche FTS5 sur une note de test retourne un snippet avec `<mark>`

---

# Partie 3 — Sources de contenu

## 3.1 `ContentSource` — signature unique dès le premier connecteur

```dart
// lib/sources/content_source.dart
import '../core/models/search_result.dart';

abstract class ContentSource {
  String get id;
  String get displayName;
  Future<SourceSearchResult> search(String query, {int? page, int? limit});
}
```

```dart
// lib/sources/base_content_source.dart
import '../core/network/rate_limiter.dart';
import '../core/network/circuit_breaker.dart';
import '../core/security/url_validator.dart';
import 'content_source.dart';

/// Tout connecteur étend CETTE classe, jamais ContentSource directement — c'est ce
/// qui garantit que rate limiting, circuit breaker et validation d'URL s'appliquent
/// systématiquement, sans dépendre de la discipline de chaque nouveau contributeur.
abstract class BaseContentSource implements ContentSource {
  final RateLimiter _rateLimiter = RateLimiter(maxPerWindow: 30, window: const Duration(seconds: 60));
  final CircuitBreaker _circuitBreaker = CircuitBreaker(failureThreshold: 5, openDuration: const Duration(seconds: 60));

  CircuitState get circuitState => _circuitBreaker.state; // exposé pour l'UI (Partie 5)

  @override
  Future<SourceSearchResult> search(String query, {int? page, int? limit}) async {
    await _rateLimiter.acquire(id);
    return _circuitBreaker.call(() async {
      final results = await doSearch(query, page: page, limit: limit);
      for (final r in results.items) { UrlValidator.validate(r.downloadUrl); }
      return results;
    });
  }

  Future<SourceSearchResult> doSearch(String query, {int? page, int? limit});

  /// À utiliser pour tout appel HTTP additionnel hors search() (ex: fetchChecksums) —
  /// pour que le rate limiting couvre TOUS les appels d'une source, pas seulement search().
  Future<T> rateLimited<T>(Future<T> Function() action) async {
    await _rateLimiter.acquire(id);
    return action();
  }
}
```

## 3.2 Project Gutenberg

```dart
// lib/sources/gutenberg/gutenberg_source.dart
import '../../core/http/http_client.dart';
import '../../core/models/search_result.dart';
import '../base_content_source.dart';

class GutenbergSource extends BaseContentSource {
  final HttpClient _http;
  GutenbergSource(this._http);

  @override String get id => 'gutenberg';
  @override String get displayName => 'Project Gutenberg';

  @override
  Future<SourceSearchResult> doSearch(String query, {int? page, int? limit}) async {
    final data = await _http.get('https://gutendex.com/books',
        queryParameters: {'search': query, 'page': page ?? 1});
    final results = (data['results'] as List).map((b) => SearchResult(
          id: 'gb_${b['id']}', title: b['title'],
          author: (b['authors'] as List).isNotEmpty ? b['authors'][0]['name'] : null,
          mediaType: MediaType.book, sourceName: displayName,
          downloadUrl: (b['formats'] as Map)['application/epub+zip'] ?? '',
          isDirectDownload: true, coverUrl: (b['formats'] as Map)['image/jpeg'],
        )).where((r) => r.downloadUrl.isNotEmpty).toList();
    return SourceSearchResult(items: results, hasMore: data['next'] != null);
  }
}
```

## 3.3 Internet Archive (avec vérification de checksum)

```dart
// lib/sources/internet_archive/internet_archive_source.dart
import '../../core/http/http_client.dart';
import '../../core/models/search_result.dart';
import '../../core/logging/app_logger.dart';
import '../base_content_source.dart';

class InternetArchiveSource extends BaseContentSource {
  final HttpClient _http;
  InternetArchiveSource(this._http);

  @override String get id => 'internet_archive';
  @override String get displayName => 'Internet Archive';

  @override
  Future<SourceSearchResult> doSearch(String query, {int? page, int? limit}) async {
    final data = await _http.get('https://archive.org/advancedsearch.php', queryParameters: {
      'q': query, 'fl[]': ['identifier', 'title', 'creator'], 'rows': limit ?? 20,
      'page': page ?? 1, 'output': 'json',
    });
    final docs = (data['response']['docs'] as List);
    final items = docs.map((d) => SearchResult(
          id: 'ia_${d['identifier']}', title: d['title'] ?? '',
          author: d['creator'] is List ? d['creator'][0] : d['creator'],
          mediaType: MediaType.book, sourceName: displayName,
          downloadUrl: 'https://archive.org/download/${d['identifier']}/${d['identifier']}.epub',
          isDirectDownload: true, coverUrl: 'https://archive.org/services/img/${d['identifier']}',
        )).toList();
    return SourceSearchResult(items: items, totalCount: data['response']['numFound']);
  }

  /// Seule source V1 à fournir des hash MD5/SHA-1 par fichier — appelé au téléchargement,
  /// pas à la recherche (pour ne pas la ralentir). Passe par rateLimited(), pas un appel
  /// "hors radar" du rate limiter de cette source.
  Future<Map<String, String>?> fetchChecksums(String identifier, String filename) {
    return rateLimited(() async {
      try {
        final meta = await _http.get('https://archive.org/metadata/$identifier');
        final files = (meta['files'] as List).cast<Map>();
        final match = files.firstWhere((f) => f['name'] == filename, orElse: () => {});
        if (match.isEmpty) return null;
        return {
          if (match['sha1'] != null) 'sha1': match['sha1'] as String,
          if (match['md5'] != null) 'md5': match['md5'] as String,
        };
      } catch (e) {
        AppLogger.warn('Checksum fetch failed for $identifier', module: 'INTERNET_ARCHIVE', error: e);
        return null; // un échec ne bloque jamais le téléchargement
      }
    });
  }
}
```

## 3.4 LibriVox

```dart
// lib/sources/librivox/librivox_source.dart
import '../../core/http/http_client.dart';
import '../../core/models/search_result.dart';
import '../base_content_source.dart';

class LibrivoxSource extends BaseContentSource {
  final HttpClient _http;
  LibrivoxSource(this._http);

  @override String get id => 'librivox';
  @override String get displayName => 'LibriVox';

  @override
  Future<SourceSearchResult> doSearch(String query, {int? page, int? limit}) async {
    final data = await _http.get('https://librivox.org/api/feed/audiobooks',
        queryParameters: {'title': '^$query', 'format': 'json', 'limit': limit ?? 20,
          'offset': ((page ?? 1) - 1) * (limit ?? 20)});
    final books = (data['books'] as List? ?? []);
    final items = books.map((b) => SearchResult(
          id: 'lv_${b['id']}', title: b['title'], author: b['authors']?[0]?['display_name'],
          mediaType: MediaType.audiobook, sourceName: displayName,
          downloadUrl: b['url_zip_file'] ?? '', isDirectDownload: true,
          coverUrl: b['coverart_jpg'],
        )).where((r) => r.downloadUrl.isNotEmpty).toList();
    return SourceSearchResult(items: items);
  }
}
```

## 3.5 Standard Ebooks — fallback dual JSON → OPDS

```dart
// lib/sources/standard_ebooks/standard_ebooks_source.dart
import '../../core/http/http_client.dart';
import '../../core/models/search_result.dart';
import '../../core/logging/app_logger.dart';
import '../base_content_source.dart';

class StandardEbooksSource extends BaseContentSource {
  final HttpClient _http;
  StandardEbooksSource(this._http);

  @override String get id => 'standard_ebooks';
  @override String get displayName => 'Standard Ebooks';

  @override
  Future<SourceSearchResult> doSearch(String query, {int? page, int? limit}) async {
    try {
      return await _searchJson(query); // rapide, pas de parsing XML
    } catch (e) {
      AppLogger.warn('Standard Ebooks JSON failed, falling back to OPDS', module: id, error: e);
      try {
        return await _searchOpds(query);
      } catch (e2) {
        AppLogger.error('Standard Ebooks OPDS also failed', module: id, error: e2);
        rethrow;
      }
    }
  }

  Future<SourceSearchResult> _searchJson(String query) async {
    final data = await _http.get('https://standardebooks.org/ebooks.json');
    final List ebooks = (data is List) ? data : [];
    final q = query.toLowerCase();
    final items = ebooks.where((e) {
      final title = (e['title'] as String? ?? '').toLowerCase();
      final author = (e['author'] as String? ?? '').toLowerCase();
      return title.contains(q) || author.contains(q);
    }).take(20).map((e) {
      final slug = e['url'] as String? ?? '';
      return SearchResult(
        id: 'se_${slug.replaceAll('/', '_')}', title: e['title'] ?? '', author: e['author'],
        mediaType: MediaType.book, sourceName: displayName,
        downloadUrl: 'https://standardebooks.org${slug}downloads/epub', isDirectDownload: true,
        coverUrl: 'https://standardebooks.org${slug}downloads/cover.jpg',
      );
    }).toList();
    return SourceSearchResult(items: items);
  }

  /// Stub V1 : parsing XML non implémenté, retourne une liste vide + log explicite plutôt
  /// que de planter. À implémenter en V2 seulement si le JSON venait à disparaître (ADR-004).
  Future<SourceSearchResult> _searchOpds(String query) async {
    AppLogger.warn('Standard Ebooks: OPDS fallback parsing not implemented in V1', module: id);
    return const SourceSearchResult(items: []);
  }
}
```

### ✅ Checklist Partie 3
- [ ] Une recherche sur chacune des 4 sources retourne au moins un résultat sur une requête connue (« Pride and Prejudice » par ex.)
- [ ] Couper le réseau et chercher : le circuit breaker s'ouvre après 5 échecs, pas de crash
- [ ] `fetchChecksums()` testé avec un mock retournant `null` (cas où le réseau échoue) — le téléchargement ne doit pas être bloqué

---

# Partie 4 — Gestionnaire de téléchargements

> Cette classe a existé en 3 versions incompatibles dans les anciennes itérations du guide (concurrence non gérée, pause sans effet réel, priorité ignorée). Voici la **seule** version à coder — pas de variante à corriger plus tard.

## 4.1 `DownloadManager` — version corrigée (post-audit)

> Cette classe a existé en 3 versions incompatibles dans les anciennes itérations du guide, **puis une 4ᵉ version** (celle de la refonte initiale) contenait 5 bugs distincts trouvés à l'audit : `queryParameters` perdu en amont (Partie 1.9, déjà corrigé), fichiers LibriVox jamais extraits, aucune ligne persistée avant succès (reprise après crash inopérante), nettoyage des fichiers partiels qui ne se déclenchait jamais, checksums Internet Archive jamais réellement appelés. Tout est corrigé ci-dessous — **c'est la version définitive.**

```dart
// lib/download_manager/download_manager.dart
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:collection/collection.dart';
import 'package:uuid/uuid.dart';
import 'package:archive/archive_io.dart';
import '../core/http/http_client.dart';
import '../core/models/download_job.dart';
import '../core/models/search_result.dart';
import '../core/security/filename_sanitizer.dart';
import '../core/security/windows_path_validator.dart';
import '../core/security/zip_bomb_guard.dart';
import '../core/integrity/checksum_verifier.dart';
import '../core/security/url_validator.dart';
import '../core/errors/exceptions.dart';
import '../core/logging/app_logger.dart';
import '../library/library_repository.dart';
import '../sources/internet_archive/internet_archive_source.dart';
import 'cover_processor.dart';

class DownloadManager extends ChangeNotifier {
  final HttpClient httpClient;
  final LibraryRepository repository;
  final Database db;
  final Directory libraryDir;
  final List<DownloadJob> jobs = [];
  /// Injecté depuis la composition root (Partie 7) — optionnel, utilisé seulement pour
  /// les téléchargements dont la source est Internet Archive. Garde DownloadManager
  /// découplé des autres connecteurs (pas d'import de GutenbergSource etc. ici).
  final InternetArchiveSource? internetArchiveSource;

  int maxConcurrent = 3; // configurable 1–6, Settings
  int _activeCount = 0;
  final Map<String, CancelToken> _cancelTokens = {};

  DownloadManager({required this.httpClient, required this.repository, required this.db,
      required this.libraryDir, this.internetArchiveSource});

  Future<void> enqueue(SearchResult result, {int priority = 2}) async {
    final job = DownloadJob(id: const Uuid().v4(), result: result, priority: priority);
    final insertAt = jobs.indexWhere((j) => j.priority > job.priority);
    if (insertAt == -1) jobs.add(job); else jobs.insert(insertAt, job);
    notifyListeners();

    if (!result.isDirectDownload) {
      job.status = DownloadStatus.failed;
      job.errorMessage = 'Client de téléchargement non configuré (V2).';
      notifyListeners();
      return;
    }
    if (!await _hasDiskSpace()) {
      job.status = DownloadStatus.failed;
      job.errorMessage = 'Espace disque insuffisant';
      notifyListeners();
      return;
    }
    // [Correctif audit C-03] Persisté DÈS L'ENQUEUE, pas seulement au succès — sans
    // cette ligne, resumeAll() ne trouve jamais rien après un crash puisqu'aucune
    // ligne 'queued'/'downloading' n'a jamais existé en base.
    await _persistJobState(job);
    _tryStartNext();
  }

  Future<bool> _hasDiskSpace({int minBytes = 100 * 1024 * 1024}) async {
    // Implémentation réelle dépend du package utilisé pour interroger l'espace libre
    // (ex: disk_space ou appel plateforme dédié) — vérifier > 100 Mo avant de continuer.
    return true;
  }

  void _tryStartNext() {
    if (_activeCount >= maxConcurrent) return;
    final next = jobs.firstWhereOrNull((j) => j.status == DownloadStatus.queued);
    if (next == null) return;

    _activeCount++;
    next.status = DownloadStatus.downloading;
    notifyListeners();
    unawaited(_persistJobState(next));

    final cancelToken = CancelToken();
    _cancelTokens[next.id] = cancelToken;

    _downloadDirect(next, cancelToken).whenComplete(() {
      _activeCount--;
      _cancelTokens.remove(next.id);
      _tryStartNext();
    });
  }

  Future<void> _downloadDirect(DownloadJob job, CancelToken cancelToken) async {
    try {
      UrlValidator.validate(job.result.downloadUrl);
      final savePath = _buildSavePath(job.result);
      // [Correctif audit C-04] Assigné ICI, avant même le téléchargement — sans ça,
      // _cleanupPartialFile() ne trouvait jamais rien à supprimer sur le chemin
      // d'échec, puisque localPath restait null jusqu'au succès.
      job.localPath = savePath;

      // [Correctif audit S-02] Récupération RÉELLE des checksums Internet Archive,
      // jamais appelée dans la version précédente malgré le code existant.
      if (job.result.sourceName == 'Internet Archive' && internetArchiveSource != null) {
        final filename = savePath.split('/').last;
        final identifier = job.result.id.replaceFirst('ia_', '');
        final checksums = await internetArchiveSource!.fetchChecksums(identifier, filename);
        job.expectedSha1 = checksums?['sha1'];
        job.expectedMd5 = checksums?['md5'];
      }

      await httpClient.downloadWithResume(
        url: job.result.downloadUrl, savePath: savePath, cancelToken: cancelToken,
        onProgress: (received, total) {
          job.progress = total > 0 ? received / total : 0;
          notifyListeners();
        },
      );

      // [Correctif audit C-02] LibriVox livre un ZIP (plusieurs MP3), pas un M4B —
      // la version précédente l'enregistrait sous l'extension .m4b sans jamais
      // l'extraire, et le zip-bomb guard ne s'appliquait qu'aux "book", laissant
      // passer cette archive sans aucune vérification malgré sa nature de ZIP.
      if (job.result.sourceName == 'LibriVox') {
        await ZipBombGuard.check(savePath); // l'archive elle-même, indépendamment du media_type
        final extractDir = savePath.substring(0, savePath.length - 4); // retire ".zip"
        await Directory(extractDir).create(recursive: true);
        await extractFileToDisk(savePath, extractDir);
        await File(savePath).delete(); // l'archive d'origine n'est plus nécessaire une fois extraite
        job.localPath = extractDir; // pointe vers le DOSSIER — cohérent avec AudioPlayerScreen (Partie 6.2)
      } else {
        if (job.result.mediaType == MediaType.book) await ZipBombGuard.check(savePath);
        if (job.expectedSha1 != null || job.expectedMd5 != null) {
          final ok = await ChecksumVerifier.verify(savePath,
              expectedSha1: job.expectedSha1, expectedMd5: job.expectedMd5);
          if (!ok) throw CorruptedFileException('Checksum mismatch', 'Fichier corrompu, retéléchargement nécessaire');
        }
      }

      // [Correctif audit A-03] Compression et enregistrement de la couverture —
      // CoverProcessor existait déjà mais n'était jamais appelé ; tous les items
      // retombaient systématiquement sur CoverPlaceholder.
      if (job.result.coverUrl != null) {
        try {
          final bytes = await httpClient.getBytes(job.result.coverUrl!);
          final coverPath = '${libraryDir.path}/covers/${job.result.id}.jpg';
          await Directory('${libraryDir.path}/covers').create(recursive: true);
          await CoverProcessor.compressAndSave(bytes, coverPath);
          job.coverPath = coverPath;
        } catch (e) {
          AppLogger.warn('Cover download/compression failed for ${job.id}', module: 'DOWNLOAD', error: e);
          // Une couverture manquante n'est jamais bloquante — CoverPlaceholder prend le relais.
        }
      }

      job.status = DownloadStatus.completed;
      job.completedAt = DateTime.now();
      await _persistJobState(job);
      await repository.saveItem(_jobToLibraryItem(job));
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) { await _persistJobState(job); return; } // pause volontaire
      await _handleFailure(job, e);
    } catch (e) {
      await _handleFailure(job, e);
    } finally {
      notifyListeners();
    }
  }

  Future<void> _handleFailure(DownloadJob job, Object error) async {
    job.retryCount++;
    final retryable = _isRetryable(error);
    if (retryable && job.retryCount < 3) {
      job.status = DownloadStatus.queued; // fichier partiel conservé pour la reprise
    } else {
      job.status = DownloadStatus.failed;
      job.errorMessage = error.toString();
      await _cleanupPartialFile(job); // job.localPath est maintenant fiable (voir C-04)
    }
    await _persistJobState(job);
  }

  /// 4xx = erreur définitive (404 : le fichier n'existe plus à cette URL), inutile de
  /// retenter. Timeout/5xx = temporaire, retenter a du sens.
  bool _isRetryable(Object error) {
    if (error is DioException) {
      final code = error.response?.statusCode;
      if (code != null && code >= 400 && code < 500) return false;
    }
    return true;
  }

  Future<void> _cleanupPartialFile(DownloadJob job) async {
    if (job.localPath == null) return;
    final target = FileSystemEntity.typeSync(job.localPath!) == FileSystemEntityType.directory
        ? Directory(job.localPath!) : File(job.localPath!);
    if (await target.exists()) {
      AppLogger.info('Cleaning up partial file: job ${job.id}', module: 'DOWNLOAD');
      await target.delete(recursive: true);
    }
  }

  /// Pause RÉELLE : annule le flux Dio en cours via son CancelToken. Le fichier
  /// partiel reste sur disque, downloadWithResume() reprendra depuis sa taille réelle.
  void pauseJob(String jobId) {
    _cancelTokens[jobId]?.cancel('Paused by user');
    final job = jobs.firstWhereOrNull((j) => j.id == jobId);
    if (job == null) return;
    job.status = DownloadStatus.paused;
    notifyListeners();
    unawaited(_persistJobState(job));
  }

  void resumeJob(String jobId) {
    final job = jobs.firstWhereOrNull((j) => j.id == jobId);
    if (job == null) return;
    job.status = DownloadStatus.queued;
    notifyListeners();
    unawaited(_persistJobState(job));
    _tryStartNext();
  }

  void reorderPriority(String jobId, int newPriority) {
    final job = jobs.firstWhereOrNull((j) => j.id == jobId);
    if (job == null) return;
    job.priority = newPriority;
    jobs.sort((a, b) => a.priority.compareTo(b.priority));
    notifyListeners();
    unawaited(_persistJobState(job));
  }

  /// Reprise après un crash de l'app — voir Partie 7 pour l'appel au démarrage.
  /// Fonctionne désormais réellement : enqueue()/_tryStartNext()/pauseJob() persistent
  /// chacun leur changement d'état (correctif C-03), donc cette requête trouve des lignes.
  Future<void> resumeAll() async {
    final rows = await db.query('downloads', where: "status IN ('downloading', 'queued')");
    for (final row in rows) {
      final job = DownloadJob.fromMap(row); // désérialisation réparée, voir correctif A-01
      if (job.status == DownloadStatus.downloading) job.status = DownloadStatus.queued;
      jobs.add(job);
    }
    jobs.sort((a, b) => a.priority.compareTo(b.priority));
    notifyListeners();
    for (var i = 0; i < maxConcurrent; i++) { _tryStartNext(); }
  }

  Future<void> _persistJobState(DownloadJob job) => db.insert('downloads', {
        'id': job.id, 'title': job.result.title, 'download_url': job.result.downloadUrl,
        'result_json': jsonEncode(job.result.toJson()), // correctif A-01
        'save_path': job.localPath, 'status': job.status.name, 'progress': job.progress,
        'priority': job.priority, 'retry_count': job.retryCount,
        'expected_sha1': job.expectedSha1, 'expected_md5': job.expectedMd5,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'completed_at': job.completedAt?.millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

  LibraryItem _jobToLibraryItem(DownloadJob job) => LibraryItem(
        id: job.result.id, title: job.result.title, author: job.result.author,
        mediaType: job.result.mediaType, localPath: job.localPath, coverPath: job.coverPath,
        sourceName: job.result.sourceName, addedAt: DateTime.now(),
      );

  String _buildSavePath(SearchResult result) {
    final name = FilenameSanitizer.sanitize('${result.author ?? "Inconnu"} — ${result.title}');
    final folder = result.mediaType == MediaType.audiobook ? 'audiobooks' : 'books';
    // [Correctif audit C-02] LibriVox livre un .zip, pas un .m4b — l'extension doit
    // refléter ce qui est réellement téléchargé avant extraction.
    final ext = result.sourceName == 'LibriVox' ? 'zip'
        : (result.mediaType == MediaType.audiobook ? 'm4b' : 'epub');
    final path = '${libraryDir.path}/$folder/$name.$ext';
    assert(FilenameSanitizer.isWithinSandbox(path, libraryDir.path));
    // [Correctif audit S-03] WindowsPathValidator était défini mais jamais appelé.
    final pathError = WindowsPathValidator.validate(path);
    if (pathError != null) {
      throw DiskFullException('Invalid path: $pathError', 'Nom de fichier trop long ou invalide');
    }
    return path;
  }
}
```

## 4.2 Compression et cache des couvertures

```dart
// lib/download_manager/cover_processor.dart
import 'package:image/image.dart' as img;

class CoverProcessor {
  static Future<void> compressAndSave(List<int> bytes, String savePath) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return;
    final resized = img.copyResize(decoded, width: 400, height: 600, interpolation: img.Interpolation.linear);
    final jpg = img.encodeJpg(resized, quality: 85);
    await File(savePath).writeAsBytes(jpg);
  }
}
```

```dart
// lib/core/cache/cover_cache_manager.dart
class CoverCacheManager {
  static const _maxTotalBytes = 200 * 1024 * 1024;
  static const _maxAge = Duration(days: 30);
  final Database _db; final Directory _coverDir;
  CoverCacheManager(this._db, this._coverDir);

  Future<void> recordAccess(String filename, int sizeBytes) => _db.insert('cover_cache_index',
      {'filename': filename, 'size_bytes': sizeBytes, 'accessed_at': DateTime.now().millisecondsSinceEpoch},
      conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> evictIfNeeded() async {
    final cutoff = DateTime.now().subtract(_maxAge).millisecondsSinceEpoch;
    final stale = await _db.query('cover_cache_index', where: 'accessed_at < ?', whereArgs: [cutoff]);
    for (final row in stale) { await _deleteEntry(row['filename'] as String); }

    final rows = await _db.query('cover_cache_index', orderBy: 'accessed_at ASC');
    var total = rows.fold<int>(0, (s, r) => s + (r['size_bytes'] as int));
    var i = 0;
    while (total > _maxTotalBytes && i < rows.length) {
      await _deleteEntry(rows[i]['filename'] as String);
      total -= rows[i]['size_bytes'] as int;
      i++;
    }
  }

  Future<void> _deleteEntry(String filename) async {
    final f = File('${_coverDir.path}/$filename');
    if (await f.exists()) await f.delete();
    await _db.delete('cover_cache_index', where: 'filename = ?', whereArgs: [filename]);
  }
}
```

### ✅ Checklist Partie 4
- [ ] Télécharger un livre de test, interrompre le Wi-Fi en cours de route → le job repasse en `queued`, fichier partiel conservé
- [ ] Reconnecter le Wi-Fi, relancer manuellement → reprend depuis la taille réelle du fichier (vérifier via la taille du fichier avant/après, pas depuis zéro)
- [ ] `pauseJob()` sur un téléchargement actif arrête réellement le transfert (vérifiable : la taille du fichier cesse de grandir)
- [ ] Enqueue 5 jobs avec des priorités différentes, vérifier que les priorité 1 démarrent avant les priorité 3
- [ ] Forcer un 404 → le job passe en `failed` sans retry, le fichier partiel est nettoyé

---

# Partie 5 — Bibliothèque et recherche (UI)

## 5.1 Navigation — `RootNavigation`

```dart
// lib/screens/root_navigation.dart
// [Correctif — revérification finale] Ce widget était référencé dans main.dart
// (Partie 7.2, `home: const RootNavigation()`) sans jamais avoir été codé — le point
// d'entrée concret de la navigation à 4 onglets manquait entièrement au guide.
class RootNavigation extends StatefulWidget {
  const RootNavigation({super.key});
  @override State<RootNavigation> createState() => _RootNavigationState();
}

class _RootNavigationState extends State<RootNavigation> {
  // _index commence toujours à 0 → LibraryScreen est l'accueil — c'est la philosophie
  // "bibliothèque d'abord" : la recherche/téléchargement ALIMENTENT la bibliothèque,
  // jamais l'inverse (voir /docs/00_VISION_ET_PORTEE.md).
  int _index = 0;

  static const _screens = [
    LibraryScreen(), SearchScreen(), QueueScreen(), SettingsScreen(),
  ];

  static const _destinations = [
    NavigationDestination(icon: Icon(Icons.auto_stories), label: 'Bibliothèque'),
    NavigationDestination(icon: Icon(Icons.search), label: 'Recherche'),
    NavigationDestination(icon: Icon(Icons.download), label: 'Téléchargements'),
    NavigationDestination(icon: Icon(Icons.settings), label: 'Paramètres'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens), // IndexedStack : conserve
          // l'état de chaque onglet (scroll, recherche en cours) au lieu de le recréer
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: _destinations,
      ),
    );
  }
}
```

## 5.2 `CoverPlaceholder` — typographique + icône de type de média

```dart
// lib/widgets/cover_placeholder.dart
class CoverPlaceholder extends StatelessWidget {
  final String title; final String? author; final MediaType mediaType;
  const CoverPlaceholder({super.key, required this.title, this.author, required this.mediaType});

  static const _palette = [
    Color(0xFFD71921), Color(0xFF2E3440), Color(0xFF8E5572),
    Color(0xFF1D7874), Color(0xFFB5560A), Color(0xFF3B5BA9),
  ];

  @override
  Widget build(BuildContext context) {
    final hash = title.codeUnits.fold<int>(0, (a, b) => a + b);
    final color = _palette[hash % _palette.length];
    final initial = title.isNotEmpty ? title[0].toUpperCase() : '?';

    return Stack(children: [
      Container(
        color: color, alignment: Alignment.center,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(initial, style: const TextStyle(fontFamily: 'Silkscreen', fontSize: 32,
              color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(title, maxLines: 3, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 10, color: Colors.white70)),
          ),
        ]),
      ),
      Positioned(top: 6, right: 6,
          child: Icon(mediaType == MediaType.audiobook ? Icons.headphones : Icons.menu_book,
              size: 16, color: Colors.white70)),
    ]);
  }
}
```

Usage partout où une couverture est affichée :

```dart
item.coverPath != null
    ? Image.file(File(item.coverPath!), fit: BoxFit.cover)
    : CoverPlaceholder(title: item.title, author: item.author, mediaType: item.mediaType),
```

## 5.3 `LibraryScreen` — accueil

```dart
// lib/screens/library_screen.dart
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _filter = 'all'; // all | books | audiobooks | recent
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final connectivity = context.watch<ConnectivityService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Libraria')),
      body: Column(children: [
        if (!connectivity.isOnline)
          Container(color: AppColors.offline, padding: const EdgeInsets.all(8),
              child: const Text('Hors ligne — lecture seule', style: TextStyle(color: Colors.white))),
        Padding(padding: const EdgeInsets.all(8),
            child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Filtrer...'),
                onChanged: (v) => setState(() => _searchQuery = v))),
        SingleChildScrollView(scrollDirection: Axis.horizontal,
            child: Row(children: [
              ChoiceChip(label: const Text('Tous'), selected: _filter == 'all', onSelected: (_) => setState(() => _filter = 'all')),
              ChoiceChip(label: const Text('Livres'), selected: _filter == 'books', onSelected: (_) => setState(() => _filter = 'books')),
              ChoiceChip(label: const Text('Audiobooks'), selected: _filter == 'audiobooks', onSelected: (_) => setState(() => _filter = 'audiobooks')),
              ChoiceChip(label: const Text('Lu récemment'), selected: _filter == 'recent', onSelected: (_) => setState(() => _filter = 'recent')),
            ])),
        Expanded(child: FutureBuilder<List<LibraryItem>>(
          future: _filter == 'recent'
              ? context.read<LibraryRepository>().getRecentlyOpened()
              : context.read<LibraryRepository>().getAllActive(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final items = snapshot.data!.where((i) =>
                (_filter == 'all' || _filter == 'recent' ||
                 (_filter == 'books' && i.mediaType == MediaType.book) ||
                 (_filter == 'audiobooks' && i.mediaType == MediaType.audiobook)) &&
                (_searchQuery.isEmpty || i.title.toLowerCase().contains(_searchQuery.toLowerCase())))
                .toList();
            if (items.isEmpty) return const Center(child: Text('Votre bibliothèque est vide'));
            return GridView.builder( // GridView.builder dès le départ — virtualisation correcte
              padding: const EdgeInsets.all(8),
              // [Correctif audit U-02] SliverGridDelegateWithFixedCrossAxisCount(3) laissait
              // un espace vide énorme sur une fenêtre Windows large, ou des cards trop serrées
              // sur un petit téléphone. MaxCrossAxisExtent s'adapte aux deux plateformes cibles.
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 140, childAspectRatio: 0.65),
              itemCount: items.length,
              itemBuilder: (context, i) => _LibraryCard(item: items[i]),
            );
          },
        )),
      ]),
    );
  }
}

class _LibraryCard extends StatelessWidget {
  final LibraryItem item;
  const _LibraryCard({required this.item});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MediaDetailScreen(item: item))),
      child: Column(children: [
        Expanded(child: Stack(children: [
          AspectRatio(aspectRatio: 2 / 3,
              child: item.coverPath != null
                  ? Image.file(File(item.coverPath!), fit: BoxFit.cover)
                  : CoverPlaceholder(title: item.title, author: item.author, mediaType: item.mediaType)),
          if (item.isMissing)
            const Positioned(top: 4, left: 4,
                child: Icon(Icons.error, color: AppColors.error, size: 18)),
        ])),
        Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Silkscreen', fontSize: 11)),
      ]),
    );
  }
}
```

## 5.4 `SearchScreen` — distinction « aucun résultat » / « sources indisponibles »

```dart
// lib/screens/search_screen.dart
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  List<SearchResult> _results = [];
  bool _loading = false;
  late List<ContentSource> _sources;
  // [Correctif audit U-01] Nécessaire pour que le bouton "Réessayer" puisse relancer
  // la même recherche — sans ça, il n'y avait rien à relancer.
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _sources = [
      context.read<GutenbergSource>(), context.read<InternetArchiveSource>(),
      context.read<LibrivoxSource>(), context.read<StandardEbooksSource>(),
    ];
  }

  Future<void> _runSearch(String query) async {
    _lastQuery = query;
    setState(() => _loading = true);
    final futures = _sources.map((s) => s.search(query)
        .timeout(const Duration(seconds: 8), onTimeout: () => const SourceSearchResult(items: []))
        .catchError((_) => const SourceSearchResult(items: [])));
    final results = await Future.wait(futures);
    setState(() {
      _results = results.expand((r) => r.items).toList();
      _loading = false;
    });
  }

  Widget _buildEmptyState() {
    final degraded = _sources.where((s) => s is BaseContentSource && (s as BaseContentSource).circuitState == CircuitState.open).toList();
    if (degraded.isNotEmpty) {
      return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('${degraded.length} source(s) temporairement indisponible(s) : '
            '${degraded.map((s) => s.displayName).join(", ")}'),
        // [Correctif audit U-01] onPressed était vide — le bouton ne faisait rien au clic.
        TextButton(
            onPressed: _lastQuery.isEmpty ? null : () => _runSearch(_lastQuery),
            child: const Text('Réessayer')),
      ]);
    }
    return const Center(child: Text('Aucun résultat pour cette recherche.'));
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = context.watch<ConnectivityService>().isOnline;
    return Scaffold(
      appBar: AppBar(title: const Text('Recherche'), actions: [
        if (_results.length > 1)
          // [Correctif audit U-03] tooltip déjà présent ici (bon exemple), gardé tel quel.
          IconButton(icon: const Icon(Icons.download_for_offline), tooltip: 'Tout télécharger',
              onPressed: () => _downloadAllVisible(_results)),
      ]),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(8), child: TextField(
            enabled: isOnline,
            decoration: InputDecoration(hintText: isOnline ? 'Rechercher...' : 'Indisponible hors ligne'),
            onSubmitted: _runSearch)),
        if (_loading) const LinearProgressIndicator(),
        Expanded(child: _results.isEmpty ? _buildEmptyState() : ListView.builder(
          itemCount: _results.length,
          itemBuilder: (context, i) => _SearchResultTile(result: _results[i], isOnline: isOnline),
        )),
      ]),
    );
  }

  Future<void> _downloadAllVisible(List<SearchResult> results) async {
    if (results.length > 10) {
      final confirmed = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
        title: const Text('Télécharger tout ?'),
        content: Text('${results.length} éléments seront ajoutés à la file.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirmer')),
        ],
      ));
      if (confirmed != true) return;
    }
    final dm = context.read<DownloadManager>();
    for (final r in results) { await dm.enqueue(r); }
  }
}

class _SearchResultTile extends StatelessWidget {
  final SearchResult result; final bool isOnline;
  const _SearchResultTile({required this.result, required this.isOnline});
  @override
  Widget build(BuildContext context) => ListTile(
        leading: SizedBox(width: 40, height: 60,
            child: result.coverUrl != null
                ? CachedNetworkImage(imageUrl: result.coverUrl!,
                    errorWidget: (_, __, ___) => CoverPlaceholder(title: result.title, author: result.author, mediaType: result.mediaType))
                : CoverPlaceholder(title: result.title, author: result.author, mediaType: result.mediaType)),
        title: Text(result.title), subtitle: Text('${result.author ?? "Inconnu"} · ${result.sourceName}'),
        trailing: IconButton(icon: const Icon(Icons.download),
            onPressed: isOnline ? () => context.read<DownloadManager>().enqueue(result) : null,
            tooltip: isOnline ? 'Télécharger' : 'Hors ligne'),
      );
}
```

## 5.5 `QueueScreen`

```dart
// lib/screens/queue_screen.dart
class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final dm = context.watch<DownloadManager>();
    return Scaffold(
      appBar: AppBar(title: Text('Téléchargements (${dm.jobs.where((j) => j.status == DownloadStatus.downloading).length}/${dm.maxConcurrent} actifs)')),
      body: ListView.builder(
        itemCount: dm.jobs.length,
        itemBuilder: (context, i) {
          final job = dm.jobs[i];
          return ListTile(
            title: Text(job.result.title),
            subtitle: LinearProgressIndicator(value: job.progress),
            // [Correctif audit U-03] tooltips ajoutés — boutons icône-only sans texte visible.
            trailing: switch (job.status) {
              DownloadStatus.downloading => IconButton(icon: const Icon(Icons.pause), tooltip: 'Mettre en pause', onPressed: () => dm.pauseJob(job.id)),
              DownloadStatus.paused => IconButton(icon: const Icon(Icons.play_arrow), tooltip: 'Reprendre', onPressed: () => dm.resumeJob(job.id)),
              DownloadStatus.failed => IconButton(icon: const Icon(Icons.refresh), tooltip: 'Réessayer', onPressed: () => dm.resumeJob(job.id)),
              _ => const Icon(Icons.check, color: AppColors.success, semanticLabel: 'Terminé'),
            },
          );
        },
      ),
    );
  }
}
```

## 5.6 Fichiers manquants — badge + relier

```dart
// lib/library/local_file_verifier.dart
class LocalFileVerifier {
  final LibraryRepository repo;
  LocalFileVerifier(this.repo);

  Future<void> verifyAll() async {
    final items = await repo.getAllActive();
    for (final item in items) {
      if (item.localPath == null) continue;
      final exists = await File(item.localPath!).exists();
      if (exists == item.isMissing) continue; // déjà à jour
      await repo.markMissing(item.id, isMissing: !exists);
    }
  }
}
```

```dart
// lib/screens/library_screen.dart — action de relink, sur le détail d'un item manquant
Future<void> relink(BuildContext context, LibraryItem item, LibraryRepository repo) async {
  final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['epub', 'mp3', 'm4b']);
  final path = picked?.files.single.path;
  if (path == null) return;
  final sha = sha256.convert(await File(path).readAsBytes()).toString(); // fichier de couverture, taille raisonnable
  if (item.contentSha256 != null && sha != item.contentSha256) {
    final confirmed = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Fichier différent'),
      content: const Text('Ce fichier ne correspond pas exactement à l\'original. Continuer ?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continuer')),
      ],
    ));
    if (confirmed != true) return;
  }
  await repo.relink(item.id, newPath: path, newSha: sha);
}
```

Tâche périodique (vérification toutes les 12h) :

```dart
// lib/main.dart (enregistrement) — voir Partie 7 pour le câblage complet
Workmanager().registerPeriodicTask('libraria.verify_local_files', 'verifyLocalFiles',
    frequency: const Duration(hours: 12), constraints: Constraints(networkType: NetworkType.notRequired));
```

## 5.7 Garde-fou suppression — corbeille à 2 paliers

```dart
// lib/library/library_repository.dart — ajout
Future<void> softDelete(List<String> ids) => _db.update('library_items',
    {'deleted_at': DateTime.now().millisecondsSinceEpoch},
    where: 'id IN (${ids.map((_) => '?').join(',')})', whereArgs: ids);

Future<void> purgeOlderThan(Duration age) async {
  final cutoff = DateTime.now().subtract(age).millisecondsSinceEpoch;
  final rows = await _db.query('library_items', where: 'deleted_at IS NOT NULL AND deleted_at < ?', whereArgs: [cutoff]);
  for (final row in rows) {
    if (row['local_path'] != null) { final f = File(row['local_path'] as String); if (await f.exists()) await f.delete(); }
  }
  await _db.delete('library_items', where: 'deleted_at IS NOT NULL AND deleted_at < ?', whereArgs: [cutoff]);
}
```

```dart
// lib/screens/library_screen.dart — confirmation différenciée par taille de sélection
Future<bool> confirmBatchDelete(BuildContext context, int count) async {
  if (count < 10) return await _simpleConfirm(context, count) ?? false;
  final word = await _askConfirmWord(context, expected: 'SUPPRIMER');
  if (word != 'SUPPRIMER') return false;
  if (count < 50) return true;
  return await _countdownConfirm(context, seconds: 5) ?? false; // suppression massive
}
```

## 5.8 Étagères et tags — UI

```dart
// lib/screens/shelf_screen.dart — réordonnancement par glisser-déposer + alternative non-drag
ReorderableListView.builder(
  itemCount: shelves.length,
  onReorder: (oldIndex, newIndex) => shelfRepo.reorder(oldIndex, newIndex),
  itemBuilder: (context, i) => ListTile(
    key: ValueKey(shelves[i].id), title: Text(shelves[i].name),
    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
      // Alternative non-drag — WCAG 2.2 SC 2.5.7 : le glisser-déposer seul n'est pas accessible
      IconButton(icon: const Icon(Icons.arrow_upward), onPressed: i > 0 ? () => shelfRepo.moveUp(shelves[i].id) : null),
      IconButton(icon: const Icon(Icons.arrow_downward), onPressed: i < shelves.length - 1 ? () => shelfRepo.moveDown(shelves[i].id) : null),
    ]),
  ),
);
```

## 5.9 `SettingsScreen`, `TrashScreen` et onboarding

```dart
// lib/screens/settings_screen.dart
// [Correctif — revérification finale] La version précédente ne montrait que des
// "extraits clés" hors de toute classe — SettingsScreen n'avait jamais de définition
// complète, alors que RootNavigation (Partie 5.1) l'instancie directement.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final dm = context.watch<DownloadManager>();
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(children: [
        ListTile(
          title: const Text('Téléchargements simultanés'),
          subtitle: Slider(
              value: dm.maxConcurrent.toDouble(), min: 1, max: 6, divisions: 5,
              label: '${dm.maxConcurrent}',
              onChanged: (v) => setState(() => dm.maxConcurrent = v.toInt())),
        ),
        ListTile(
          title: const Text('Corbeille'),
          subtitle: const Text('Restaurer ou vider'),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrashScreen())),
        ),
        ListTile(
          title: const Text('Envoyer un rapport de diagnostic'),
          subtitle: const Text('Rien n\'est envoyé automatiquement — vous choisissez où le partager'),
          leading: const Icon(Icons.bug_report_outlined),
          onTap: () => context.read<DiagnosticReportService>().shareReport(),
        ),
      ]),
    );
  }
}
```

```dart
// lib/screens/trash_screen.dart
// [Correctif — revérification finale] Référencé depuis SettingsScreen et la checklist
// de la Partie 5, jamais défini nulle part dans le guide.
class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final repo = context.read<LibraryRepository>();
    return Scaffold(
      appBar: AppBar(title: const Text('Corbeille'), actions: [
        TextButton(
          onPressed: () async { await repo.purgeOlderThan(Duration.zero); if (context.mounted) Navigator.pop(context); },
          child: const Text('Tout vider'),
        ),
      ]),
      body: FutureBuilder<List<LibraryItem>>(
        future: repo.getDeletedItems(), // voir ajout ci-dessous
        builder: (context, snapshot) {
          final items = snapshot.data ?? [];
          if (items.isEmpty) return const Center(child: Text('Corbeille vide'));
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) => ListTile(
              title: Text(items[i].title),
              trailing: IconButton(icon: const Icon(Icons.restore), tooltip: 'Restaurer',
                  onPressed: () => repo.restore(items[i].id)),
            ),
          );
        },
      ),
    );
  }
}
```

```dart
// lib/library/library_repository.dart — ajouts nécessaires à TrashScreen
Future<List<LibraryItem>> getDeletedItems() => _db
    .query('library_items', where: 'deleted_at IS NOT NULL', orderBy: 'deleted_at DESC')
    .then((rows) => rows.map(_fromMap).toList());

Future<void> restore(String id) => _db.update('library_items', {'deleted_at': null}, where: 'id = ?', whereArgs: [id]);
```

Onboarding (premier lancement) : 2-3 écrans `PageView` présentant la philosophie « bibliothèque d'abord » et les 4 sources V1 — pas de code détaillé ici, contenu purement informatif.

### ✅ Checklist Partie 5
- [ ] `LibraryScreen` affiche correctement une bibliothèque vide, puis après un téléchargement de test
- [ ] Couper le réseau pendant une recherche : message « sources indisponibles » distinct de « aucun résultat »
- [ ] Supprimer un item passe par la corbeille, restaurable depuis `TrashScreen`
- [ ] Réordonner une étagère fonctionne à la fois par glisser-déposer ET par les boutons haut/bas
- [ ] `RootNavigation` bascule entre les 4 onglets sans perdre l'état de chacun (ex: texte de recherche saisi, scroll de la bibliothèque)

---

# Partie 6 — Lecteurs EPUB et audiobook

## 6.1 Lecteur EPUB — position exacte, pas seulement un pourcentage

```dart
// lib/readers/epub_reader_screen.dart
class EpubReaderScreen extends StatefulWidget {
  final LibraryItem item;
  const EpubReaderScreen({super.key, required this.item});
  @override State<EpubReaderScreen> createState() => _EpubReaderScreenState();
}

class _EpubReaderScreenState extends State<EpubReaderScreen> {
  EpubController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = EpubController(
      document: EpubDocument.openFile(File(widget.item.localPath!)),
      epubCfi: widget.item.lastCfi, // reprise EXACTE — pas le pourcentage seul
    );
  }

  void _onPositionChanged(EpubChapterViewValue? value) {
    if (value == null) return;
    final percent = value.position; // selon l'API exposée par epub_view
    final cfi = value.chapter?.startCfi ?? '';
    context.read<LibraryRepository>().updatePosition(widget.item.id, readProgress: percent, lastCfi: cfi);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: EpubViewActualChapter(controller: _controller!),
      body: EpubView(
        controller: _controller!,
        onChapterChanged: (value) => _onPositionChanged(value),
        builders: EpubViewBuilders<DefaultBuilderOptions>(
          options: const DefaultBuilderOptions(),
          chapterBuilder: (context, builders, document, chapters, paragraphs, index, anchor, paragraphIndex) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DefaultBuilder().chapterBuilder(context, builders, document, chapters, paragraphs, index, anchor, paragraphIndex),
            );
          },
        ),
      ),
    );
  }
}
```

**Texte adaptatif** — code réel, pas juste une mention de principe :

```dart
// Appliqué à tout le texte du lecteur, pas seulement décrit comme bonne pratique
Text(paragraphText, textScaleFactor: MediaQuery.textScaleFactorOf(context)),
```

**Fallback EPUB complexe** :

```dart
ElevatedButton(
  onPressed: () => launchUrl(Uri.file(widget.item.localPath!)),
  child: const Text('Ouvrir avec…'),
), // si epub_view échoue à charger un EPUB avec CSS avancé/scripts/DRM
```

**Si bascule future vers `flutter_epub_viewer`** (CFI natifs pour les notes, voir ADR-007 dans `/docs/01_DECISIONS.md`) : désactiver explicitement le JS du contenu EPUB (EPUB3 peut en embarquer), ou conserver `epub_view` qui n'a par construction aucun moteur JS.

## 6.2 Lecteur audiobook — multi-fichiers, position correcte

```dart
// lib/readers/audio_player_screen.dart
class AudioPlayerScreen extends StatefulWidget {
  final LibraryItem item;
  const AudioPlayerScreen({super.key, required this.item});
  @override State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  final _player = AudioPlayer();
  List<File> _files = [];

  @override
  void initState() {
    super.initState();
    _loadAudiobook();
  }

  Future<void> _loadAudiobook() async {
    final dir = Directory(widget.item.localPath!);
    if (await dir.exists()) {
      // Dossier multi-fichiers (LibriVox livre souvent un livre en dizaines de MP3 séparés)
      _files = (await dir.list().toList()).whereType<File>()
          .where((f) => f.path.endsWith('.mp3')).toList()
        ..sort((a, b) => a.path.compareTo(b.path)); // ordre alphabétique = ordre des chapitres

      await _player.setAudioSource(ConcatenatingAudioSource(
          children: _files.map((f) => AudioSource.uri(Uri.file(f.path))).toList()));

      // Position stockée comme (index fichier, position ms) — pas une seule valeur en
      // secondes, sinon la reprise pointe vers le mauvais chapitre après réouverture.
      final saved = _parseStoredPosition(widget.item.lastCfi);
      if (saved != null) {
        await _player.seek(Duration(milliseconds: saved.positionMs), index: saved.fileIndex);
      }
    } else {
      await _player.setAudioSource(AudioSource.uri(Uri.file(widget.item.localPath!))); // M4B unique
    }

    _player.positionStream.listen((pos) => _savePositionThrottled(pos));
  }

  void _savePositionThrottled(Duration pos) {
    // Toutes les 10s : sérialiser (currentIndex, pos.inMilliseconds) dans last_cfi
    final stored = '${_player.currentIndex ?? 0}:${pos.inMilliseconds}';
    context.read<LibraryRepository>().updatePosition(widget.item.id, readProgress: 0 /* calculé séparément */, lastCfi: stored);
  }

  ({int fileIndex, int positionMs})? _parseStoredPosition(String? raw) {
    if (raw == null || !raw.contains(':')) return null;
    final parts = raw.split(':');
    return (fileIndex: int.parse(parts[0]), positionMs: int.parse(parts[1]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.item.title)),
      body: Column(children: [
        StreamBuilder<PlayerState>(stream: _player.playerStateStream, builder: (context, snapshot) {
          final playing = snapshot.data?.playing ?? false;
          // [Correctif audit U-03] Aucun tooltip nulle part sur les contrôles audio —
          // TalkBack/Narrator ne pouvaient rien annoncer sur ces boutons icône-only.
          return IconButton(
            iconSize: 64, icon: Icon(playing ? Icons.pause_circle : Icons.play_circle),
            tooltip: playing ? 'Mettre en pause' : 'Lire',
            onPressed: () => playing ? _player.pause() : _player.play(),
          );
        }),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(icon: const Icon(Icons.replay_30), tooltip: 'Reculer de 30 secondes',
              onPressed: () => _player.seek(_player.position - const Duration(seconds: 30))),
          IconButton(icon: const Icon(Icons.forward_30), tooltip: 'Avancer de 30 secondes',
              onPressed: () => _player.seek(_player.position + const Duration(seconds: 30))),
        ]),
      ]),
    );
  }

  @override
  void dispose() { _player.dispose(); super.dispose(); }
}
```

Permissions et service de premier plan déjà déclarés en Partie 0 (`FOREGROUND_SERVICE_MEDIA_PLAYBACK`).

## 6.3 Notes et surlignages (V2)

```dart
// lib/readers/epub_reader_screen.dart — extrait, gestion de la sélection
void _onTextSelected(String text, String cfi) {
  showDialog(context: context, builder: (_) => NoteEditorDialog(
    onSave: (note, color) => context.read<NoteRepository>().addNote(
        const Uuid().v4(), widget.item.id, cfi, text: text, note: note),
  ));
}
```

Export Markdown et recherche plein texte FTS5 : voir `NoteRepository.searchNotes()` (Partie 2.3).

### ✅ Checklist Partie 6
- [ ] Ouvrir un EPUB de test, changer de chapitre, fermer l'app, rouvrir → reprise au bon endroit via `last_cfi`, pas une approximation par pourcentage
- [ ] Ouvrir un audiobook LibriVox multi-fichiers : lecture continue d'un fichier à l'autre sans interruption audible
- [ ] Fermer/rouvrir un audiobook multi-fichiers en cours de lecture → reprend sur le bon fichier ET à la bonne position
- [ ] Changer la taille de police système (réglages Android) → le texte du lecteur s'adapte

---

# Partie 7 — Démarrage, connectivité, composition finale

## 7.1 `ConnectivityService`

```dart
// lib/core/connectivity/connectivity_service.dart
class ConnectivityService extends ChangeNotifier {
  bool isOnline = true;
  StreamSubscription? _sub;

  ConnectivityService() {
    _sub = Connectivity().onConnectivityChanged.listen((result) {
      isOnline = result != ConnectivityResult.none;
      notifyListeners();
    });
  }

  @override
  void dispose() { _sub?.cancel(); super.dispose(); }
}
```

## 7.2 Composition root — `main.dart`, version finale

```dart
// lib/main.dart

// [Correctif — revérification finale] Requise par Workmanager().initialize() plus bas
// dans ce même fichier — sans cette fonction top-level, la compilation échoue.
// pragma vmEntryPoint nécessaire : Workmanager exécute ce callback dans un isolate
// séparé, qui doit pouvoir le retrouver même après tree-shaking en release.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == 'verifyLocalFiles') {
      final db = await DatabaseHelper.database;
      final verifier = LocalFileVerifier(LibraryRepository(db));
      await verifier.verifyAll();
    }
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = await DatabaseHelper.database; // onConfigure (PRAGMA) + schéma appliqués ici

  // Permissions et resumeAll() n'ont pas de dépendance entre eux — parallélisés
  final httpClient = DioHttpClient();
  final libraryDir = await getApplicationDocumentsDirectory();
  final libraryRepo = LibraryRepository(db);
  // internetArchiveSource créé AVANT le DownloadManager — [correctif audit S-02] injecté
  // pour que la vérification de checksum Internet Archive soit réellement appelée.
  final internetArchiveSource = InternetArchiveSource(httpClient);
  final downloadManager = DownloadManager(
      httpClient: httpClient, repository: libraryRepo, db: db, libraryDir: libraryDir,
      internetArchiveSource: internetArchiveSource);

  await Future.wait([
    PermissionService.requestStoragePermissions(),
    PermissionService.requestNotificationPermission(),
    downloadManager.resumeAll(),
  ]);

  Workmanager().initialize(callbackDispatcher);
  Workmanager().registerPeriodicTask('libraria.verify_local_files', 'verifyLocalFiles',
      frequency: const Duration(hours: 12), constraints: Constraints(networkType: NetworkType.notRequired));

  runApp(MultiProvider(
    providers: [
      Provider<HttpClient>.value(value: httpClient),
      ChangeNotifierProvider.value(value: downloadManager),
      ChangeNotifierProvider(create: (_) => ConnectivityService()),
      Provider.value(value: libraryRepo),
      Provider(create: (_) => ShelfRepository(db)),
      Provider(create: (_) => TagRepository(db)),
      Provider(create: (_) => NoteRepository(db)),
      Provider(create: (_) => DiagnosticReportService()),
      Provider(create: (_) => CoverCacheManager(db, Directory('${libraryDir.path}/covers'))),
      Provider<GutenbergSource>(create: (_) => GutenbergSource(httpClient)),
      Provider<InternetArchiveSource>.value(value: internetArchiveSource),
      Provider<LibrivoxSource>(create: (_) => LibrivoxSource(httpClient)),
      Provider<StandardEbooksSource>(create: (_) => StandardEbooksSource(httpClient)),
      // [Correctif audit A-02] ReadingStatsService et LocalRecommender ont été retirés
      // d'ici : ce sont des fonctionnalités V3 (voir /docs/10_ROADMAP.md), leurs classes
      // ne sont pas codées dans ce guide V1/V2. Les ajouter ici sans les avoir écrites
      // empêchait purement et simplement la compilation. À réintroduire au moment de
      // coder la Partie V3 correspondante.
    ],
    child: const LibrariaApp(),
  ));
}

class LibrariaApp extends StatelessWidget {
  const LibrariaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Libraria',
        theme: AppTheme.light, darkTheme: AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('fr'), // V1 : forcé fr ; retirer en V2 pour suivre la locale système
        home: const RootNavigation(),
      );
}
```

## 7.3 i18n — fichiers `.arb`

```json
// lib/l10n/app_fr.arb
{
  "@@locale": "fr",
  "errorNetwork": "Pas de connexion réseau",
  "errorSourceUnavailable": "Source indisponible : {sourceName}",
  "@errorSourceUnavailable": { "placeholders": { "sourceName": { "type": "String" } } },
  "errorDiskFull": "Espace disque insuffisant",
  "errorParsing": "Fichier invalide ou corrompu",
  "libraryEmpty": "Votre bibliothèque est vide",
  "offlineBanner": "Hors ligne — lecture seule"
}
```

```json
// lib/l10n/app_en.arb — V2
{
  "@@locale": "en",
  "errorNetwork": "No network connection",
  "errorSourceUnavailable": "Source unavailable: {sourceName}",
  "errorDiskFull": "Not enough disk space",
  "errorParsing": "Invalid or corrupted file",
  "libraryEmpty": "Your library is empty",
  "offlineBanner": "Offline — read-only"
}
```

### ✅ Checklist Partie 7
- [ ] Couper le réseau au lancement : bannière offline visible, actions réseau désactivées
- [ ] Tuer l'app en plein téléchargement, relancer : `resumeAll()` recharge le job et reprend
- [ ] Toutes les chaînes visibles passent par `AppLocalizations`, aucune chaîne française codée en dur restante dans les écrans

---

# Partie 8 — Tests et CI/CD

## 8.1 Stratégie

Chaque fichier de `lib/core/security/`, `lib/core/network/`, `lib/core/integrity/` a son test écrit **dans la même session** que son code — pas reporté après coup. `HttpClient` est mocké partout (`MockHttpClient`, mocktail) — aucun vrai appel réseau dans `flutter test`.

```dart
// test/core/security/url_validator_test.dart
void main() {
  group('UrlValidator', () {
    test('accepte une URL https publique', () {
      expect(() => UrlValidator.validate('https://gutendex.com/books'), returnsNormally);
    });
    test('rejette un schéma non http(s)', () {
      expect(() => UrlValidator.validate('file:///etc/passwd'), throwsA(isA<NetworkException>()));
    });
    test('rejette une IP privée sans allowPrivateNetwork', () {
      expect(() => UrlValidator.validate('http://192.168.1.1/admin'), throwsA(isA<NetworkException>()));
    });
    test('accepte une IP privée avec allowPrivateNetwork (connecteur OPDS local)', () {
      expect(() => UrlValidator.validate('http://192.168.1.1/opds', allowPrivateNetwork: true), returnsNormally);
    });
  });
}
```

```dart
// test/core/security/filename_sanitizer_property_test.dart
import 'package:glados/glados.dart';

void main() {
  Glados<String>().test('sanitize() ne produit jamais de ".." dans le résultat', (input) {
    expect(FilenameSanitizer.sanitize(input).contains('..'), isFalse);
  });
  Glados<String>().test('sanitize() ne produit jamais de séparateur de chemin', (input) {
    final r = FilenameSanitizer.sanitize(input);
    expect(r.contains('/') || r.contains('\\'), isFalse);
  });
}
```

```dart
// test/library/migration_rollback_test.dart
test('une migration qui échoue ne bumpe pas user_version', () async {
  // ouvrir v1 → tenter upgrade v2 qui lève une exception → réouvrir → vérifier user_version == 1
});
test('enchaînement multi-versions (v1 → version courante) appliqué sans erreur', () async {
  // cas réel d'un utilisateur qui installe une version ayant sauté plusieurs releases
});
```

```dart
// test/download_manager/download_manager_test.dart
test('enqueue() insère un job priorité 1 avant un job priorité 2 déjà en attente', () async {
  final dm = DownloadManager(httpClient: MockHttpClient(), repository: mockRepo, db: mockDb, libraryDir: tempDir);
  await dm.enqueue(resultA, priority: 2);
  await dm.enqueue(resultB, priority: 1);
  expect(dm.jobs.first.result, resultB);
});
test('pauseJob() annule le CancelToken et le job repasse en paused', () async { /* ... */ });
```

## 8.2 Golden tests

```dart
// test/goldens/loader_golden_test.dart
void main() {
  testGoldens('Loader matches golden', (tester) async {
    final builder = DeviceBuilder()..addScenario(widget: const Loader());
    await tester.pumpDeviceBuilder(builder);
    await screenMatchesGolden(tester, 'loader_default');
  });
}
// Répéter pour : DotMatrixProgressBar, OfflineBadge, LibraryCard
```

Générer la baseline (`flutter test --update-goldens`) **avant** la première exécution CI — sinon le job échoue dès le premier run, faute de référence à comparer.

## 8.3 CI/CD complet

```yaml
# .github/workflows/ci.yml
name: CI
on:
  push: { branches: [main] }
  pull_request: { branches: [main] }

jobs:
  analyze-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { flutter-version: '3.x' }
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test --coverage
      - uses: VeryGoodOpenSource/very_good_coverage@v3
        with: { path: coverage/lcov.info, min_coverage: 80 }

  golden-tests:
    runs-on: ubuntu-latest
    needs: analyze-and-test
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { flutter-version: '3.x' }
      - run: flutter pub get
      - run: flutter test test/goldens

  build-android:
    runs-on: ubuntu-latest
    needs: analyze-and-test
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { flutter-version: '3.x' }
      - run: flutter pub get
      - run: flutter build apk --obfuscate --split-debug-info=build/symbols/ --release
      - uses: actions/upload-artifact@v4
        with: { name: android-symbols, path: build/symbols } # conservés hors repo Git

  build-windows:
    runs-on: windows-latest
    needs: analyze-and-test
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { flutter-version: '3.x' }
      - run: flutter pub get
      - run: flutter build windows --release
```

Seuil global 80 %, pas par fichier ajouté — un script de diff par PR serait plus précis mais disproportionné pour un projet solo.

## 8.4 `CONTRIBUTING.md`

```markdown
## Ajouter une nouvelle source
Tout nouveau connecteur étend `BaseContentSource`, jamais `ContentSource` directement —
sinon le rate limiting, le circuit breaker et la validation d'URL ne s'appliquent pas.

Deux emplacements possibles selon l'édition ciblée (ADR-014) :
- `lib/sources/<name>/` — source « V1 », embarquée dans les deux éditions (Play Store
  ET GitHub). Réservée aux catalogues au statut juridique non ambigu (domaine public,
  licences libres, prêt légal).
- `lib/sources/extended/` — source « GitHub Edition only ». Ajouter la classe *et*
  l'enregistrer dans `ExtendedSourcesRegistry.allAvailable`. Toggle OFF par défaut,
  code retiré du binaire Play Store par le tree-shaker.

## Sources à statut variable
- **Anna's Archive**, **Z-Library**, **Library Genesis**, **Sci-Hub** : GitHub Edition
  uniquement (`lib/sources/extended/`), désactivées par défaut. Voir ADR-014 dans
  `docs/restructuration_claude.md`. Ne jamais les ajouter à `lib/sources/<name>/`,
  ce serait les livrer par erreur au Play Store.
- Tout connecteur nécessitant de contourner un DRM : hors périmètre, quelle que soit
  l'édition.

## Convention de dossiers
`lib/core/`, `lib/sources/`, `lib/download_manager/`, `lib/library/`, `lib/readers/`,
`lib/screens/` — voir `/docs/README.md`. Tout code reçu d'un outil externe est renommé
pour s'y conformer avant d'être intégré.

## Couverture de test
≥ 80 % global, vérifié en CI (`very_good_coverage`). Un nouveau fichier dans
`lib/core/security/` sans test associé fait échouer la CI mécaniquement.
```



## 8.5 Deux éditions Android + Windows (ADR-014)

Le projet produit trois artefacts à partir du même dépôt :

```bash
# Play Store Edition (Android) — build par défaut, sans sources étendues
flutter build appbundle --release \
  --obfuscate --split-debug-info=build/symbols/playstore/

# GitHub Edition (Android) — sources étendues activables (OFF par défaut)
flutter build apk --release \
  --dart-define=EXTENDED_SOURCES=true \
  --obfuscate --split-debug-info=build/symbols/github/

# Windows — même posture que la GitHub Edition
flutter build windows --release \
  --dart-define=EXTENDED_SOURCES=true
```

Règles :
- Le `.aab` uploadé sur le Play Console est **toujours** buildé sans `--dart-define=EXTENDED_SOURCES=true`. Ne pas se tromper de commande dans le workflow de release, sinon suspension de compte quasi immédiate.
- L'APK de la GitHub Release inclut la chaîne `github-edition` dans son nom de fichier pour éviter toute confusion à l'installation manuelle.
- La description de la GitHub Release rappelle : « Sources étendues désactivées par défaut. Vous êtes responsable de leur activation. »
- Le `versionCode` Android reste identique entre les deux éditions ; seul le `applicationId` diffère (`com.tonnom.libraria` vs `com.tonnom.libraria.github`) pour permettre l'installation côte à côte pendant les tests.

### ✅ Checklist Partie 8
- [ ] `flutter test --coverage` ≥ 80 % avant tout push
- [ ] CI verte sur les 4 jobs (analyze, golden, build Android, build Windows)
- [ ] `CONTRIBUTING.md` à jour, lu avant toute contribution externe

---

# Partie 9 — Fonctionnalités V2

## 9.1 OPDS sortant — Libraria comme serveur local

```dart
// lib/server/opds_server.dart
class OpdsServer {
  HttpServer? _server;
  final LibraryRepository _library;
  final RateLimiter _localRateLimiter = RateLimiter(maxPerWindow: 60, window: const Duration(minutes: 1));
  OpdsServer(this._library);

  Future<String> start({int port = 8780}) async {
    final router = Router()
      ..get('/opds', _rootFeed)
      ..get('/opds/books', _booksFeed)
      ..get('/opds/download/<id>', _downloadFile);
    _server = await serve(router, InternetAddress.anyIPv4, port);
    final ip = await NetworkInfo().getWifiIP();
    return 'http://$ip:$port/opds';
  }

  Future<void> stop() async => await _server?.close(force: true);

  Future<Response> _booksFeed(Request req) async {
    final clientIp = req.context['shelf.io.connection_info']?.toString() ?? 'unknown';
    await _localRateLimiter.acquire(clientIp); // anti-DoS local, réseau partagé/coworking
    final items = await _library.getAllActive();
    return Response.ok(_buildAtomFeed(title: 'Tous les livres', entries: items),
        headers: {'content-type': 'application/atom+xml;profile=opds-catalog'});
  }

  Future<Response> _rootFeed(Request req) async => Response.ok(
      _buildAtomFeed(title: 'Libraria', entries: const []),
      headers: {'content-type': 'application/atom+xml;profile=opds-catalog'});

  Future<Response> _downloadFile(Request req, String id) async {
    final items = await _library.getAllActive();
    final item = items.firstWhereOrNull((i) => i.id == id);
    if (item == null || item.localPath == null) return Response.notFound('Introuvable');
    return Response.ok(File(item.localPath!).openRead(), headers: {
      'content-type': 'application/epub+zip',
      'content-disposition': 'attachment; filename="${item.title}.epub"',
    });
  }

  String _buildAtomFeed({required String title, required List<LibraryItem> entries}) {
    final entriesXml = entries.map((e) => '''
      <entry><title>${_escape(e.title)}</title><id>urn:libraria:${e.id}</id>
      <author><name>${_escape(e.author ?? "Inconnu")}</name></author>
      <link rel="http://opds-spec.org/acquisition" href="/opds/download/${e.id}" type="application/epub+zip"/></entry>''').join();
    return '''<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom" xmlns:opds="http://opds-spec.org/2010/catalog">
  <title>$title</title><id>urn:libraria:root</id><updated>${DateTime.now().toIso8601String()}</updated>
  $entriesXml
</feed>''';
  }
  String _escape(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;');
}
```

UI Settings : `Switch` + texte d'aide sur le prompt pare-feu Windows + `QrImageView` pour appairer une liseuse (Moon+ Reader, KOReader).

## 9.2 Synchronisation des paramètres — chiffrée

```dart
// lib/core/sync/settings_sync_service.dart
class SettingsSyncService {
  /// Argon2id (dérivation de clé depuis la passphrase) + AES-256-GCM (chiffrement).
  static Future<String> encrypt(String json, String passphrase) async { /* ... */ throw UnimplementedError(); }
  static Future<String> decrypt(String encrypted, String passphrase) async { /* ... */ throw UnimplementedError(); }
}
```

```dart
abstract class SyncBackend {
  String get name;
  Future<void> upload(String filename, String content);
  Future<String?> download(String filename);
  Future<bool> testConnection();
}
// Implémentations V2 : WebDavSyncBackend, GoogleDriveSyncBackend
```

Clés API **jamais incluses par défaut** dans l'export — opt-in explicite requis.

## 9.3 Export et sauvegarde complète chiffrée

```dart
// lib/export/library_exporter.dart
class LibraryExporter {
  final LibraryRepository _library;
  LibraryExporter(this._library);

  Future<String> exportJson() async {
    final items = await _library.getAllActive();
    return jsonEncode({'version': 1, 'exported_at': DateTime.now().toIso8601String(),
        'items': items.map((i) => i.toMap()).toList()});
  }

  /// Réutilise le chiffrement déjà construit pour la sync — aucun nouveau primitif
  /// cryptographique, juste le branchement entre les deux.
  Future<void> backupFullLibraryEncrypted(String passphrase, SyncBackend backend) async {
    final json = await exportJson();
    final encrypted = await SettingsSyncService.encrypt(json, passphrase);
    await backend.upload('libraria_backup_${DateTime.now().toIso8601String()}.enc', encrypted);
  }

  /// Sauvegarde incrémentale : ne ré-upload pas si rien n'a changé depuis la dernière fois.
  Future<bool> backupIfChanged(String passphrase, SyncBackend backend, String? lastFingerprint) async {
    final items = await _library.getAllActive();
    final fingerprint = '${items.length}_${items.map((i) => i.id).join().hashCode}';
    if (fingerprint == lastFingerprint) return false; // rien à faire
    await backupFullLibraryEncrypted(passphrase, backend);
    return true;
  }
}
```

## 9.4 Rapport de diagnostic — zéro télémétrie automatique

```dart
// lib/core/diagnostics/diagnostic_report_service.dart
class DiagnosticReportService {
  Future<File> generateReport() async {
    final logs = await AppLogger.readRecentLogs(maxLines: 2000); // déjà sanitizé à l'écriture
    final info = await PackageInfo.fromPlatform();
    final report = StringBuffer()
      ..writeln('=== Rapport de diagnostic Libraria ===')
      ..writeln('App version: ${info.version}+${info.buildNumber}')
      ..writeln('Plateforme: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}')
      ..writeln('--- Logs récents ---')..writeln(logs);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/libraria_diagnostic_${DateTime.now().millisecondsSinceEpoch}.txt');
    await file.writeAsString(report.toString());
    return file;
  }
  Future<void> shareReport() async => Share.shareXFiles([XFile((await generateReport()).path)]);
}
```

Aucun SDK tiers (Sentry, Crashlytics) — voir ADR-006.

### ✅ Checklist Partie 9
- [ ] Activer le serveur OPDS, ouvrir l'URL depuis un navigateur sur le même réseau → flux Atom valide
- [ ] Appairer une liseuse réelle (Moon+ Reader/KOReader) si disponible
- [ ] Exporter une sauvegarde chiffrée, la restaurer sur un second appareil de test
- [ ] Générer un rapport de diagnostic, vérifier qu'aucune clé API/passphrase n'apparaît en clair dans le fichier

---

# Partie 10 — Perspectives V3+

Pas de code détaillé ici par choix — ces fonctionnalités dépendent de retours d'usage réels sur V1/V2, coder leur détail aujourd'hui serait spéculatif. Décisions et raisonnement complets dans `/docs/01_DECISIONS.md` et `/docs/10_ROADMAP.md`.

- **Statistiques de lecture locales** — 100 % local, zéro réseau, export Markdown.
- **Recommandations locales** — similarité de Jaccard sur tags/auteur/genre, zéro appel réseau.
- **Bibliothèque multimédia** — films/séries/anime/musique en métadonnées uniquement (TMDb/TVDB/AniList/MusicBrainz), pas de lecteur vidéo intégré.
- **Synchronisation multi-appareils** — Syncthing, WebDAV/NAS, ou Cloudflare Workers ; mêmes primitives de chiffrement que la sauvegarde V2.
- **Recherche locale FTS5** — seulement quand la bibliothèque approche le millier d'items (le `LIKE` actuel suffit avant ça).
- **Profils famille** (ADR-012) et **lecture audio synchronisée** (ADR-013) — sous réserve, voir le raisonnement détaillé dans les ADR correspondants avant de t'engager.

---

*Fin du guide. Pour le « pourquoi » de toute décision référencée ici, voir `/docs`. Pour le suivi des recommandations restantes, voir `/docs/11_BACKLOG.md`.*

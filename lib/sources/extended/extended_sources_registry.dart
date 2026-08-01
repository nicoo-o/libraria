import '../../core/http/http_client.dart';
import '../content_source.dart';
import 'annas_archive_source.dart';
import 'build_flags.dart';
import 'extended_sources_settings.dart';
import 'libgen_source.dart';
import 'scihub_source.dart';
import 'zlibrary_source.dart';

/// Registre unique des sources étendues (GitHub Edition).
///
/// Le composeur d'application (`main.dart`) combine ce registre avec le registre
/// des 4 sources V1 pour construire la liste effective présentée à l'écran de
/// recherche. Sur la Play Store Edition, [allAvailable] et [enabled] renvoient
/// systématiquement `[]` — inutile d'ajouter un `if` dans main.dart, le registre
/// gère lui-même la coupure.
class ExtendedSourcesRegistry {
  ExtendedSourcesRegistry({
    required HttpClient httpClient,
    required ExtendedSourcesSettings settings,
  })  : _httpClient = httpClient,
        _settings = settings;

  final HttpClient _httpClient;
  final ExtendedSourcesSettings _settings;

  /// Toutes les sources étendues *déclarées* pour la GitHub Edition.
  /// Vide sur Play Store Edition.
  List<ContentSource> get allAvailable {
    if (!kExtendedSourcesAvailable) return const <ContentSource>[];
    return <ContentSource>[
      AnnasArchiveSource(httpClient: _httpClient),
      ZLibrarySource(httpClient: _httpClient),
      LibgenSource(httpClient: _httpClient),
      SciHubSource(httpClient: _httpClient),
    ];
  }

  /// Sous-ensemble effectivement activé par l'utilisateur *maintenant*.
  List<ContentSource> get enabled =>
      allAvailable.where((s) => _settings.isEnabled(s.id)).toList(growable: false);
}

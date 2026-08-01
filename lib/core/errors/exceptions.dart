/// Hiérarchie d'exceptions — référence unique.
/// Voir docs/restructuration_claude.md, chapitre 02 (Architecture).
///
/// `CorruptedFileException` était utilisée par `ChecksumVerifier`/`ZipBombGuard` dans une
/// version antérieure du guide sans jamais avoir été déclarée — elle est déclarée ici, une
/// fois pour toutes. Toute nouvelle exception métier DOIT être ajoutée dans ce fichier,
/// jamais redéfinie ailleurs (voir 11_BACKLOG.md, item C-02).
library;

abstract class LibrariaException implements Exception {
  final String technical;
  final String userMessage;
  LibrariaException(this.technical, this.userMessage);

  @override
  String toString() => 'LibrariaException($technical)';
}

/// Erreur réseau : URL invalide, hôte interdit, trop de redirections, timeout, etc.
class NetworkException extends LibrariaException {
  NetworkException(super.technical, super.userMessage);
}

/// Erreur remontée par un `ContentSource` (recherche, circuit breaker ouvert, etc.)
class SourceException extends LibrariaException {
  SourceException(super.technical, super.userMessage);
}

/// Espace disque insuffisant pour démarrer ou poursuivre un téléchargement.
class DiskFullException extends LibrariaException {
  DiskFullException(super.technical, super.userMessage);
}

/// Échec de parsing (JSON/XML d'une source, métadonnées EPUB, etc.)
class ParsingException extends LibrariaException {
  ParsingException(super.technical, super.userMessage);
}

/// Fichier corrompu, suspect (zip-bomb), ou de type invalide (EPUB sans `mimetype`,
/// checksum ne correspondant pas à celui annoncé par la source).
class CorruptedFileException extends LibrariaException {
  CorruptedFileException(super.technical, super.userMessage);
}

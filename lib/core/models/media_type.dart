/// Défini complet dès V1, activé progressivement.
/// V1 filtre l'UI sur `book`/`audiobook` uniquement ; le champ `media_type TEXT` en base
/// accepte toutes les valeurs dès la première migration — activer les autres types en V3
/// ne touche pas au schéma. Voir docs/restructuration_claude.md, chapitre 02.
enum MediaType { book, audiobook, movie, series, anime, music }

extension MediaTypeStorage on MediaType {
  String get storageValue => name;

  static MediaType fromStorage(String value) =>
      MediaType.values.firstWhere((m) => m.name == value, orElse: () => MediaType.book);

  /// V1/V2 : seuls ces deux types sont exposés dans l'UI (00_VISION_ET_PORTEE.md).
  static const activeInV1 = {MediaType.book, MediaType.audiobook};
}

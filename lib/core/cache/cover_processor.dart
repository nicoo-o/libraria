import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Compression à l'enregistrement (ADR-010) : 400×600 maximum, JPEG qualité 85.
/// Toujours réencodé en JPEG, quel que soit le format source (PNG, WebP...) —
/// simplifie le cache (une seule extension possible) et garantit la taille.
///
/// Décoder/redimensionner/encoder une image bloque le thread UI si fait en
/// direct — `compute()` l'exécute dans un isolate séparé, même motif que
/// `ChecksumVerifier`/`ZipBombGuard` ailleurs dans le projet. Charger l'image
/// entière en mémoire ici est acceptable (contrairement aux gros fichiers
/// livre/audio) : une couverture fait au plus quelques centaines de Ko, et
/// décoder une image nécessite de toute façon tous ses pixels en mémoire.
class CoverProcessor {
  static const maxWidth = 400;
  static const maxHeight = 600;
  static const jpegQuality = 85;

  static Future<List<int>> process(List<int> rawBytes) =>
      compute(_processInIsolate, Uint8List.fromList(rawBytes));

  static List<int> _processInIsolate(Uint8List rawBytes) {
    img.Image? image;
    try {
      image = img.decodeImage(rawBytes);
    } catch (_) {
      throw const FormatException('Format image non reconnu');
    }
    if (image == null) {
      throw const FormatException('Format image non reconnu');
    }

    // Ne jamais agrandir une image déjà plus petite que 400×600 — seulement
    // réduire si nécessaire, en conservant les proportions.
    final scale = [1.0, maxWidth / image.width, maxHeight / image.height].reduce((a, b) => a < b ? a : b);

    final resized = scale < 1.0
        ? img.copyResize(
            image,
            width: (image.width * scale).round(),
            height: (image.height * scale).round(),
          )
        : image;

    return img.encodeJpg(resized, quality: jpegQuality);
  }
}

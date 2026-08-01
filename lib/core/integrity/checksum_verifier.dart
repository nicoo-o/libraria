import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

class ChecksumVerifier {
  /// Vérifie en (mode) streaming sans charger tout le fichier en mémoire via un
  /// flux `openRead()`.
  ///
  /// - Si `expectedSha1` est fourni : vérifie SHA-1
  /// - Si `expectedMd5` est fourni : vérifie MD5
  /// - Si les deux sont fournis : exige la concordance des deux
  static Future<bool> verify(
    String filePath, {
    String? expectedSha1,
    String? expectedMd5,
  }) async {
    final sha1Hex = expectedSha1?.toLowerCase();
    final md5Hex = expectedMd5?.toLowerCase();
    if (sha1Hex == null && md5Hex == null) return true;

    return compute(_verifyInIsolate, <String, String?>{
      'path': filePath,
      'sha1': sha1Hex,
      'md5': md5Hex,
    });
  }

  static Future<bool> _verifyInIsolate(Map<String, String?> args) async {
    final path = args['path']!;
    final file = File(path);

    final expectedSha1 = args['sha1'];
    final expectedMd5 = args['md5'];

    // [Correctif] `fold()` accumulait chaque chunk dans une `List<int>` avant de
    // hacher : le fichier ENTIER finissait chargé en mémoire malgré l'usage
    // apparent de `openRead()` — exactement l'anti-pattern que le commentaire
    // ci-dessus (et ZipBombGuard ailleurs) dit vouloir éviter. `sha1.bind`/
    // `md5.bind` (package `crypto`) hachent le flux au fur et à mesure, sans
    // jamais garder le fichier entier en mémoire — même motif que
    // `_sha256Streaming` juste plus bas dans ce fichier.
    if (expectedSha1 != null) {
      final digest = await sha1.bind(file.openRead()).first;
      if (digest.toString().toLowerCase() != expectedSha1) return false;
    }

    if (expectedMd5 != null) {
      final digest = await md5.bind(file.openRead()).first;
      if (digest.toString().toLowerCase() != expectedMd5) return false;
    }

    return true;
  }

  /// SHA-256 complet (utilisé par Import/duplication) — calcul isolé.
  static Future<String> computeStreaming(File file) async {
    return compute(_sha256Streaming, file.path);
  }

  static Future<String> _sha256Streaming(String path) async {
    final f = File(path);
    final digest = sha256.bind(f.openRead());
    return (await digest.first).toString();
  }
}

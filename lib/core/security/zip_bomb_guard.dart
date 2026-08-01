import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import '../errors/exceptions.dart';

class ZipBombGuard {
  static const _maxRatio = 200;
  static const _maxUncompressedBytes = 200 * 1024 * 1024;

  /// Decompression et verification en flux (`compute()` + `openRead()`), JAMAIS
  /// `readAsBytes()` sur un fichier qui peut depasser quelques Mo -- un audiobook de
  /// 800 Mo charge entier en RAM sur le thread principal est un risque reel d'OOM et
  /// de gel UI. Appele apres telechargement (DownloadManager) et avant ouverture d'un
  /// import local.
  static Future<void> check(String filePath) => compute(_checkInIsolate, filePath);

  static Future<void> _checkInIsolate(String filePath) async {
    final file = File(filePath);
    final compressed = await file.length();
    final inputStream = InputFileStream(filePath);
    try {
      final archive = ZipDecoder().decodeBuffer(inputStream); // decodage en flux, pas decodeBytes()
      var uncompressed = 0;
      var mimetypeFound = false;
      for (final entry in archive.files) {
        uncompressed += entry.size.toInt();
        if (uncompressed > _maxUncompressedBytes) {
          throw CorruptedFileException('ZIP bomb suspected', 'Fichier EPUB corrompu ou suspect');
        }
        if (entry.name == 'mimetype') mimetypeFound = true;
      }
      if (compressed > 0 && uncompressed / compressed > _maxRatio) {
        throw CorruptedFileException('ZIP bomb ratio', 'Fichier EPUB corrompu ou suspect');
      }
      if (!mimetypeFound) {
        throw CorruptedFileException('Not a valid EPUB', 'Fichier invalide');
      }
    } finally {
      inputStream.closeSync();
    }
  }
}
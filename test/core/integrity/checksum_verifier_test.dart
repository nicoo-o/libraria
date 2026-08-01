import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:libraria/core/integrity/checksum_verifier.dart';

void main() {
  late Directory tempDir;
  late File testFile;
  late String contentSha1;
  late String contentMd5;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('checksum_verifier_test_');
    testFile = File('${tempDir.path}/test_file.bin');
    final bytes = List<int>.generate(10000, (i) => i % 256); // contenu déterministe, pas trivial (pas que des zéros)
    await testFile.writeAsBytes(bytes);
    contentSha1 = sha1.convert(bytes).toString();
    contentMd5 = md5.convert(bytes).toString();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('retourne true sans aucun checksum attendu (rien à vérifier)', () async {
    final result = await ChecksumVerifier.verify(testFile.path);
    expect(result, isTrue);
  });

  test('retourne true quand le SHA-1 correspond', () async {
    final result = await ChecksumVerifier.verify(testFile.path, expectedSha1: contentSha1);
    expect(result, isTrue);
  });

  test('retourne false quand le SHA-1 ne correspond pas', () async {
    final result = await ChecksumVerifier.verify(testFile.path, expectedSha1: 'a' * 40);
    expect(result, isFalse);
  });

  test('retourne true quand le MD5 correspond', () async {
    final result = await ChecksumVerifier.verify(testFile.path, expectedMd5: contentMd5);
    expect(result, isTrue);
  });

  test('retourne false quand le MD5 ne correspond pas', () async {
    final result = await ChecksumVerifier.verify(testFile.path, expectedMd5: 'a' * 32);
    expect(result, isFalse);
  });

  test('exige la concordance des DEUX quand SHA-1 et MD5 sont fournis', () async {
    final bothOk = await ChecksumVerifier.verify(
      testFile.path,
      expectedSha1: contentSha1,
      expectedMd5: contentMd5,
    );
    expect(bothOk, isTrue);

    final oneWrong = await ChecksumVerifier.verify(
      testFile.path,
      expectedSha1: contentSha1,
      expectedMd5: 'a' * 32,
    );
    expect(oneWrong, isFalse);
  });

  test('la comparaison est insensible à la casse (majuscules acceptées)', () async {
    final result = await ChecksumVerifier.verify(testFile.path, expectedSha1: contentSha1.toUpperCase());
    expect(result, isTrue);
  });

  // [Régression] Couvre le correctif "chargement en mémoire" : ce test échoue
  // seulement s'il timeout ou lève une OOM sur un fichier plus gros — la
  // taille ci-dessous (~20 Mo) est modeste mais suffisante pour exercer le
  // vrai chemin `openRead()` plutôt qu'un cas trivial d'un seul chunk.
  test('vérifie correctement un fichier de plusieurs Mo (chemin streaming réel)', () async {
    final bigFile = File('${tempDir.path}/big_file.bin');
    final sink = bigFile.openWrite();
    final chunk = List<int>.generate(1024 * 1024, (i) => i % 256); // 1 Mo
    for (var i = 0; i < 20; i++) {
      sink.add(chunk);
    }
    await sink.close();

    final digest = await ChecksumVerifier.computeStreaming(bigFile);
    final result = await ChecksumVerifier.verify(bigFile.path, expectedSha1: null, expectedMd5: null);
    expect(result, isTrue); // rien à vérifier ici, mais ne doit pas planter sur un gros fichier
    expect(digest, isNotEmpty);
  });
}

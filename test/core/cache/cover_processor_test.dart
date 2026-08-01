import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:libraria/core/cache/cover_processor.dart';

void main() {
  List<int> buildPng(int width, int height) {
    // La couleur des pixels n'a aucune importance pour ces tests (seules les
    // dimensions et la décodabilité sont vérifiées) — image non retouchée.
    final image = img.Image(width, height);
    return img.encodePng(image);
  }

  test('redimensionne une image plus grande que 400×600 en conservant les proportions', () async {
    final source = buildPng(1000, 1500); // ratio 2:3, comme une vraie couverture de livre

    final processed = await CoverProcessor.process(source);
    final result = img.decodeJpg(processed)!;

    expect(result.width, lessThanOrEqualTo(CoverProcessor.maxWidth));
    expect(result.height, lessThanOrEqualTo(CoverProcessor.maxHeight));
    // Proportions conservées (à l'arrondi près) : 1000/1500 == largeur/hauteur.
    expect((result.width / result.height - 1000 / 1500).abs(), lessThan(0.01));
  });

  test('n\'agrandit jamais une image déjà plus petite que 400×600', () async {
    final source = buildPng(100, 150);

    final processed = await CoverProcessor.process(source);
    final result = img.decodeJpg(processed)!;

    expect(result.width, 100);
    expect(result.height, 150);
  });

  // [Régression] `filename = '${job.id}.jpg'` dans DownloadManager suppose que
  // la sortie est TOUJOURS un JPEG, quel que soit le format source — sinon
  // l'extension du fichier ne correspondrait pas à son contenu réel.
  test('réencode toujours en JPEG, même si la source est un PNG', () async {
    final source = buildPng(200, 300);
    final processed = await CoverProcessor.process(source);

    // Un JPEG valide se décode avec decodeJpg ; un PNG lèverait/retournerait null.
    expect(img.decodeJpg(processed), isNotNull);
  });

  test('lève une exception explicite si les octets ne sont pas une image valide', () async {
    await expectLater(
      CoverProcessor.process([1, 2, 3, 4, 5]),
      throwsA(isA<FormatException>()),
    );
  });

  test('respecte la limite de largeur même pour une image très large et peu haute', () async {
    final source = buildPng(2000, 100); // paysage extrême

    final processed = await CoverProcessor.process(source);
    final result = img.decodeJpg(processed)!;

    expect(result.width, lessThanOrEqualTo(CoverProcessor.maxWidth));
    expect(result.height, lessThanOrEqualTo(CoverProcessor.maxHeight));
  });
}

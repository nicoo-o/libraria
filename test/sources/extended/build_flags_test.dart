import 'package:flutter_test/flutter_test.dart';
import 'package:libraria/sources/extended/build_flags.dart';

void main() {
  test('kExtendedSourcesAvailable est false par défaut (Play Store Edition)', () {
    // Ce test est lancé sans --dart-define=EXTENDED_SOURCES=true.
    // Il valide que la valeur par défaut protège bien la Play Store Edition.
    // Le job CI dédié GitHub Edition doit être lancé séparément avec le flag.
    expect(kExtendedSourcesAvailable, isFalse);
  });
}

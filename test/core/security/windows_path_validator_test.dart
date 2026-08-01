import 'package:flutter_test/flutter_test.dart';

import 'package:libraria/core/security/windows_path_validator.dart';

void main() {
  test('accepte un chemin vide de tout problème', () {
    expect(WindowsPathValidator.validate(r'C:\Users\test\Documents\book.epub'), isNull);
  });

  test('rejette un chemin vide', () {
    expect(WindowsPathValidator.validate(''), 'path.empty');
  });

  test('rejette un chemin dépassant legacyMax (260) sans support des chemins longs', () {
    final longPath = r'C:\' + ('a' * 300);
    expect(WindowsPathValidator.validate(longPath), 'path.too_long');
  });

  test('accepte un chemin dépassant 260 caractères si longPathSupport est activé', () {
    final longPath = r'C:\' + ('a' * 300);
    expect(WindowsPathValidator.validate(longPath, longPathSupport: true), isNull);
  });

  test('rejette toujours un chemin dépassant longPathMax même avec longPathSupport', () {
    final tooLong = r'C:\' + ('a' * 40000);
    expect(WindowsPathValidator.validate(tooLong, longPathSupport: true), 'path.too_long');
  });

  test('rejette un segment se terminant par un espace (Windows les ignore silencieusement)', () {
    expect(WindowsPathValidator.validate(r'C:\Users\test \book.epub'), 'path.trailing_dot_or_space');
  });

  test('rejette un segment se terminant par un point (réservé Windows)', () {
    expect(WindowsPathValidator.validate(r'C:\Users\test.\book.epub'), 'path.trailing_dot_or_space');
  });

  test('accepte un point final sur le nom de FICHIER lui-même s\'il n\'est pas un segment intermédiaire',
      () {
    // Le dernier segment est "book.epub" qui ne se termine ni par un espace ni
    // par un point isolé -> valide.
    expect(WindowsPathValidator.validate(r'C:\Users\test\book.epub'), isNull);
  });

  test('gère les séparateurs mixtes (/ et \\)', () {
    expect(WindowsPathValidator.validate(r'C:/Users\test/book.epub'), isNull);
    expect(WindowsPathValidator.validate('C:/Users /test/book.epub'), 'path.trailing_dot_or_space');
  });
}

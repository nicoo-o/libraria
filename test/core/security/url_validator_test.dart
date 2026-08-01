import 'package:flutter_test/flutter_test.dart';
import 'package:libraria/core/errors/exceptions.dart';
import 'package:libraria/core/security/url_validator.dart';

void main() {
  group('UrlValidator', () {
    test('accepte une URL https publique', () {
      expect(() => UrlValidator.validate('https://example.com/book.epub'), returnsNormally);
    });

    test('rejette localhost par défaut', () {
      expect(() => UrlValidator.validate('http://localhost/x'), throwsA(isA<NetworkException>()));
    });

    test('rejette un schéma non http(s)', () {
      expect(() => UrlValidator.validate('file:///etc/passwd'), throwsA(isA<NetworkException>()));
    });

    test('rejette une IP privée 192.168.x.x par défaut', () {
      expect(() => UrlValidator.validate('http://192.168.1.1/x'), throwsA(isA<NetworkException>()));
    });

    test('autorise une IP privée si allowPrivateNetwork: true (connecteurs LAN)', () {
      expect(
        () => UrlValidator.validate('http://192.168.1.1/x', allowPrivateNetwork: true),
        returnsNormally,
      );
    });

    test('isPrivateIp reconnaît les plages RFC 1918', () {
      expect(UrlValidator.isPrivateIp('10.0.0.5'), isTrue);
      expect(UrlValidator.isPrivateIp('172.16.0.5'), isTrue);
      expect(UrlValidator.isPrivateIp('172.32.0.5'), isFalse); // hors plage 16-31
      expect(UrlValidator.isPrivateIp('8.8.8.8'), isFalse);
    });
  });
}

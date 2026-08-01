import 'package:flutter_test/flutter_test.dart';

import 'package:libraria/core/security/certificate_validator.dart';

void main() {
  test('refuse toujours si l\'utilisateur n\'a pas explicitement opté (userOptIn: false)', () {
    expect(
      CertificateValidator.shouldAllowSelfSigned(uri: Uri.parse('https://localhost:8080'), userOptIn: false),
      isFalse,
    );
  });

  test('autorise localhost si userOptIn est vrai', () {
    expect(
      CertificateValidator.shouldAllowSelfSigned(uri: Uri.parse('https://localhost:8080'), userOptIn: true),
      isTrue,
    );
  });

  test('autorise un domaine .local si userOptIn est vrai', () {
    expect(
      CertificateValidator.shouldAllowSelfSigned(uri: Uri.parse('https://nas.local'), userOptIn: true),
      isTrue,
    );
  });

  test('autorise une IP privée (192.168.x.x) si userOptIn est vrai', () {
    expect(
      CertificateValidator.shouldAllowSelfSigned(uri: Uri.parse('https://192.168.1.10'), userOptIn: true),
      isTrue,
    );
  });

  // [Sécurité] Le point le plus important de ce validateur : même avec
  // userOptIn à true, un hôte Internet public ne doit JAMAIS être autorisé à
  // présenter un certificat auto-signé — sinon n'importe quel site pourrait en
  // profiter, pas seulement le NAS/serveur local visé par ce mécanisme.
  test('refuse toujours un hôte Internet public, même avec userOptIn à true', () {
    expect(
      CertificateValidator.shouldAllowSelfSigned(uri: Uri.parse('https://example.com'), userOptIn: true),
      isFalse,
    );
    expect(
      CertificateValidator.shouldAllowSelfSigned(uri: Uri.parse('https://8.8.8.8'), userOptIn: true),
      isFalse,
    );
  });
}

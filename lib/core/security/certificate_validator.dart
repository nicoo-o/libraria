import 'url_validator.dart';

class CertificateValidator {
  static bool shouldAllowSelfSigned({required Uri uri, required bool userOptIn}) {
    if (!userOptIn) return false;
    if (uri.host == 'localhost' || uri.host.endsWith('.local')) return true;
    if (UrlValidator.isPrivateIp(uri.host)) return true;
    return false; // Internet public : jamais
  }
}

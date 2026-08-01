import '../errors/exceptions.dart';

class UrlValidator {
  static const _allowedSchemes = {'http', 'https'};
  static const _blockedHosts = {'localhost', '127.0.0.1', '0.0.0.0', '::1'};

  static Uri validate(String url, {bool allowPrivateNetwork = false}) {
    final uri = Uri.tryParse(url);
    if (uri == null) throw NetworkException('Invalid URL', 'URL invalide');
    if (!_allowedSchemes.contains(uri.scheme)) {
      throw NetworkException('Forbidden scheme: ${uri.scheme}', 'Schéma non autorisé');
    }
    if (!allowPrivateNetwork && (_blockedHosts.contains(uri.host) || isPrivateIp(uri.host))) {
      throw NetworkException('Forbidden host: ${uri.host}', 'Hôte non autorisé pour cette source');
    }
    return uri;
  }

  /// `allowPrivateNetwork: true` réservé aux connecteurs LAN explicites (OPDS local,
  /// Prowlarr) — jamais aux 4 sources publiques V1.
  static bool isPrivateIp(String host) {
    final parts = host.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((p) => p == null)) return false;
    final a = parts[0]!, b = parts[1]!;
    return a == 10 || (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 168);
  }
}

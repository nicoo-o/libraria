import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../logging/app_logger.dart';

/// Notifie l'UI (bannière hors-ligne, 08_UI_UX_DESIGN_SYSTEM.md) et sert de point de
/// branchement pour la reprise groupée après reconnexion (chapitre 12, NF-035 :
/// `downloadManager.resumeAll()` sur transition offline → online).
class ConnectivityService extends ChangeNotifier {
  /// [Testabilité] `connectivity` injectable — sans ce point d'entrée, tout
  /// test widget qui monte `LibrariaApp` (donc `ConnectivityService`) toucherait
  /// le vrai canal de plateforme `connectivity_plus`, absent en environnement
  /// `flutter test` (MissingPluginException).
  ConnectivityService({Connectivity? connectivity}) : _connectivity = connectivity ?? Connectivity() {
    _sub = _connectivity.onConnectivityChanged.listen(_onChanged);
    // [Correctif] `onConnectivityChanged` n'émet que sur un CHANGEMENT, jamais
    // l'état courant au moment de l'abonnement — sans cet appel, `isOnline`
    // restait à `true` (sa valeur par défaut) si l'app démarrait déjà hors
    // ligne, jusqu'au prochain changement de connectivité (qui peut ne jamais
    // survenir pendant toute la session). La bannière hors-ligne (Partie 7)
    // ne se serait alors jamais affichée pour un démarrage hors-ligne.
    _connectivity.checkConnectivity().then(_onChanged);
  }

  final Connectivity _connectivity;
  bool isOnline = true;
  late final dynamic _sub;

  /// Callback injecté depuis main.dart (chapitre 12, NF-035) — pas d'import
  /// direct de DownloadManager ici pour éviter un cycle core/ → download_manager/.
  VoidCallback? onReconnected;

  void _onChanged(List<ConnectivityResult> results) {
    AppLogger.info('Connectivity changed: $results', module: 'CONNECTIVITY');
    final wasOnline = isOnline;
    isOnline = results.any((r) => r != ConnectivityResult.none);
    if (!wasOnline && isOnline) {
      AppLogger.info('Reconnected, triggering onReconnected callback', module: 'CONNECTIVITY');
      onReconnected?.call();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

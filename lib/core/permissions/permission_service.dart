import 'package:permission_handler/permission_handler.dart';

import '../logging/app_logger.dart';

class PermissionService {
  /// Reessaie une demande de permission si l'Activity Android n'est pas encore
  /// detectee par le plugin (arrive parfois sur un cold start, meme apres
  /// addPostFrameCallback, si l'attachement natif de l'Activity est legerement
  /// en retard sur le premier frame Flutter). Sans ce garde-fou, l'appel echoue
  /// silencieusement avec une PlatformException non recuperable.
  static Future<PermissionStatus> _requestWithRetry(
    Permission permission, {
    // [Correctif] 3 tentatives / ~1,5s cumule s'est revele insuffisant sur un
    // emulateur charge (Gradle/GC encore actifs juste apres le cold start) : le
    // Davey frame de plus d'1s observe montre que l'attachement natif de
    // l'Activity peut prendre plusieurs secondes. 8 tentatives / delai croissant
    // (jusqu'a ~14s cumules dans le pire cas) restent invisibles pour l'usager
    // sur un device normal, ou ca reussit des la 1ere tentative.
    int maxAttempts = 8,
  }) async {
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await permission.request();
      } catch (e) {
        final isActivityNotReady = e.toString().contains('Unable to detect current Android Activity');
        if (!isActivityNotReady || attempt == maxAttempts) {
          rethrow;
        }
        AppLogger.info(
          'Activity Android pas encore prete, nouvelle tentative ($attempt/$maxAttempts)',
          module: 'PERMISSIONS',
        );
        await Future.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
    // Inatteignable (la derniere iteration rethrow ou return), mais requis par l'analyseur.
    return PermissionStatus.denied;
  }

  static Future<bool> requestStoragePermissions() async {
    final imagesStatus = await _requestWithRetry(Permission.photos);
    if (imagesStatus.isLimited) {
      AppLogger.info('Acces image partiel accorde (Android 14+)', module: 'PERMISSIONS');
    }
    final audioStatus = await _requestWithRetry(Permission.audio);
    return audioStatus.isGranted || imagesStatus.isGranted || imagesStatus.isLimited;
  }

  static Future<bool> requestNotificationPermission() async =>
      (await _requestWithRetry(Permission.notification)).isGranted;
}
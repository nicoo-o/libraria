import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../logging/app_logger.dart';

/// Rapport de diagnostic exportable, déclenché manuellement — zéro télémétrie
/// automatique, zéro SDK tiers (ADR-006). Les logs sont déjà sanitizés par
/// `LogSanitizer` avant même d'entrer dans `AppLogger` (03_SECURITE.md).
class DiagnosticReportService {
  Future<File> generateReport() async {
    final logs = await AppLogger.readRecentLogs(maxLines: 2000);
    final info = await PackageInfo.fromPlatform();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/libraria_diagnostic_${DateTime.now().millisecondsSinceEpoch}.txt');

    final buffer = StringBuffer()
      ..writeln('Libraria — Rapport de diagnostic')
      ..writeln('Version : ${info.version}+${info.buildNumber}')
      ..writeln('Généré le : ${DateTime.now().toIso8601String()}')
      ..writeln('---')
      ..writeln(logs.join('\n'));

    await file.writeAsString(buffer.toString());
    return file;
  }

  /// Utilise le package `share_plus` (budgété au chapitre 12, R1'' — NF-090).
  /// [Correctif] `Share.shareXFiles()` est dépréciée depuis share_plus v10 —
  /// `SharePlus.instance.share(ShareParams(...))` est la nouvelle API stable.
  Future<void> shareReport() async {
    final file = await generateReport();
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }
}

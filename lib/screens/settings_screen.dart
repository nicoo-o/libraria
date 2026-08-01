import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../backup/backup_service.dart';
import '../core/diagnostics/diagnostic_report_service.dart';
import '../l10n/app_localizations.dart';
import '../library/settings_repository.dart';
import '../sources/extended/build_flags.dart';
import '../sources/extended/extended_sources_registry.dart';
import '../sources/extended/extended_sources_settings.dart';
import 'trash_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: ListView(
        children: [
          // [Correctif ADR-011] softDelete() existait déjà côté repository,
          // mais aucun écran ne permettait de voir ni restaurer les éléments
          // supprimés — ils restaient invisibles jusqu'à la purge à 30 jours.
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: Text(l10n.trashTitle),
            subtitle: Text(l10n.trashSubtitle),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrashScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: Text(l10n.settingsDiagnosticTitle),
            subtitle: Text(l10n.settingsDiagnosticSubtitle),
            onTap: () => DiagnosticReportService().shareReport(),
          ),
          // [Correctif — bug réel trouvé en test réel] Aucun moyen de
          // désactiver individuellement une des 4 sources V1 de base
          // n'existait dans Réglages — seules les sources ÉTENDUES
          // (GitHub Edition, section plus bas) avaient un tel toggle.
          const _CoreSourcesSection(),
          // Section « Sources étendues » — n'apparaît QUE sur GitHub Edition
          // (ADR-014). Sur Play Store Edition, kExtendedSourcesAvailable == false
          // et cette section n'est pas construite.
          if (kExtendedSourcesAvailable) const _ExtendedSourcesSection(),
          // [Chapitre 12, NF-061/NF-062 — trou comblé] Aucun module de
          // sauvegarde n'existait avant ce correctif (voir audit V1).
          const _BackupSection(),
          // TODO (P1) : concurrence max des téléchargements (1-6), thème clair/sombre,
          // verrouillage par PIN (proposition #10), sauvegarde WebDAV (V2 — NF-061/062
          // ci-dessus couvrent la sauvegarde LOCALE, pas WebDAV).
        ],
      ),
    );
  }
}

class _ExtendedSourcesSection extends StatelessWidget {
  const _ExtendedSourcesSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = context.watch<ExtendedSourcesSettings>();
    final registry = context.read<ExtendedSourcesRegistry>();
    final sources = registry.allAvailable;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 32),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            l10n.settingsExtendedSourcesTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            l10n.settingsExtendedSourcesWarning,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        for (final source in sources)
          SwitchListTile(
            title: Text(source.displayName),
            subtitle: Text(l10n.settingsSourceIdLabel(source.id)),
            value: settings.isEnabled(source.id),
            onChanged: (v) => settings.setEnabled(source.id, v),
          ),
      ],
    );
  }
}

/// [Correctif — bug réel trouvé en test réel] Activer/désactiver une des 4
/// sources V1 de base — le mécanisme équivalent existait déjà pour les
/// sources étendues (`_ExtendedSourcesSection`/`ExtendedSourcesSettings`)
/// mais pas pour ces 4-là, filtrées nulle part dans `search_screen.dart`
/// avant ce correctif.
class _CoreSourcesSection extends StatefulWidget {
  const _CoreSourcesSection();

  @override
  State<_CoreSourcesSection> createState() => _CoreSourcesSectionState();
}

class _CoreSourcesSectionState extends State<_CoreSourcesSection> {
  // (id, displayName) — pas besoin des instances ContentSource réelles ici,
  // juste de quoi afficher/persister le choix ; search_screen.dart applique
  // le filtre au moment de chercher.
  static const _coreSources = [
    ('gutenberg', 'Project Gutenberg'),
    ('internet_archive', 'Internet Archive'),
    ('librivox', 'LibriVox'),
    ('standard_ebooks', 'Standard Ebooks'),
  ];

  final Map<String, bool> _enabled = {};

  @override
  void initState() {
    super.initState();
    unawaited(_loadAll());
  }

  Future<void> _loadAll() async {
    final settings = context.read<SettingsRepository>();
    final loaded = <String, bool>{};
    for (final (id, _) in _coreSources) {
      loaded[id] = await settings.isSourceEnabled(id);
    }
    if (mounted) setState(() => _enabled.addAll(loaded));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = context.read<SettingsRepository>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 32),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(l10n.settingsCoreSourcesTitle, style: Theme.of(context).textTheme.titleMedium),
        ),
        for (final (id, displayName) in _coreSources)
          SwitchListTile(
            title: Text(displayName),
            value: _enabled[id] ?? true,
            onChanged: (v) {
              setState(() => _enabled[id] = v);
              unawaited(settings.setSourceEnabled(id, v));
            },
          ),
      ],
    );
  }
}
/// voir backup_service.dart pour le détail du périmètre (DB + couvertures,
/// sans WebDAV) et de la vérification d'intégrité.
class _BackupSection extends StatefulWidget {
  const _BackupSection();

  @override
  State<_BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends State<_BackupSection> {
  bool _running = false;
  late Future<List<BackupEntry>> _backups;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _backups = context.read<BackupService>().listBackups();
  }

  String _formatSize(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} Ko';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  Future<void> _runBackup() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _running = true);
    try {
      final result = await context.read<BackupService>().createBackup();
      final size = await result.archiveFile.length();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.settingsBackupSuccess(_formatSize(size)))));
      setState(_refresh);
    } catch (_) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text(l10n.settingsBackupFailure)));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _verify(BackupEntry entry) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await context.read<BackupService>().verifyBackup(entry.file);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(ok ? l10n.settingsBackupVerifyOk : l10n.settingsBackupVerifyFailed)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 32),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(l10n.settingsBackupTitle, style: Theme.of(context).textTheme.titleMedium),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(l10n.settingsBackupWarning, style: const TextStyle(fontSize: 12)),
        ),
        ListTile(
          leading: _running
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.backup_outlined),
          title: Text(l10n.settingsBackupCreate),
          subtitle: Text(l10n.settingsBackupSubtitle),
          onTap: _running ? null : _runBackup,
        ),
        FutureBuilder<List<BackupEntry>>(
          future: _backups,
          builder: (context, snapshot) {
            final backups = snapshot.data ?? [];
            if (backups.isEmpty) return const SizedBox.shrink();
            return Column(
              children: [
                for (final entry in backups.take(5))
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.archive_outlined),
                    title: Text(p.basename(entry.file.path), overflow: TextOverflow.ellipsis),
                    subtitle: Text(_formatSize(entry.sizeBytes)),
                    trailing: IconButton(
                      icon: const Icon(Icons.verified_outlined),
                      tooltip: l10n.settingsBackupVerify,
                      onPressed: () => _verify(entry),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

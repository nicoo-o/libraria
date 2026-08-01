import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/download_job.dart';
import '../download_manager/download_manager.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';

class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dm = context.watch<DownloadManager>();
    final downloadingCount = dm.jobs.where((j) => j.status == DownloadStatus.downloading).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.queueTitle(downloadingCount, dm.maxConcurrent)),
      ),
      body: dm.jobs.isEmpty
          ? Center(child: Text(l10n.queueEmpty))
          : ListView.builder(
              itemCount: dm.jobs.length,
              itemBuilder: (context, i) {
                final job = dm.jobs[i];

                return ListTile(
                  title: Text(job.result.title),
                  subtitle: job.status == DownloadStatus.completed
                      ? Text(l10n.queueCompleted)
                      : LinearProgressIndicator(
                          value: job.progress,
                          minHeight: 6,
                        ),
                  trailing: _JobActions(job: job),
                );
              },
            ),
    );
  }
}

class _JobActions extends StatelessWidget {
  final DownloadJob job;
  const _JobActions({required this.job});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dm = context.read<DownloadManager>();

    return switch (job.status) {
      DownloadStatus.downloading => IconButton(
          icon: const Icon(Icons.pause_circle_outline),
          tooltip: l10n.pause,
          onPressed: () => dm.pauseJob(job.id),
        ),
      DownloadStatus.paused => IconButton(
          icon: const Icon(Icons.play_circle_outline),
          tooltip: l10n.resume,
          onPressed: () => dm.resumeJob(job.id),
        ),
      DownloadStatus.failed => IconButton(
          icon: const Icon(Icons.refresh),
          color: AppColors.accent,
          tooltip: l10n.retry,
          onPressed: () => dm.resumeJob(job.id),
        ),
      DownloadStatus.completed => const Icon(Icons.check_circle, color: AppColors.accent),

      _ => Text(job.status.name),
    };
  }
}


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/library_item.dart';
import '../l10n/app_localizations.dart';
import '../library/library_change_notifier.dart';
import '../library/library_repository.dart';

/// Corbeille — 2ᵉ palier de sécurité avant suppression réelle (ADR-011,
/// docs/restructuration_claude.md). `softDelete()` posait déjà `deleted_at`
/// depuis le début, mais aucun écran ne permettait de voir ni de restaurer les
/// éléments concernés — ils restaient invisibles jusqu'à la purge à 30 jours.
class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  late Future<List<LibraryItem>> _items;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _items = context.read<LibraryRepository>().getTrash();
  }

  Future<void> _restore(LibraryItem item) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await context.read<LibraryRepository>().restore(item.id);
    if (!mounted) return;
    context.read<LibraryChangeNotifier>().notifyChanged();
    setState(_refresh);
    messenger.showSnackBar(SnackBar(content: Text(l10n.trashItemRestored(item.title))));
  }

  static const _purgeAfterDays = 30; // doit rester cohérent avec l'appel purgeDeletedOlderThan() côté main.dart

  int _daysRemaining(LibraryItem item) {
    final deletedAt = item.deletedAt;
    if (deletedAt == null) return _purgeAfterDays; // ne devrait pas arriver ici (getTrash() filtre déjà)
    final elapsed = DateTime.now().difference(deletedAt).inDays;
    final remaining = _purgeAfterDays - elapsed;
    return remaining < 0 ? 0 : remaining;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.trashTitle)),
      body: FutureBuilder<List<LibraryItem>>(
        future: _items,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final items = snapshot.data!;
          if (items.isEmpty) {
            return Center(child: Text(l10n.trashEmpty));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              return ListTile(
                title: Text(item.title),
                subtitle: Text(l10n.trashDaysRemaining(_daysRemaining(item))),
                trailing: TextButton(
                  onPressed: () => _restore(item),
                  child: Text(l10n.trashRestore),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

import 'dart:convert';

import 'package:csv/csv.dart';

import '../core/models/media_type.dart';
import '../core/models/library_item.dart';

/// Export de la bibliothèque — JSON (sauvegarde chiffrée, 03_SECURITE.md) et CSV
/// (chapitre 12, NF-091/099, déjà budgété dans MES_PROPOSITIONS_LIBRARIA.md Partie 2).
class LibraryExporter {
  Future<String> exportJson(List<LibraryItem> items) async {
    return jsonEncode(items.map((i) => i.toMap()).toList());
  }

  String exportCsv(List<LibraryItem> items) {
    final rows = [
      ['Titre', 'Auteur', 'Type', 'Progression', 'Note', 'Genre', 'Année'],
      ...items.map((i) => [
            i.title,
            i.author ?? '',
            i.mediaType.storageValue,
            i.readProgress.toStringAsFixed(2),
            i.rating?.toString() ?? '',
            i.genre ?? '',
            i.year?.toString() ?? '',
          ]),
    ];
    return const ListToCsvConverter().convert(rows);
  }
}

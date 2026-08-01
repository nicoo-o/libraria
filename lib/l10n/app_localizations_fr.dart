// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get navLibrary => 'Bibliothèque';

  @override
  String get navSearch => 'Recherche';

  @override
  String get navDownloads => 'Téléchargements';

  @override
  String get navSettings => 'Paramètres';

  @override
  String get offlineBanner =>
      'Hors ligne — recherche et téléchargements en pause';

  @override
  String get libraryEmptyState =>
      'Ta bibliothèque est vide — commence par une recherche.';

  @override
  String get searchHint => 'Rechercher un livre ou un audiobook…';

  @override
  String get searchNoResults => 'Aucun résultat pour cette recherche.';

  @override
  String searchSourcesUnavailable(String sources) {
    return 'Sources indisponibles : $sources';
  }

  @override
  String get retry => 'Réessayer';

  @override
  String get downloadTooltip => 'Télécharger';

  @override
  String get sourceStatusAvailable => 'Disponible';

  @override
  String get sourceStatusRecovering => 'Reprise en cours';

  @override
  String get sourceStatusUnavailable => 'Indisponible';

  @override
  String get searchAlreadyOwned => 'Déjà dans votre bibliothèque';

  @override
  String queueTitle(int downloading, int max) {
    return 'Téléchargements ($downloading/$max actifs)';
  }

  @override
  String get queueEmpty => 'Aucun téléchargement en cours.';

  @override
  String get queueCompleted => 'Terminé';

  @override
  String get pause => 'Mettre en pause';

  @override
  String get resume => 'Reprendre';

  @override
  String get settingsDiagnosticTitle => 'Partager un rapport de diagnostic';

  @override
  String get settingsDiagnosticSubtitle =>
      'Zéro télémétrie automatique — envoi manuel uniquement (ADR-006).';

  @override
  String get settingsBackupTitle => 'Sauvegarde locale';

  @override
  String get settingsBackupWarning =>
      'Sauvegarde la bibliothèque, les réglages et les couvertures — pas les fichiers EPUB/audio eux-mêmes (re-téléchargeables depuis leurs sources).';

  @override
  String get settingsBackupCreate => 'Créer une sauvegarde';

  @override
  String get settingsBackupSubtitle =>
      'Archive locale, avec vérification d\'intégrité';

  @override
  String settingsBackupSuccess(String size) {
    return 'Sauvegarde créée ($size).';
  }

  @override
  String get settingsBackupFailure => 'La sauvegarde a échoué.';

  @override
  String get settingsBackupVerify => 'Vérifier l\'intégrité';

  @override
  String get settingsBackupVerifyOk =>
      'Intégrité vérifiée — l\'archive n\'a pas été altérée.';

  @override
  String get settingsBackupVerifyFailed =>
      'Échec de vérification — l\'archive semble corrompue ou modifiée.';

  @override
  String get settingsCoreSourcesTitle => 'Sources de recherche';

  @override
  String get settingsExtendedSourcesTitle =>
      'Sources étendues (GitHub Edition)';

  @override
  String get settingsExtendedSourcesWarning =>
      'Désactivées par défaut. Ces sources agrègent des catalogues au statut juridique variable selon les pays. Vous êtes responsable de leur usage.';

  @override
  String settingsSourceIdLabel(String id) {
    return 'Identifiant : $id';
  }

  @override
  String get mediaDetailUnknownAuthor => 'Auteur inconnu';

  @override
  String get mediaDetailOpen => 'Ouvrir';

  @override
  String get mediaDetailDelete => 'Supprimer';

  @override
  String get mediaDetailDeleteConfirmTitle => 'Mettre à la corbeille ?';

  @override
  String mediaDetailDeleteConfirmBody(String title) {
    return '« $title » sera déplacé vers la corbeille et supprimé définitivement après 30 jours. Vous pourrez le restaurer avant cette échéance.';
  }

  @override
  String get cancel => 'Annuler';

  @override
  String get mediaDetailMissingFile =>
      'Le fichier local de cet ouvrage est introuvable.';

  @override
  String get mediaDetailRelink => 'Relier le fichier';

  @override
  String get mediaDetailRelinkSuccess => 'Fichier relié avec succès.';

  @override
  String get mediaDetailMarkAsRead => 'Marquer comme lu';

  @override
  String get mediaDetailMarkedAsRead => 'Lu ✓';

  @override
  String mediaDetailDeletedUndo(String title) {
    return '« $title » a été déplacé vers la corbeille.';
  }

  @override
  String get undo => 'Annuler';

  @override
  String get readerNoLocalFile => 'Aucun fichier local associé à cet ouvrage.';

  @override
  String get audioNoFilesFound => 'Aucun fichier audio trouvé dans ce dossier.';

  @override
  String audioLoadError(String error) {
    return 'Impossible de lire ce fichier audio : $error';
  }

  @override
  String get audioRewind30 => 'Reculer de 30 secondes';

  @override
  String get audioForward30 => 'Avancer de 30 secondes';

  @override
  String get audioPlay => 'Lire';

  @override
  String get audioLoadErrorGeneric =>
      'La lecture de ce fichier audio a échoué.';

  @override
  String get audioChaptersTitle => 'Chapitres';

  @override
  String audioChapterNumber(int number) {
    return 'Chapitre $number';
  }

  @override
  String get audioBackgroundHint =>
      'La lecture continue en arrière-plan — vous pouvez fermer cet écran ou éteindre l\'écran.';

  @override
  String get epubOpenFailed =>
      'Ce fichier n\'a pas pu être ouvert dans le lecteur intégré (mise en forme avancée, script ou protection non pris en charge).';

  @override
  String get epubOpenWith => 'Ouvrir avec…';

  @override
  String get epubNoAppFound =>
      'Aucune application capable d\'ouvrir ce fichier n\'a été trouvée.';

  @override
  String get epubTableOfContents => 'Table des matières';

  @override
  String get epubSwitchToScrolled => 'Passer en défilement continu';

  @override
  String get epubSwitchToPaginated => 'Passer en mode page par page';

  @override
  String get epubAddBookmark => 'Ajouter un signet ici';

  @override
  String get epubBookmarkAdded => 'Signet ajouté.';

  @override
  String get epubBookmarksTitle => 'Signets';

  @override
  String get epubNoBookmarks => 'Aucun signet pour cet ouvrage.';

  @override
  String epubBookmarkAt(String date) {
    return 'Signet du $date';
  }

  @override
  String get epubTheme => 'Thème de lecture';

  @override
  String get epubThemeClair => 'Clair';

  @override
  String get epubThemeSombre => 'Sombre';

  @override
  String get epubThemeLiseuse => 'Sépia';

  @override
  String get offlineBadge => 'Hors ligne';

  @override
  String get trashTitle => 'Corbeille';

  @override
  String get trashSubtitle =>
      'Éléments supprimés, en attente d\'effacement définitif';

  @override
  String get trashEmpty => 'La corbeille est vide.';

  @override
  String get trashRestore => 'Restaurer';

  @override
  String trashDaysRemaining(int days) {
    return 'Suppression définitive dans $days j';
  }

  @override
  String trashItemRestored(String title) {
    return '« $title » a été restauré.';
  }
}

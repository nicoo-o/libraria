import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr')
  ];

  /// Libellé de l'onglet Bibliothèque (navigation) et titre de son écran.
  ///
  /// In fr, this message translates to:
  /// **'Bibliothèque'**
  String get navLibrary;

  /// Libellé de l'onglet Recherche (navigation) et titre de son écran.
  ///
  /// In fr, this message translates to:
  /// **'Recherche'**
  String get navSearch;

  /// Libellé de l'onglet Téléchargements (navigation).
  ///
  /// In fr, this message translates to:
  /// **'Téléchargements'**
  String get navDownloads;

  /// Libellé de l'onglet Paramètres (navigation) et titre de son écran.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get navSettings;

  /// Bannière affichée en haut de l'app quand ConnectivityService.isOnline est faux.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne — recherche et téléchargements en pause'**
  String get offlineBanner;

  /// Message affiché quand la bibliothèque ne contient aucun ouvrage.
  ///
  /// In fr, this message translates to:
  /// **'Ta bibliothèque est vide — commence par une recherche.'**
  String get libraryEmptyState;

  /// Texte indicatif du champ de recherche.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un livre ou un audiobook…'**
  String get searchHint;

  /// Affiché quand la recherche ne retourne aucun résultat.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat pour cette recherche.'**
  String get searchNoResults;

  /// Affiché quand une ou plusieurs sources ont leur circuit breaker ouvert.
  ///
  /// In fr, this message translates to:
  /// **'Sources indisponibles : {sources}'**
  String searchSourcesUnavailable(String sources);

  /// Libellé générique d'un bouton/action de nouvelle tentative.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get retry;

  /// Tooltip du bouton de téléchargement sur un résultat de recherche.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger'**
  String get downloadTooltip;

  /// État d'une source de contenu dont le circuit breaker est fermé (chapitre 12, NF-069).
  ///
  /// In fr, this message translates to:
  /// **'Disponible'**
  String get sourceStatusAvailable;

  /// État d'une source de contenu dont le circuit breaker est semi-ouvert (halfOpen), en test de reprise.
  ///
  /// In fr, this message translates to:
  /// **'Reprise en cours'**
  String get sourceStatusRecovering;

  /// État d'une source de contenu dont le circuit breaker est ouvert.
  ///
  /// In fr, this message translates to:
  /// **'Indisponible'**
  String get sourceStatusUnavailable;

  /// Tooltip du badge affiché sur un résultat de recherche déjà présent dans la bibliothèque (chapitre 12, NF-075).
  ///
  /// In fr, this message translates to:
  /// **'Déjà dans votre bibliothèque'**
  String get searchAlreadyOwned;

  /// Titre de l'écran Téléchargements, avec le nombre de jobs actifs sur le maximum autorisé.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargements ({downloading}/{max} actifs)'**
  String queueTitle(int downloading, int max);

  /// Affiché quand la file de téléchargements est vide.
  ///
  /// In fr, this message translates to:
  /// **'Aucun téléchargement en cours.'**
  String get queueEmpty;

  /// Statut affiché pour un téléchargement terminé.
  ///
  /// In fr, this message translates to:
  /// **'Terminé'**
  String get queueCompleted;

  /// Tooltip/action de mise en pause (file de téléchargement et lecteur audio).
  ///
  /// In fr, this message translates to:
  /// **'Mettre en pause'**
  String get pause;

  /// Tooltip du bouton de reprise d'un téléchargement en pause.
  ///
  /// In fr, this message translates to:
  /// **'Reprendre'**
  String get resume;

  /// Titre de l'option de partage du rapport de diagnostic.
  ///
  /// In fr, this message translates to:
  /// **'Partager un rapport de diagnostic'**
  String get settingsDiagnosticTitle;

  /// Sous-titre expliquant l'absence de télémétrie automatique.
  ///
  /// In fr, this message translates to:
  /// **'Zéro télémétrie automatique — envoi manuel uniquement (ADR-006).'**
  String get settingsDiagnosticSubtitle;

  /// Titre de la section de sauvegarde locale (chapitre 12, NF-061/NF-062).
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde locale'**
  String get settingsBackupTitle;

  /// Rappel du périmètre exact de la sauvegarde (ce qui est inclus / exclu).
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde la bibliothèque, les réglages et les couvertures — pas les fichiers EPUB/audio eux-mêmes (re-téléchargeables depuis leurs sources).'**
  String get settingsBackupWarning;

  /// Bouton pour lancer une sauvegarde manuelle.
  ///
  /// In fr, this message translates to:
  /// **'Créer une sauvegarde'**
  String get settingsBackupCreate;

  /// Sous-titre du bouton de création de sauvegarde.
  ///
  /// In fr, this message translates to:
  /// **'Archive locale, avec vérification d\'intégrité'**
  String get settingsBackupSubtitle;

  /// Confirmation après une sauvegarde réussie, avec la taille de l'archive.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde créée ({size}).'**
  String settingsBackupSuccess(String size);

  /// Message affiché si createBackup() échoue.
  ///
  /// In fr, this message translates to:
  /// **'La sauvegarde a échoué.'**
  String get settingsBackupFailure;

  /// Tooltip du bouton de vérification d'intégrité d'une sauvegarde (NF-062).
  ///
  /// In fr, this message translates to:
  /// **'Vérifier l\'intégrité'**
  String get settingsBackupVerify;

  /// Résultat positif de verifyBackup().
  ///
  /// In fr, this message translates to:
  /// **'Intégrité vérifiée — l\'archive n\'a pas été altérée.'**
  String get settingsBackupVerifyOk;

  /// Résultat négatif de verifyBackup().
  ///
  /// In fr, this message translates to:
  /// **'Échec de vérification — l\'archive semble corrompue ou modifiée.'**
  String get settingsBackupVerifyFailed;

  /// Titre de la section d'activation/désactivation des 4 sources V1 de base.
  ///
  /// In fr, this message translates to:
  /// **'Sources de recherche'**
  String get settingsCoreSourcesTitle;

  /// Titre de la section des sources étendues (opt-in, GitHub Edition uniquement).
  ///
  /// In fr, this message translates to:
  /// **'Sources étendues (GitHub Edition)'**
  String get settingsExtendedSourcesTitle;

  /// Avertissement affiché au-dessus des sources étendues.
  ///
  /// In fr, this message translates to:
  /// **'Désactivées par défaut. Ces sources agrègent des catalogues au statut juridique variable selon les pays. Vous êtes responsable de leur usage.'**
  String get settingsExtendedSourcesWarning;

  /// Sous-titre affichant l'identifiant technique d'une source étendue.
  ///
  /// In fr, this message translates to:
  /// **'Identifiant : {id}'**
  String settingsSourceIdLabel(String id);

  /// Affiché quand un ouvrage n'a pas d'auteur renseigné.
  ///
  /// In fr, this message translates to:
  /// **'Auteur inconnu'**
  String get mediaDetailUnknownAuthor;

  /// Bouton pour ouvrir un ouvrage (lecteur EPUB ou audio).
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir'**
  String get mediaDetailOpen;

  /// Tooltip/bouton de suppression (vers la corbeille) d'un ouvrage.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get mediaDetailDelete;

  /// Titre de la boîte de dialogue de confirmation de suppression.
  ///
  /// In fr, this message translates to:
  /// **'Mettre à la corbeille ?'**
  String get mediaDetailDeleteConfirmTitle;

  /// Corps de la boîte de dialogue de confirmation de suppression.
  ///
  /// In fr, this message translates to:
  /// **'« {title} » sera déplacé vers la corbeille et supprimé définitivement après 30 jours. Vous pourrez le restaurer avant cette échéance.'**
  String mediaDetailDeleteConfirmBody(String title);

  /// Bouton générique d'annulation.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get cancel;

  /// Message affiché quand is_missing est vrai sur l'ouvrage.
  ///
  /// In fr, this message translates to:
  /// **'Le fichier local de cet ouvrage est introuvable.'**
  String get mediaDetailMissingFile;

  /// Bouton pour relier un fichier local après déplacement/renommage externe.
  ///
  /// In fr, this message translates to:
  /// **'Relier le fichier'**
  String get mediaDetailRelink;

  /// Confirmation après un relink() réussi.
  ///
  /// In fr, this message translates to:
  /// **'Fichier relié avec succès.'**
  String get mediaDetailRelinkSuccess;

  /// Bouton pour marquer manuellement un ouvrage comme entièrement lu (chapitre 12, NF-006).
  ///
  /// In fr, this message translates to:
  /// **'Marquer comme lu'**
  String get mediaDetailMarkAsRead;

  /// État du bouton une fois l'ouvrage marqué comme lu.
  ///
  /// In fr, this message translates to:
  /// **'Lu ✓'**
  String get mediaDetailMarkedAsRead;

  /// Message du SnackBar après suppression, avec bouton Annuler (chapitre 12, NF-085).
  ///
  /// In fr, this message translates to:
  /// **'« {title} » a été déplacé vers la corbeille.'**
  String mediaDetailDeletedUndo(String title);

  /// Libellé générique du bouton d'annulation d'une action réversible (SnackBarAction), distinct de "cancel" qui annule une boîte de dialogue avant validation.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get undo;

  /// Affiché quand un ouvrage n'a pas (ou plus) de fichier local (lecteur EPUB et audio).
  ///
  /// In fr, this message translates to:
  /// **'Aucun fichier local associé à cet ouvrage.'**
  String get readerNoLocalFile;

  /// Affiché quand le dossier d'un audiobook extrait ne contient aucun MP3.
  ///
  /// In fr, this message translates to:
  /// **'Aucun fichier audio trouvé dans ce dossier.'**
  String get audioNoFilesFound;

  /// Affiché quand le chargement de l'audiobook échoue pour une raison inattendue.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de lire ce fichier audio : {error}'**
  String audioLoadError(String error);

  /// Tooltip du bouton de retour arrière de 30 secondes.
  ///
  /// In fr, this message translates to:
  /// **'Reculer de 30 secondes'**
  String get audioRewind30;

  /// Tooltip du bouton d'avance rapide de 30 secondes.
  ///
  /// In fr, this message translates to:
  /// **'Avancer de 30 secondes'**
  String get audioForward30;

  /// Tooltip du bouton de lecture (quand en pause).
  ///
  /// In fr, this message translates to:
  /// **'Lire'**
  String get audioPlay;

  /// Message générique affiché quand le chargement de l'audiobook échoue pour une raison non catégorisée.
  ///
  /// In fr, this message translates to:
  /// **'La lecture de ce fichier audio a échoué.'**
  String get audioLoadErrorGeneric;

  /// Titre de la liste des chapitres (fichiers) d'un audiobook, et tooltip du bouton qui l'ouvre.
  ///
  /// In fr, this message translates to:
  /// **'Chapitres'**
  String get audioChaptersTitle;

  /// Libellé d'un chapitre dans la liste, par numéro (les audiobooks multi-fichiers n'ont pas de titre de chapitre exploitable sans lecture de métadonnées ID3).
  ///
  /// In fr, this message translates to:
  /// **'Chapitre {number}'**
  String audioChapterNumber(int number);

  /// Rappel affiché sous les contrôles du lecteur audio, indiquant que la lecture survit à la fermeture de l'écran (notification/lockscreen).
  ///
  /// In fr, this message translates to:
  /// **'La lecture continue en arrière-plan — vous pouvez fermer cet écran ou éteindre l\'écran.'**
  String get audioBackgroundHint;

  /// Message affiché quand epub_view ne parvient pas à ouvrir un fichier EPUB.
  ///
  /// In fr, this message translates to:
  /// **'Ce fichier n\'a pas pu être ouvert dans le lecteur intégré (mise en forme avancée, script ou protection non pris en charge).'**
  String get epubOpenFailed;

  /// Bouton de repli pour ouvrir l'EPUB dans une autre application.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir avec…'**
  String get epubOpenWith;

  /// Message affiché quand aucune application ne peut ouvrir le fichier EPUB en repli.
  ///
  /// In fr, this message translates to:
  /// **'Aucune application capable d\'ouvrir ce fichier n\'a été trouvée.'**
  String get epubNoAppFound;

  /// Tooltip du bouton ouvrant la table des matières de l'EPUB.
  ///
  /// In fr, this message translates to:
  /// **'Table des matières'**
  String get epubTableOfContents;

  /// Tooltip du bouton pour basculer du mode page par page vers le défilement continu.
  ///
  /// In fr, this message translates to:
  /// **'Passer en défilement continu'**
  String get epubSwitchToScrolled;

  /// Tooltip du bouton pour basculer du défilement continu vers le mode page par page.
  ///
  /// In fr, this message translates to:
  /// **'Passer en mode page par page'**
  String get epubSwitchToPaginated;

  /// Tooltip du bouton pour ajouter un signet à la position courante.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un signet ici'**
  String get epubAddBookmark;

  /// Confirmation affichée après l'ajout d'un signet.
  ///
  /// In fr, this message translates to:
  /// **'Signet ajouté.'**
  String get epubBookmarkAdded;

  /// Titre de la liste des signets d'un ouvrage.
  ///
  /// In fr, this message translates to:
  /// **'Signets'**
  String get epubBookmarksTitle;

  /// Affiché quand un ouvrage n'a aucun signet enregistré.
  ///
  /// In fr, this message translates to:
  /// **'Aucun signet pour cet ouvrage.'**
  String get epubNoBookmarks;

  /// Libellé d'un signet dans la liste, avec sa date de création.
  ///
  /// In fr, this message translates to:
  /// **'Signet du {date}'**
  String epubBookmarkAt(String date);

  /// Tooltip du bouton pour changer le thème de lecture (clair/sombre/liseuse).
  ///
  /// In fr, this message translates to:
  /// **'Thème de lecture'**
  String get epubTheme;

  /// Nom du thème de lecture clair.
  ///
  /// In fr, this message translates to:
  /// **'Clair'**
  String get epubThemeClair;

  /// Nom du thème de lecture sombre.
  ///
  /// In fr, this message translates to:
  /// **'Sombre'**
  String get epubThemeSombre;

  /// Nom du thème de lecture sépia (liseuse).
  ///
  /// In fr, this message translates to:
  /// **'Sépia'**
  String get epubThemeLiseuse;

  /// Badge affiché sur un ouvrage dont le fichier local est manquant.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne'**
  String get offlineBadge;

  /// Titre de l'écran Corbeille et libellé de l'entrée dans Paramètres.
  ///
  /// In fr, this message translates to:
  /// **'Corbeille'**
  String get trashTitle;

  /// Sous-titre de l'entrée Corbeille dans l'écran Paramètres.
  ///
  /// In fr, this message translates to:
  /// **'Éléments supprimés, en attente d\'effacement définitif'**
  String get trashSubtitle;

  /// Affiché quand la corbeille ne contient aucun élément.
  ///
  /// In fr, this message translates to:
  /// **'La corbeille est vide.'**
  String get trashEmpty;

  /// Bouton pour restaurer un élément de la corbeille.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer'**
  String get trashRestore;

  /// Nombre de jours restants avant la purge définitive d'un élément de la corbeille.
  ///
  /// In fr, this message translates to:
  /// **'Suppression définitive dans {days} j'**
  String trashDaysRemaining(int days);

  /// Confirmation affichée après restauration d'un élément.
  ///
  /// In fr, this message translates to:
  /// **'« {title} » a été restauré.'**
  String trashItemRestored(String title);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}

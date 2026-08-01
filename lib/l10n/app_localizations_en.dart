// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navLibrary => 'Library';

  @override
  String get navSearch => 'Search';

  @override
  String get navDownloads => 'Downloads';

  @override
  String get navSettings => 'Settings';

  @override
  String get offlineBanner => 'Offline — search and downloads paused';

  @override
  String get libraryEmptyState =>
      'Your library is empty — start with a search.';

  @override
  String get searchHint => 'Search for a book or audiobook…';

  @override
  String get searchNoResults => 'No results for this search.';

  @override
  String searchSourcesUnavailable(String sources) {
    return 'Unavailable sources: $sources';
  }

  @override
  String get retry => 'Retry';

  @override
  String get downloadTooltip => 'Download';

  @override
  String get sourceStatusAvailable => 'Available';

  @override
  String get sourceStatusRecovering => 'Recovering';

  @override
  String get sourceStatusUnavailable => 'Unavailable';

  @override
  String get searchAlreadyOwned => 'Already in your library';

  @override
  String queueTitle(int downloading, int max) {
    return 'Downloads ($downloading/$max active)';
  }

  @override
  String get queueEmpty => 'No downloads in progress.';

  @override
  String get queueCompleted => 'Done';

  @override
  String get pause => 'Pause';

  @override
  String get resume => 'Resume';

  @override
  String get settingsDiagnosticTitle => 'Share a diagnostic report';

  @override
  String get settingsDiagnosticSubtitle =>
      'No automatic telemetry — manual sending only (ADR-006).';

  @override
  String get settingsBackupTitle => 'Local backup';

  @override
  String get settingsBackupWarning =>
      'Backs up the library, settings, and covers — not the EPUB/audio files themselves (re-downloadable from their sources).';

  @override
  String get settingsBackupCreate => 'Create a backup';

  @override
  String get settingsBackupSubtitle => 'Local archive, with integrity check';

  @override
  String settingsBackupSuccess(String size) {
    return 'Backup created ($size).';
  }

  @override
  String get settingsBackupFailure => 'Backup failed.';

  @override
  String get settingsBackupVerify => 'Verify integrity';

  @override
  String get settingsBackupVerifyOk =>
      'Integrity verified — the archive has not been altered.';

  @override
  String get settingsBackupVerifyFailed =>
      'Verification failed — the archive appears corrupted or modified.';

  @override
  String get settingsCoreSourcesTitle => 'Search sources';

  @override
  String get settingsExtendedSourcesTitle =>
      'Extended sources (GitHub Edition)';

  @override
  String get settingsExtendedSourcesWarning =>
      'Disabled by default. These sources aggregate catalogs with a legal status that varies by country. You are responsible for their use.';

  @override
  String settingsSourceIdLabel(String id) {
    return 'ID: $id';
  }

  @override
  String get mediaDetailUnknownAuthor => 'Unknown author';

  @override
  String get mediaDetailOpen => 'Open';

  @override
  String get mediaDetailDelete => 'Delete';

  @override
  String get mediaDetailDeleteConfirmTitle => 'Move to trash?';

  @override
  String mediaDetailDeleteConfirmBody(String title) {
    return '\"$title\" will be moved to trash and permanently deleted after 30 days. You can restore it before then.';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get mediaDetailMissingFile =>
      'This item\'s local file could not be found.';

  @override
  String get mediaDetailRelink => 'Relink file';

  @override
  String get mediaDetailRelinkSuccess => 'File relinked successfully.';

  @override
  String get mediaDetailMarkAsRead => 'Mark as read';

  @override
  String get mediaDetailMarkedAsRead => 'Read ✓';

  @override
  String mediaDetailDeletedUndo(String title) {
    return '\"$title\" was moved to trash.';
  }

  @override
  String get undo => 'Undo';

  @override
  String get readerNoLocalFile => 'No local file associated with this item.';

  @override
  String get audioNoFilesFound => 'No audio file found in this folder.';

  @override
  String audioLoadError(String error) {
    return 'Couldn\'t play this audio file: $error';
  }

  @override
  String get audioRewind30 => 'Rewind 30 seconds';

  @override
  String get audioForward30 => 'Forward 30 seconds';

  @override
  String get audioPlay => 'Play';

  @override
  String get audioLoadErrorGeneric => 'Playback of this audio file failed.';

  @override
  String get audioChaptersTitle => 'Chapters';

  @override
  String audioChapterNumber(int number) {
    return 'Chapter $number';
  }

  @override
  String get audioBackgroundHint =>
      'Playback continues in the background — you can close this screen or turn off the screen.';

  @override
  String get epubOpenFailed =>
      'This file couldn\'t be opened in the built-in reader (advanced formatting, script, or unsupported protection).';

  @override
  String get epubOpenWith => 'Open with…';

  @override
  String get epubNoAppFound => 'No app capable of opening this file was found.';

  @override
  String get epubTableOfContents => 'Table of contents';

  @override
  String get epubSwitchToScrolled => 'Switch to continuous scroll';

  @override
  String get epubSwitchToPaginated => 'Switch to page-by-page';

  @override
  String get epubAddBookmark => 'Add a bookmark here';

  @override
  String get epubBookmarkAdded => 'Bookmark added.';

  @override
  String get epubBookmarksTitle => 'Bookmarks';

  @override
  String get epubNoBookmarks => 'No bookmarks for this item.';

  @override
  String epubBookmarkAt(String date) {
    return 'Bookmark from $date';
  }

  @override
  String get epubTheme => 'Reading theme';

  @override
  String get epubThemeClair => 'Light';

  @override
  String get epubThemeSombre => 'Dark';

  @override
  String get epubThemeLiseuse => 'Sepia';

  @override
  String get offlineBadge => 'Offline';

  @override
  String get trashTitle => 'Trash';

  @override
  String get trashSubtitle => 'Deleted items, awaiting permanent removal';

  @override
  String get trashEmpty => 'Trash is empty.';

  @override
  String get trashRestore => 'Restore';

  @override
  String trashDaysRemaining(int days) {
    return 'Permanently deleted in $days d';
  }

  @override
  String trashItemRestored(String title) {
    return '\"$title\" has been restored.';
  }
}

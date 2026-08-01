import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/models/bookmark.dart';
import '../core/models/library_item.dart';
import '../l10n/app_localizations.dart';
import '../library/bookmark_repository.dart';
import '../library/library_repository.dart';
import '../library/settings_repository.dart';
import '../theme/reader_themes.dart';

/// Lecteur EPUB — `flutter_epub_viewer` (WebView + epub.js), ADR-007 révisé.
class EpubReaderScreen extends StatefulWidget {
  const EpubReaderScreen({super.key, required this.item});
  final LibraryItem item;

  @override
  State<EpubReaderScreen> createState() => _EpubReaderScreenState();
}

class _EpubReaderScreenState extends State<EpubReaderScreen>
    with WidgetsBindingObserver {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  late EpubController _controller;
  late final EpubSource _epubSource;
  List<EpubChapter> _chapters = [];

  // État de lecture
  String? _lastCfi;
  double _readProgress = 0.0;
  bool _hasError = false;

  // Verrou de sécurité contre les événements "0" au chargement
  bool _isInitialized = false;

  // [Idée utilisateur] Distingue la toute première ouverture du livre (où
  // `initialCfi` suffit déjà) d'un rechargement suite à un changement de
  // mode de lecture (`_repositioning`) — voir _onEpubLoaded().
  bool _isFirstLoad = true;

  // [Correctif — bug réel confirmé] Repositionnement après un changement de
  // mode de lecture. `_repositioning` masque la saccade visible (voir
  // build()) le temps que `display(cfi: ...)` termine sa navigation dans
  // _onEpubLoaded ci-dessous.
  //
  // [Essai raté, conservé en commentaire pour ne pas retenter la même
  // erreur] `EpubLocation.progress` semblait une alternative plus fiable que
  // le CFI (indépendante du flow) -- en pratique elle renvoie 0.0 par défaut
  // (epub.js n'a probablement pas généré ses "locations" internes, étape
  // nécessaire pour un vrai pourcentage), donc `toProgressPercentage(0.0)`
  // ramenait systématiquement au tout début du livre -- bien pire que le CFI
  // "à peu près juste" qu'on avait avant. Retour au CFI.
  bool _repositioning = false;

  // Réglages
  late EpubDisplaySettings _displaySettings;
  EpubFlow _currentFlow = EpubFlow.paginated;

  // Dépendances
  late final LibraryRepository _libraryRepository;
  late final SettingsRepository _settingsRepository;
  bool _dependenciesReady = false;

  static const _readingModeKey = 'epub_reading_mode';
  static const _themeKey = 'epub_reader_theme';
  ReaderTheme _theme = ReaderTheme.clair;

  Timer? _positionPollTimer;

  @override
  void initState() {
    super.initState();
    _controller = EpubController();
    _epubSource = EpubSource.fromFile(File(widget.item.localPath!));

    // Initialisation par défaut (paginated)
    _displaySettings = EpubDisplaySettings(
      flow: _currentFlow,
      snap: true,
      useSnapAnimationAndroid: false,
    );

    WidgetsBinding.instance.addObserver(this);

    if (widget.item.localPath == null) {
      _hasError = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dependenciesReady) {
      _libraryRepository = context.read<LibraryRepository>();
      _settingsRepository = context.read<SettingsRepository>();
      _lastCfi = widget.item.lastCfi;
      _readProgress = widget.item.readProgress;

      // Charger le mode sauvegardé
      _settingsRepository.getValue(_readingModeKey).then((savedMode) {
        if (!mounted) return;
        if (savedMode != null) {
          final newFlow =
              savedMode == 'scrolled' ? EpubFlow.scrolled : EpubFlow.paginated;
          setState(() {
            _currentFlow = newFlow;
            _displaySettings = EpubDisplaySettings(
              flow: newFlow,
              snap: newFlow == EpubFlow.paginated,
              // [Correctif] Indispensable pour le défilement fluide sur Android
              useSnapAnimationAndroid: newFlow == EpubFlow.scrolled,
            );
          });
        }
      });

      // Charger le thème sauvegardé
      _settingsRepository.getValue(_themeKey).then((savedTheme) {
        if (!mounted || savedTheme == null) return;
        final match = ReaderTheme.values.where((t) => t.name == savedTheme);
        if (match.isNotEmpty) setState(() => _theme = match.first);
      });

      _dependenciesReady = true;
    }
  }

  void _onRelocated(EpubLocation location) {
    // [Correctif] onRelocated est cassé par useSnapAnimationAndroid en mode scrolled.
    // On ne l'écoute donc que pour le mode paginated.
    if (!_isInitialized || _currentFlow == EpubFlow.scrolled) return;

    final cfi = location.startCfi;
    if (cfi.isEmpty || cfi == _lastCfi) return;

    _lastCfi = cfi;
    _readProgress = location.progress;
    unawaited(_savePosition());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(_savePosition());
    }
  }

  Future<void> _savePosition() async {
    final cfi = _lastCfi;
    if (cfi == null || !_dependenciesReady) return;

    widget.item.lastCfi = cfi;
    widget.item.readProgress = _readProgress;

    await _libraryRepository.updatePosition(
      widget.item.id,
      readProgress: _readProgress,
      lastCfi: cfi,
    );
  }

  void _toggleFlow() async {
    try {
      final loc = await _controller.getCurrentLocation();
      if (loc.startCfi.isNotEmpty) {
        _lastCfi = loc.startCfi;
      }
    } catch (_) {}

    final newFlow = _currentFlow == EpubFlow.paginated
        ? EpubFlow.scrolled
        : EpubFlow.paginated;

    setState(() {
      _isInitialized = false;
      _repositioning = true;
      _currentFlow = newFlow;
      // Recréer le contrôleur garantit un état propre pour le nouveau mode
      _controller = EpubController();
      _displaySettings = EpubDisplaySettings(
        flow: newFlow,
        snap: newFlow == EpubFlow.paginated,
        useSnapAnimationAndroid: newFlow == EpubFlow.scrolled,
      );
    });

    await _settingsRepository.setValue(_readingModeKey, newFlow.name);

    if (newFlow == EpubFlow.scrolled) {
      _startPositionPoll();
    } else {
      _stopPositionPoll();
    }
  }

  void _startPositionPoll() {
    _stopPositionPoll();
    _positionPollTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!_isInitialized || _currentFlow != EpubFlow.scrolled) return;
      try {
        final loc = await _controller.getCurrentLocation();
        if (loc.startCfi == _lastCfi) return;

        _lastCfi = loc.startCfi;
        _readProgress = loc.progress;
        unawaited(_savePosition());
      } catch (_) {}
    });
  }

  void _stopPositionPoll() {
    _positionPollTimer?.cancel();
    _positionPollTimer = null;
  }

  void _onEpubLoaded() {
    // Verrou de 3s pour stabiliser le rendu et le saut vers initialCfi
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) _isInitialized = true;
    });

    if (_currentFlow == EpubFlow.scrolled) {
      _startPositionPoll();
    }

    if (_isFirstLoad) {
      _isFirstLoad = false;
      // [Idée utilisateur — étendu à la reprise normale] `initialCfi` (passé
      // à EpubViewer) a déjà positionné correctement epub.js à l'ouverture —
      // pas de raison de re-naviguer explicitement ici (contrairement au
      // changement de mode ci-dessous). On se contente de surligner
      // brièvement le point de reprise, pour rassurer visuellement
      // l'utilisateur qu'il est bien revenu où il en était. Uniquement s'il
      // y a une VRAIE reprise (livre déjà commencé, `lastCfi` non nul) — pas
      // à la toute première ouverture d'un livre neuf (page 1, rien à
      // signaler, ce serait un surlignage inutile et surprenant).
      final resumeCfi = widget.item.lastCfi;
      if (resumeCfi != null && resumeCfi.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) _flashHighlight(resumeCfi);
        });
      }
    } else if (_repositioning) {
      // [Correctif — bug réel confirmé en test] Changement de mode de
      // lecture : `initialCfi` seul ne suffit pas de façon fiable ici
      // (limitation documentée par le package pour le flow scrolled) — on
      // force donc un appel EXPLICITE à `display(cfi: ...)` après un court
      // délai, une fois la nouvelle rendition chargée. La saccade que ça
      // provoquait est masquée par `_repositioning` (voir build()), donc
      // invisible pour l'utilisateur.
      final cfi = _lastCfi;
      if (cfi != null && cfi.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (!mounted) return;
          _controller.display(cfi: cfi);
          setState(() => _repositioning = false);
          // [Idée utilisateur — "surligner le mot/la phrase où reprendre
          // pour ne pas se perdre"] Le CFI encode déjà la référence exacte
          // du chapitre (structure /6/14!/... du CFI == référence de
          // spine) : `display(cfi:)` charge donc TOUJOURS le bon chapitre,
          // epub.js n'a pas le choix. L'imprécision observée au changement
          // de mode est forcément DANS le bon chapitre (résolution de
          // l'offset de caractère qui diffère légèrement entre rendu
          // paginé et défilant) — pas un mauvais chapitre.
          _flashHighlight(cfi);
        });
      } else {
        // Filet de sécurité : pas de CFI à appliquer, ne jamais laisser
        // l'overlay de chargement bloqué indéfiniment.
        setState(() => _repositioning = false);
      }
    }

    unawaited(_applyTheme(_theme));
  }

  /// Surligne temporairement `cfi` puis retire le surlignage après quelques
  /// secondes — un repère "vous étiez ici", pas une vraie annotation créée
  /// par l'utilisateur (voir `_addBookmark`/`_showBookmarks` pour celles-ci,
  /// qui restent permanentes tant que l'utilisateur ne les supprime pas).
  void _flashHighlight(String cfi) async {
    try {
      await _controller.addHighlight(
          cfi: cfi, color: Colors.yellow, opacity: 0.5);
      Future.delayed(const Duration(seconds: 4), () {
        _controller.removeHighlight(cfi: cfi);
      });
    } catch (_) {
      // Un surlignage manqué n'est jamais bloquant pour la lecture.
    }
  }

  Future<void> _applyTheme(ReaderTheme theme) async {
    final colors = readerThemeColors[theme]!;
    final bg = _toCssHex(colors.background);
    final text = _toCssHex(colors.text);
    try {
      await _controller.updateTheme(
        theme: EpubTheme.custom(customCss: {
          'body': {'background-color': bg, 'color': text},
          'p': {'color': text},
          'div': {'color': text},
          'span': {'color': text},
          'h1': {'color': text},
          'h2': {'color': text},
          'h3': {'color': text},
        }),
      );
    } catch (_) {}
  }

  String _toCssHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  void _cycleTheme() async {
    const values = ReaderTheme.values;
    final next = values[(values.indexOf(_theme) + 1) % values.length];
    setState(() => _theme = next);
    await _settingsRepository.setValue(_themeKey, next.name);
    await _applyTheme(next);
  }

  IconData _themeIcon(ReaderTheme theme) => switch (theme) {
        ReaderTheme.clair => Icons.light_mode_outlined,
        ReaderTheme.sombre => Icons.dark_mode_outlined,
        ReaderTheme.liseuse => Icons.menu_book_outlined,
      };

  String _themeLabel(AppLocalizations l10n, ReaderTheme theme) =>
      switch (theme) {
        ReaderTheme.clair => l10n.epubThemeClair,
        ReaderTheme.sombre => l10n.epubThemeSombre,
        ReaderTheme.liseuse => l10n.epubThemeLiseuse,
      };

  void _onChaptersLoaded(List<EpubChapter> chapters) {
    setState(() => _chapters = chapters);
  }

  Future<void> _openExternally() async {
    final path = widget.item.localPath;
    if (path == null) return;
    final uri = Uri.file(path);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.epubNoAppFound)));
    }
  }

  Future<void> _addBookmark() async {
    final cfi = _lastCfi;
    if (cfi == null || !mounted) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await context
        .read<BookmarkRepository>()
        .add(itemId: widget.item.id, location: cfi);
    if (mounted) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.epubBookmarkAdded)));
    }
  }

  Future<void> _showBookmarks() async {
    final l10n = AppLocalizations.of(context);
    final bookmarkRepo = context.read<BookmarkRepository>();

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return FutureBuilder<List<Bookmark>>(
          future: bookmarkRepo.getForItem(widget.item.id),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()));
            }
            final bookmarks = snapshot.data!;
            if (bookmarks.isEmpty) {
              return SizedBox(
                  height: 120,
                  child: Center(child: Text(l10n.epubNoBookmarks)));
            }
            return ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l10n.epubBookmarksTitle,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                for (final bookmark in bookmarks)
                  ListTile(
                    leading: const Icon(Icons.bookmark),
                    title: Text(l10n.epubBookmarkAt(
                      '${bookmark.createdAt.day.toString().padLeft(2, '0')}/'
                      '${bookmark.createdAt.month.toString().padLeft(2, '0')}/'
                      '${bookmark.createdAt.year}',
                    )),
                    onTap: () {
                      _controller.display(cfi: bookmark.location);
                      Navigator.of(sheetContext).pop();
                    },
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await bookmarkRepo.delete(bookmark.id);
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                      },
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_hasError) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.item.title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.menu_book_outlined, size: 48),
                const SizedBox(height: 16),
                Text(l10n.epubOpenFailed, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _openExternally,
                  icon: const Icon(Icons.open_in_new),
                  label: Text(l10n.epubOpenWith),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final themeColors = readerThemeColors[_theme]!;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: themeColors.background,
      appBar: AppBar(
        title: Text(widget.item.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: Icon(_themeIcon(_theme)),
            tooltip: '${l10n.epubTheme} — ${_themeLabel(l10n, _theme)}',
            onPressed: _cycleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_add_outlined),
            tooltip: l10n.epubAddBookmark,
            onPressed: _addBookmark,
          ),
          IconButton(
            icon: const Icon(Icons.bookmarks_outlined),
            tooltip: l10n.epubBookmarksTitle,
            onPressed: _showBookmarks,
          ),
          IconButton(
            icon: Icon(_currentFlow == EpubFlow.paginated
                ? Icons.view_day_outlined
                : Icons.auto_stories_outlined),
            tooltip: _currentFlow == EpubFlow.paginated
                ? l10n.epubSwitchToScrolled
                : l10n.epubSwitchToPaginated,
            onPressed: _toggleFlow,
          ),
          IconButton(
            icon: const Icon(Icons.menu),
            tooltip: l10n.epubTableOfContents,
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: _chapters.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                children: [
                  for (final chapter in _chapters)
                    ListTile(
                      title: Text(chapter.title),
                      onTap: () {
                        _controller.display(cfi: chapter.href);
                        Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
      ),
      body: Stack(
        children: [
          EpubViewer(
            key: ValueKey(_currentFlow),
            epubSource: _epubSource,
            epubController: _controller,
            displaySettings: _displaySettings,
            initialCfi: _lastCfi ?? widget.item.lastCfi,
            onEpubLoaded: _onEpubLoaded,
            onChaptersLoaded: _onChaptersLoaded,
            onRelocated: _onRelocated,
          ),
          // [Correctif — bug réel confirmé en test] Masque la saccade du
          // repositionnement (voir _onEpubLoaded) : sans cet overlay,
          // l'utilisateur voyait la page "sauter" pendant le court instant où
          // `display(cfi: ...)` navigue vers la bonne position après un
          // changement de mode de lecture.
          if (_repositioning)
            Positioned.fill(
              child: Container(
                color: themeColors.background,
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPositionPoll();
    unawaited(_savePosition());
    super.dispose();
  }
}

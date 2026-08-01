import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/connectivity/connectivity_service.dart';
import 'l10n/app_localizations.dart';
import 'screens/library_screen.dart';
import 'screens/queue_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';
import 'theme/app_theme.dart';

/// Navigation library-first — `_index` commence toujours à 0 → `LibraryScreen` est
/// l'accueil (02_ARCHITECTURE.md).
class LibrariaApp extends StatelessWidget {
  const LibrariaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Libraria',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // [Partie 7] i18n — français (langue source) + anglais, générés depuis
      // lib/l10n/*.arb par `flutter gen-l10n` (voir l10n.yaml, pubspec.yaml
      // `generate: true`). GlobalMaterialLocalizations etc. couvrent aussi les
      // widgets Material natifs (boutons "Annuler"/"OK" des dialogues système,
      // etc.), pas seulement AppLocalizations.
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const _RootNavigation(),
    );
  }
}

class _RootNavigation extends StatefulWidget {
  const _RootNavigation();

  @override
  State<_RootNavigation> createState() => _RootNavigationState();
}

class _RootNavigationState extends State<_RootNavigation> {
  int _index = 0;

  static const _screens = [
    LibraryScreen(),
    SearchScreen(),
    QueueScreen(),
    SettingsScreen(),
  ];

  List<NavigationDestination> _destinations(AppLocalizations l10n) => [
        NavigationDestination(icon: const Icon(Icons.auto_stories), label: l10n.navLibrary),
        NavigationDestination(icon: const Icon(Icons.search), label: l10n.navSearch),
        NavigationDestination(icon: const Icon(Icons.download), label: l10n.navDownloads),
        NavigationDestination(icon: const Icon(Icons.settings), label: l10n.navSettings),
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // [Partie 7] Bannière hors-ligne — ConnectivityService (main.dart) existait
    // déjà et était fourni, mais rien ne l'affichait nulle part dans l'UI.
    // Placée au-dessus de l'IndexedStack (pas dans un seul écran) pour rester
    // visible quel que soit l'onglet actif.
    final isOnline = context.watch<ConnectivityService>().isOnline;

    return Scaffold(
      body: Column(
        children: [
          if (!isOnline)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.errorContainer,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off, size: 16, color: Theme.of(context).colorScheme.onErrorContainer),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      l10n.offlineBanner,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            // [Correctif] IndexedStack, pas `_screens[_index]` : garde les 4 onglets
            // montés en permanence et conserve l'état de chacun (texte de recherche
            // saisi, position de scroll de la bibliothèque) au lieu de détruire/
            // recréer le State à chaque changement d'onglet. C'était le point
            // explicitement vérifié par la checklist Partie 5 du guide
            // (docs/GUIDE_PAS_A_PAS_LIBRARIA.md).
            child: IndexedStack(index: _index, children: _screens),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: _destinations(l10n),
      ),
    );
  }
}

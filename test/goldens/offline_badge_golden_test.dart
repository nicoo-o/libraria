import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:libraria/l10n/app_localizations.dart';
import 'package:libraria/widgets/cover_placeholder.dart';

/// Golden test — voir test/goldens/README.md pour la commande de génération
/// de la baseline (`flutter test --update-goldens test/goldens`) à lancer une
/// première fois avant que la CI ne puisse comparer utilement.
void main() {
  testWidgets('OfflineBadge — rendu français par défaut', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        theme: ThemeData(fontFamily: 'Ahem'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: Center(child: OfflineBadge()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(OfflineBadge),
      matchesGoldenFile('goldens/offline_badge_fr.png'),
    );
  });
}

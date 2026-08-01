import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:libraria/l10n/app_localizations.dart';
import 'package:libraria/widgets/cover_placeholder.dart';

/// Golden test — voir test/goldens/README.md pour la commande de génération
/// de la baseline (`flutter test --update-goldens test/goldens`) à lancer une
/// première fois avant que la CI ne puisse comparer utilement.
void main() {
  testWidgets('OfflineBadge — rendu français par défaut', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(child: OfflineBadge()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(OfflineBadge));
    final expectedText = AppLocalizations.of(context).offlineBadge;

    final textWidget = tester.widget<Text>(find.text(expectedText));
    expect(textWidget.style?.color, Colors.white);
    expect(textWidget.style?.fontSize, 12);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:libraria/core/models/media_type.dart';
import 'package:libraria/widgets/cover_placeholder.dart';

/// Golden test — voir test/goldens/README.md pour la commande de génération
/// de la baseline (`flutter test --update-goldens test/goldens`) à lancer une
/// première fois avant que la CI ne puisse comparer utilement.
void main() {
  testWidgets('CoverPlaceholder — livre', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 120,
              height: 180,
              child: CoverPlaceholder(
                title: 'Pride and Prejudice',
                author: 'Jane Austen',
                mediaType: MediaType.book,
              ),
            ),
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(CoverPlaceholder),
      matchesGoldenFile('goldens/cover_placeholder_book.png'),
    );
  });

  testWidgets('CoverPlaceholder — audiobook (icône casque, pas livre)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 120,
              height: 180,
              child: CoverPlaceholder(
                title: 'Alice in Wonderland',
                author: 'Lewis Carroll',
                mediaType: MediaType.audiobook,
              ),
            ),
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(CoverPlaceholder),
      matchesGoldenFile('goldens/cover_placeholder_audiobook.png'),
    );
  });

  testWidgets('CoverPlaceholder — titre vide (repli "?" plutôt qu\'un crash)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 120,
              height: 180,
              child: CoverPlaceholder(title: '', mediaType: MediaType.book),
            ),
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(CoverPlaceholder),
      matchesGoldenFile('goldens/cover_placeholder_empty_title.png'),
    );
  });
}

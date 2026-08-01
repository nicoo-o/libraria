import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:libraria/library/bookmark_repository.dart';
import 'package:libraria/library/migrations/migrations.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late BookmarkRepository repo;

  late Database db;
  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    for (final stmt in splitSqlStatements(fullSchemaV17)) {
      await db.execute(stmt);
    }
    repo = BookmarkRepository(db);
  });

  tearDown(() async {
    await db.close();
  });
  test('add() crée un signet et le retourne', () async {
    final bookmark =
        await repo.add(itemId: 'book-1', location: 'epubcfi(/6/6!/4/2/1)');
    expect(bookmark.itemId, 'book-1');
    expect(bookmark.location, 'epubcfi(/6/6!/4/2/1)');
  });

  test('getForItem() ne retourne que les signets de l\'item demandé', () async {
    await repo.add(itemId: 'book-1', location: 'epubcfi(/a)');
    await repo.add(itemId: 'book-1', location: 'epubcfi(/b)');
    await repo.add(itemId: 'book-2', location: 'epubcfi(/c)');

    final forBook1 = await repo.getForItem('book-1');
    expect(forBook1, hasLength(2));
    expect(forBook1.every((b) => b.itemId == 'book-1'), isTrue);
  });

  test('getForItem() retourne les signets du plus récent au plus ancien',
      () async {
    final first = await repo.add(itemId: 'book-1', location: 'epubcfi(/a)');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final second = await repo.add(itemId: 'book-1', location: 'epubcfi(/b)');

    final bookmarks = await repo.getForItem('book-1');
    expect(bookmarks.first.id, second.id);
    expect(bookmarks.last.id, first.id);
  });

  test('delete() retire le signet', () async {
    final bookmark = await repo.add(itemId: 'book-1', location: 'epubcfi(/a)');
    await repo.delete(bookmark.id);

    expect(await repo.getForItem('book-1'), isEmpty);
  });
}

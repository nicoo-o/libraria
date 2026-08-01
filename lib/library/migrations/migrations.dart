import 'migration_v1.dart';
import 'migration_v2.dart';
import 'migration_v3.dart';
import 'migration_v4.dart';
import 'migration_v5.dart';
import 'migration_v6.dart';
import 'migration_v7.dart';
import 'migration_v8.dart';
import 'migration_v9.dart';
import 'migration_v10.dart';
import 'migration_v11.dart';
import 'migration_v12.dart';
import 'migration_v13.dart';
import 'migration_v14.dart';
import 'migration_v15.dart';
import 'migration_v16.dart';
import 'migration_v17.dart';

export 'schema_full.dart' show fullSchemaV17;
export 'sql_utils.dart' show splitSqlStatements;
export 'migration_v1.dart' show migrationV1;

/// Séquence appliquée par `onUpgrade` — une entrée par version, jamais de
/// redéfinition ailleurs (chapitre 04 + chapitre 12, R3'').
String? migrationForVersion(int version) {
  switch (version) {
    case 1:
      return migrationV1;
    case 2:
      return migrationV2;
    case 3:
      return migrationV3;
    case 4:
      return migrationV4;
    case 5:
      return migrationV5;
    case 6:
      return migrationV6;
    case 7:
      return migrationV7;
    case 8:
      return migrationV8;
    case 9:
      return migrationV9;
    case 10:
      return migrationV10;
    case 11:
      return migrationV11;
    case 12:
      return migrationV12;
    case 13:
      return migrationV13;
    case 14:
      return migrationV14;
    case 15:
      return migrationV15;
    case 16:
      return migrationV16;
    case 17:
      return migrationV17;
    default:
      return null;
  }
}

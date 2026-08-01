/// Découpe un script SQL en instructions individuelles pour `db.execute()`
/// (sqflite n'exécute qu'une instruction à la fois). Un simple `split(';')` casse les
/// triggers `CREATE TRIGGER ... BEGIN ... ; ... ; END;`, dont le corps contient des
/// `;` qui ne sont PAS des séparateurs d'instructions au niveau du script. Ce
/// splitter garde ces blocs `BEGIN...END` intacts.
List<String> splitSqlStatements(String script) {
  final statements = <String>[];
  final buffer = StringBuffer();
  var depth = 0; // profondeur BEGIN/END

  final upper = script.toUpperCase();
  var i = 0;
  while (i < script.length) {
    final remainderUpper = upper.substring(i);
    if (remainderUpper.startsWith('BEGIN') &&
        (i == 0 || !_isWordChar(script[i - 1])) &&
        (i + 5 >= script.length || !_isWordChar(script[i + 5]))) {
      depth++;
    } else if (remainderUpper.startsWith('END') &&
        (i == 0 || !_isWordChar(script[i - 1])) &&
        (i + 3 >= script.length || !_isWordChar(script[i + 3]))) {
      if (depth > 0) depth--;
    }

    final char = script[i];
    buffer.write(char);
    if (char == ';' && depth == 0) {
      final stmt = buffer.toString().trim();
      if (stmt.isNotEmpty) statements.add(stmt.substring(0, stmt.length - 1));
      buffer.clear();
    }
    i++;
  }
  final last = buffer.toString().trim();
  if (last.isNotEmpty) statements.add(last.endsWith(';') ? last.substring(0, last.length - 1) : last);
  return statements;
}

bool _isWordChar(String c) => RegExp(r'[A-Za-z0-9_]').hasMatch(c);

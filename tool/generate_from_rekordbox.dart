import 'dart:ffi';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:rekorddart/rekorddart.dart';
import 'package:sqlite3/open.dart' as sqlite_open;
import 'package:sqlite3/sqlite3.dart' as sqlite;

const String _envSqlcipherDylib = 'SQLCIPHER_DYLIB';
const String _envRekordboxDbKey = 'REKORDBOX_DB_KEY';

Future<void> main(List<String> args) async {
  _configureSqlcipherDynamicLibrary();

  final config = getMostRecentRekordboxConfig();
  if (config == null) {
    stderr.writeln('Rekordbox installation not found.');
    exitCode = 1;
    return;
  }

  final dbFile = File(config.dbPath);
  if (!dbFile.existsSync()) {
    stderr.writeln('Rekordbox DB not found at ${config.dbPath}');
    exitCode = 1;
    return;
  }

  final key = _getConfigValue(_envRekordboxDbKey);
  if (key == null || key.isEmpty) {
    stderr.writeln(
      'Missing SQLCipher key: set $_envRekordboxDbKey in environment',
    );
    exitCode = 2;
    return;
  }

  // Open SQLCipher DB with key and dump CREATE statements.
  final db = sqlite.sqlite3.open(dbFile.path);
  try {
    db.execute("PRAGMA key = '$key';");

    final result = db.select(
      """
SELECT type, name, sql
FROM sqlite_master
WHERE type IN ('table','index','view')
  AND sql IS NOT NULL
ORDER BY CASE type WHEN 'table' THEN 0 WHEN 'view' THEN 1 ELSE 2 END, name;""",
    );

    final buffer = StringBuffer()
      ..writeln('-- Generated from Rekordbox schema. Do not edit by hand.')
      ..writeln();

    for (final row in result) {
      var sql = row['sql'] as String;
      sql = _normalizeSqlForDrift(sql);
      buffer.writeln('$sql;\n');
    }

    final outDir = Directory(p.join('lib', 'database'));
    if (!outDir.existsSync()) outDir.createSync(recursive: true);
    final outFile = File(p.join(outDir.path, 'rekordbox_schema.drift'))
      ..writeAsStringSync(buffer.toString());

    stdout.writeln('Wrote schema to ${outFile.path}');
  } finally {
    db.dispose();
  }
}

String _normalizeSqlForDrift(String sql) {
  var out = sql.trim();
  out = out.replaceAll('`', '"');
  out = out
      .replaceAll(RegExp(r'VARCHAR\(\d+\)', caseSensitive: false), 'TEXT')
      .replaceAll(RegExp(r'CHAR\(\d+\)', caseSensitive: false), 'TEXT')
      .replaceAll(RegExp(r'TINYINT\(\d+\)', caseSensitive: false), 'INTEGER')
      .replaceAll(RegExp(r'BIGINT\(\d+\)', caseSensitive: false), 'BIGINT')
      .replaceAll(RegExp(r'INTEGER\(\d+\)', caseSensitive: false), 'INTEGER')
      .replaceAll(RegExp(r'FLOAT\(\d+\)', caseSensitive: false), 'FLOAT');
  out = out
      .replaceAll(RegExp('FLOAT', caseSensitive: false), 'REAL')
      .replaceAll(RegExp('DATETIME', caseSensitive: false), 'TEXT')
      .replaceAll(RegExp('BIGINT', caseSensitive: false), 'INTEGER');
  out = out.replaceAll(RegExp('AUTOINCREMENT', caseSensitive: false), '');

  // Handle Dart reserved keywords and conflicting column names
  out = out.replaceAll('"Class"', '"ItemClass"');
  out = out.replaceAll('"TableName"', '"EntityTableName"');

  return out;
}

void _configureSqlcipherDynamicLibrary() {
  final overridePath = _getConfigValue(_envSqlcipherDylib);
  if (overridePath != null && overridePath.isNotEmpty) {
    sqlite_open.open.overrideForAll(() => DynamicLibrary.open(overridePath));
    return;
  }

  // Check common locations based on platform
  final candidates = <String>[];

  if (Platform.isMacOS) {
    candidates.addAll([
      // Apple Silicon (Homebrew default)
      '/opt/homebrew/opt/sqlcipher/lib/libsqlcipher.0.dylib',
      '/opt/homebrew/opt/sqlcipher/lib/libsqlcipher.dylib',
      // Intel (Homebrew default)
      '/usr/local/opt/sqlcipher/lib/libsqlcipher.0.dylib',
      '/usr/local/opt/sqlcipher/lib/libsqlcipher.dylib',
    ]);
  } else if (Platform.isLinux) {
    candidates.addAll([
      // Debian/Ubuntu default
      '/usr/lib/x86_64-linux-gnu/libsqlcipher.so.0',
      '/usr/lib/x86_64-linux-gnu/libsqlcipher.so',
      // Generic Linux locations
      '/usr/lib/libsqlcipher.so.0',
      '/usr/lib/libsqlcipher.so',
      '/usr/local/lib/libsqlcipher.so.0',
      '/usr/local/lib/libsqlcipher.so',
    ]);
  } else if (Platform.isWindows) {
    candidates.addAll([
      r'C:\Program Files\SQLCipher\sqlcipher.dll',
      r'C:\Program Files (x86)\SQLCipher\sqlcipher.dll',
      r'C:\sqlcipher\sqlcipher.dll',
    ]);
  }

  for (final path in candidates) {
    if (File(path).existsSync()) {
      sqlite_open.open.overrideForAll(() => DynamicLibrary.open(path));
      return;
    }
  }

  // If we reach here, no library was found
  throw StateError(
    'SQLCipher library not found. Please install SQLCipher or set the '
    '$_envSqlcipherDylib environment variable to the library path.\n'
    'Searched locations:\n${candidates.map((p) => '  - $p').join('\n')}',
  );
}

String? _getConfigValue(String name) {
  final env = Platform.environment[name];
  return (env != null && env.isNotEmpty) ? env : null;
}

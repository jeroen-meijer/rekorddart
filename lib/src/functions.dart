import 'dart:io';

import 'package:sqlite3/common.dart';

/// Throws a [StateError] when [database] runs on plain SQLite instead of
/// SQLCipher, which cannot open a Rekordbox database.
///
/// `package:sqlite3` picks its native library when the app is built. Apps that
/// use rekorddart select SQLCipher in their own `pubspec.yaml`:
///
/// ```yaml
/// hooks:
///   user_defines:
///     sqlite3:
///       source: sqlcipher
/// ```
void ensureSqlcipher(CommonDatabase database) {
  if (database.select('PRAGMA cipher_version').isNotEmpty) return;

  throw StateError(
    'SQLite was loaded without SQLCipher, so the Rekordbox database cannot be '
    "opened. Add this to your app's pubspec.yaml and run it with `dart run`, "
    '`dart test`, `dart build cli` or `dart install`:\n'
    '\n'
    'hooks:\n'
    '  user_defines:\n'
    '    sqlite3:\n'
    '      source: sqlcipher\n',
  );
}

/// Checks if a process named `rekordbox` is running on the current system.
///
/// Uses platform-appropriate tools and exact-name matching to avoid false
/// positives:
/// - Windows: `tasklist /FI "IMAGENAME eq rekordbox.exe"`
/// - macOS: `pgrep -x rekordbox` (falls back to `ps -Ac -o comm`)
/// - Linux: `pgrep -x rekordbox` (falls back to `pidof rekordbox`)
Future<bool> checkIsRekordboxRunning() async {
  const processName = 'rekordbox';

  if (Platform.isWindows) {
    // Exact image match and suppress header for easier parsing
    final res = await Process.run('tasklist', [
      '/FI',
      'IMAGENAME eq $processName.exe',
      '/NH',
    ]);
    if (res.exitCode != 0) return false;
    final out = (res.stdout as Object?).toString().toLowerCase();
    if (out.contains('no tasks are running')) return false;
    return out.contains('$processName.exe');
  }

  if (Platform.isMacOS) {
    // Prefer pgrep with exact-name match
    final res = await Process.run('pgrep', ['-x', processName]);
    if (res.exitCode == 0) return true;

    // Fallback: list process commands and look for an exact match
    final ps = await Process.run('ps', ['-Ac', '-o', 'comm']);
    if (ps.exitCode != 0) return false;
    return ps.stdout
        .toString()
        .split('\n')
        .map((s) => s.trim())
        .any((cmd) => cmd == processName);
  }

  // Linux and other unix-likes
  final res = await Process.run('pgrep', ['-x', processName]);
  if (res.exitCode == 0) return true;

  final pidof = await Process.run('pidof', [processName]);
  return pidof.exitCode == 0 && pidof.stdout.toString().trim().isNotEmpty;
}

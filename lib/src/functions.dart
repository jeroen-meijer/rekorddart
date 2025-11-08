import 'dart:ffi';
import 'dart:io';

import 'package:sqlite3/open.dart' as sqlite_open;

/// Configures the SQLCipher dynamic library for use with sqlite3.
///
/// This function attempts to locate the SQLCipher library in the
/// following order:
/// 1. Environment variable override: `SQLCIPHER_DYLIB`
/// 2. Platform-specific common installation paths
/// 3. Throws [StateError] if library not found
///
/// The environment variable takes precedence for custom installations.
void configureSqlcipherDynamicLibrary({
  String? Function(String)? getConfigValue,
}) {
  const envSqlcipherDylib = 'SQLCIPHER_DYLIB';

  // Use provided config getter or default to environment variables
  final configGetter = getConfigValue ?? _getDefaultConfigValue;

  final overridePath = configGetter(envSqlcipherDylib);
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
    '$envSqlcipherDylib environment variable to the library path.\n'
    'Searched locations:\n${candidates.map((p) => '  - $p').join('\n')}',
  );
}

String? _getDefaultConfigValue(String name) {
  if (Platform.environment[name] case final envValue?
      when envValue.isNotEmpty) {
    return envValue;
  }
  return null;
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

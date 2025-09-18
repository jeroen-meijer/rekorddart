import 'dart:io';

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

import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:xml/xml.dart';

/// Database file names for different Rekordbox versions
const String _dbFileV5 = 'datafile.edb';
const String _dbFileV6 = 'master.db';

/// {@template rekordbox_config}
/// Configuration structure for Rekordbox database access
/// {@endtemplate}
class RekordboxConfig {
  /// {@macro rekordbox_config}
  const RekordboxConfig({
    required this.majorVersion,
    required this.installDir,
    required this.appDir,
    required this.rbAppDir,
    required this.dbDir,
    required this.dbPath,
  });

  /// The major version of the Rekordbox database
  final RekordboxVersion majorVersion;

  /// The installation directory of the Rekordbox database
  final String installDir;

  /// The application directory of the Rekordbox database
  final String appDir;

  /// The Rekordbox application directory
  final String rbAppDir;

  /// The database directory of the Rekordbox database
  final String dbDir;

  /// The database path of the Rekordbox database
  final String dbPath;

  /// Check if the database file exists
  bool get dbExists => File(dbPath).existsSync();

  @override
  String toString() {
    return 'RekordboxConfig('
        'majorVersion: $majorVersion, '
        'installDir: $installDir, '
        'appDir: $appDir, '
        'rbAppDir: $rbAppDir, '
        'dbDir: $dbDir, '
        'dbPath: $dbPath'
        ')';
  }
}

/// The version of the Rekordbox database
enum RekordboxVersion {
  /// Rekordbox 5
  v5,

  /// Rekordbox 6
  v6,

  /// Rekordbox 7
  v7,
}

/// Gets the Rekordbox configuration for the most recent major version.
///
/// Returns `null` if no Rekordbox configuration is found.
RekordboxConfig? getMostRecentRekordboxConfig() {
  for (final version in RekordboxVersion.values.reversed) {
    if (getRekordboxConfig(version) case final config?) {
      return config;
    }
  }

  return null;
}

/// Get Rekordbox configuration for the specified major version.
///
/// Returns `null` if the Rekordbox configuration is not found.
RekordboxConfig? getRekordboxConfig(RekordboxVersion majorVersion) {
  final installDir = _getInstallDir(majorVersion);

  final appDir = _getAppDir();

  final rbAppDirName = switch (majorVersion) {
    RekordboxVersion.v6 || RekordboxVersion.v7 => 'rekordbox6',
    RekordboxVersion.v5 => 'rekordbox',
  };

  final rbAppDir = path.join(appDir, rbAppDirName);

  final dbDir = _readSettingsDbDir(rbAppDir);
  if (dbDir == null) return null;

  final dbFilename = switch (majorVersion) {
    RekordboxVersion.v6 || RekordboxVersion.v7 => _dbFileV6,
    RekordboxVersion.v5 => _dbFileV5,
  };
  final dbPath = path.join(dbDir, dbFilename);

  return RekordboxConfig(
    majorVersion: majorVersion,
    installDir: installDir,
    appDir: appDir,
    rbAppDir: rbAppDir,
    dbDir: dbDir,
    dbPath: dbPath,
  );
}

String _getInstallDir(RekordboxVersion majorVersion) {
  if (Platform.isWindows) {
    final programFiles =
        Platform.environment['ProgramFiles'] ?? r'C:\Program Files';
    final pioneerDir = programFiles.replaceAll('(x86)', '').trim();

    if (majorVersion == RekordboxVersion.v7) {
      return path.join(pioneerDir, 'rekordbox');
    } else {
      return path.join(pioneerDir, 'Pioneer');
    }
  } else if (Platform.isMacOS) {
    return '/Applications';
  } else {
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }
}

String _getAppDir() {
  if (Platform.isWindows) {
    final appData =
        Platform.environment['APPDATA'] ?? r'C:\Users\<user>\AppData\Roaming';
    return path.join(appData, 'Pioneer');
  } else if (Platform.isMacOS) {
    final home = Platform.environment['HOME'] ?? '~';
    return path.join(home, 'Library', 'Application Support', 'Pioneer');
  } else {
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }
}

String? _readSettingsDbDir(String rbAppDir) {
  final settingsPath = path.join(rbAppDir, 'rekordbox3.settings');
  final settingsFile = File(settingsPath);

  if (!settingsFile.existsSync()) {
    return null;
  }

  try {
    final xmlContent = settingsFile.readAsStringSync();
    final document = XmlDocument.parse(xmlContent);

    final valueElements = document.findAllElements('VALUE');

    for (final element in valueElements) {
      final nameAttr = element.getAttribute('name');
      if (nameAttr == 'masterDbDirectory') {
        final valAttr = element.getAttribute('val');
        if (valAttr != null) {
          return valAttr;
        }
      }
    }
  } catch (e) {
    return null;
  }

  return null;
}

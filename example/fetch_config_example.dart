import 'package:cli_table/cli_table.dart';
import 'package:rekorddart/logger.dart';
import 'package:rekorddart/rekorddart.dart' hide Table;

/// Example demonstrating how to fetch Rekordbox configuration
/// for different versions of Rekordbox.
Future<void> main() async {
  log('=== Rekordbox Configuration Fetcher Example ===\n');

  log('Checking most recent Rekordbox configuration...');
  final config = getMostRecentRekordboxConfig();

  log('Checking if Rekordbox is running...');
  final isRunning = await checkIsRekordboxRunning();

  final table = Table(header: ['Field', 'Value'], columnWidths: [24, 80]);

  // ignore: avoid_positional_boolean_parameters
  String yesNo(bool value) => value ? '✅ Yes' : '❌ No';

  table
    ..add(['Configuration found', yesNo(config != null)])
    ..add(['Rekordbox is running', yesNo(isRunning)]);
  if (config != null) {
    table
      ..add(['Major version', '${config.majorVersion}'])
      ..add(['Install directory', config.installDir])
      ..add(['App directory', config.appDir])
      ..add(['RB app directory', config.rbAppDir])
      ..add(['Database directory', config.dbDir])
      ..add(['Database path', config.dbPath])
      ..add(['Database exists', yesNo(config.dbExists)]);
  }

  log(table);
}

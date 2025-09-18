import 'package:drift/drift.dart';
import 'package:rekorddart/logger.dart';
import 'package:rekorddart/rekorddart.dart';

/// Example demonstrating how to fetch the most recent 10 tracks
/// with title, artist, BPM, and date created information.
Future<void> main() async {
  log('=== Recent Tracks Example ===\n');

  try {
    final db = await RekordboxDatabase.connect();

    log('🔍 Fetching most recent 10 tracks...');

    final tracks =
        await (db.select(db.djmdContent)
              ..where((track) => track.rbLocalDeleted.equals(0))
              ..orderBy([(track) => OrderingTerm.desc(track.createdAt)])
              ..limit(10))
            .get();

    if (tracks.isEmpty) {
      log('📭 No tracks found in the database.');
      return;
    }

    log('🎵 Found ${tracks.length} tracks:\n');

    for (final track in tracks) {
      final title = track.title ?? 'Unknown Title';
      final bpm = track.bpm?.toString() ?? 'Unknown BPM';
      final addedDate = track.createdAt;

      var artistName = 'Unknown Artist';
      if (track.artistID != null) {
        final artist =
            await (db.select(db.djmdArtist)
                  ..where((artist) => artist.id.equals(track.artistID!)))
                .getSingleOrNull();
        artistName = artist?.name ?? 'Unknown Artist';
      }

      log('🎧 "$title" by $artistName');
      log('   BPM: ${bpm.tryParseBpm()} | Added: $addedDate');
      log('');
    }
  } catch (e) {
    log('❌ Error: $e');
    log('Make sure you have set the REKORDBOX_DB_KEY environment variable');
    log('and that your Rekordbox database is accessible.');
  }
}

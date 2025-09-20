import 'package:rekorddart/logger.dart';
import 'package:rekorddart/rekorddart.dart';

/// Example demonstrating how to fetch the most recent 10 tracks
/// with title, artist, BPM, and date created information.
Future<void> main() async {
  log('=== Recent Tracks Example ===\n');

  try {
    final db = await RekordboxDatabase.connect();

    log('🔍 Fetching most recent 10 tracks...');

    final base = (db.select(db.djmdContent)
      ..excludeDeleted()
      ..orderBy([(track) => OrderingTerm.desc(track.createdAt)])
      ..limit(10));
    final rows = await base.join([
      leftOuterJoin(
        db.djmdArtist,
        db.djmdArtist.id.equalsExp(db.djmdContent.artistID),
      ),
    ]).get();

    if (rows.isEmpty) {
      log('📭 No tracks found in the database.');
      return;
    }

    log('🎵 Found ${rows.length} tracks:\n');

    for (final row in rows) {
      final track = row.readTable(db.djmdContent);
      final artist = row.readTableOrNull(db.djmdArtist);
      final title = track.title ?? 'Unknown Title';
      final bpm = track.realBpm;
      final addedDate = track.createdAt;
      final artistName =
          artist?.name ?? track.srcArtistName ?? 'Unknown Artist';

      log('🎧 "$title" by $artistName');
      log('   BPM: ${bpm ?? 'Unknown BPM'} | Added: $addedDate');
      log('');
    }
  } catch (e) {
    log('❌ Error: $e');
    log('Make sure you have set the REKORDBOX_DB_KEY environment variable');
    log('and that your Rekordbox database is accessible.');
  }
}

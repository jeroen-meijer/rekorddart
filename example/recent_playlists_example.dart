import 'package:rekorddart/logger.dart';
import 'package:rekorddart/rekorddart.dart';

/// Example demonstrating how to fetch the most recent 5 playlists
/// by name and creation date.
Future<void> main() async {
  log('=== Recent Playlists Example ===\n');

  try {
    final db = await RekordboxDatabase.connect();

    log('🔍 Fetching most recent 5 playlists...');

    final query = db.select(db.djmdPlaylist)
      ..excludeDeleted()
      ..where((playlist) => playlist.name.isNotNull())
      ..orderBy([(playlist) => OrderingTerm.desc(playlist.createdAt)])
      ..limit(5);

    final playlists = await query.get();

    if (playlists.isEmpty) {
      log('📭 No playlists found in the database.');
      return;
    }

    log('🎼 Found ${playlists.length} playlists:\n');

    for (final playlist in playlists) {
      final name = playlist.name ?? 'Unnamed Playlist';
      final createdAt = playlist.createdAt;
      final isSmartList = playlist.smartList?.isNotEmpty ?? false;
      final playlistType = isSmartList
          ? '🧠 Smart Playlist'
          : '📋 Regular Playlist';

      log('$playlistType: "$name"');
      log('   Created: $createdAt');

      if (playlist.id != null) {
        final songCount =
            await (db.select(db.djmdSongPlaylist)..where(
                  (songPlaylist) =>
                      songPlaylist.playlistID.equals(playlist.id!) &
                      songPlaylist.rbLocalDeleted.equals(0),
                ))
                .get();

        log('   Tracks: ${songCount.length}');
      }

      log('');
    }
  } catch (e) {
    log('❌ Error: $e');
    log('Make sure you have set the REKORDBOX_DB_KEY environment variable');
    log('and that your Rekordbox database is accessible.');
  }
}

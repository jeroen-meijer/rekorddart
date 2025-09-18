import 'package:drift/drift.dart';
import 'package:rekorddart/logger.dart';
import 'package:rekorddart/rekorddart.dart';

/// Example demonstrating how to create a new playlist and add the user's
/// 5 most recent tracks to it.
Future<void> main() async {
  log('=== Create Playlist Example ===\n');

  try {
    final db = await RekordboxDatabase.connect();

    final now = DateTime.now();
    final dateStr = [
      now.year,
      now.month,
      now.day,
    ].map((e) => e.toString().padLeft(2, '0')).join('-');
    final timeStr = [
      now.hour,
      now.minute,
      now.second,
    ].map((e) => e.toString().padLeft(2, '0')).join(':');

    final playlistName = 'New Playlist $dateStr $timeStr';

    log('🎼 Creating playlist: "$playlistName"');

    log('🔍 Fetching 5 most recent tracks...');
    final recentTracks =
        await (db.select(db.djmdContent)
              ..where((track) => track.rbLocalDeleted.equals(0))
              ..orderBy([(track) => OrderingTerm.desc(track.createdAt)])
              ..limit(5))
            .get();

    if (recentTracks.isEmpty) {
      log('❌ No tracks found in the database. Cannot create playlist.');
      return;
    }

    log('📀 Found ${recentTracks.length} tracks to add:');
    for (final track in recentTracks) {
      log('   • ${track.title ?? 'Unknown Title'}');
    }

    log('\n💾 Creating playlist in database...');

    final createdPlaylist = await db.createPlaylist(name: playlistName);

    final playlistId = createdPlaylist.id!;

    log('✅ Playlist created with ID: ${createdPlaylist.id}');

    log('\n🎵 Adding tracks to playlist...');
    for (var i = 0; i < recentTracks.length; i++) {
      final track = recentTracks[i];

      await db.addSongToPlaylist(
        playlistId: playlistId,
        contentId: track.id!,
      );

      log('   ✓ Added track ${i + 1}: ${track.title ?? 'Unknown Title'}');
    }

    log(
      '\n🎉 Successfully created playlist "$playlistName" with ${recentTracks.length} tracks!',
    );
    log('📝 The playlist should now appear in your Rekordbox application.');

    log('\n🔍 Verifying playlist creation...');
    final playlistAfterEdits = await (db.select(
      db.djmdPlaylist,
    )..where((playlist) => playlist.id.equals(playlistId))).getSingleOrNull();

    if (playlistAfterEdits != null) {
      final trackCount =
          await (db.select(db.djmdSongPlaylist)..where(
                (songPlaylist) => songPlaylist.playlistID.equals(playlistId),
              ))
              .get();

      log('✅ Verification successful:');
      log('   • Playlist: ${createdPlaylist.name}');
      log('   • Tracks: ${trackCount.length}');
      log('   • Created: ${createdPlaylist.createdAt}');
    } else {
      log('❌ Verification failed: Could not find created playlist');
    }
  } catch (e) {
    log('❌ Error: $e');
    log('Make sure you have set the REKORDBOX_DB_KEY environment variable');
    log('and that your Rekordbox database is accessible.');
    log('\n⚠️  Note: Creating playlists modifies your Rekordbox database.');
    log('   Make sure to backup your database before running this example!');
  }
}

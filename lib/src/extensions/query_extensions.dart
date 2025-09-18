import 'package:drift/drift.dart';
import 'package:rekorddart/rekorddart.dart';

/// Extension methods for [DjmdContent] queries.
extension ContentQueryExtension<D> on SingleTableQueryMixin<DjmdContent, D> {
  /// Excludes all deleted tracks from this query.
  ///
  /// Internally runs a `WHERE rbLocalDeleted = 0` clause.
  void excludeDeleted() {
    where((track) => track.rbLocalDeleted.equals(0));
  }
}

/// Extension methods for [DjmdPlaylist] queries.
extension PlaylistQueryExtension<D> on SingleTableQueryMixin<DjmdPlaylist, D> {
  /// Excludes all deleted playlists from this query.
  ///
  /// Internally runs a `WHERE rbLocalDeleted = 0` clause.
  void excludeDeleted() {
    where((playlist) => playlist.rbLocalDeleted.equals(0));
  }
}

/// Extension methods for [DjmdSongPlaylist] queries.
extension SongPlaylistQueryExtension<D>
    on SingleTableQueryMixin<DjmdSongPlaylist, D> {
  /// Excludes all deleted song playlists from this query.
  ///
  /// Internally runs a `WHERE rbLocalDeleted = 0` clause.
  void excludeDeleted() {
    where((songPlaylist) => songPlaylist.rbLocalDeleted.equals(0));
  }
}

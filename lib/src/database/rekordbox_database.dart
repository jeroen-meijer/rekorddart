import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:rekorddart/rekorddart.dart';
import 'package:sqlite3/open.dart' as sqlite_open;
import 'package:uuid/uuid.dart';

part 'rekordbox_database.g.dart';

const String _envSqlcipherDylib = 'SQLCIPHER_DYLIB';
const String _envRekordboxDbKey = 'REKORDBOX_DB_KEY';

/// {@template rekordbox_database}
/// An instance of a Rekordbox database, powered by Drift.
///
/// Once instantiated, will automatically connect to the SQLCipher encrypted
/// Rekordbox database. It is highly recommended to only have one instance of
/// this class in your application.
/// {@endtemplate}
@DriftDatabase(include: {'rekordbox_schema.drift'})
class RekordboxDatabase extends _$RekordboxDatabase {
  /// {@macro rekordbox_database}
  RekordboxDatabase._() : super(_openConnection());

  /// Creates a new instance of [RekordboxDatabase] and immediately connects to
  /// the encrypted Rekordbox database.
  ///
  /// If [allowConnectionWhenRunning] is false, it will throw an error if
  /// Rekordbox is running. It is **highly recommended** to keep this set to
  /// `false`.
  ///
  /// ---
  ///
  /// {@macro rekordbox_database}
  static Future<RekordboxDatabase> connect({
    bool allowConnectionWhenRunning = false,
  }) async {
    if (!allowConnectionWhenRunning && await checkIsRekordboxRunning()) {
      throw StateError(
        'Rekordbox is running. Please close it before '
        'connecting to the database.',
      );
    }
    return RekordboxDatabase._();
  }

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      // Don't create tables - use existing Rekordbox schema
      onCreate: (migrator) async {
        // No-op: database already exists with Rekordbox schema
      },
      onUpgrade: (migrator, from, to) async {
        // No-op: don't modify Rekordbox database
      },
    );
  }

  /// The ID of the root playlist. If a playlist has no parent, this is its
  /// parent ID.
  static const rootPlaylistId = 'root';

  /// Creates a new playlist with reasonable defaults and returns the created
  /// row.
  ///
  /// - Generates a unique string ID if [id] is null/empty
  /// - Generates a UUID v4 if [uuid] is null/empty
  /// - Defaults [parentId] to 'root' when null/empty
  /// - When [seq] is not provided, it appends the playlist at the end
  Future<DjmdPlaylistData> createPlaylist({
    required String name,
    String? parentId,
    int? seq,
    int attribute = 0,
    String? imagePath,
    String? smartListXml,
    String? id,
    String? uuid,
  }) async {
    final effectiveParentId = switch (parentId?.trim()) {
      final parentId? when parentId.isNotEmpty => parentId,
      _ => rootPlaylistId,
    };
    final effectiveSeq =
        seq ?? await _computeNextSeq(parentId: effectiveParentId);
    final effectiveId = (id == null || id.isEmpty)
        ? await _generateUnusedPlaylistId()
        : id;
    final effectiveUuid = (uuid == null || uuid.isEmpty)
        ? const Uuid().v4()
        : uuid;

    final nowIso = DateTime.now().toIso8601String();

    return into(djmdPlaylist).insertReturning(
      DjmdPlaylistCompanion.insert(
        id: Value(effectiveId),
        seq: Value(effectiveSeq),
        name: Value(name),
        imagePath: Value(imagePath),
        attribute: Value(attribute),
        parentID: Value(effectiveParentId),
        smartList: smartListXml.toValue(),
        uuid: Value(effectiveUuid),
        rbDataStatus: const Value(0),
        rbLocalDataStatus: const Value(0),
        rbLocalDeleted: const Value(0),
        rbLocalSynced: const Value(0),
        usn: const Value(null),
        rbLocalUsn: const Value(null),
        createdAt: nowIso,
        updatedAt: nowIso,
      ),
    );
  }

  Future<int> _computeNextSeq({String? parentId}) async {
    final cnt = await _countPlaylists(parentId: parentId);
    return cnt + 1;
  }

  Future<String> _generateUnusedPlaylistId() async {
    const maxTries = 1000000;
    final random = Random.secure();
    for (var i = 0; i < maxTries; i++) {
      final value = random.nextInt(1 << 28);
      if (value < 100) continue;
      final candidate = value.toString();
      final existing = await (select(
        djmdPlaylist,
      )..where((pl) => pl.id.equals(candidate))).getSingleOrNull();
      if (existing == null) return candidate;
    }
    throw StateError(
      'Unable to generate an unused playlist ID after $maxTries attempts',
    );
  }

  Future<int> _countPlaylists({String? parentId}) async {
    final c = countAll();
    final row =
        await (selectOnly(djmdPlaylist)
              ..addColumns([c])
              ..where(djmdPlaylist.parentID.equals(parentId ?? rootPlaylistId)))
            .getSingle();
    return row.read(c) ?? 0;
  }

  /// Counts non-deleted songs in a playlist efficiently.
  Future<int> countSongsInPlaylist(String playlistId) async {
    final c = countAll();
    final row =
        await (selectOnly(djmdSongPlaylist)
              ..addColumns([c])
              ..where(
                djmdSongPlaylist.playlistID.equals(playlistId) &
                    djmdSongPlaylist.rbLocalDeleted.equals(0),
              ))
            .getSingle();
    return row.read(c) ?? 0;
  }

  /// Adds multiple songs to a playlist, normalizing missing fields to valid
  /// defaults to prevent corrupt entries.
  ///
  /// - Assigns sequential TrackNo values appending to the end
  /// - Fills missing ID with UUID v4
  /// - Ensures PlaylistID is set to [playlistId]
  /// - Sets rbLocalDeleted = 0 and default status fields to 0
  /// - Fills missing UUID with UUID v4
  /// - Sets createdAt / updatedAt to now when absent
  Future<List<DjmdSongPlaylistData>> addSongsToPlaylist({
    required String playlistId,
    required List<DjmdSongPlaylistCompanion> entries,
  }) async {
    if (entries.isEmpty) return const <DjmdSongPlaylistData>[];

    final nowIso = DateTime.now().toIso8601String();
    var nextTrack = await countSongsInPlaylist(playlistId) + 1;

    final results = <DjmdSongPlaylistData>[];
    for (final input in entries) {
      // ContentID must be present.
      final contentId = input.contentID.present ? input.contentID.value : null;
      if (contentId == null || contentId.isEmpty) {
        throw ArgumentError('DjmdSongPlaylistCompanion is missing ContentID');
      }

      assert(
        !input.trackNo.present ||
            input.trackNo.value == null ||
            input.trackNo.value! > 0,
        'trackNo must be omitted or greater than 0 when adding songs to a '
        'playlist (song $contentId)',
      );

      final normalized = DjmdSongPlaylistCompanion.insert(
        id: Value(
          input.id.present &&
                  input.id.value != null &&
                  input.id.value!.isNotEmpty
              ? input.id.value!
              : const Uuid().v4(),
        ),
        playlistID: Value(playlistId),
        contentID: Value(contentId),
        trackNo: Value(nextTrack++),
        uuid: Value(
          input.uuid.present &&
                  input.uuid.value != null &&
                  input.uuid.value!.isNotEmpty
              ? input.uuid.value!
              : const Uuid().v4(),
        ),
        rbDataStatus: const Value(0),
        rbLocalDataStatus: const Value(0),
        rbLocalDeleted: const Value(0),
        rbLocalSynced: const Value(0),
        usn: const Value(null),
        rbLocalUsn: const Value(null),
        createdAt: input.createdAt.present ? input.createdAt.value : nowIso,
        updatedAt: input.updatedAt.present ? input.updatedAt.value : nowIso,
      );

      final inserted = await into(djmdSongPlaylist).insertReturning(normalized);
      results.add(inserted);
    }

    return results;
  }

  /// Adds a single song to a playlist. Delegates to [addSongsToPlaylist].
  Future<DjmdSongPlaylistData> addSongToPlaylist({
    required String playlistId,
    required String contentId,
    String? id,
    String? uuid,
    int? trackNo, // Ignored: we append at end to keep sequence valid
  }) async {
    final inserted = await addSongsToPlaylist(
      playlistId: playlistId,
      entries: [
        DjmdSongPlaylistCompanion(
          id: id.toValue(),
          contentID: Value(contentId),
        ),
      ],
    );
    return inserted.first;
  }
}

/// Opens a Drift database connected to the encrypted Rekordbox database.
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final config = getMostRecentRekordboxConfig();
    if (config == null) {
      throw StateError('Rekordbox installation not found on this system.');
    }

    _configureSqlcipherDynamicLibrary();

    final dbFile = File(config.dbPath);
    if (!dbFile.existsSync()) {
      throw StateError('Rekordbox database not found at: ${config.dbPath}');
    }

    final database = NativeDatabase(
      dbFile,
      setup: (rawDb) {
        final key = _getConfigValue(_envRekordboxDbKey);
        if (key == null || key.isEmpty) {
          throw StateError(
            'Missing SQLCipher key: set $_envRekordboxDbKey in the environment',
          );
        }
        rawDb
          ..execute("PRAGMA key = '$key';")
          ..execute('PRAGMA cipher_page_size = 4096;')
          ..execute('PRAGMA cache_size = 10000;')
          ..execute('PRAGMA temp_store = MEMORY;');
      },
    );

    return database;
  });
}

void _configureSqlcipherDynamicLibrary() {
  final overridePath = _getConfigValue(_envSqlcipherDylib);
  if (overridePath != null && overridePath.isNotEmpty) {
    sqlite_open.open.overrideForAll(() => DynamicLibrary.open(overridePath));
    return;
  }

  if (Platform.isMacOS) {
    final candidates = <String>[
      // Apple Silicon (Homebrew default)
      '/opt/homebrew/opt/sqlcipher/lib/libsqlcipher.0.dylib',
      '/opt/homebrew/opt/sqlcipher/lib/libsqlcipher.dylib',
      // Intel (Homebrew default)
      '/usr/local/opt/sqlcipher/lib/libsqlcipher.0.dylib',
      '/usr/local/opt/sqlcipher/lib/libsqlcipher.dylib',
    ];

    for (final path in candidates) {
      if (File(path).existsSync()) {
        sqlite_open.open.overrideForAll(() => DynamicLibrary.open(path));
        return;
      }
    }
  }
}

String? _getConfigValue(String name) {
  if (Platform.environment[name] case final envValue?
      when envValue.isNotEmpty) {
    return envValue;
  }

  return null;
}

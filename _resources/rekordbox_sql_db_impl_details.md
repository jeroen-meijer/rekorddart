# Dart/Flutter SQLCipher solutions for rekordbox database access

Based on comprehensive research, there are **no existing Flutter/Dart libraries** specifically for rekordbox databases, representing a pioneering opportunity. However, excellent generic SQLCipher 4 solutions exist that can work with your rekordbox master.db file. The optimal approach combines **SqfEntity for code generation** from your existing encrypted database with **Drift for runtime type-safe access**.

## Recommended solution architecture

The most practical approach for your rekordbox database uses a **hybrid strategy** that leverages the strengths of different libraries for code generation versus runtime access. SqfEntity can introspect your existing SQLCipher database to generate initial ORM models, while Drift provides superior runtime performance and type safety.

### Primary tools for code generation

**SqfEntity** emerges as the best option for generating Dart classes from your existing rekordbox database. It uniquely supports introspecting existing SQLite/SQLCipher schemas through its `convertDatabaseToModelBase()` function, which can read your database structure and generate corresponding Dart models automatically.

```yaml
# pubspec.yaml
dependencies:
  sqfentity: ^2.5.0
  sqfentity_gen: ^2.5.0
  
dev_dependencies:
  build_runner: ^2.6.0
```

To generate models from your rekordbox database, first decrypt a copy for development:

```dart
// lib/models/rekordbox_model.dart
import 'package:sqfentity/sqfentity.dart';
import 'package:sqfentity_gen/sqfentity_gen.dart';

class RekordboxDbModel extends SqfEntityModelProvider {}

Future<void> generateModelsFromExisting() async {
  // Convert existing database to model
  final dbModel = await convertDatabaseToModelBase(
    RekordboxDbModel()
      ..databaseName = 'rekordbox_master.db'
      ..bundledDatabasePath = 'assets/master_decrypted.db' // Temporary decrypted copy
  );
  
  // Generate model constants
  final modelString = SqfEntityConverter(dbModel).createConstDatabase();
  // Save modelString to file for further customization
}

// After generation, use with encryption
@SqfEntityBuilder(rekordboxModel)
const rekordboxModel = SqfEntityModel(
  modelName: 'RekordboxModel',
  databaseName: 'master.db',
  password: '402fd482c38817c35ffa8ffb8c7d93143b749e7d315df7a81732a1ff43608497',
  databaseTables: [/* Generated tables here */],
);
```

Run code generation with:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Superior runtime solution with Drift

While SqfEntity handles initial code generation, **Drift** provides the most robust runtime implementation with SQLCipher 4. It offers compile-time SQL validation, reactive queries, and excellent encryption support with minimal overhead.

```yaml
dependencies:
  drift: ^2.28.1
  sqlcipher_flutter_libs: ^0.6.4
  sqlite3: ^2.4.0
  path: ^1.9.0
  
dev_dependencies:
  drift_dev: ^2.28.1
  build_runner: ^2.6.0
```

Complete Drift setup for rekordbox:

```dart
// lib/database/rekordbox_database.dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';
import 'package:path/path.dart' as p;

part 'rekordbox_database.g.dart';

// Define tables based on rekordbox schema
class DjmdContent extends Table {
  IntColumn get id => integer().named('ID').autoIncrement()();
  TextColumn get title => text().named('Title')();
  TextColumn get artist => text().named('ArtistName')();
  IntColumn get bpm => integer().named('BPM').nullable()();
  IntColumn get duration => integer().named('Duration')();
  TextColumn get filePath => text().named('FilePath')();
  IntColumn get artistId => integer().named('ArtistID').nullable()();
  IntColumn get albumId => integer().named('AlbumID').nullable()();
  IntColumn get genreId => integer().named('GenreID').nullable()();
}

class DjmdPlaylist extends Table {
  IntColumn get id => integer().named('ID').autoIncrement()();
  TextColumn get name => text().named('Name')();
  IntColumn get parentId => integer().named('ParentID').nullable()();
  TextColumn get smartList => text().named('SmartList').nullable()(); // XML conditions
}

class DjmdSongPlaylist extends Table {
  IntColumn get id => integer().named('ID').autoIncrement()();
  IntColumn get playlistId => integer().named('PlaylistID')();
  IntColumn get contentId => integer().named('ContentID')();
  IntColumn get trackNo => integer().named('TrackNo')();
}

@DriftDatabase(tables: [DjmdContent, DjmdPlaylist, DjmdSongPlaylist])
class RekordboxDatabase extends _$RekordboxDatabase {
  RekordboxDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // Type-safe query methods
  Future<List<DjmdContentData>> getTracksByArtist(String artistName) {
    return (select(djmdContent)
      ..where((t) => t.artist.equals(artistName))
      ..orderBy([(t) => OrderingTerm.asc(t.title)])
    ).get();
  }

  Stream<List<DjmdContentData>> watchTracksInPlaylist(int playlistId) {
    final query = select(djmdContent).join([
      innerJoin(
        djmdSongPlaylist,
        djmdSongPlaylist.contentId.equalsExp(djmdContent.id)
      )
    ])..where(djmdSongPlaylist.playlistId.equals(playlistId));

    return query.watch().map((rows) {
      return rows.map((row) => row.readTable(djmdContent)).toList();
    });
  }

  // BPM range search
  Future<List<DjmdContentData>> findTracksByBpmRange(int minBpm, int maxBpm) {
    return (select(djmdContent)
      ..where((t) => t.bpm.isBetweenValues(minBpm, maxBpm))
      ..orderBy([(t) => OrderingTerm.asc(t.bpm)])
    ).get();
  }

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      // Use the actual rekordbox database path
      final dbPath = '/Users/jeroen/Library/Pioneer/rekordbox/master.db';
      final file = File(dbPath);

      if (!await file.exists()) {
        throw Exception('Rekordbox database not found at $dbPath');
      }

      return NativeDatabase.createInBackground(
        file,
        isolateSetup: () async {
          // Required for Android
          if (Platform.isAndroid) {
            await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
            open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
          }
        },
        setup: (rawDb) {
          // Apply encryption key
          rawDb.execute("PRAGMA key = '402fd482c38817c35ffa8ffb8c7d93143b749e7d315df7a81732a1ff43608497';");
          
          // Performance optimizations for large music libraries
          rawDb.execute("PRAGMA cipher_page_size = 4096;");
          rawDb.execute("PRAGMA cache_size = 10000;");
          rawDb.execute("PRAGMA temp_store = MEMORY;");
        },
      );
    });
  }
}
```

## Rekordbox database schema details

The rekordbox master.db contains **eight primary tables** that form the core music library structure. Understanding this schema is crucial for building effective queries and maintaining data integrity.

### Core table relationships

The **DjmdContent** table serves as the central entity containing track metadata including title, BPM, key, duration, and file paths. It connects to DjmdArtist, DjmdAlbum, and DjmdGenre through foreign keys. The **DjmdSongPlaylist** junction table enables many-to-many relationships between tracks and playlists, while **DjmdPlaylist** stores both regular playlists and smart playlists (with XML filter conditions in the SmartList field).

## Performance optimization strategies

Working with large music libraries requires careful optimization to maintain UI responsiveness. The **most critical factor** is connection management - never repeatedly open and close SQLCipher connections as key derivation is extremely expensive (256,000 PBKDF2 rounds by default).

### Essential optimizations for Flutter

```dart
// Singleton pattern for connection reuse
class DatabaseManager {
  static RekordboxDatabase? _instance;
  
  static Future<RekordboxDatabase> getInstance() async {
    _instance ??= RekordboxDatabase();
    await _instance!.executor.ensureOpen(_instance!.executor);
    return _instance!;
  }
}

// Batch operations for bulk imports
Future<void> importLargePlaylists(List<PlaylistData> items) async {
  final db = await DatabaseManager.getInstance();
  await db.batch((batch) {
    for (final item in items) {
      batch.insert(db.djmdPlaylist, item);
    }
  });
}

// Pagination for large result sets
Stream<List<Track>> getTracksPagedStream(int pageSize) async* {
  int offset = 0;
  List<Track> batch;
  
  do {
    batch = await db.djmdContent
      .limit(pageSize, offset: offset)
      .get();
    
    if (batch.isNotEmpty) {
      yield batch;
      offset += pageSize;
    }
  } while (batch.length == pageSize);
}
```

### SQLCipher-specific performance tuning

For optimal performance with encrypted databases, adjust cipher parameters based on your security requirements:

```sql
-- Performance vs security trade-offs
PRAGMA cipher_page_size = 4096;  -- Larger pages for music metadata
PRAGMA kdf_iter = 64000;          -- Reduce from 256000 if security allows
PRAGMA cache_size = 10000;        -- Increase cache for large libraries
PRAGMA temp_store = MEMORY;       -- Use memory for temp operations
```

## Complete implementation workflow

### Step 1: Initial setup and dependencies

Add all required packages to pubspec.yaml, ensuring version compatibility with your Flutter SDK.

### Step 2: Generate initial models

Use SqfEntity to introspect your database structure. Create a temporary decrypted copy for development-time introspection:

```bash
# Decrypt database for schema extraction (development only)
sqlite3 master.db
> PRAGMA key = '402fd482c38817c35ffa8ffb8c7d93143b749e7d315df7a81732a1ff43608497';
> .output schema.sql
> .schema
> .quit
```

### Step 3: Implement Drift models

Convert generated SqfEntity models to Drift table definitions, adding relationships and custom query methods specific to rekordbox use cases.

### Step 4: Create repository layer

Build a repository pattern that abstracts database operations:

```dart
class RekordboxRepository {
  final RekordboxDatabase _db;
  
  RekordboxRepository(this._db);
  
  // High-level operations
  Future<List<Track>> searchTracks(String query) async {
    return await _db.customSelect(
      'SELECT * FROM DjmdContent WHERE Title LIKE ?1 OR ArtistName LIKE ?1',
      variables: [Variable.withString('%$query%')]
    ).map((row) => Track.fromData(row.data)).get();
  }
  
  Stream<List<Playlist>> watchPlaylists() {
    return _db.select(_db.djmdPlaylist).watch()
      .map((rows) => rows.map((row) => Playlist.fromData(row)).toList());
  }
}
```

### Step 5: Implement UI integration

Use StreamBuilder widgets for reactive updates:

```dart
StreamBuilder<List<Track>>(
  stream: repository.watchTracksInPlaylist(playlistId),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return CircularProgressIndicator();
    return ListView.builder(
      itemCount: snapshot.data!.length,
      itemBuilder: (context, index) => TrackListItem(snapshot.data![index]),
    );
  },
);
```

## Alternative approaches

While the Drift + SqfEntity combination provides the optimal solution, **sqflite_sqlcipher** offers a simpler alternative if you're comfortable with manual SQL and don't require advanced ORM features. It provides basic SQLCipher 4 support with straightforward encryption:

```dart
// Simple sqflite_sqlcipher approach
import 'package:sqflite_sqlcipher/sqflite.dart';

final db = await openDatabase(
  'master.db',
  password: '402fd482c38817c35ffa8ffb8c7d93143b749e7d315df7a81732a1ff43608497',
  readOnly: true, // Recommended for rekordbox database
  onOpen: (db) async {
    // Manual queries without ORM
    final tracks = await db.query('DjmdContent', 
      where: 'BPM BETWEEN ? AND ?', 
      whereArgs: [120, 130]
    );
    // Manual mapping required
    return tracks.map((row) => Track.fromMap(row)).toList();
  }
);
```

## Best practices and considerations

When working with the rekordbox database, **always open in read-only mode** unless you fully understand the schema constraints and have proper backups. The database uses complex relationships and rekordbox expects specific data formats.

For **production applications**, implement proper error handling for encryption failures, corrupted databases, and missing files. Consider caching frequently accessed data in memory to reduce encryption overhead, and use background isolates for heavy operations like full library scans.

The lack of existing Flutter rekordbox libraries presents an opportunity to create the first comprehensive solution. Reference the mature **pyrekordbox** (Python) and **go-rekordbox** (Go) implementations for schema details and best practices, as they've already solved many challenges you'll encounter.
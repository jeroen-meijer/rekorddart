# Rekorddart 💿🎯

A Dart library for accessing Rekordbox databases.

## Features

// TODO

## Getting started

- Dart 3.8.2+
- Rekordbox 6.0.0+
- SQLCipher 4.0.0+

## Usage

Generate entity classes from your local Rekordbox database and use a type-safe ORM without writing SQL.

### 1. Install dependencies

```
fvm dart pub get
```

### 2. Set environment variables

Set the SQLCipher library and Rekordbox DB key via environment variables:

```
export SQLCIPHER_DYLIB=/opt/homebrew/opt/sqlcipher/lib/libsqlcipher.0.dylib
export REKORDBOX_DB_KEY=<your Rekordbox sqlcipher key>
```

#### Getting the Rekordbox Database Key

You can obtain the Rekordbox database encryption key in several ways:

1. **Download from online sources** (recommended):
   ```bash
   # Install the rekorddart executable globally
   fvm dart pub global activate --source path .
   
   # Download and display the encryption key
   download_key
   ```

2. **Use the default key**: If no `REKORDBOX_DB_KEY` environment variable is set, the library will automatically use a default key (`402fd482c38817c35ffa8ffb8c7d93143b749e7d315df7a81732a1ff43608497`).

3. **Set manually**: If you already know your key, set it directly:
   ```bash
   export REKORDBOX_DB_KEY=your_key_here
   ```

### 3. (Optional)Generate Drift schema from your encrypted Rekordbox DB

```
fvm dart run tool/generate_from_rekordbox.dart
```

This writes `lib/database/rekordbox_schema.drift` based on your actual database.

### 4. (Optional) Run code generation

```
fvm dart run build_runner build --delete-conflicting-outputs
```

### 5. Use the database

```dart
import 'package:rekorddart/rekorddart.dart';

// The library automatically handles encryption key retrieval:
// 1. Uses REKORDBOX_DB_KEY environment variable if set
// 2. Falls back to default key if environment variable is not set
final key = getRekordboxEncryptionKey();

final db = RekordboxDatabase();
// Use generated DAOs/entities, e.g.
final tracks = await db.select(db.djmdContent).get();
```

## Examples

The `example/` directory contains practical usage examples:

- **`recent_tracks_example.dart`** - Fetches the 10 most recent tracks with title, artist, BPM, and date
- **`recent_playlists_example.dart`** - Gets the 5 most recent playlists with name and track count
- **`create_playlist_example.dart`** - Creates a new playlist with current date/time and adds 5 most recent tracks

Run examples:

```bash
# Check if Rekordbox is running and get configuration
fvm dart run example/fetch_config_example.dart

export REKORDBOX_DB_KEY=<your_key>
# Fetch the 10 most recent tracks
fvm dart run example/recent_tracks_example.dart
# Fetch the 5 most recent playlists
fvm dart run example/recent_playlists_example.dart

# ⚠️ Warning: This modifies your Rekordbox database!
# Create a new playlist with current date/time and add 5 most recent tracks
fvm dart run example/create_playlist_example.dart
```

## Additional information

// TODO
# Rekorddart 💿🎯

A Dart library for accessing Rekordbox databases.

> [!CAUTION]
> ⚠️ **DISCLAIMER** ⚠️
>
> This library is not in any way affiliated with AlphaTheta, Pioneer DJ, or any other company.
> It is also heavily in development and may change at any time.
> **Make a backup of your entire Rekordbox library before running any code.**
> I am not responsible for any damage to your Rekordbox library
> or for the time you've lost having to put all your beat grids and cue points back after you broke something.

## Features

- Type-safe access to your Rekordbox database
- No need to export and re-import your Rekordbox library from/to XML
- Create, read, update, and delete any track, playlist, or other entity

## Getting started

Make sure you have the following installed:

### Prerequisites

- **Dart 3.8.2+**: [Download Dart SDK](https://dart.dev/get-dart) - Choose your platform and follow the installation instructions
- **Rekordbox 6.0.0+**: [Download Rekordbox](https://rekordbox.com/en/download/) - Official DJ software from AlphaTheta/Pioneer DJ
- **SQLCipher 4.0.0+**: [Download SQLCipher](https://www.zetetic.net/sqlcipher/open-source/) - Encrypted SQLite database library
  - **macOS (Homebrew)**: `brew install sqlcipher`
  - **Windows**: [Pre-compiled binaries](https://www.zetetic.net/sqlcipher/downloads/)
  - **Linux**: Install via your package manager (e.g., `apt install sqlcipher` on Ubuntu)

## Usage

Add the library to your `pubspec.yaml`, instantiate the `RekordboxDatabase` class and start querying your database.

```dart
import 'package:rekorddart/rekorddart.dart';

final db = await RekordboxDatabase.connect();
final tracks = await db.select(db.djmdContent).get();
```

### 1. Install dependencies

```sh
dart pub get
```

### 2. Set environment variables

Set the SQLCipher library and Rekordbox DB key via environment variables:

```sh
export SQLCIPHER_DYLIB=/opt/homebrew/opt/sqlcipher/lib/libsqlcipher.0.dylib
# Optional
export REKORDBOX_DB_KEY=<your Rekordbox sqlcipher key>
```

#### Getting the Rekordbox Database Key

You can obtain the Rekordbox database encryption key in several ways:

1. **Download from online sources** (recommended):

   ```sh
   # Install the rekorddart executable globally
   dart pub global activate rekorddart

   # OR if you want to build from source
   dart pub global activate --source path .

   # Download and display the encryption key
   download_key
   ```

2. **Use the default key**: If no `REKORDBOX_DB_KEY` environment variable is set, the library will automatically use a default key.

3. **Set manually**: If you already know your key, set it directly:

   ```sh
   export REKORDBOX_DB_KEY=your_key_here
   ```

### 3. (Optional)Generate Drift schema from your encrypted Rekordbox DB

```
dart run tool/generate_from_rekordbox.dart
```

This writes `lib/database/rekordbox_schema.drift` based on your actual database.

### 4. (Optional) Run code generation

```
dart run build_runner build --delete-conflicting-outputs
```

## Examples

The `example/` directory contains practical usage examples:

- **`fetch_config_example.dart`** - Fetches the Rekordbox configuration
- **`recent_tracks_example.dart`** - Fetches the 10 most recent tracks with title, artist, BPM, and date
- **`recent_playlists_example.dart`** - Gets the 5 most recent playlists with name and track count
- **`create_playlist_example.dart`** - **(⚠️ Warning: This modifies your Rekordbox database!)** Creates a new playlist with current date/time and adds 5 most recent tracks

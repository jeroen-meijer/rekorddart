## Upcoming

## 2.0.0

- docs: require every PR to update Upcoming; prefer end-user wording when the change is visible; write what the UI does instead of soft wrappers; keep changelog bullets consecutive (no blank lines between them)
- chore: add database and extensions barrels; export them from rekorddart.dart
- feat: `RekordboxDatabase.connect(allowConnectionWhenRunning: true)` prints a warning when Rekordbox is running, since writing to the database then can corrupt it
- feat!: you no longer install SQLCipher yourself. Add `hooks: user_defines: sqlite3: source: sqlcipher` to your app's `pubspec.yaml` and `package:sqlite3` downloads it when the app builds. `configureSqlcipherDynamicLibrary` and `SQLCIPHER_DYLIB` are gone, and `connect()` throws a clear error when the app loads plain SQLite
- chore(deps)!: upgrade to sqlite3 3, drift 2.35 and xml 7. rekorddart re-exports drift, so your app gets the drift 2.35 API

## 1.1.1

- fix: use default encryption key when REKORDBOX_DB_KEY environment variable is not set

## 1.1.0

- feat: auto-scan for SQL Cipher library in common installation locations.

## 1.0.2

- feat: add `createPlaylistFolder` and `deletePlaylist` methods to `RekordboxDatabase`.

## 1.0.1

- chore: export `package:drift` from this package, circumventing the need to add it as a dependency in your project.
- docs: minor example updates, add outer join in `recent_tracks_example`.

## 1.0.0

- Initial version.

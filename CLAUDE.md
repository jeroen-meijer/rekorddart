# Rekorddart

A Dart library for type-safe access to Rekordbox SQLite databases (SQLCipher-encrypted).

## Tech Stack

- **Dart 3.10+**
- **Drift** — SQLite ORM, schema from `rekordbox_schema.drift`
- **sqlite3** — SQLite driver
- **SQLCipher** — encryption (external; must be installed)
- **very_good_analysis** — lint rules

## Key Directories

```
lib/
├── rekorddart.dart        # Public exports
├── database/              # Rekordbox DB access
│   ├── rekordbox_database.dart
│   ├── rekordbox_schema.drift
│   └── rekordbox_database.g.dart
├── config.dart            # DB path, SQLCipher config
├── extensions/            # Query helpers, DJMD content extensions
└── functions.dart
example/                   # Usage examples (fetch_config, recent_tracks, create_playlist)
tool/                      # generate_from_rekordbox.dart — introspect DB → drift schema
bin/                       # download_key executable
_resources/                 # rekordbox_sql_db_impl_details.md (implementation notes)
```

## Prerequisites / Environment

- **Rekordbox 6.0.0+** — produces `master.db` (SQLCipher-encrypted)
- **SQLCipher 4.0.0+** — `brew install sqlcipher` (macOS)
- Optional env vars:
  - `SQLCIPHER_DYLIB` — path to libsqlcipher (if non-standard)
  - `REKORDBOX_DB_KEY` — decryption key (or use default)

## Common Commands

```bash
dart pub get
dart run build_runner build --delete-conflicting-outputs
dart run tool/generate_from_rekordbox.dart   # Regenerate drift schema from your DB
dart test
```

## Code Standards

- Use `dart` (not `fvm dart`).
- Schema lives in `lib/database/`; Drift generates `.g.dart` files.
- Extensions in `lib/src/extensions/` — query helpers, DJMD content utilities.

## Project-Specific Warnings

- **Not affiliated with AlphaTheta/Pioneer DJ.** For development only.
- **Always back up your Rekordbox library** before running any code that modifies the DB.
- Writing to the Rekordbox database can corrupt beat grids, cue points, etc. — use with caution.
- Examples like `create_playlist_example.dart` modify the DB — test on a copy.

## Documentation

- [README.md](README.md) — setup, usage
- [_resources/rekordbox_sql_db_impl_details.md](_resources/rekordbox_sql_db_impl_details.md) — SQLCipher/Dart integration details

## Changelog

`CHANGELOG.md` → `## Upcoming` is the **user-facing draft for the next release**, not a commit diary.

- Write for someone who gets the next package version. Conventional prefixes are fine.
- **Unshipped work:** edit or merge existing Upcoming bullets. Do not add `fix(X)` under a `feat(X)` that never left Upcoming.
- **After a release:** only then does a later bug fix get its own Upcoming line.
- Prefer fewer, broader bullets. Skip internal-only churn unless consumers notice it.
- Run `/humanize` (or match that skill) on every new or edited Upcoming bullet before you commit. Keep conventional prefixes; the rest should read like a short product note, not a session diary.
- Keep the `## Upcoming` heading forever. On release, move its bullets into `## {version}` (or `## {version} - {YYYY-MM-DD}`) under it.

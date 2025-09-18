#!/bin/bash

# Generate Drift schema and run build runner for Rekordbox database
set -e

echo "🎵 Rekordbox Drift Generator"
echo "=========================="

# Check if REKORDBOX_DB_KEY is set
if [ -z "$REKORDBOX_DB_KEY" ]; then
    echo "❌ Error: REKORDBOX_DB_KEY environment variable is not set"
    echo "Please export your Rekordbox SQLCipher key:"
    echo "export REKORDBOX_DB_KEY=<your_key>"
    exit 1
fi

# Optional: Check for SQLCipher library (macOS Homebrew paths)
if [ "$(uname)" = "Darwin" ] && [ -z "$SQLCIPHER_DYLIB" ]; then
    for lib_path in \
        "/opt/homebrew/opt/sqlcipher/lib/libsqlcipher.0.dylib" \
        "/opt/homebrew/opt/sqlcipher/lib/libsqlcipher.dylib" \
        "/usr/local/opt/sqlcipher/lib/libsqlcipher.0.dylib" \
        "/usr/local/opt/sqlcipher/lib/libsqlcipher.dylib"; do
        if [ -f "$lib_path" ]; then
            export SQLCIPHER_DYLIB="$lib_path"
            echo "📚 Found SQLCipher library: $lib_path"
            break
        fi
    done

    if [ -z "$SQLCIPHER_DYLIB" ]; then
        echo "⚠️  Warning: SQLCipher library not found in standard Homebrew locations"
        echo "   You may need to install it with: brew install sqlcipher"
        echo "   Or set SQLCIPHER_DYLIB manually"
    fi
fi

echo ""
echo "🔧 Installing dependencies..."
fvm dart pub get

echo ""
echo "🗃️  Generating Drift schema from Rekordbox database..."
fvm dart run tool/generate_from_rekordbox.dart

echo ""
echo "⚙️  Running Drift code generation..."
fvm dart run build_runner build --delete-conflicting-outputs

echo ""
echo "✅ Done! Your Rekordbox database entities are ready to use."
echo ""
echo "Example usage:"
echo "  import 'package:rekorddart/database/rekordbox_database.dart';"
echo "  final db = RekordboxDatabase();"
echo "  final tracks = await db.select(db.djmdContent).get();"

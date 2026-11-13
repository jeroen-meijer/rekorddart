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

echo ""
echo "🔧 Installing dependencies..."
dart pub get

echo ""
echo "🗃️  Generating Drift schema from Rekordbox database..."
dart run tool/generate_from_rekordbox.dart

echo ""
echo "⚙️  Running Drift code generation..."
dart run build_runner build --delete-conflicting-outputs

echo ""
echo "✅ Done! Your Rekordbox database entities are ready to use."
echo ""
echo "Example usage:"
echo "  import 'package:rekorddart/database/rekordbox_database.dart';"
echo "  final db = RekordboxDatabase();"
echo "  final tracks = await db.select(db.djmdContent).get();"

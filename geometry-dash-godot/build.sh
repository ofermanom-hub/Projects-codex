#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
OUT="$SCRIPT_DIR/dist/GeometryDash.zip"

if [ ! -f "$GODOT" ]; then
    echo "ERROR: Godot not found at $GODOT"
    exit 1
fi

echo "============================================"
echo " Geometry Dash — Godot 4.3 macOS Build"
echo "============================================"

echo "[1/3] Importing project..."
"$GODOT" --headless --path "$SCRIPT_DIR" --import

echo "[2/3] Exporting macOS build..."
mkdir -p "$SCRIPT_DIR/dist"
"$GODOT" --headless --path "$SCRIPT_DIR" --export-release "macOS" "$OUT"

echo "[3/3] Done!"
echo "Output: $OUT"
echo "Unzip and double-click GeometryDash.app to run."

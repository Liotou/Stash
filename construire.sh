#!/bin/bash
# Compile Stash et assemble Stash.app à côté de ce script.
set -euo pipefail

racine="$(cd "$(dirname "$0")" && pwd)"
cd "$racine"

echo "→ Compilation…"
swift build -c release --disable-sandbox

app="$racine/Stash.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"

cp "$racine/.build/release/Stash" "$app/Contents/MacOS/Stash"
cp "$racine/Ressources/Info.plist" "$app/Contents/Info.plist"
cp "$racine/Ressources/Stash.icns" "$app/Contents/Resources/Stash.icns"
printf 'APPL????' > "$app/Contents/PkgInfo"

echo "→ Signature ad hoc…"
codesign --force --sign - --identifier fr.equiriconi.stash "$app"

echo "✓ Prêt : $app"

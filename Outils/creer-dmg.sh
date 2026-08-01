#!/bin/bash
# Assemble Stash.dmg : l'application et un alias vers /Applications, à glisser dedans.
# Usage : Outils/creer-dmg.sh   (construit l'app au préalable si besoin)
set -euo pipefail

racine="$(cd "$(dirname "$0")/.." && pwd)"
cd "$racine"

[ -d "Stash.app" ] || ./construire.sh

version="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Ressources/Info.plist)"
dmg="$racine/Stash-$version.dmg"
montage="$(mktemp -d)/Stash"

mkdir -p "$montage"
/usr/bin/ditto "$racine/Stash.app" "$montage/Stash.app"
ln -s /Applications "$montage/Applications"

echo "→ Création de l’image disque…"
rm -f "$dmg"
hdiutil create -volname "Stash" -srcfolder "$montage" -ov -format UDZO -quiet "$dmg"
rm -rf "$(dirname "$montage")"

echo "✓ Prêt : $dmg"

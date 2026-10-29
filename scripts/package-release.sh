#!/bin/bash
# Build a renamed, independently branded universal release on macOS.
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${1:-1.6.0}"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Version must be major.minor.patch" >&2
  exit 1
fi
export APP_NAME=Lineboard
export APP_ICON_SCRIPT=scripts/make-lineboard-icon.swift
export VERSION_OVERRIDE="$VERSION"
export BUILD_NUMBER=160
scripts/build-app.sh release
APP="build/Lineboard.app"
cp LICENSE "$APP/Contents/Resources/LICENSE"
# Adding resources invalidates the signature, so sign the final bundle again.
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
lipo "$APP/Contents/MacOS/Tendedero" -verify_arch arm64 x86_64
OUT="build/release"
mkdir -p "$OUT"
ZIP="Lineboard-$VERSION-universal.app.zip"
DMG="Lineboard-$VERSION-universal.dmg"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUT/$ZIP"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/Lineboard.app"
ln -s /Applications "$STAGE/Applications"
cp LICENSE "$STAGE/LICENSE.txt"
cat > "$STAGE/Read Me.txt" <<'TXT'
Lineboard — independent universal clipboard fork of Tendedero.
Requires macOS 14+, Apple Silicon or Intel. Drag Lineboard.app into Applications.
Quit any running Tendedero/Lineboard before opening this version.
This build is ad-hoc signed and is NOT Apple-notarized. No Developer ID is bundled.
Use macOS Privacy & Security / Open Anyway only if you trust this repository.
Settings and clipboard history use the existing bundle identifier for compatibility.
Repository: https://github.com/LeeHero0803/tendedero
TXT
rm -f "$OUT/$DMG"
hdiutil create -quiet -volname Lineboard -srcfolder "$STAGE" -fs HFS+ -format UDZO "$OUT/$DMG"
export LINEBOARD_RELEASE_VERSION="$VERSION"
python3 - <<'PY'
import json, os, subprocess
from pathlib import Path
info={"product":"Lineboard","version":os.environ["LINEBOARD_RELEASE_VERSION"],
      "source_commit":subprocess.check_output(["git","rev-parse","HEAD"],text=True).strip(),
      "architectures":["arm64","x86_64"],"minimum_macos":"14.0",
      "signing":"ad-hoc","notarized":False}
Path('build/release/build-info.json').write_text(json.dumps(info,indent=2)+'\n')
PY
(cd "$OUT" && shasum -a 256 "$ZIP" "$DMG" build-info.json > SHA256SUMS.txt)
echo "Release assets ready in $OUT"

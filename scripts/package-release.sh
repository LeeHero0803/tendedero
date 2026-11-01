#!/bin/bash
# Build a renamed, independently branded universal release on macOS.
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${1:-1.6.0}"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Version must be major.minor.patch" >&2
  exit 1
fi
PACKAGE_LABEL="${PACKAGE_LABEL:-$VERSION}"
if [[ ! "$PACKAGE_LABEL" =~ ^[A-Za-z0-9][A-Za-z0-9.+-]*$ ]]; then
  echo "Package label must use letters, digits, dots, plus or minus" >&2
  exit 1
fi
export APP_NAME=Lineboard
export APP_ICON_SCRIPT=scripts/make-lineboard-icon.swift
export VERSION_OVERRIDE="$VERSION"
export BUILD_NUMBER="${BUILD_NUMBER:-${VERSION//./}}"
scripts/build-app.sh release
APP="build/Lineboard.app"
cp LICENSE "$APP/Contents/Resources/LICENSE"
# Adding resources invalidates the signature, so sign the final bundle again.
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
lipo "$APP/Contents/MacOS/Tendedero" -verify_arch arm64 x86_64
OUT="build/release"
mkdir -p "$OUT"
ZIP="Lineboard-$PACKAGE_LABEL-universal.app.zip"
DMG="Lineboard-$PACKAGE_LABEL-universal.dmg"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUT/$ZIP"
WORK="$(mktemp -d)"
STAGE="$WORK/stage"
MOUNT="$WORK/mount"
cleanup() {
  if mount | grep -Fq " on $MOUNT ("; then
    hdiutil detach -quiet "$MOUNT" || hdiutil detach -force -quiet "$MOUNT" || true
  fi
  rm -rf "$WORK"
}
trap cleanup EXIT
mkdir -p "$STAGE/.background" "$STAGE/.info" "$MOUNT"
ditto "$APP" "$STAGE/Lineboard.app"
ln -s /Applications "$STAGE/Applications"
cp LICENSE "$STAGE/.info/LICENSE.txt"
cat > "$STAGE/.info/Read Me.txt" <<'TXT'
Lineboard — independent universal clipboard fork of Tendedero.
Requires macOS 14+, Apple Silicon or Intel. Drag Lineboard.app into Applications.
Quit any running Tendedero/Lineboard before opening this version.
This build is ad-hoc signed and is NOT Apple-notarized. No Developer ID is bundled.
Use macOS Privacy & Security / Open Anyway only if you trust this repository.
Settings and clipboard history use the existing bundle identifier for compatibility.
Repository: https://github.com/LeeHero0803/tendedero
TXT
swift scripts/make-dmg-background.swift "$WORK/bg1x.png" 1
swift scripts/make-dmg-background.swift "$WORK/bg2x.png" 2
tiffutil -cathidpicheck "$WORK/bg1x.png" "$WORK/bg2x.png" \
  -out "$STAGE/.background/background.tiff" >/dev/null

# Store Finder's drag-to-install layout before compressing the disk image.
RW="$WORK/rw.dmg"
SIZE_MB="$(du -sm "$STAGE" | awk '{print $1 + 40}')"
hdiutil create -quiet -srcfolder "$STAGE" -volname Lineboard -fs HFS+ \
  -format UDRW -size "${SIZE_MB}m" "$RW"
hdiutil attach -quiet -readwrite -noverify -noautoopen -nobrowse \
  -mountpoint "$MOUNT" "$RW"
osascript <<OSA
with timeout of 120 seconds
  set installFolder to POSIX file "$MOUNT" as alias
  tell application "Finder"
    open installFolder
    set installWindow to container window of installFolder
    set current view of installWindow to icon view
    set toolbar visible of installWindow to false
    set statusbar visible of installWindow to false
    set bounds of installWindow to {200, 120, 800, 528}
    set opts to icon view options of installWindow
    set arrangement of opts to not arranged
    set icon size of opts to 112
    set text size of opts to 13
    set background picture of opts to POSIX file "$MOUNT/.background/background.tiff" as alias
    set position of item "Lineboard.app" of installFolder to {160, 178}
    set position of item "Applications" of installFolder to {440, 178}
    set bounds of installWindow to {200, 120, 800, 528}
    update installFolder without registering applications
    delay 1
    set bounds of installWindow to {200, 120, 800, 528}
    delay 1
    close installWindow
  end tell
end timeout
OSA
sync
if [[ ! -s "$MOUNT/.DS_Store" ]]; then
  echo "Finder did not save the installer window layout" >&2
  exit 1
fi
hdiutil detach -quiet "$MOUNT"
rm -f "$OUT/$DMG"
hdiutil convert -quiet "$RW" -format UDZO -imagekey zlib-level=9 -o "$OUT/$DMG"
export LINEBOARD_RELEASE_VERSION="$VERSION"
export LINEBOARD_PACKAGE_LABEL="$PACKAGE_LABEL"
export BUILD_CHANNEL="${BUILD_CHANNEL:-release}"
python3 - <<'PY'
import json, os, subprocess
from pathlib import Path
info={"product":"Lineboard","version":os.environ["LINEBOARD_RELEASE_VERSION"],
      "package_label":os.environ["LINEBOARD_PACKAGE_LABEL"],
      "channel":os.environ["BUILD_CHANNEL"],
      "source_commit":subprocess.check_output(["git","rev-parse","HEAD"],text=True).strip(),
      "architectures":["arm64","x86_64"],"minimum_macos":"14.0",
      "signing":"ad-hoc","notarized":False}
Path('build/release/build-info.json').write_text(json.dumps(info,indent=2)+'\n')
PY
(cd "$OUT" && shasum -a 256 "$ZIP" "$DMG" build-info.json > SHA256SUMS.txt)
echo "Release assets ready in $OUT"

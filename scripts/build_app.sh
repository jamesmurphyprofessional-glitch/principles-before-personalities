#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="Principles Before Personalities"
EXEC_NAME="PrinciplesBeforePersonalities"
DIST_DIR="$ROOT/dist"
APP_BUNDLE="$DIST_DIR/${APP_NAME}.app"
APPLICATIONS="/Applications/${APP_NAME}.app"
ICON_SRC="$ROOT/Assets/icon-source.jpg"

echo "==> Building ${APP_NAME}…"
swift build -c release --product "$EXEC_NAME"

BIN="$ROOT/.build/release/$EXEC_NAME"
if [[ ! -f "$BIN" ]]; then
  BIN="$(find "$ROOT/.build" -type f -name "$EXEC_NAME" -path "*/release/*" ! -path "*.dSYM*" | head -1)"
fi
if [[ -z "${BIN}" || ! -f "$BIN" ]]; then
  echo "error: could not find release binary" >&2
  exit 1
fi

echo "==> Assembling .app…"
rm -rf "$DIST_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BIN" "$APP_BUNDLE/Contents/MacOS/$EXEC_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$EXEC_NAME"
cp "$ROOT/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
printf 'APPLPBPB' > "$APP_BUNDLE/Contents/PkgInfo"

# The app reads library.json from Bundle.main (Contents/Resources). Never rely on
# SwiftPM's synthesized Bundle.module at runtime: it calls fatalError when its
# resource bundle is not found next to the executable.
if grep -rq --include='*.swift' 'Bundle\.module' "$ROOT/Sources"; then
  echo "error: Sources reference Bundle.module; use Bundle.main instead" >&2
  exit 1
fi

BIN_DIR="$(dirname "$BIN")"
RES_BUNDLE_NAME="${EXEC_NAME}_${EXEC_NAME}.bundle"
RES_BUNDLE="$BIN_DIR/$RES_BUNDLE_NAME"
[[ -d "$RES_BUNDLE" ]] || RES_BUNDLE="$ROOT/.build/release/$RES_BUNDLE_NAME"

LIBRARY_JSON="$RES_BUNDLE/Contents/Resources/library.json"
if [[ ! -f "$LIBRARY_JSON" ]]; then
  LIBRARY_JSON="$ROOT/Sources/$EXEC_NAME/Resources/library.json"
fi
if [[ ! -f "$LIBRARY_JSON" ]]; then
  echo "error: missing bundled library" >&2
  exit 1
fi
cp "$LIBRARY_JSON" "$APP_BUNDLE/Contents/Resources/library.json"

# Belt and braces: also ship the SwiftPM resource bundle inside Contents/Resources
# so Bundle.module would resolve (via Bundle.main.resourceURL) if ever referenced.
if [[ -d "$RES_BUNDLE" ]]; then
  ditto "$RES_BUNDLE" "$APP_BUNDLE/Contents/Resources/$RES_BUNDLE_NAME"
fi

if [[ -f "$ICON_SRC" ]]; then
  echo "==> Building icon…"
  ICONSET="$ROOT/.build/AppIcon.iconset"
  rm -rf "$ICONSET"
  mkdir -p "$ICONSET"
  PNG="$ROOT/.build/icon_source.png"
  sips -s format png "$ICON_SRC" --out "$PNG" >/dev/null
  while read -r name size; do
    sips -z "$size" "$size" "$PNG" --out "$ICONSET/$name" >/dev/null
  done <<'EOF'
icon_16x16.png 16
icon_16x16@2x.png 32
icon_32x32.png 32
icon_32x32@2x.png 64
icon_128x128.png 128
icon_128x128@2x.png 256
icon_256x256.png 256
icon_256x256@2x.png 512
icon_512x512.png 512
icon_512x512@2x.png 1024
EOF
  iconutil -c icns "$ICONSET" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

echo "==> Signing…"
codesign --force --deep --sign - "$APP_BUNDLE"

echo "==> Installing to /Applications…"
osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
killall "$EXEC_NAME" >/dev/null 2>&1 || true
sleep 0.3
rm -rf "$APPLICATIONS"
cp -R "$APP_BUNDLE" "$APPLICATIONS"
xattr -cr "$APPLICATIONS" 2>/dev/null || true
codesign --force --deep --sign - "$APPLICATIONS"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APPLICATIONS" >/dev/null 2>&1 || true

echo "==> Opening…"
open "$APPLICATIONS"
echo "Installed: $APPLICATIONS"

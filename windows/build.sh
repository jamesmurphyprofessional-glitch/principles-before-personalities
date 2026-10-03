#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_ROOT="$(cd "$ROOT/.." && pwd)"
DESKTOP="$HOME/Desktop"
MAC_APP="/Applications/Principles Before Personalities.app"
STAGE_MAC="$(mktemp -d)/Principles Before Personalities"
STAGE_WIN="$(mktemp -d)/Principles Before Personalities"
MAC_ZIP="$DESKTOP/Principles Before Personalities - Mac.zip"
WIN_ZIP="$DESKTOP/Principles Before Personalities - Windows.zip"

export PATH="$HOME/.dotnet:/usr/local/share/dotnet:/opt/homebrew/bin:$PATH"

echo "==> Refreshing the Mac app…"
zsh "$APP_ROOT/scripts/build_app.sh" >/tmp/pbp-mac-build.log

echo "==> Building the Windows icon…"
python3 - "$APP_ROOT/Assets/icon-source.jpg" "$ROOT/icon.ico" << 'PY'
import struct, subprocess, sys, tempfile
from pathlib import Path
src, dest = Path(sys.argv[1]), Path(sys.argv[2])
tmpdir = Path(tempfile.mkdtemp())
images = []
for px in (16, 32, 48, 256):
    out = tmpdir / ("icon_%d.png" % px)
    subprocess.check_call(["sips", "-s", "format", "png", "-z", str(px), str(px), str(src), "--out", str(out)], stdout=subprocess.DEVNULL)
    images.append((px, px, out.read_bytes()))
header = struct.pack("<HHH", 0, 1, len(images))
offset = 6 + 16 * len(images)
entries = b""
body = b""
for w, h, data in images:
    entries += struct.pack("<BBBBHHII", 0 if w >= 256 else w, 0 if h >= 256 else h, 0, 0, 1, 32, len(data), offset)
    offset += len(data)
    body += data
dest.write_bytes(header + entries + body)
print(dest, dest.stat().st_size)
PY

echo "==> Building the Windows app…"
dotnet build "$ROOT/PrinciplesBeforePersonalities.csproj" -c Release -v m
OUT="$ROOT/bin/Release/net462"

echo "==> Staging Windows zip…"
rm -rf "$STAGE_WIN"
mkdir -p "$STAGE_WIN"
cp "$OUT/Principles Before Personalities.exe" "$STAGE_WIN/"
cp "$OUT/Principles Before Personalities.exe.config" "$STAGE_WIN/" 2>/dev/null || true
cp "$APP_ROOT/Sources/PrinciplesBeforePersonalities/Resources/library.json" "$STAGE_WIN/library.json"
cat > "$STAGE_WIN/Read Me.txt" << 'EOF'
Principles Before Personalities

Double-click "Principles Before Personalities.exe".
This copy is for Windows 10 or Windows 11. Nothing else needs to be installed.

Select text, then click a color to highlight it.
The yellow Note button puts a sticky note on the page. Drag its top bar to move it, type in it, and use the colored dots to change it.
Highlights, page markers, and notes are saved on this PC and are still there the next time you open the app.

Contains the public-domain first edition text of "Alcoholics Anonymous" (1939, with the
1941 printing's revisions) and its personal stories. This is not the current edition.
Public domain in the United States only; copyright status in other countries may differ.
Not affiliated with or endorsed by Alcoholics Anonymous World Services, Inc.
EOF

rm -f "$WIN_ZIP"
ditto -c -k --keepParent "$STAGE_WIN" "$WIN_ZIP"

echo "==> Staging Mac zip…"
rm -rf "$STAGE_MAC"
mkdir -p "$STAGE_MAC"
cp -R "$MAC_APP" "$STAGE_MAC/Principles Before Personalities.app"
cat > "$STAGE_MAC/Read Me.txt" << 'EOF'
Principles Before Personalities

Drag Principles Before Personalities into Applications, then open it.
If macOS says the app cannot be opened, right-click it and choose Open.

Select text, then click a color to highlight it.
The yellow note button puts a sticky note on the page.
Highlights, page markers, and notes stay on this Mac between sessions.

Contains the public-domain first edition text of "Alcoholics Anonymous" (1939, with the
1941 printing's revisions) and its personal stories. This is not the current edition.
Public domain in the United States only; copyright status in other countries may differ.
Not affiliated with or endorsed by Alcoholics Anonymous World Services, Inc.
EOF
rm -f "$MAC_ZIP"
ditto -c -k --keepParent "$STAGE_MAC" "$MAC_ZIP"

echo "==> Done"
ls -lh "$MAC_ZIP" "$WIN_ZIP"
file "$STAGE_WIN/Principles Before Personalities.exe"
unzip -l "$WIN_ZIP"
unzip -l "$MAC_ZIP"

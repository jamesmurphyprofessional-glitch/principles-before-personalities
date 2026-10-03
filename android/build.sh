#!/bin/bash
# Builds the Android APK from the shared web app in ../web.
set -euo pipefail
cd "$(dirname "$0")"
export ANDROID_HOME="${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
ROOT="$(cd .. && pwd)"
SRC="$ROOT/Assets/icon-source.jpg"
RES=app/src/main/res

# 1) Bundle the web app (library-data.js carries the content; library.json is not needed in the APK;
#    web/README.txt is the iPhone zip's read-me, not app content)
rm -rf app/src/main/assets/www
mkdir -p app/src/main/assets/www
rsync -a --exclude library.json --exclude README.txt --exclude '.DS_Store' --exclude '._*' "$ROOT/web/" app/src/main/assets/www/

# 2) Launcher icons from the shared icon source
for pair in mdpi:48:108 hdpi:72:162 xhdpi:96:216 xxhdpi:144:324 xxxhdpi:192:432; do
  IFS=: read -r d px fg <<< "$pair"
  mkdir -p "$RES/mipmap-$d"
  sips -s format png -z "$px" "$px" "$SRC" --out "$RES/mipmap-$d/ic_launcher.png" >/dev/null
  inner=$(( fg * 80 / 100 ))
  sips -s format png -z "$inner" "$inner" "$SRC" --out "$RES/mipmap-$d/ic_launcher_foreground.png" >/dev/null
  sips --padToHeightWidth "$fg" "$fg" --padColor 0B121C "$RES/mipmap-$d/ic_launcher_foreground.png" >/dev/null
done

# 3) Build (release build type, signed with the local debug key for sideloading)
if [ -x ./gradlew ]; then G=./gradlew; else G=gradle; fi
$G --no-daemon assembleRelease
ls -la app/build/outputs/apk/release/

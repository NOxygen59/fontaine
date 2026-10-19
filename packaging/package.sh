#!/usr/bin/env bash
# Builds Fontaine for iOS 16+ and packages it.
#
#   packaging/package.sh               -> dist/Fontaine-<version>-ios16.tipa (TrollStore)
#   packaging/package.sh --simulator   -> dist/simulator/Fontaine.app
#
# Needs Xcode. No Xcode project: the core (Sources/FontCore) and the app (App/) are compiled
# together by swiftc as one module; the root helper (Helper/, device build only) by clang.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
VERSION=1.0.0
SIMULATOR=0
[ "${1:-}" = "--simulator" ] && SIMULATOR=1
if [ "$SIMULATOR" = 1 ]; then
  SDK=iphonesimulator; TARGET=arm64-apple-ios16.0-simulator; PLATFORM=iPhoneSimulator
else
  SDK=iphoneos; TARGET=arm64-apple-ios16.0; PLATFORM=iPhoneOS
fi

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
APP="$STAGE/Payload/Fontaine.app"
mkdir -p "$APP"
xcrun -sdk "$SDK" swiftc -target "$TARGET" -swift-version 5 -O -whole-module-optimization -parse-as-library \
  -module-name Fontaine Sources/FontCore/*.swift App/*.swift -o "$APP/Fontaine"
sed -e "s/@VERSION@/$VERSION/g" -e "s/@PLATFORM@/$PLATFORM/g" packaging/Info.plist.in >"$APP/Info.plist"
plutil -lint "$APP/Info.plist" >/dev/null
plutil -convert binary1 "$APP/Info.plist"
printf 'APPL????' >"$APP/PkgInfo"

ICON=packaging/icon-1024.png
for spec in "AppIcon60x60@2x:120" "AppIcon60x60@3x:180" "AppIcon76x76@2x~ipad:152" "AppIcon83.5x83.5@2x~ipad:167" "AppIcon76x76~ipad:76"; do
  sips -z "${spec##*:}" "${spec##*:}" "$ICON" --out "$APP/${spec%%:*}.png" >/dev/null
done
strip -x "$APP/Fontaine" 2>/dev/null || true

if [ "$SIMULATOR" = 1 ]; then
  # The Simulator refuses the system-install entitlement without Apple's provisioning: no
  # entitlements there (test with FONTAINE_TEST_SCOPE=process).
  codesign --force --sign - --timestamp=none "$APP"
  rm -rf dist/simulator && mkdir -p dist/simulator && cp -R "$APP" dist/simulator/
  echo "$ROOT/dist/simulator/Fontaine.app"
  exit 0
fi
# The root helper puts fonts in the bundle (iPadOS installs only fonts from there): signed first,
# with its own entitlements, then sealed in the app.
xcrun -sdk "$SDK" clang -target "$TARGET" -Os -Wall -Wextra -Werror Helper/fontaine-helper.c -o "$APP/fontaine-helper"
strip -x "$APP/fontaine-helper" 2>/dev/null || true
chmod 755 "$APP/fontaine-helper"
codesign --force --sign - --timestamp=none --entitlements packaging/helper-entitlements.plist "$APP/fontaine-helper"
codesign --force --sign - --timestamp=none --entitlements packaging/entitlements.plist "$APP"
mkdir -p dist
OUT="$ROOT/dist/Fontaine-$VERSION-ios16.tipa"
rm -f "$OUT"
(cd "$STAGE" && zip -qry "$OUT" Payload)
echo "$OUT"

#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
derived_data="$PWD/.build/release"
output="$PWD/dist"

xcodebuild -project RightMouse.xcodeproj -scheme RightMouse -configuration Release \
  -derivedDataPath "$derived_data" ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO build

app="$derived_data/Build/Products/Release/RightMouse.app"
extension="$app/Contents/PlugIns/RightMouseFinder.appex"
codesign --verify --deep --strict "$app"
for binary in "$app/Contents/MacOS/RightMouse" "$extension/Contents/MacOS/RightMouseFinder"; do
  architectures=" $(lipo -archs "$binary") "
  if [[ "$architectures" != *" arm64 "* || "$architectures" != *" x86_64 "* ]]; then
    echo "Missing architecture in $binary: $architectures" >&2
    exit 1
  fi
done
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
build=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app/Contents/Info.plist")
extension_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$extension/Contents/Info.plist")
extension_build=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$extension/Contents/Info.plist")
if [[ "$version" != "$extension_version" || "$build" != "$extension_build" ]]; then
  echo "App and Finder extension versions must match ($version/$build vs $extension_version/$extension_build)" >&2
  exit 1
fi
if [[ -n "${RELEASE_TAG:-}" && "$RELEASE_TAG" != "v$version" ]]; then
  echo "Release tag $RELEASE_TAG must match app version v$version" >&2
  exit 1
fi

mkdir -p "$output"
archive="RightMouse-$version-universal.zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "$output/$archive"
(
  cd "$output"
  shasum -a 256 "$archive" > SHA256SUMS.txt
  shasum -a 256 -c SHA256SUMS.txt
)

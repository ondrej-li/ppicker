#!/bin/sh
# Builds the direct-download package: a Developer ID-signed, notarized app inside a DMG and a zip.
#
# Uses the Xcode account signed in to team B592D69P29 for automatic signing and notarization.
# Run from anywhere: scripts/package.sh
set -eu
cd "$(dirname "$0")/.."

if [ -z "${DEVELOPER_DIR:-}" ] && [ -d /Applications/Xcode.app ]; then
    DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
    export DEVELOPER_DIR
fi

VERSION=$(sed -n 's/^[[:space:]]*MARKETING_VERSION: "\(.*\)"/\1/p' project.yml | head -1)
BUILD=$(sed -n 's/^[[:space:]]*CURRENT_PROJECT_VERSION: "\(.*\)"/\1/p' project.yml | head -1)
[ -n "$VERSION" ] || { echo "Could not read MARKETING_VERSION from project.yml"; exit 1; }

ARCHIVE=build/ProfilePicker-Release.xcarchive
APP="build/notarized/Profile Picker.app"
DMG="build/ProfilePicker-${VERSION}.dmg"
ZIP="build/ProfilePicker-${VERSION}.zip"
SUMS="build/ProfilePicker-${VERSION}-SHA256SUMS.txt"

xcodegen generate

echo "Archiving Profile Picker $VERSION ($BUILD)"
xcodebuild \
    -project ProfilePicker.xcodeproj \
    -scheme ProfilePicker \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVE" \
    -allowProvisioningUpdates \
    archive

echo "Submitting to Apple's notary service"
rm -rf build/notarize-upload
xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportPath build/notarize-upload \
    -exportOptionsPlist scripts/ExportOptions-developerid-upload.plist \
    -allowProvisioningUpdates

echo "Waiting for notarization (this usually takes a few minutes)"
for _ in $(seq 1 40); do
    rm -rf build/notarized
    if xcodebuild -exportNotarizedApp -archivePath "$ARCHIVE" -exportPath build/notarized > build/notarize.log 2>&1; then
        break
    fi
    if ! grep -q "processing and not ready" build/notarize.log; then
        cat build/notarize.log
        exit 1
    fi
    sleep 15
done
[ -d "$APP" ] || { echo "Notarization did not finish in time"; exit 1; }

xcrun stapler validate "$APP"
spctl -a -vvv -t exec "$APP"

echo "Building the DMG and zip"
rm -rf build/dmg
mkdir -p build/dmg
ditto "$APP" "build/dmg/Profile Picker.app"
ln -s /Applications "build/dmg/Applications"
cp "Packaging/Read Me.txt" "build/dmg/Read Me.txt"

rm -f "$DMG" "$ZIP" "$SUMS"
hdiutil create -quiet -volname "Profile Picker ${VERSION}" -srcfolder build/dmg -ov -format UDZO "$DMG"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

(cd build && shasum -a 256 "$(basename "$DMG")" "$(basename "$ZIP")" > "$(basename "$SUMS")")

echo
echo "Package ready:"
echo "  $DMG"
echo "  $ZIP"
echo "  $SUMS"

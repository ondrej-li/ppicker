#!/bin/sh
# Builds a signed Mac App Store package for Profile Picker.
#
#   scripts/release.sh            archive + export, leave the .pkg in build/export
#   scripts/release.sh --upload   also upload the package to App Store Connect
#
# Signing uses the Xcode account that is signed in to team B592D69P29 (automatic signing).
# For an upload without Xcode's account, set ASC_KEY_ID, ASC_ISSUER_ID and ASC_PRIVATE_KEY_PATH
# to an App Store Connect API key instead.
#
# Before uploading, the app record for cz.ondralinek.ppicker must exist in App Store Connect,
# and CURRENT_PROJECT_VERSION in project.yml must be higher than any build already uploaded.
set -eu
cd "$(dirname "$0")/.."

if [ -z "${DEVELOPER_DIR:-}" ] && [ -d /Applications/Xcode.app ]; then
    DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
    export DEVELOPER_DIR
fi

UPLOAD=false
[ "${1:-}" = "--upload" ] && UPLOAD=true

xcodegen generate

xcodebuild \
    -project ProfilePicker.xcodeproj \
    -scheme ProfilePicker \
    -configuration AppStore \
    -destination 'generic/platform=macOS' \
    -archivePath build/ProfilePicker.xcarchive \
    -allowProvisioningUpdates \
    archive

rm -rf build/export
xcodebuild \
    -exportArchive \
    -archivePath build/ProfilePicker.xcarchive \
    -exportPath build/export \
    -exportOptionsPlist scripts/ExportOptions.plist \
    -allowProvisioningUpdates

PACKAGE="build/export/Profile Picker.pkg"
echo
echo "Package: $PACKAGE"
pkgutil --check-signature "$PACKAGE" | head -4

if [ "$UPLOAD" = true ]; then
    if [ -n "${ASC_KEY_ID:-}" ] && [ -n "${ASC_ISSUER_ID:-}" ] && [ -n "${ASC_PRIVATE_KEY_PATH:-}" ]; then
        echo "Uploading with App Store Connect API key $ASC_KEY_ID"
        xcrun altool --upload-app --file "$PACKAGE" \
            --api-key "$ASC_KEY_ID" --api-issuer "$ASC_ISSUER_ID"
    elif [ -n "${ASC_KEY_ID:-}" ] && [ -n "${ASC_ISSUER_ID:-}" ]; then
        echo "Uploading with the Xcode account and App Store Connect API key $ASC_KEY_ID"
        sed 's#<string>export</string>#<string>upload</string>#' scripts/ExportOptions.plist \
            > build/ExportOptions-upload.plist
        xcodebuild \
            -exportArchive \
            -archivePath build/ProfilePicker.xcarchive \
            -exportPath build/upload \
            -exportOptionsPlist build/ExportOptions-upload.plist \
            -allowProvisioningUpdates \
            -authenticationKeyPath "$ASC_PRIVATE_KEY_PATH" \
            -authenticationKeyID "$ASC_KEY_ID" \
            -authenticationKeyIssuerID "$ASC_ISSUER_ID"
    else
        echo "Uploading with the Xcode account"
        sed 's#<string>export</string>#<string>upload</string>#' scripts/ExportOptions.plist \
            > build/ExportOptions-upload.plist
        xcodebuild \
            -exportArchive \
            -archivePath build/ProfilePicker.xcarchive \
            -exportPath build/upload \
            -exportOptionsPlist build/ExportOptions-upload.plist \
            -allowProvisioningUpdates
    fi
fi

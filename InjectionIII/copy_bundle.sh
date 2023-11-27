#!/bin/bash -x
#
#  copy_bundle.sh
#  InjectionIII
#
#  Copies injection bundle for on-device injection.
#  Thanks @oryonatan
#
if [ "$CONFIGURATION" == "Debug" ]; then
    RESOURCES="$(dirname "$0")"
    if [ "$PLATFORM_NAME" == "iphonesimulator" ]; then
     BUNDLE=${1:-iOSInjection}
    else
     BUNDLE=${1:-maciOSInjection}
    fi
    COPY="$CODESIGNING_FOLDER_PATH/iOSInjection.bundle"
    rsync -a "$RESOURCES/$BUNDLE.bundle"/* "$COPY/" &&
    /usr/libexec/PlistBuddy -c "Add :UserHome string $HOME"  "$COPY/Info.plist" &&
    codesign -f --sign "$EXPANDED_CODE_SIGN_IDENTITY" --timestamp\=none --preserve-metadata\=identifier,entitlements,flags --generate-entitlement-der "$COPY/Frameworks/SwiftTrace.framework/SwiftTrace" &&
    codesign -f --sign "$EXPANDED_CODE_SIGN_IDENTITY" --timestamp\=none --preserve-metadata\=identifier,entitlements,flags --generate-entitlement-der "$COPY" &&
    defaults write com.johnholdsworth.InjectionIII "$PROJECT_FILE_PATH" $EXPANDED_CODE_SIGN_IDENTITY
fi

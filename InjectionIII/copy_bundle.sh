#!/bin/bash -x
#
#  copy_bundle.sh
#  InjectionIII
#
#  Copies injection bundle for on-device injection.
#  Thanks @oryonatan
#
#  $Id: //depot/ResidentEval/InjectionIII/copy_bundle.sh#4 $
#

if [ "$CONFIGURATION" == "Debug" ]; then
    RESOURCES="$(dirname "$0")"
    COPY="$CODESIGNING_FOLDER_PATH/iOSInjection.bundle"
    STRACE="$COPY/Frameworks/SwiftTrace.framework/SwiftTrace"
    PLIST="$COPY/Info.plist"
    if [ "$PLATFORM_NAME" == "macosx" ]; then
     BUNDLE=${1:-macOSInjection}
     COPY="$CODESIGNING_FOLDER_PATH/Contents/Resources/macOSInjection.bundle"
     STRACE="$COPY/Contents/Frameworks/SwiftTrace.framework/Versions/A/SwiftTrace"
     PLIST="$COPY/Contents/Info.plist"
    elif [ "$PLATFORM_NAME" == "appletvsimulator" ]; then
     BUNDLE=${1:-tvOSInjection}
    elif [ "$PLATFORM_NAME" == "iphonesimulator" ]; then
     BUNDLE=${1:-iOSInjection}
    else
     BUNDLE=${1:-maciOSInjection}
    fi
    rsync -a "$RESOURCES/$BUNDLE.bundle"/* "$COPY/" &&
    /usr/libexec/PlistBuddy -c "Add :UserHome string $HOME" "$PLIST" &&
    codesign -f --sign "$EXPANDED_CODE_SIGN_IDENTITY" --timestamp\=none --preserve-metadata\=identifier,entitlements,flags --generate-entitlement-der "$STRACE" "$COPY" &&
    defaults write com.johnholdsworth.InjectionIII "$PROJECT_FILE_PATH" $EXPANDED_CODE_SIGN_IDENTITY
fi

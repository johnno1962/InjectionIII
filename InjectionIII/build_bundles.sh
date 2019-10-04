#!/bin/bash -x

#  build_bundles.sh
#  InjectionIII
#
#  Created by John Holdsworth on 04/10/2019.
#  Copyright © 2019 John Holdsworth. All rights reserved.

SYMROOT=/tmp/Injection
export PLATFORM_DIR_OS=$DEVELOPER_DIR/Platforms/iPhoneSimulator.platform &&
"$DEVELOPER_BIN_DIR"/xcodebuild SYMROOT=$SYMROOT PRODUCT_NAME=iOSInjection LD_RUNPATH_SEARCH_PATHS="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphonesimulator $PLATFORM_DIR_OS/Developer/Library/Frameworks @loader_path/Frameworks" -arch x86_64 -sdk iphonesimulator -config Debug -target InjectionBundle &&
rsync -au $SYMROOT/Debug-iphonesimulator/iOSInjection.bundle  "$CODESIGNING_FOLDER_PATH/Contents/Resources" &&
export PLATFORM_DIR_OS=$DEVELOPER_DIR/Platforms/AppleTVSimulator.platform &&
"$DEVELOPER_BIN_DIR"/xcodebuild SYMROOT=$SYMROOT PRODUCT_NAME=tvOSInjection LD_RUNPATH_SEARCH_PATHS="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/appletvsimulator $PLATFORM_DIR_OS/Developer/Library/Frameworks @loader_path/Frameworks" -arch x86_64 -sdk appletvsimulator -config Debug -target InjectionBundle &&
rsync -au $SYMROOT/Debug-appletvsimulator/tvOSInjection.bundle  "$CODESIGNING_FOLDER_PATH/Contents/Resources" &&
find $CODESIGNING_FOLDER_PATH/Contents/Resources/*.bundle -name '*.h' -delete

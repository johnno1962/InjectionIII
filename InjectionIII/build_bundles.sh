#!/bin/bash -x

#  build_bundles.sh
#  InjectionIII
#
#  Created by John Holdsworth on 04/10/2019.
#  Copyright © 2019 John Holdsworth. All rights reserved.

SYMROOT=/tmp/Injection
export XCODE_PLATFORM_DIR=/Applications/Xcode.app/Contents/Developer &&
"$DEVELOPER_BIN_DIR"/xcodebuild SYMROOT=$SYMROOT PRODUCT_NAME=macOSSwiftUISupport LD_RUNPATH_SEARCH_PATHS="$XCODE_PLATFORM_DIR/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphonesimulator $XCODE_PLATFORM_DIR/Platforms/iPhoneSimulator.platform/Developer/Library/Frameworks @loader_path/Frameworks" -arch x86_64 -arch arm64 -sdk macosx -config Debug -target SwiftUISupport &&
rsync -au $SYMROOT/Debug/macOSSwiftUISupport.bundle   "$CODESIGNING_FOLDER_PATH/Contents/Resources" &&
"$DEVELOPER_BIN_DIR"/xcodebuild SYMROOT=$SYMROOT PRODUCT_NAME=iOSSwiftUISupport LD_RUNPATH_SEARCH_PATHS="$XCODE_PLATFORM_DIR/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphonesimulator $XCODE_PLATFORM_DIR/Platforms/iPhoneSimulator.platform/Developer/Library/Frameworks @loader_path/Frameworks" -arch x86_64 -arch arm64 -sdk iphonesimulator -config Debug -target SwiftUISupport &&
"$DEVELOPER_BIN_DIR"/xcodebuild SYMROOT=$SYMROOT PRODUCT_NAME=iOSInjection LD_RUNPATH_SEARCH_PATHS="$XCODE_PLATFORM_DIR/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphonesimulator $XCODE_PLATFORM_DIR/Platforms/iPhoneSimulator.platform/Developer/Library/Frameworks @loader_path/Frameworks" -arch x86_64 -arch arm64 -sdk iphonesimulator -config Debug -target InjectionBundle &&
rsync -au $SYMROOT/Debug-iphonesimulator/iOSSwiftUISupport.bundle "$CODESIGNING_FOLDER_PATH/Contents/Resources" &&
rsync -au $SYMROOT/Debug-iphonesimulator/iOSInjection.bundle  "$CODESIGNING_FOLDER_PATH/Contents/Resources" &&
"$DEVELOPER_BIN_DIR"/xcodebuild SYMROOT=$SYMROOT PRODUCT_NAME=tvOSSwiftUISupport LD_RUNPATH_SEARCH_PATHS="$XCODE_PLATFORM_DIR/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/appletvsimulator $XCODE_PLATFORM_DIR/Platforms/iPhoneSimulator.platform/Developer/Library/Frameworks @loader_path/Frameworks" -arch x86_64 -arch arm64 -sdk appletvsimulator -config Debug -target SwiftUISupport &&
"$DEVELOPER_BIN_DIR"/xcodebuild SYMROOT=$SYMROOT PRODUCT_NAME=tvOSInjection LD_RUNPATH_SEARCH_PATHS="$XCODE_PLATFORM_DIR/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/appletvsimulator $XCODE_PLATFORM_DIR/Platforms/AppleTVSimulator.platform/Developer/Library/Frameworks @loader_path/Frameworks" -arch x86_64 -arch arm64 -sdk appletvsimulator -config Debug -target InjectionBundle &&
rsync -au $SYMROOT/Debug-appletvsimulator/tvOSSwiftUISupport.bundle "$CODESIGNING_FOLDER_PATH/Contents/Resources" &&
rsync -au $SYMROOT/Debug-appletvsimulator/tvOSInjection.bundle  "$CODESIGNING_FOLDER_PATH/Contents/Resources" &&
find $CODESIGNING_FOLDER_PATH/Contents/Resources/*.bundle -name '*.h' -delete

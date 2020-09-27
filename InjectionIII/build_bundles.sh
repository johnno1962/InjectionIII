#!/bin/bash -x

#  build_bundles.sh
#  InjectionIII
#
#  Created by John Holdsworth on 04/10/2019.
#  Copyright © 2019 John Holdsworth. All rights reserved.

#SYMROOT=/tmp/Injection
export XCODE_PLATFORM_DIR=/Applications/Xcode.app/Contents/Developer &&
"$DEVELOPER_BIN_DIR"/xcodebuild SYMROOT=$SYMROOT PRODUCT_NAME=macOSSwiftUISupport LD_RUNPATH_SEARCH_PATHS="$XCODE_PLATFORM_DIR/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphonesimulator $XCODE_PLATFORM_DIR/Platforms/iPhoneSimulator.platform/Developer/Library/Frameworks @loader_path/Frameworks" -arch x86_64 -arch arm64 -sdk macosx -config $CONFIGURATION -target SwiftUISupport &&
rsync -au $SYMROOT/$CONFIGURATION/macOSSwiftUISupport.bundle   "$CODESIGNING_FOLDER_PATH/Contents/Resources" &&
SYMROOT=/tmp/iOSInjection &&
"$DEVELOPER_BIN_DIR"/xcodebuild SYMROOT=$SYMROOT PRODUCT_NAME=SwiftTrace LD_RUNPATH_SEARCH_PATHS="$XCODE_PLATFORM_DIR/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphonesimulator $XCODE_PLATFORM_DIR/Platforms/iPhoneSimulator.platform/Developer/Library/Frameworks @loader_path/Frameworks" -arch x86_64 -arch arm64 -sdk iphonesimulator -config $CONFIGURATION -target SwiftTrace &&
"$DEVELOPER_BIN_DIR"/xcodebuild SYMROOT=$SYMROOT PRODUCT_NAME=iOSInjection LD_RUNPATH_SEARCH_PATHS="$XCODE_PLATFORM_DIR/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphonesimulator $XCODE_PLATFORM_DIR/Platforms/iPhoneSimulator.platform/Developer/Library/Frameworks @loader_path/Frameworks @loader_path/../iOSInjection.bundle/Frameworks" -arch x86_64 -arch arm64 -sdk iphonesimulator -config $CONFIGURATION -target InjectionBundle &&
"$DEVELOPER_BIN_DIR"/xcodebuild SYMROOT=$SYMROOT PRODUCT_NAME=iOSSwiftUISupport LD_RUNPATH_SEARCH_PATHS="$XCODE_PLATFORM_DIR/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphonesimulator $XCODE_PLATFORM_DIR/Platforms/iPhoneSimulator.platform/Developer/Library/Frameworks @loader_path/Frameworks @loader_path/../iOSInjection.bundle/Frameworks" FRAMEWORK_SEARCH_PATHS="$SYMROOT $SYMROOT/iOSInjection.bundle/Frameworks" -arch x86_64 -arch arm64 -sdk iphonesimulator -config $CONFIGURATION -target SwiftUISupport &&
rsync -au $SYMROOT/$CONFIGURATION-iphonesimulator/iOSSwiftUISupport.bundle "$CODESIGNING_FOLDER_PATH/Contents/Resources" &&
rsync -au $SYMROOT/$CONFIGURATION-iphonesimulator/iOSInjection.bundle  "$CODESIGNING_FOLDER_PATH/Contents/Resources" &&
SYMROOT=/tmp/tvOSInjection &&
"$DEVELOPER_BIN_DIR"/xcodebuild SYMROOT=$SYMROOT PRODUCT_NAME=SwiftTrace LD_RUNPATH_SEARCH_PATHS="$XCODE_PLATFORM_DIR/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/appletvsimulator $XCODE_PLATFORM_DIR/Platforms/AppleTVSimulator.platform/Developer/Library/Frameworks @loader_path/Frameworks" -arch x86_64 -arch arm64 -sdk appletvsimulator -config $CONFIGURATION -target SwiftTrace &&
"$DEVELOPER_BIN_DIR"/xcodebuild SYMROOT=$SYMROOT PRODUCT_NAME=tvOSInjection LD_RUNPATH_SEARCH_PATHS="$XCODE_PLATFORM_DIR/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/appletvsimulator $XCODE_PLATFORM_DIR/Platforms/AppleTVSimulator.platform/Developer/Library/Frameworks @loader_path/Frameworks" -arch x86_64 -arch arm64 -sdk appletvsimulator -config $CONFIGURATION -target InjectionBundle &&
"$DEVELOPER_BIN_DIR"/xcodebuild SYMROOT=$SYMROOT PRODUCT_NAME=tvOSSwiftUISupport LD_RUNPATH_SEARCH_PATHS="$XCODE_PLATFORM_DIR/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/appletvsimulator $XCODE_PLATFORM_DIR/Platforms/iPhoneSimulator.platform/Developer/Library/Frameworks @loader_path/Frameworks @loader_path/../tvOSInjection.bundle/Frameworks" FRAMEWORK_SEARCH_PATHS="$SYMROOT/tvOSInjection.bundle/Frameworks" -arch x86_64 -arch arm64 -sdk appletvsimulator -config $CONFIGURATION -target SwiftUISupport &&
rsync -au $SYMROOT/$CONFIGURATION-appletvsimulator/tvOSSwiftUISupport.bundle "$CODESIGNING_FOLDER_PATH/Contents/Resources" &&
rsync -au $SYMROOT/$CONFIGURATION-appletvsimulator/tvOSInjection.bundle  "$CODESIGNING_FOLDER_PATH/Contents/Resources" &&
find $CODESIGNING_FOLDER_PATH/Contents/Resources/*.bundle -name '*.h' -delete

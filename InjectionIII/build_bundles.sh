#!/bin/bash -x
#
#  build_bundles.sh
#  InjectionIII
#
#  Created by John Holdsworth on 04/10/2019.
#  Copyright © 2019 John Holdsworth. All rights reserved.
#
#  $Id: //depot/ResidentEval/InjectionIII/build_bundles.sh#28 $
#

# Injection has to assume a fixed path for Xcode.app as it uses
# Swift and the user's project may contain only Objective-C.
# The second "rpath" is to be able to find XCTest.framework.
FIXED_XCODE_DEVELOPER_PATH=/Applications/Xcode.app/Contents/Developer

function build_bundle () {
    FAMILY=$1
    PLATFORM=$2
    SDK=$3
    "$DEVELOPER_BIN_DIR"/xcodebuild SYMROOT=$SYMROOT ARCHS="$ARCHS" PRODUCT_NAME=SwiftTrace -sdk $SDK -config $CONFIGURATION -target SwiftTrace &&
    "$DEVELOPER_BIN_DIR"/xcodebuild SYMROOT=$SYMROOT ARCHS="$ARCHS" PRODUCT_NAME="${FAMILY}Injection" LD_RUNPATH_SEARCH_PATHS="$FIXED_XCODE_DEVELOPER_PATH/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/$SDK $FIXED_XCODE_DEVELOPER_PATH/Platforms/$PLATFORM.platform/Developer/Library/Frameworks @loader_path/Frameworks" -sdk $SDK -config $CONFIGURATION -target InjectionBundle &&
    "$DEVELOPER_BIN_DIR"/xcodebuild SYMROOT=$SYMROOT ARCHS="$ARCHS" PRODUCT_NAME="${FAMILY}SwiftUISupport" -sdk $SDK -config $CONFIGURATION -target SwiftUISupport
}

#build_bundle macOS MacOSX macosx &&
build_bundle iOS iPhoneSimulator iphonesimulator &&
build_bundle tvOS AppleTVSimulator appletvsimulator &&

# SwiftUISupport needs to be but separately from the main 
"$DEVELOPER_BIN_DIR"/xcodebuild SYMROOT=$SYMROOT ARCHS="$ARCHS" PRODUCT_NAME=macOSSwiftUISupport -sdk macosx -config $CONFIGURATION -target SwiftUISupport &&
rsync -au $SYMROOT/$CONFIGURATION/macOSSwiftUISupport.bundle $SYMROOT/$CONFIGURATION-*/*.bundle "$CODESIGNING_FOLDER_PATH/Contents/Resources" &&
rsync -au $SYMROOT/$CONFIGURATION-iphonesimulator/SwiftTrace.framework/{Headers,Modules} "$CODESIGNING_FOLDER_PATH/Contents/Resources/iOSInjection.bundle/Frameworks/SwiftTrace.framework" &&
rsync -au $SYMROOT/$CONFIGURATION-appletvsimulator/SwiftTrace.framework/{Headers,Modules} "$CODESIGNING_FOLDER_PATH/Contents/Resources/tvOSInjection.bundle/Frameworks/SwiftTrace.framework"

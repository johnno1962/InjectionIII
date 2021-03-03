//
//  InjectionClient.h
//  InjectionBundle
//
//  Created by John Holdsworth on 06/11/2017.
//  Copyright © 2017 John Holdsworth. All rights reserved.
//
//  $Id: //depot/ResidentEval/InjectionBundle/InjectionClient.h#29 $
//
//  Shared definitions between server and client.
//

#import "SimpleSocket.h"
#import "UserDefaults.h"
#import <mach-o/dyld.h>
#ifndef __IPHONE_OS_VERSION_MIN_REQUIRED
#import <AppKit/NSWorkspace.h>
#import <libproc.h>
#endif

#import "Xprobe.h"

#ifdef INJECTION_III_APP
#define INJECTION_ADDRESS ":8898"
#import "/tmp/InjectionIIISalt.h"
#define INJECTION_KEY @"bvijkijyhbtrbrebzjbbzcfbbvvq"
#define APP_NAME "InjectionIII"
#define APP_PREFIX "💉 "
#else
#define INJECTION_ADDRESS ":8899"
#define INJECTION_SALT 2122172543
extern NSString *INJECTION_KEY;
#define APP_NAME "HotReloading"
#define APP_PREFIX "🔥 "
#endif

#define FRAMEWORK_DELIMITER @","
#define CALLORDER_DELIMITER @"---"

@interface InjectionClientLegacy
@property BOOL vaccineEnabled;
+ (InjectionClientLegacy *)sharedInstance;
- (void)vaccine:object;
+ (void)flash:vc;
- (void)rebuildWithStoryboard:(NSString *)changed error:(NSError **)err;
@end

@interface NSObject(HotReloading)
+ (void)runXCTestCase:(Class)aTestCase;
+ (BOOL)injectUI:(NSString *)changed;
@end

typedef NS_ENUM(int, InjectionCommand) {
    // commands to Bundle
    InjectionConnected,
    InjectionWatching,
    InjectionLog,
    InjectionSigned,
    InjectionLoad,
    InjectionInject,
    InjectionIdeProcPath,
    InjectionXprobe,
    InjectionEval,
    InjectionVaccineSettingChanged,

    InjectionTrace,
    InjectionUntrace,
    InjectionTraceUI,
    InjectionTraceUIKit,
    InjectionTraceSwiftUI,
    InjectionTraceFramework,
    InjectionQuietInclude,
    InjectionInclude,
    InjectionExclude,
    InjectionStats,
    InjectionCallOrder,
    InjectionFileOrder,
    InjectionFileReorder,
    InjectionUninterpose,
    InjectionFeedback,
    InjectionLookup,

    InjectionInvalid = 1000,

    InjectionEOF = ~0
};

typedef NS_ENUM(int, InjectionResponse) {
    // responses from bundle
    InjectionComplete,
    InjectionPause,
    InjectionSign,
    InjectionError,
    InjectionFrameworkList,
    InjectionCallOrderList,

    InjectionExit = ~0
};

//
//  InjectionClient.mm
//  InjectionBundle
//
//  Created by John Holdsworth on 06/11/2017.
//  Copyright © 2017 John Holdsworth. All rights reserved.
//
//  $Id: //depot/ResidentEval/InjectionBundle/InjectionClient.mm#141 $
//

#import "InjectionClient.h"
#import "SwiftTrace.h"
#import <mach-o/dyld.h>

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
#import <UIKit/UIKit.h>
#if __has_include("tvOSInjection10-Swift.h")
#import "tvOSInjection10-Swift.h"
#elif __has_include("tvOSInjection-Swift.h")
#import "tvOSInjection-Swift.h"
#elif __has_include("iOSInjection10-Swift.h")
#import "iOSInjection10-Swift.h"
#else
#import "iOSInjection-Swift.h"
#endif
#import <objc/runtime.h>

@interface NSObject (Remapped)
+ (void)addMappingFromIdentifier:(NSString *)identifier toObject:(id)object forCoder:(id)coder;
+ (id)mappedObjectForCoder:(id)decoder withIdentifier:(NSString *)identifier;
@end

@implementation NSObject (Remapper)

static struct {
    NSMutableDictionary *inputIndexes;
    NSMutableArray *output, *order;
    int orderIndex;
} remapper;

+ (void)my_addMappingFromIdentifier:(NSString *)identifier toObject:(id)object forCoder:(id)coder {
    //NSLog(@"Map %@ = %@", identifier, object);
    if(remapper.output && [identifier hasPrefix:@"UpstreamPlaceholder-"]) {
        if (remapper.inputIndexes)
            remapper.inputIndexes[identifier] = @([remapper.inputIndexes count]);
        else
            [remapper.output addObject:object];
    }
    [self my_addMappingFromIdentifier:identifier toObject:object forCoder:coder];
}

+ (id)my_mappedObjectForCoder:(id)decoder withIdentifier:(NSString *)identifier {
    //NSLog(@"Mapped? %@", identifier);
    if(remapper.output && [identifier hasPrefix:@"UpstreamPlaceholder-"]) {
        if (remapper.inputIndexes)
            [remapper.order addObject:remapper.inputIndexes[identifier] ?: @""];
        else
            return remapper.output[[remapper.order[remapper.orderIndex++] intValue]];
    }
    return [self my_mappedObjectForCoder:decoder withIdentifier:identifier];
}

@end

@interface UIViewController (StoryboardInjection)
- (void)_loadViewFromNibNamed:(NSString *)a0 bundle:(NSBundle *)a1;
@end
@implementation UIViewController (iOS14StoryboardInjection)
- (void)iOS14LoadViewFromNibNamed:(NSString *)nibName bundle:(NSBundle *)bundle {
    if ([self respondsToSelector:@selector(_loadViewFromNibNamed:bundle:)])
        [self _loadViewFromNibNamed:nibName bundle:bundle];
    else {
        size_t vcSize = class_getInstanceSize([UIViewController class]);
        size_t mySize = class_getInstanceSize([self class]);
        char *extra = (char *)(__bridge void *)self + vcSize;
        NSData *ivars = [NSData dataWithBytes:extra length:mySize-vcSize];
        (void)[self initWithNibName:nibName bundle:bundle];
        memcpy(extra, ivars.bytes, ivars.length);
        [self loadView];
    }
}
@end
#else
#if __has_include("macOSInjection10-Swift.h")
#import "macOSInjection10-Swift.h"
#else
#import "macOSInjection-Swift.h"
#endif
#endif

#ifdef XPROBE_PORT
#import "../XprobePlugin/Classes/Xtrace.mm"
#import "../XprobePlugin/Classes/Xprobe.mm"
#import "../XprobePlugin/Classes/Xprobe+Service.mm"

@interface BundleInjection: NSObject
@end
@implementation BundleInjection
+ (const char *)connectedAddress {
    return "127.0.0.1";
}
@end

@implementation Xprobe(Seeding)
#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
+ (NSArray *)xprobeSeeds {
    UIApplication *app = [UIApplication sharedApplication];
    NSMutableArray *seeds = [[app windows] mutableCopy];
    [seeds insertObject:app atIndex:0];
    return seeds;
}
#else
+ (NSArray *)xprobeSeeds {
    NSApplication *app = [NSApplication sharedApplication];
    NSMutableArray *seeds = [[app windows] mutableCopy];
    if ( app.delegate )
        [seeds insertObject:app.delegate atIndex:0];
    return seeds;
}
#endif
@end
#endif

#import <XCTest/XCTest.h>

@interface SwiftTrace : NSObject
@end

@implementation NSObject(RunXCTestCase)
+ (void)runXCTestCase:(Class)aTestCase {
    Class _XCTestSuite = objc_getClass("XCTestSuite");
    XCTestSuite *suite0 = [_XCTestSuite testSuiteWithName: @"InjectedTest"];
    XCTestSuite *suite = [_XCTestSuite testSuiteForTestCaseClass: aTestCase];
    Class _XCTestSuiteRun = objc_getClass("XCTestSuiteRun");
    XCTestSuiteRun *tr = [_XCTestSuiteRun testRunWithTest: suite];
    [suite0 addTest:suite];
    [suite0 performTest:tr];
}
@end

@interface SwiftUISupport
+ (void)setupWithPointer:(void *)ptr;
@end

@implementation InjectionClient

+ (void)load {
    // connect to InjectionIII.app using socket
    if (InjectionClient *client = [self connectTo:INJECTION_ADDRESS])
        [client run];
    else {
        printf("💉 Injection loaded but could not connect. Is InjectionIII.app running?\n");
#ifndef __IPHONE_OS_VERSION_MIN_REQUIRED
        printf("⚠️ For a macOS app you need to turn off the sandbox to connect. ⚠️\n");
#endif
    }
}

- (void)runInBackground {
    SwiftEval *builder = [SwiftEval sharedInstance];
    NSString *tmpDir = [self readString];
    BOOL notPlugin = ![@"/tmp" isEqualToString:tmpDir];
    builder.tmpDir = tmpDir;

    if (notPlugin)
        [self writeInt:INJECTION_SALT];
    [self writeString:INJECTION_KEY];

    NSString *frameworksPath = [NSBundle mainBundle].privateFrameworksPath;
    [self writeString:frameworksPath];

    [self writeString:builder.arch];
    [self writeString:[NSBundle mainBundle].executablePath];

    int codesignStatusPipe[2];
    pipe(codesignStatusPipe);
    SimpleSocket *reader = [[SimpleSocket alloc] initSocket:codesignStatusPipe[0]];
    SimpleSocket *writer = [[SimpleSocket alloc] initSocket:codesignStatusPipe[1]];

    // make available implementation of signing delegated to macOS app
    builder.signer = ^BOOL(NSString *_Nonnull dylib) {
        [self writeCommand:InjectionSign withString:dylib];
        return [reader readString].boolValue;
    };

    NSDictionary<NSString *,NSString *> *frameworkPaths;
    if (notPlugin) {
        NSMutableArray *frameworks = [NSMutableArray new];
        NSMutableArray *sysFrameworks = [NSMutableArray new];
        NSMutableDictionary *imageMap = [NSMutableDictionary new];
        const char *bundleFrameworks = frameworksPath.UTF8String;

        for (int32_t i = _dyld_image_count()-1; i >= 0 ; i--) {
            const char *imageName = _dyld_get_image_name(i);
            if (!strstr(imageName, ".framework/")) continue;
            NSString *imagePath = [NSString stringWithUTF8String:imageName];
            NSString *frameworkName = imagePath.lastPathComponent;
            [imageMap setValue:imagePath forKey:frameworkName];
            [strstr(imageName, bundleFrameworks) ?
             frameworks : sysFrameworks addObject:frameworkName];
        }

        [self writeCommand:InjectionFrameworkList withString:
         [frameworks componentsJoinedByString:FRAMEWORK_DELIMITER]];
        [self writeString:
         [sysFrameworks componentsJoinedByString:FRAMEWORK_DELIMITER]];
        [self writeString:[[SwiftInjection packageNames]
                           componentsJoinedByString:FRAMEWORK_DELIMITER]];
        frameworkPaths = imageMap;
    }

    // As tmp file names come in, inject them
    InjectionCommand command;
    while ((command = (InjectionCommand)[self readInt]) != InjectionEOF) {
        switch (command) {
        case InjectionVaccineSettingChanged: {
            NSString *string = [self readString];
            NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];

            NSDictionary *dictionary = (NSDictionary *)json;
            if (dictionary != nil) {
                NSNumber *vaccineEnabled = [dictionary valueForKey:@"Enabled Vaccine"];
                builder.vaccineEnabled = [vaccineEnabled boolValue];
            }
            break;
        }
        case InjectionConnected: {
            NSString *projectFile = [self readString];
            builder.projectFile = projectFile;
            builder.derivedLogs = nil;
            printf("💉 Injection connected 👍\n");
            NSString *pbxFile = [projectFile
                 stringByAppendingPathComponent:@"project.pbxproj"];
            NSString *pbxContents = [NSString
                 stringWithContentsOfFile:pbxFile
                 encoding:NSUTF8StringEncoding error:NULL];
            if (![pbxContents containsString:@"-interposable"])
                printf("💉 Have you remembered to add \"-Xlinker -interposable\" to your project's \"Other Linker Flags\"?\n");
            break;
        }
        case InjectionWatching: {
            NSString *directory = [self readString];
            printf("💉 Watching %s/**\n", directory.UTF8String);
            break;
        }
        case InjectionLog:
            printf("%s\n", [self readString].UTF8String);
            break;
        case InjectionSigned:
            [writer writeString:[self readString]];
            break;
        case InjectionTrace:
            [SwiftTrace swiftTraceMainBundle];
            printf("💉 Added trace to non-final methods of classes in app bundle\n");
            [self filteringChanged];
            break;
        case InjectionUntrace:
            [SwiftTrace swiftTraceRemoveAllTraces];
            break;
        case InjectionTraceUI:
            [self loadSwuftUISupprt];
            [SwiftTrace swiftTraceMainBundleMethods];
            [SwiftTrace swiftTraceMainBundle];
            printf("💉 Added trace to methods in main bundle\n");
            [self filteringChanged];
            break;
        case InjectionTraceUIKit:
            dispatch_sync(dispatch_get_main_queue(), ^{
                Class OSView = objc_getClass("UIView") ?: objc_getClass("NSView");
                printf("💉 Adding trace to the framework containg %s, this will take a while...\n", class_getName(OSView));
                [OSView swiftTraceBundle];
                printf("💉 Completed adding trace.\n");
            });
            [self filteringChanged];
            break;
        case InjectionTraceSwiftUI:
            if (Class AnyText = [self loadSwuftUISupprt]) {
                printf("💉 Adding trace to SwiftUI calls.\n");
                [SwiftTrace swiftTraceMethodsInFrameworkContaining:AnyText];
                [self filteringChanged];
            }
            break;
        case InjectionTraceFramework: {
            NSString *frameworkName = [self readString];
            if (const char *frameworkPath =
                frameworkPaths[frameworkName].UTF8String) {
                printf("💉 Tracing %s\n", frameworkPath);
                [SwiftTrace swiftTraceMethodsInBundle:frameworkPath packageName:nil];
                [SwiftTrace swiftTraceBundlePath:frameworkPath];
            }
            else {
                printf("💉 Tracing package %s\n", frameworkName.UTF8String);
                NSString *mainBundlePath = [NSBundle mainBundle].executablePath;
                [SwiftTrace swiftTraceMethodsInBundle:mainBundlePath.UTF8String
                                          packageName:frameworkName];
            }
            [self filteringChanged];
            break;
        }
        case InjectionQuietInclude:
            [SwiftTrace setSwiftTraceFilterInclude:[self readString]];
            break;
        case InjectionInclude:
            [SwiftTrace setSwiftTraceFilterInclude:[self readString]];
            [self filteringChanged];
            break;
        case InjectionExclude:
            [SwiftTrace setSwiftTraceFilterExclude:[self readString]];
            [self filteringChanged];
            break;
        case InjectionStats:
            static int top = 200;
            printf("\n💉 Sorted top %d elapsed time/invocations by method\n"
                   "💉 =================================================\n", top);
            [SwiftInjection dumpStatsWithTop:top];
            [self needsTracing];
            break;
        case InjectionCallOrder:
            printf("\n💉 Function names in the order they were first called:\n"
                   "💉 ===================================================\n");
            for (NSString *signature : [SwiftInjection callOrder])
                printf("%s\n", signature.UTF8String);
            [self needsTracing];
            break;
        case InjectionFileOrder:
            printf("\n💉 Source files in the order they were first referenced:\n"
                   "💉 =====================================================\n"
                   "💉 (Order the source files should be compiled in target)\n");
            [SwiftInjection fileOrder];
            [self needsTracing];
            break;
        case InjectionFileReorder:
            [self writeCommand:InjectionCallOrderList
                    withString:[[SwiftInjection callOrder]
                                componentsJoinedByString:CALLORDER_DELIMITER]];
            [self needsTracing];
            break;
        case InjectionUninterpose:
            [SwiftTrace swiftTraceRevertAllInterposes];
            [SwiftTrace swiftTraceRemoveAllTraces];
            printf("💉 Removed all traces (and injections).\n");
            break;
        case InjectionInvalid:
            printf("💉 ⚠️ Connection rejected. Are you running the correct version of InjectionIII.app from /Applications? ⚠️\n");
            break;
        case InjectionIdeProcPath: {
            builder.lastIdeProcPath = [self readString];
            break;
        }
        default: {
            NSString *changed = [self readString];
            dispatch_async(dispatch_get_main_queue(), ^{
                NSError *err = nil;
                switch (command) {
                case InjectionLoad:
                    [SwiftInjection injectWithTmpfile:changed error:&err];
                    break;
                case InjectionInject: {
#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
                    if ([changed hasSuffix:@"storyboard"] || [changed hasSuffix:@"xib"]) {
                        if (![self injectUI:changed])
                            return;
                    }
                    else
#endif
                        [SwiftInjection injectWithOldClass:nil classNameOrFile:changed];
                    break;
                }
#ifdef XPROBE_PORT
                case InjectionXprobe:
                    [Xprobe connectTo:NULL retainObjects:YES];
                    [Xprobe search:@""];
                    break;
                case InjectionEval: {
                    NSArray<NSString *> *parts = [changed componentsSeparatedByString:@"^"];
                    int pathID = parts[0].intValue;
                    [self writeCommand:InjectionPause withString:@"5"];
                    if ([xprobePaths[pathID].object respondsToSelector:@selector(swiftEvalWithCode:)])
                        (void)[xprobePaths[pathID].object swiftEvalWithCode:parts[3].stringByRemovingPercentEncoding];
                    else
                        printf("💉 Xprobe: Eval only works on NSObject subclasses\n");
                    [Xprobe writeString:[NSString stringWithFormat:@"$('BUSY%d').hidden = true; ", pathID]];
                    break;
                }
#endif
                default:
                    [self writeCommand:InjectionError withString:[NSString
                          stringWithFormat:@"Invalid command #%d", command]];
                    break;
                }

                [self writeCommand:err ? InjectionError : InjectionComplete
                        withString:err ? err.localizedDescription : nil];
            });
        }
        }
    }
}

- (Class)loadSwuftUISupprt {
    static char classInSwiftUIMangled[] = "$s7SwiftUI14AnyTextStorageCN";
    if (Class AnyText = (__bridge Class)
        dlsym(RTLD_DEFAULT, classInSwiftUIMangled)) {
        NSString *swiftUIBundlePath = [[[NSBundle
            bundleForClass:[self class]] bundlePath]
            stringByReplacingOccurrencesOfString:@"Injection.bundle"
                                 withString:@"SwiftUISupport.bundle"];
        if (Class swiftUISupport = [[NSBundle
                                     bundleWithPath:swiftUIBundlePath]
                                    classNamed:@"SwiftUISupport"])
            [swiftUISupport setupWithPointer:NULL];
        else
            printf("💉 Could not find SwiftUISupport at path: %s\n",
                   swiftUIBundlePath.UTF8String);
        return AnyText;
    }
    return nil;
}

- (void)needsTracing {
    if (![SwiftTrace swiftTracing])
        printf("💉 ⚠️ You need to have traced something to gather stats.\n");
}

- (void)filteringChanged {
    if ([SwiftTrace swiftTracing]) {
        NSString *exclude = SwiftTrace.swiftTraceFilterExclude;
        if (NSString *include = SwiftTrace.swiftTraceFilterInclude)
            printf(exclude ?
               "💉 Filtering trace to include methods matching '%s' but not '%s'.\n" :
               "💉 Filtering trace to include methods matching '%s'.\n",
               include.UTF8String, exclude.UTF8String);
        else
            printf(exclude ?
               "💉 Filtering trace to exclude methods matching '%s'.\n" :
               "💉 Not filtering trace (Menu Item: 'Set Filters')\n",
               exclude.UTF8String);
    }
}

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
- (BOOL)injectUI:(NSString *)changed {
    static NSMutableDictionary *allOrder;
    static dispatch_once_t once;

    dispatch_once(&once, ^{
        Class proxyClass = objc_getClass("UIProxyObject");
        method_exchangeImplementations(
           class_getClassMethod(proxyClass,
                                @selector(my_addMappingFromIdentifier:toObject:forCoder:)),
           class_getClassMethod(proxyClass,
                                @selector(addMappingFromIdentifier:toObject:forCoder:)));
        method_exchangeImplementations(
           class_getClassMethod(proxyClass,
                                @selector(my_mappedObjectForCoder:withIdentifier:)),
           class_getClassMethod(proxyClass,
                                @selector(mappedObjectForCoder:withIdentifier:)));
        allOrder = [NSMutableDictionary new];
    });

    @try {
        UIViewController *rootViewController = [UIApplication sharedApplication].windows.firstObject.rootViewController;
        UINavigationController *navigationController = (UINavigationController*)rootViewController;
        UIViewController *visibleVC = rootViewController;

        if (UIViewController *child =
            visibleVC.childViewControllers.firstObject)
            visibleVC = child;
        if ([visibleVC respondsToSelector:@selector(viewControllers)])
            visibleVC = [(UISplitViewController *)visibleVC
                         viewControllers].lastObject;

        if ([visibleVC respondsToSelector:@selector(visibleViewController)])
            visibleVC = [(UINavigationController *)visibleVC
                         visibleViewController];
        if (!visibleVC.nibName && [navigationController respondsToSelector:@selector(topViewController)]) {
          visibleVC = [navigationController topViewController];
        }

        NSString *nibName = visibleVC.nibName;

        if (!(remapper.order = allOrder[nibName])) {
            remapper.inputIndexes = [NSMutableDictionary new];
            remapper.output = [NSMutableArray new];
            allOrder[nibName] = remapper.order = [NSMutableArray new];

            [visibleVC iOS14LoadViewFromNibNamed:visibleVC.nibName
                                          bundle:visibleVC.nibBundle];

            remapper.inputIndexes = nil;
            remapper.output = nil;
        }

        NSError *err = nil;
        [[SwiftEval sharedInstance] rebuildWithStoryboard:changed error:&err];
        if (err)
            return FALSE;
    
        void (^resetRemapper)(void) = ^{
            remapper.output = [NSMutableArray new];
            remapper.orderIndex = 0;
        };
        
        resetRemapper();

        [visibleVC iOS14LoadViewFromNibNamed:visibleVC.nibName
                                      bundle:visibleVC.nibBundle];

        if ([SwiftEval sharedInstance].vaccineEnabled == YES) {
            resetRemapper();
            [SwiftInjection vaccine:visibleVC];
        } else {
            [visibleVC viewDidLoad];
            [visibleVC viewWillAppear:NO];
            [visibleVC viewDidAppear:NO];

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
            [SwiftInjection flash:visibleVC];
#endif
        }
    }
    @catch(NSException *e) {
        printf("Problem reloading nib: %s\n", e.reason.UTF8String);
    }

    remapper.output = nil;
    return true;
}
#endif

@end

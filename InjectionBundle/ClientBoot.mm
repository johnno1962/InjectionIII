//
//  ClientBoot.mm
//  InjectionIII
//
//  Created by John Holdsworth on 02/24/2021.
//  Copyright © 2021 John Holdsworth. All rights reserved.
//
//  $Id: //depot/ResidentEval/InjectionBundle/ClientBoot.mm#4 $
//
//  Initiate connection to server side of InjectionIII/HotReloading.
//

#import "InjectionClient.h"
#import <XCTest/XCTest.h>
#import <objc/runtime.h>

#ifndef INJECTION_III_APP
NSString *INJECTION_KEY = @__FILE__;
#endif

#if defined(DEBUG) || defined(INJECTION_III_APP)
@interface BundleInjection: NSObject
@end
@implementation BundleInjection

+ (void)load {
    if (Class clientClass = objc_getClass("InjectionClient"))
        for (int i=0, retrys=3; i<retrys; i++) {
            if (SimpleSocket *client = [clientClass
                                        connectTo:@INJECTION_ADDRESS]) {
                [client run];
                return;
            }
            else
                sleep(1);
        }

#ifdef INJECTION_III_APP
    printf(APP_PREFIX"Injection loaded but could not connect. Is InjectionIII.app running?\n");
#else
    printf(APP_PREFIX"⚠️ HotReloading loaded but could not connect. Is injectiond running? ⚠️\n"
           APP_PREFIX"Have you added the following \"Run Script\" build phase to your project?\n"
           "$SYMROOT/../../SourcePackages/checkouts/HotReloading/start_daemon.sh\n");
#endif
#ifndef __IPHONE_OS_VERSION_MIN_REQUIRED
    printf(APP_PREFIX"⚠️ For a macOS app you need to turn off the sandbox to connect. ⚠️\n");
#endif
}

+ (const char *)connectedAddress {
    return "127.0.0.1";
}
@end

@implementation NSObject (RunXCTestCase)
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

@implementation Xprobe(Seeding)
+ (NSArray *)xprobeSeeds {
    #ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
    UIApplication *app = [UIApplication sharedApplication];
    NSMutableArray *seeds = [[app windows] mutableCopy];
    [seeds insertObject:app atIndex:0];
    #else
    NSApplication *app = [NSApplication sharedApplication];
    NSMutableArray *seeds = [[app windows] mutableCopy];
    if ( app.delegate )
        [seeds insertObject:app.delegate atIndex:0];
    #endif
    return seeds;
}
@end
#endif

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
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

+ (BOOL)injectUI:(NSString *)changed {
    static NSMutableDictionary *allOrder;
    static dispatch_once_t once;
    printf(APP_PREFIX"Waiting for rebuild of %s\n", changed.UTF8String);

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

        Class SwiftEval = objc_getClass("SwiftEval");

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
            [objc_getClass("SwiftInjection") vaccine:visibleVC];
        } else {
            [visibleVC viewDidLoad];
            [visibleVC viewWillAppear:NO];
            [visibleVC viewDidAppear:NO];

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
            [objc_getClass("SwiftInjection") flash:visibleVC];
#endif
        }
    }
    @catch(NSException *e) {
        printf("Problem reloading nib: %s\n", e.reason.UTF8String);
    }

    remapper.output = nil;
    return true;
}
@end
#endif

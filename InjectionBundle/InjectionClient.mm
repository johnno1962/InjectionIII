//
//  InjectionClient.mm
//  InjectionBundle
//
//  Created by John Holdsworth on 06/11/2017.
//  Copyright © 2017 John Holdsworth. All rights reserved.
//

#import "InjectionClient.h"
#import "InjectionServer.h"

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
#if __has_include("tvOSInjection10-Swift.h")
#import "tvOSInjection10-Swift.h"
#elif __has_include("tvOSInjection-Swift.h")
#import "tvOSInjection-Swift.h"
#elif __has_include("iOSInjection10-Swift.h")
#import "iOSInjection10-Swift.h"
#else
#import "iOSInjection-Swift.h"
#endif
#import <UIKit/UIKit.h>

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED

@interface UIViewController (ViewControllerRecursion)
- (NSArray*)allViewControllersRecursive;
    @end

@implementation UIViewController (ViewControllerRecursion)

- (NSArray*)allViewControllersRecursive {
    NSMutableArray *viewControllers = [NSMutableArray new];
    [viewControllers addObject:self];
    [viewControllers addObjectsFromArray:[self childViewControllersRecursive]];
    [viewControllers addObjectsFromArray:[self presentedViewControllers]];
    return viewControllers;
}

- (NSArray*)childViewControllersRecursive
    {
        NSMutableArray *viewControllers = [NSMutableArray new];
        for (UIViewController *viewController in self.childViewControllers) {
            [viewControllers addObject:viewController];
            if ([viewController.childViewControllers count] > 0) {
                [viewControllers addObjectsFromArray:(NSArray*)[viewController childViewControllersRecursive]];
            }
        }
        return viewControllers;
    }

- (NSArray*)presentedViewControllers
    {
        NSMutableArray *viewControllers = [NSMutableArray new];

        if (self.presentedViewController) {
            [viewControllers addObject: self.presentedViewController];
            [viewControllers addObjectsFromArray: [self.presentedViewController presentedViewControllers]];
        }

        return viewControllers;
    }
    @end
#endif

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

@implementation InjectionClient

+ (void)load {
    // connect to InjetionIII.app using sicket
    if (InjectionClient *client = [self connectTo:INJECTION_ADDRESS])
        [client run];
    else
        printf("Injection loaded but could not connect. Is InjectionIII.app running?\n");

}

- (void)runInBackground {
    [SwiftEval sharedInstance].tmpDir = [self readString];
    [SwiftEval sharedInstance].injectionNumber = 100;

    [self writeString:INJECTION_KEY];
    [self writeString:[NSBundle mainBundle].privateFrameworksPath];
#ifdef __LP64__
    [self writeString:@"x86_64"];
#else
    [self writeString:@"i386"];
#endif
    [self writeString:[NSBundle mainBundle].executablePath];

    int codesignStatusPipe[2];
    pipe(codesignStatusPipe);
    SimpleSocket *reader = [[SimpleSocket alloc] initSocket:codesignStatusPipe[0]];
    SimpleSocket *writer = [[SimpleSocket alloc] initSocket:codesignStatusPipe[1]];

    // make available implementation of signing delegated to macOS app
    [SwiftEval sharedInstance].signer = ^BOOL(NSString *_Nonnull dylib) {
        [self writeCommand:InjectionSign withString:dylib];
        return [reader readString].boolValue;
    };

    // As tmp file names come in, inject them
    InjectionCommand command;
    while ((command = (InjectionCommand)[self readInt]) != InjectionEOF) {
        switch (command) {
        case InjectionProject: {
            NSString *projectFile = [self readString];
            [SwiftEval sharedInstance].projectFile = projectFile;
            [SwiftEval sharedInstance].derivedLogs = nil;
            printf("Injection connected, watching %s/**\n",
                   projectFile.stringByDeletingLastPathComponent.UTF8String);
            break;
        }
        case InjectionLog:
            printf("%s\n", [self readString].UTF8String);
            break;
        case InjectionSigned:
            [writer writeString:[self readString]];
            break;
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
                    if ([xprobePaths[pathID].object respondsToSelector:@selector(evalSwift:)])
                        [xprobePaths[pathID].object evalSwift:parts[3].stringByRemovingPercentEncoding];
                    else
                        printf("Eval only works on NSObject subclasses\n");
                    [Xprobe writeString:[NSString stringWithFormat:@"$('BUSY%d').hidden = true; ", pathID]];
                }
#endif
                default:
                    [self writeCommand:InjectionError withString:@"Invalid command"];
                    break;
                }

                [self writeCommand:err ? InjectionError : InjectionComplete
                        withString:err ? err.localizedDescription : nil];
            });
        }
        }
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
        UIViewController *visibleVC = rootViewController;

        NSMutableArray *viewControllers = [NSMutableArray new];
        UINavigationController *navigationController = (UINavigationController*)rootViewController;
        if (navigationController) {
            UIViewController *visibleViewController = [navigationController visibleViewController];
            [viewControllers addObjectsFromArray:[visibleViewController allViewControllersRecursive]];
        }

        if (UIViewController *child =
            visibleVC.childViewControllers.firstObject)
            visibleVC = child;
        if ([visibleVC respondsToSelector:@selector(viewControllers)])
            visibleVC = [(UISplitViewController *)visibleVC
                         viewControllers].lastObject;
        if ([visibleVC respondsToSelector:@selector(visibleViewController)])
            visibleVC = [(UINavigationController *)visibleVC
                         visibleViewController];

        NSString *nibName = visibleVC.nibName;
        NSString *filename = [changed lastPathComponent];

        // Try and resolve the view controller by matching description to storyboard/nib name
        for (UIViewController *viewController in viewControllers) {
          if (viewController.nibName) {
            if ([[[viewController debugDescription] lowercaseString] containsString:[[filename stringByDeletingPathExtension] lowercaseString]]) {
              nibName = viewController.nibName;
              visibleVC = viewController;
              break;
            }
          }
        }

        if (!(remapper.order = allOrder[nibName])) {
            remapper.inputIndexes = [NSMutableDictionary new];
            remapper.output = [NSMutableArray new];
            allOrder[nibName] = remapper.order = [NSMutableArray new];

            [visibleVC _loadViewFromNibNamed:visibleVC.nibName
                                      bundle:visibleVC.nibBundle];

            remapper.inputIndexes = nil;
            remapper.output = nil;
        }

        NSError *err = nil;
        [[SwiftEval sharedInstance] rebuildWithStoryboard:changed error:&err];
        if (err)
            return FALSE;

        remapper.output = [NSMutableArray new];
        remapper.orderIndex = 0;

        [visibleVC _loadViewFromNibNamed:visibleVC.nibName
                                  bundle:visibleVC.nibBundle];
        [visibleVC viewDidLoad];
        [visibleVC viewWillAppear:NO];
        [visibleVC viewDidAppear:NO];

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
        [SwiftInjection flash:visibleVC];
#endif
    }
    @catch(NSException *e) {
        printf("Problem reloading nib: %s\n", e.reason.UTF8String);
    }

    remapper.output = nil;
    return true;
}
#endif

@end

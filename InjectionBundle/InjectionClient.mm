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
#if __has_include("tvOSInjection-Swift.h")
#import "tvOSInjection-Swift.h"
#else
#import "iOSInjection-Swift.h"
#endif
#else
#import "macOSInjection-Swift.h"
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
    NSString *projectFile = [self readString];
    printf("Injection connected, watching %s/...\n",
           projectFile.stringByDeletingLastPathComponent.UTF8String);
    [self writeString:[NSBundle mainBundle].privateFrameworksPath];
#ifdef __LP64__
    [self writeString:@"x86_64"];
#else
    [self writeString:@"i386"];
#endif
    [self writeString:[NSBundle mainBundle].executablePath];

    [SwiftEval sharedInstance].projectFile = projectFile;
    [SwiftEval sharedInstance].injectionNumber = 100;

    int codesignStatusPipe[2];
    pipe(codesignStatusPipe);
    SimpleSocket *reader = [[SimpleSocket alloc] initSocket:codesignStatusPipe[0]];
    SimpleSocket *writer = [[SimpleSocket alloc] initSocket:codesignStatusPipe[1]];

    // make available implementation of signing delegated to macOS app
    [SwiftEval sharedInstance].signer = ^BOOL(NSString *_Nonnull dylib) {
        [self writeString:dylib];
        return [reader readString].boolValue;
    };

    // As tmp file names come in, inject them
    while (NSString *swiftSource = [self readString])
        if ([swiftSource hasPrefix:@"LOG "])
            printf("%s\n", [swiftSource substringFromIndex:@"LOG ".length].UTF8String);
        else if ([swiftSource hasPrefix:@"SIGNED "])
            [writer writeString:[swiftSource substringFromIndex:@"SIGNED ".length]];
        else
            dispatch_async(dispatch_get_main_queue(), ^{
                NSError *err;
                if ([swiftSource hasPrefix:@"INJECT "])
                    [SwiftInjection injectWithTmpfile:[swiftSource substringFromIndex:@"INJECT ".length] error:&err];
#ifdef XPROBE_PORT
                else if ([swiftSource hasPrefix:@"XPROBE"]) {
                    [Xprobe connectTo:NULL retainObjects:YES];
                    [Xprobe search:@""];
                }
                else if ([swiftSource hasPrefix:@"EVAL "]) {
                    NSString *args = [swiftSource substringFromIndex:@"EVAL ".length];
                    NSArray<NSString *> *parts = [args componentsSeparatedByString:@"^"];
                    int pathID = parts[0].intValue;
                    [self writeString:@"PAUSE 5"];
                    [xprobePaths[pathID].object evalSwift:parts[3].stringByRemovingPercentEncoding];
                    [Xprobe writeString:[NSString stringWithFormat:@"$('BUSY%d').hidden = true; ", pathID]];
                }
#endif
                [self writeString:err ? [@"ERROR " stringByAppendingString:err.localizedDescription] : @"COMPLETE"];
            });
}

@end

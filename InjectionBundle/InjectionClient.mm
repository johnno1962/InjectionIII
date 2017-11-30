//
//  InjectionClient.m
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

@implementation InjectionClient

+ (void)load {
    // connect to InjetionIII.app using sicket
    if (InjectionClient *client = [self connectTo:INJECTION_ADDRESS]) {
        [client run];
    }
    else
        printf("Injection loaded but could not connect. Is InjectionIII.app running?\n");

}

- (void)runInBackground {
    printf("Injection connected, watching %s\n", [self readString].UTF8String);
    [self writeString:[[NSBundle mainBundle] bundlePath]];

//    int codesignStatusPipe[2];
//    pipe(codesignStatusPipe);
//    SimpleSocket *reader = [[SimpleSocket alloc] initSocket:codesignStatusPipe[0]];
//    SimpleSocket *writer = [[SimpleSocket alloc] initSocket:codesignStatusPipe[1]];
//
//    // make available implementation of signing delegated to macOS app
//    [SwiftEval sharedInstance].signer = ^BOOL(NSString *_Nonnull dylib) {
//        [self writeString:dylib];
//        return [reader readString].boolValue;
//    };

    // As source file names come in, inject them
    while (NSString *swiftSource = [self readString])
        if ([swiftSource isEqualToString:@"WATCHER OFF"])
            printf("The file watcher is turned off\n");
//        else if ([swiftSource hasPrefix:@"SIGNED "])
//            [writer writeString:[swiftSource substringFromIndex:@"SIGNED ".length]];
        else if ([swiftSource hasPrefix:@"LOG "])
            printf("%s\n", [swiftSource substringFromIndex:@"LOG ".length].UTF8String);
        else
            dispatch_async(dispatch_get_main_queue(), ^{
                NSError *err;
                if ([swiftSource hasPrefix:@"INJECT "])
                    [SwiftInjection injectWithTmpfile:[swiftSource substringFromIndex:@"INJECT ".length] error:&err];
                else
                    [NSObject injectWithFile:swiftSource];
                [self writeString:err ? [@"ERROR " stringByAppendingString:err.localizedDescription] : @"COMPLETE"];
            });
}

@end

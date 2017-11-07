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
#import "iOSInjection-Swift.h"
#else
#import "macOSInjection-Swift.h"
#endif

@implementation InjectionClient

+ (void)load {
    if (InjectionClient *client = [self connectTo:INJECTION_ADDRESS]) {
        NSLog(@"Injection connected, watching files...");
        [client run];
    }
    else
        NSLog(@"Injection loaded but could not connect. Is InjectionIII.app running?");

}

- (void)runInBackground {
    [SwiftEval sharedInstance].signer = ^(NSString * _Nonnull dylib) {
        [self writeString:dylib];
        while (![[self readString] hasPrefix:@"CODESIGN"])
            ;
    };

    while (NSString *swiftSource = [self readString])
        dispatch_sync(dispatch_get_main_queue(), ^{
            [NSObject injectWithFile:swiftSource];
        });
}

@end

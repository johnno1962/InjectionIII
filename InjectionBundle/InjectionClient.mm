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
    // connect to InjetionIII.app using sicket
    if (InjectionClient *client = [self connectTo:INJECTION_ADDRESS]) {
        NSLog(@"Injection connected, watching %@", [client readString]);
        [client run];
    }
    else
        NSLog(@"Injection loaded but could not connect. Is InjectionIII.app running?");

}

- (void)runInBackground {
    int codesignStatusPipe[2];
    pipe(codesignStatusPipe);
    SimpleSocket *reader = [[SimpleSocket alloc] initSocket:codesignStatusPipe[0]];
    SimpleSocket *writer = [[SimpleSocket alloc] initSocket:codesignStatusPipe[1]];

    // make available implementation of signing delegated to macOS app
    [SwiftEval sharedInstance].signer = ^BOOL(NSString *_Nonnull dylib) {
        [self writeString:dylib];
        return [reader readString].boolValue;
    };

    // As source file names come in, inject them
    while (NSString *swiftSource = [self readString])
        if ([swiftSource hasPrefix:@"SIGNED "])
            [writer writeString:[swiftSource substringFromIndex:@"SIGNED ".length]];
        else
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSObject injectWithFile:swiftSource];
            });
}

@end

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
    [[self connectTo:INJECTION_ADDRESS] run];
}

- (void)runInBackground {
    while (NSString *swiftSource = [self readString])
        [NSObject injectWithFile:swiftSource];
}

@end

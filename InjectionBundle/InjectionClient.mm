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

@implementation InjectionClient

+ (void)load {
    // connect to InjetionIII.app using sicket
    if (InjectionClient *client = [self connectTo:INJECTION_ADDRESS])
        [client run];
    else
        printf("Injection loaded but could not connect. Is InjectionIII.app running?\n");

}

- (void)runInBackground {
    printf("Injection connected, watching %s/...\n", [self readString].UTF8String);
    [self writeString:[NSBundle mainBundle].privateFrameworksPath];
#ifdef __LP64__
    [self writeString:@"x86_64"];
#else
    [self writeString:@"i386"];
#endif
    [self writeString:[NSBundle mainBundle].executablePath];

    // As tmp file names come in, inject them
    while (NSString *swiftSource = [self readString])
        if ([swiftSource hasPrefix:@"LOG "])
            printf("%s\n", [swiftSource substringFromIndex:@"LOG ".length].UTF8String);
        else
            dispatch_async(dispatch_get_main_queue(), ^{
                NSError *err;
                if ([swiftSource hasPrefix:@"INJECT "])
                    [SwiftInjection injectWithTmpfile:[swiftSource substringFromIndex:@"INJECT ".length] error:&err];
                [self writeString:err ? [@"ERROR " stringByAppendingString:err.localizedDescription] : @"COMPLETE"];
            });
}

@end

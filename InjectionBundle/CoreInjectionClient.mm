//
//  CoreInjectionClient.m
//  InjectionBundle
//
//  Created by Francisco Javier Trujillo Mata on 23/04/2019.
//  Copyright © 2019 John Holdsworth. All rights reserved.
//

#import "CoreInjectionClient.h"

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
#if __has_include("tvOSInjection10-Swift.h")
#import "tvOSInjection10-Swift.h"
#elif __has_include("tvOSInjection-Swift.h")
#import "tvOSInjection-Swift.h"
#elif __has_include("iOSInjection10-Swift.h")
#import "iOSInjection10-Swift.h"
#else

#if __has_include("iOSInjection-Swift.h")
#import "iOSInjection-Swift.h"
#elif __has_include("InjectionIII/InjectionIII-Swift.h")
#import "InjectionIII/InjectionIII-Swift.h"
#endif

#endif

#else

#if __has_include("macOSInjection10-Swift.h")
#import "macOSInjection10-Swift.h"
#else

#if __has_include("macOSInjection-Swift.h")
#import "macOSInjection-Swift.h"
#elif __has_include("InjectionIII/InjectionIII-Swift.h")
#import "InjectionIII/InjectionIII-Swift.h"
#endif

#endif
#endif


@implementation CoreInjectionClient

+ (void)load {
    [self createInjectionClient];
}

- (SwiftInjection *)swiftInjection
{
    static SwiftInjection *_swiftInjection;
    if (!_swiftInjection) {
        _swiftInjection = [[SwiftInjection alloc] init];
    }
    
    return _swiftInjection;
}

@end

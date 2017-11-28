//
//  HelperProxy.m
//  Smuggler
//
//  Created by John Holdsworth on 24/06/2016.
//  Copyright © 2016 John Holdsworth. All rights reserved.
//

#import "HelperProxy.h"
#import "Helper.h"

static unsigned dlopenPageOffset, dlerrorPageOffset;

@implementation HelperProxy

+ (BOOL)inject:(NSString *)bundlePath error:(NSError **)error {
    NSConnection *c = [NSConnection connectionWithRegisteredName:@HELPER_MACH_ID host:nil];
    assert(c != nil);

    Helper *helper = (Helper *)[c rootProxy];
    assert(helper != nil);

    NSLog(@"Injecting %@", bundlePath);

    mach_error_t err = [helper inject:[NSBundle mainBundle].bundlePath bundle:bundlePath client:__FILE__
                     dlopenPageOffset: dlopenPageOffset dlerrorPageOffset: dlerrorPageOffset];

    if (err == 0) {
        NSLog(@"Injected Simulator");
        return YES;
    } else {
        NSString *description;
        switch( err ) {
            case SMHelperErrorsPayload: description = @"Unable to init payload"; break;
            case SMHelperErrorsNoSim:   description = @"Simulator is not running"; break;
            case SMHelperErrorsNoNm:    description = @"Unable to find dlopen. Is xcode-select correct?"; break;
            case SMHelperErrorsNoApp:   description = @"Could not find App running in simulator"; break;
            case SMHelperErrors32Bits:  description = @"Injection only possible for 64 bit targets"; break;
            default:
                description = [NSString stringWithCString:mach_error_string(err) ?: "Unkown mach error" encoding:NSASCIIStringEncoding];
        }

        NSLog(@"an error occurred while injecting Simulator: %@ (error code: %d)", description, (int)err);

        *error = [NSError errorWithDomain:[NSBundle mainBundle].bundleIdentifier
                                     code:err
                                 userInfo:@{NSLocalizedDescriptionKey: description}];
        return NO;
    }
}

@end

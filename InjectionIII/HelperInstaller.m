//
//  HelperInstaller.m
//  Smuggler
//
//  Created by John Holdsworth on 24/06/2016.
//  Copyright © 2016 John Holdsworth. All rights reserved.
//

#import "HelperInstaller.h"
#import <ServiceManagement/ServiceManagement.h>

@implementation HelperInstaller

+ (NSString *)kInjectionHelperID {
    return [[[[NSBundle mainBundle] infoDictionary] valueForKey:(NSString *)kCFBundleIdentifierKey] stringByAppendingString:@".Helper"];
}

+ (BOOL)isInstalled {
    NSString *helperPath = [@"/Library/PrivilegedHelperTools" stringByAppendingPathComponent:[self kInjectionHelperID]];
    return [[NSFileManager defaultManager] fileExistsAtPath:helperPath];
}

+ (BOOL)install:(NSError **)error {
    AuthorizationRef authRef = NULL;
    BOOL result = [self askPermission:&authRef error:error];

    if (result == YES) {
        result = [self installHelperTool:[self kInjectionHelperID] authorizationRef:authRef error:error];
    }

    if (result == YES) {
        NSLog(@"Installed v%@", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]);
    }

    return result;
}

+ (BOOL)askPermission:(AuthorizationRef *)authRef error:(NSError **)error {
    // Creating auth item to bless helper tool and install framework
    AuthorizationItem authItem = {kSMRightBlessPrivilegedHelper, 0, NULL, 0};

    // Creating a set of authorization rights
    AuthorizationRights authRights = {1, &authItem};

    // Specifying authorization options for authorization
    AuthorizationFlags flags = kAuthorizationFlagDefaults | kAuthorizationFlagInteractionAllowed | kAuthorizationFlagExtendRights;

    // Open dialog and prompt user for password
    OSStatus status = AuthorizationCreate(&authRights, kAuthorizationEmptyEnvironment, flags, authRef);

    if (status == errAuthorizationSuccess) {
        return YES;
    } else {
        *error = [NSError errorWithDomain:[NSBundle mainBundle].bundleIdentifier
                                     code:status
                                 userInfo:@{NSLocalizedDescriptionKey: @"Authorisation error"}];
        return NO;
    }
}

+ (BOOL)installHelperTool:(NSString *)executableLabel authorizationRef:(AuthorizationRef)authRef error:(NSError **)error {
    CFErrorRef blessError = NULL;
    BOOL result = SMJobBless(kSMDomainSystemLaunchd, (__bridge CFStringRef)executableLabel, authRef, &blessError);

    if (result == NO) {
        NSLog(@"Could not install %@ - %@", executableLabel, blessError);
        *error = (__bridge NSError *)blessError;
    } else {
        NSLog(@"Installed %@ successfully", executableLabel);
    }
    
    return result;
}

@end

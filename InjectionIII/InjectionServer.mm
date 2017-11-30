//
//  InjectionServer.m
//  InjectionIII
//
//  Created by John Holdsworth on 06/11/2017.
//  Copyright © 2017 John Holdsworth. All rights reserved.
//

#import "InjectionServer.h"
#import "SignerService.h"
#import "AppDelegate.h"
#import "FileWatcher.h"
#import "Xcode.h"

#import "InjectionIII-Swift.h"

@implementation InjectionServer {
    FileWatcher *fileWatcher;
}

+ (int)error:(NSString *)message {
    int saveno = errno;
    dispatch_async(dispatch_get_main_queue(), ^{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [[NSAlert alertWithMessageText:@"Injection Error"
                         defaultButton:@"OK" alternateButton:nil otherButton:nil
             informativeTextWithFormat:message, strerror(saveno)] runModal];
#pragma clang diagnostic pop
    });
    return -1;
}

- (void)runInBackground {
    XcodeApplication *xcode = (XcodeApplication *)[SBApplication
           applicationWithBundleIdentifier:@"com.apple.dt.Xcode"];
    XcodeWorkspaceDocument *workspace = [xcode activeWorkspaceDocument];
    NSString *projectRoot = workspace.file.path.stringByDeletingLastPathComponent;
    NSLog(@"Connection with project root: %@", projectRoot);

    // tell client app the infered project being watched
    [self writeString:projectRoot];

    [appDelegate setMenuIcon:@"InjectionOK"];

    NSMutableDictionary<NSString *, NSNumber *> *lastInjected = [NSMutableDictionary new];
    #define MIN_INJECTION_INTERVAL 1.

    [SwiftEval sharedInstance].evalError = ^NSError* (NSString *message) {
        [self writeString:[@"LOG " stringByAppendingString:message]];
        return [[NSError alloc] initWithDomain:@"SwiftEval" code:-1
                                      userInfo:@{NSLocalizedDescriptionKey: message}];
    };

    // start up  afile watcher to write changed filenames to client app
    fileWatcher = [[FileWatcher alloc] initWithRoot:projectRoot plugin:^(NSArray *changed) {
        if (appDelegate.enableWatcher.state)
            for (NSString *swiftSource in changed) {
                NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
                if (now > lastInjected[swiftSource].doubleValue + MIN_INJECTION_INTERVAL) {
                    [appDelegate setMenuIcon:@"InjectionBusy"];
                    NSString *classNameOrFile = [[swiftSource substringFromIndex:1] stringByDeletingPathExtension];
                    NSString *tmpfile = [[SwiftEval sharedInstance] rebuildClassWithOldClass:nil
                                            classNameOrFile:classNameOrFile extra:nil error:nil];
                    [self writeString:[@"INJECT " stringByAppendingString:tmpfile]];
                    lastInjected[swiftSource] = [NSNumber numberWithDouble:now];
                }
            }
        else
            [self writeString:@"WATCHER OFF"];

    }];

    // read requests to codesign from client app
    while (NSString *dylib = [self readString])
        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL response = FALSE;
            if ([dylib hasPrefix:@"SIGN "])
                response = [SignerService codesignDylib:[dylib substringFromIndex:@"SIGN ".length]];
//            if ([dylib hasPrefix:@"ERROR "])
//                [[NSAlert alertWithMessageText:@"Injection Error"
//                                 defaultButton:@"OK" alternateButton:nil otherButton:nil
//                     informativeTextWithFormat:@"%@",
//                  [dylib substringFromIndex:@"ERROR ".length]] runModal];
            [appDelegate setMenuIcon:response ? @"InjectionOK" : @"InjectionError"];
            [self writeString:response ? @"SIGNED 1" : @"SIGNED 0"];
        });

    fileWatcher = nil;
    [appDelegate setMenuIcon:@"InjectionIdle"];
}

@end

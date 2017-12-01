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

static dispatch_queue_t injectionQueue;

@implementation InjectionServer {
    FileWatcher *fileWatcher;
    NSString *bundlePath, *arch;
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

    [appDelegate setMenuIcon:@"InjectionOK"];

    // tell client app the inferred project being watched
    [self writeString:projectRoot];
    bundlePath = [self readString];
    arch = [self readString];
    [SwiftEval reset];

    NSMutableDictionary<NSString *, NSNumber *> *lastInjected = [NSMutableDictionary new];
    #define MIN_INJECTION_INTERVAL 1.

    // start up a file watcher to write changed filenames to client app
    fileWatcher = [[FileWatcher alloc] initWithRoot:projectRoot plugin:^(NSArray *changed) {
        if (appDelegate.enableWatcher.state)
            for (NSString *swiftSource in changed) {
                NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
                if (now > lastInjected[swiftSource].doubleValue + MIN_INJECTION_INTERVAL) {
                    lastInjected[swiftSource] = [NSNumber numberWithDouble:now];

                    if (!injectionQueue)
                        injectionQueue = dispatch_queue_create("InjectionQueue", DISPATCH_QUEUE_SERIAL);

                    dispatch_async(injectionQueue, ^{
                        [appDelegate setMenuIcon:@"InjectionBusy"];

                        __weak InjectionServer *weakSelf = self;
                        [SwiftEval sharedInstance].evalError = ^NSError *(NSString *message) {
                            [weakSelf writeString:[@"LOG " stringByAppendingString:message]];
                            return [[NSError alloc] initWithDomain:@"SwiftEval" code:-1
                                                          userInfo:@{NSLocalizedDescriptionKey: message}];
                        };

                        [SwiftEval sharedInstance].bundlePath = bundlePath;
                        [SwiftEval sharedInstance].arch = arch;

                        if (NSString *tmpfile = [[SwiftEval sharedInstance] rebuildClassWithOldClass:nil
                                                 classNameOrFile:swiftSource extra:nil error:nil])
                            [self writeString:[@"INJECT " stringByAppendingString:tmpfile]];
                        else
                            [appDelegate setMenuIcon:@"InjectionError"];
                    });
                }
            }
        else
            [self writeString:@"WATCHER OFF"];
    }];

    // read requests to codesign from client app
    while (NSString *dylib = [self readString])
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([dylib hasPrefix:@"COMPLETE"])
                [appDelegate setMenuIcon:@"InjectionOK"];
            if ([dylib hasPrefix:@"ERROR "])
                [appDelegate setMenuIcon:@"InjectionError"];
//                [[NSAlert alertWithMessageText:@"Injection Error"
//                                 defaultButton:@"OK" alternateButton:nil otherButton:nil
//                     informativeTextWithFormat:@"%@",
//                  [dylib substringFromIndex:@"ERROR ".length]] runModal];
        });

    fileWatcher = nil;
    [appDelegate setMenuIcon:@"InjectionIdle"];
}

@end

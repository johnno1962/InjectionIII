//
//  InjectionServer.m
//  InjectionIII
//
//  Created by John Holdsworth on 06/11/2017.
//  Copyright © 2017 John Holdsworth. All rights reserved.
//

#import "InjectionServer.h"
#import "AppDelegate.h"
#import "FileWatcher.h"
#import "Xcode.h"

#import "InjectionIII-Swift.h"

static NSString *XcodeBundleID = @"com.apple.dt.Xcode";
static dispatch_queue_t injectionQueue;

@implementation InjectionServer

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
                       applicationWithBundleIdentifier:XcodeBundleID];
    XcodeWorkspaceDocument *workspace = [xcode activeWorkspaceDocument];
    NSString *projectFile = workspace.file.path, *projectRoot = projectFile.stringByDeletingLastPathComponent;
    NSLog(@"Connection with project file: %@", projectFile);

    [appDelegate setMenuIcon:@"InjectionOK"];

    // tell client app the inferred project being watched
    [self writeString:projectRoot];

    SwiftEval *builder = [SwiftEval newInstance];

    if (NSRunningApplication *xcode = [NSRunningApplication
                                       runningApplicationsWithBundleIdentifier:XcodeBundleID].firstObject)
        builder.xcodeDev = [xcode.bundleURL.path stringByAppendingPathComponent:@"Contents/Developer"];

    builder.projectFile = projectFile;
    builder.frameworks = [self readString];
    builder.arch = [self readString];

    builder.evalError = ^NSError *(NSString *message) {
        [self writeString:[@"LOG " stringByAppendingString:message]];
        return [[NSError alloc] initWithDomain:@"SwiftEval" code:-1
                                      userInfo:@{NSLocalizedDescriptionKey: message}];
    };

    NSMutableDictionary<NSString *, NSNumber *> *lastInjected = [NSMutableDictionary new];
    #define MIN_INJECTION_INTERVAL 1.

    // start up a file watcher to write changed filenames to client app
    FileWatcher *fileWatcher = [[FileWatcher alloc] initWithRoot:projectRoot plugin:^(NSArray *changed) {
        for (NSString *swiftSource in changed) {
            NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
            if (now > lastInjected[swiftSource].doubleValue + MIN_INJECTION_INTERVAL) {
                lastInjected[swiftSource] = [NSNumber numberWithDouble:now];

                if (!injectionQueue)
                    injectionQueue = dispatch_queue_create("InjectionQueue", DISPATCH_QUEUE_SERIAL);

                NSControlStateValue watcherState = appDelegate.enableWatcher.state;
                dispatch_async(injectionQueue, ^{
                    if (watcherState == NSControlStateValueOn) {
                        [appDelegate setMenuIcon:@"InjectionBusy"];
                        if (NSString *tmpfile = [builder rebuildClassWithOldClass:nil
                                        classNameOrFile:swiftSource extra:nil error:nil])
                            [self writeString:[@"INJECT " stringByAppendingString:tmpfile]];
                        else
                            [appDelegate setMenuIcon:@"InjectionError"];
                    }
                    else
                        [self writeString:@"LOG The file watcher is turned off"];
                });
            }
        }
    }];

    // read status requests from client app
    while (NSString *dylib = [self readString])
        if ([dylib hasPrefix:@"COMPLETE"])
            [appDelegate setMenuIcon:@"InjectionOK"];
        else if ([dylib hasPrefix:@"ERROR "])
            [appDelegate setMenuIcon:@"InjectionError"];
//            dispatch_async(dispatch_get_main_queue(), ^{
//                [[NSAlert alertWithMessageText:@"Injection Error"
//                                 defaultButton:@"OK" alternateButton:nil otherButton:nil
//                     informativeTextWithFormat:@"%@",
//                  [dylib substringFromIndex:@"ERROR ".length]] runModal];
//            });

    fileWatcher = nil;
    [appDelegate setMenuIcon:@"InjectionIdle"];
}

@end

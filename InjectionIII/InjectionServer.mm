//
//  InjectionServer.mm
//  InjectionIII
//
//  Created by John Holdsworth on 06/11/2017.
//  Copyright © 2017 John Holdsworth. All rights reserved.
//

#import "InjectionServer.h"
#import "SignerService.h"
#import "AppDelegate.h"
#import "FileWatcher.h"
#import <sys/stat.h>

#import "Xcode.h"
#import "XcodeHash.h"

#import "InjectionIII-Swift.h"

static NSString *XcodeBundleID = @"com.apple.dt.Xcode";
static dispatch_queue_t injectionQueue = dispatch_queue_create("InjectionQueue", DISPATCH_QUEUE_SERIAL);

static NSMutableDictionary *projectInjected = [NSMutableDictionary new];
#define MIN_INJECTION_INTERVAL 1.

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
    SwiftEval *builder = [SwiftEval new];

    // client spcific data for building
    if (NSString *frameworks = [self readString])
        builder.frameworks = frameworks;
    else
        return;
    
    // auto-select-project
    NSString *projectFile = [self findConnectingProject:builder.frameworks];
    if (projectFile.length > 0) {
        NSLog(@"project file: %@ being watched", projectFile);
        builder.projectFile = projectFile;
        // tell client app the inferred project being watched
        [self writeString:projectFile];
    }else{
        // can't find a project to watch
        NSLog(@"error: can not find a project to watch");
        return;
    }

    if (NSString *arch = [self readString])
        builder.arch = arch;
    else
        return;

    // Xcode specific config
    if (NSRunningApplication *xcode = [NSRunningApplication
                                       runningApplicationsWithBundleIdentifier:XcodeBundleID].firstObject)
        builder.xcodeDev = [xcode.bundleURL.path stringByAppendingPathComponent:@"Contents/Developer"];

    NSString *projectName = projectFile.stringByDeletingPathExtension.lastPathComponent;
    NSString *derivedLogs = [NSString stringWithFormat:@"%@/Library/Developer/Xcode/DerivedData/%@-%@/Logs/Build",
                             NSHomeDirectory(), [projectName stringByReplacingOccurrencesOfString:@"[\\s]+" withString:@"_"
                                                  options:NSRegularExpressionSearch range:NSMakeRange(0, projectName.length)],
                             [XcodeHash hashStringForPath:projectFile]];
    if ([[NSFileManager defaultManager] fileExistsAtPath:derivedLogs])
        builder.derivedLogs = derivedLogs;
    else
        NSLog(@"Bad estimate of Derived Logs: %@ -> %@", projectFile, derivedLogs);

    // callback on errors
    builder.evalError = ^NSError *(NSString *message) {
        [self writeString:[@"LOG " stringByAppendingString:message]];
        return [[NSError alloc] initWithDomain:@"SwiftEval" code:-1
                                      userInfo:@{NSLocalizedDescriptionKey: message}];
    };

    [appDelegate setMenuIcon:@"InjectionOK"];
    appDelegate.lastConnection = self;

    auto inject = ^(NSString *swiftSource) {
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
    };

    NSMutableDictionary<NSString *, NSNumber *> *lastInjected = projectInjected[projectFile];
    if (!lastInjected)
        projectInjected[projectFile] = lastInjected = [NSMutableDictionary new];

    if (NSString *executable = [self readString]) {
        auto mtime = ^time_t (NSString *path) {
            struct stat info;
            return stat(path.UTF8String, &info) == 0 ? info.st_mtimespec.tv_sec : 0;
        };
        time_t executableBuild = mtime(executable);
        for(NSString *source in lastInjected)
            if (mtime(source) > executableBuild)
                inject(source);
    }
    else
        return;

    __block NSTimeInterval pause = 0.;
    NSString *projectRoot = builder.projectFile.stringByDeletingLastPathComponent;
    // start up a file watcher to write generated tmpfile path to client app
    FileWatcher *fileWatcher = [[FileWatcher alloc] initWithRoot:projectRoot plugin:^(NSArray *changed) {
        NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
        for (NSString *swiftSource in changed)
            if (now > lastInjected[swiftSource].doubleValue + MIN_INJECTION_INTERVAL && now > pause) {
                lastInjected[swiftSource] = [NSNumber numberWithDouble:now];
                inject(swiftSource);
            }
    }];

    // read status requests from client app
    while (NSString *response = [self readString])
        if ([response hasPrefix:@"COMPLETE"])
            [appDelegate setMenuIcon:@"InjectionOK"];
        else if ([response hasPrefix:@"PAUSE "])
            pause = [NSDate timeIntervalSinceReferenceDate] +
                [response substringFromIndex:@"PAUSE ".length].doubleValue;
        else if ([response hasPrefix:@"SIGN "])
            [self writeString:[SignerService codesignDylib:[response
                substringFromIndex:@"SIGN ".length]] ? @"SIGNED 1" : @"SIGNED 0"];
        else if ([response hasPrefix:@"ERROR "])
            [appDelegate setMenuIcon:@"InjectionError"];
//            dispatch_async(dispatch_get_main_queue(), ^{
//                [[NSAlert alertWithMessageText:@"Injection Error"
//                                 defaultButton:@"OK" alternateButton:nil otherButton:nil
//                     informativeTextWithFormat:@"%@",
//                  [dylib substringFromIndex:@"ERROR ".length]] runModal];
//            });

    // client app disconnected
    fileWatcher = nil;
    [appDelegate setMenuIcon:@"InjectionIdle"];
}

- (NSString *)findConnectingProject:(NSString *) builderFrameworksPath
{
    NSString *projectFile = @"";
    XcodeApplication *xcode = (XcodeApplication *)[SBApplication
                                                   applicationWithBundleIdentifier:XcodeBundleID];
    //traverse all workspaceDocuments and find out which workspace is connecting
    for (XcodeWorkspaceDocument *tmpWorkspaceDocument in xcode.workspaceDocuments) {
        NSString* projectName = [builderFrameworksPath stringByDeletingLastPathComponent];
        projectName = [[projectName lastPathComponent] stringByDeletingPathExtension];
        if ([tmpWorkspaceDocument.file.path containsString:projectName]) {
            projectFile = tmpWorkspaceDocument.file.path;
            NSLog(@"find connecting project file: %@", projectFile);
            break;
        }
    }
    
    //fall-back to the activeWorkspaceDocument.file.path
    //if it doesn’t find a workspace with the binary's name.
    if (projectFile.length == 0) {
        XcodeWorkspaceDocument *workspace = [xcode activeWorkspaceDocument];
        projectFile = workspace.file.path;
        NSLog(@"activeWorkspace project file: %@", projectFile);
    }
    return projectFile;
}

- (void)dealloc {
    NSLog(@"- [%@ dealloc]", self);
}

@end

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
#import "UserDefaults.h"

#import "InjectionIII-Swift.h"

static NSString *XcodeBundleID = @"com.apple.dt.Xcode";
static dispatch_queue_t injectionQueue = dispatch_queue_create("InjectionQueue", DISPATCH_QUEUE_SERIAL);

static NSMutableDictionary *projectInjected = [NSMutableDictionary new];
#define MIN_INJECTION_INTERVAL 1.

@implementation InjectionServer {
    void (^injector)(NSArray *changed);
    FileWatcher *fileWatcher;
    NSMutableArray *pending;
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
    [self writeString:NSHomeDirectory()];

    NSString *projectFile = appDelegate.selectedProject;
    static BOOL MAS = false;

    if (!projectFile) {
        XcodeApplication *xcode = (XcodeApplication *)[SBApplication
                           applicationWithBundleIdentifier:XcodeBundleID];
        XcodeWorkspaceDocument *workspace = [xcode activeWorkspaceDocument];
        projectFile = workspace.file.path;
    }

    if (!projectFile) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [appDelegate openProject:self];
        });
        projectFile = appDelegate.selectedProject;
        MAS = true;
    }
    if (!projectFile)
        return;

    NSLog(@"Connection with project file: %@", projectFile);

    // tell client app the inferred project being watched
    if (![[self readString] isEqualToString:INJECTION_KEY])
        return;

    SwiftEval *builder = [SwiftEval new];

    // client spcific data for building
    if (NSString *frameworks = [self readString])
        builder.frameworks = frameworks;
    else
        return;

    if (NSString *arch = [self readString])
        builder.arch = arch;
    else
        return;

    // Xcode specific config
    if (NSRunningApplication *xcode = [NSRunningApplication
                                       runningApplicationsWithBundleIdentifier:XcodeBundleID].firstObject)
        builder.xcodeDev = [xcode.bundleURL.path stringByAppendingPathComponent:@"Contents/Developer"];


    builder.projectFile = projectFile;

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
        [self writeCommand:InjectionLog withString:message];
        return [[NSError alloc] initWithDomain:@"SwiftEval" code:-1
                                      userInfo:@{NSLocalizedDescriptionKey: message}];
    };

    [appDelegate setMenuIcon:@"InjectionOK"];
    appDelegate.lastConnection = self;
    pending = [NSMutableArray new];

    auto inject = ^(NSString *swiftSource) {
        NSControlStateValue watcherState = appDelegate.enableWatcher.state;
        dispatch_async(injectionQueue, ^{
            if (watcherState == NSControlStateValueOn) {
                [appDelegate setMenuIcon:@"InjectionBusy"];
//                if (!MAS) {
//                    if (NSString *tmpfile = [builder rebuildClassWithOldClass:nil
//                                                              classNameOrFile:swiftSource extra:nil error:nil])
//                        [self writeString:[@"LOAD " stringByAppendingString:tmpfile]];
//                    else
//                        [appDelegate setMenuIcon:@"InjectionError"];
//                }
//                else
                    [self writeCommand:InjectionInject withString:swiftSource];
            }
            else
                [self writeCommand:InjectionLog withString:@"The file watcher is turned off"];
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
            if (![source hasSuffix:@"storyboard"] && ![source hasSuffix:@"xib"] &&
                mtime(source) > executableBuild)
                inject(source);
    }
    else
        return;

    __block NSTimeInterval pause = 0.;

    // start up a file watcher to write generated tmpfile path to client app

    NSMutableDictionary<NSString *, NSArray *> *testCache = [NSMutableDictionary new];

    injector = ^(NSArray *changed) {
        NSMutableArray *changedFiles = [NSMutableArray arrayWithArray:changed];

        if ([[NSUserDefaults standardUserDefaults] boolForKey:UserDefaultsTDDEnabled]) {
            for (NSString *injectedFile in changed) {
                NSArray *matchedTests = testCache[injectedFile] ?:
                    (testCache[injectedFile] = [InjectionServer searchForTestWithFile:injectedFile
                                    projectRoot:projectFile.stringByDeletingLastPathComponent
                                    fileManager:[NSFileManager defaultManager]]);
                [changedFiles addObjectsFromArray:matchedTests];
            }
        }

        NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
        BOOL automatic = appDelegate.enableWatcher.state == NSControlStateValueOn;
        for (NSString *swiftSource in changedFiles)
            if (![pending containsObject:swiftSource])
                if (now > lastInjected[swiftSource].doubleValue + MIN_INJECTION_INTERVAL && now > pause) {
                    lastInjected[swiftSource] = [NSNumber numberWithDouble:now];
                    [pending addObject:swiftSource];
                    if (!automatic)
                        [self writeCommand:InjectionLog
                                withString:[NSString stringWithFormat:
                                            @"'%@' saved, type ctrl-= to inject",
                                            swiftSource.lastPathComponent]];
                }

        if (automatic)
            [self injectPending];
    };

    [self setProject:projectFile];

    // read status requests from client app
    InjectionCommand command;
    while ((command = (InjectionCommand)[self readInt]) != InjectionEOF) {
        switch (command) {
        case InjectionComplete:
            [appDelegate setMenuIcon:@"InjectionOK"];
            break;
        case InjectionPause:
            pause = [NSDate timeIntervalSinceReferenceDate] +
                [self readString].doubleValue;
            break;
        case InjectionSign: {
            BOOL signedOK = [SignerService codesignDylib:[self readString]];
            [self writeCommand:InjectionSigned withString: signedOK ? @"1": @"0"];
            break;
        }
        case InjectionError:
            [appDelegate setMenuIcon:@"InjectionError"];
            NSLog(@"Injection error: %@", [self readString]);
//            dispatch_async(dispatch_get_main_queue(), ^{
//                [[NSAlert alertWithMessageText:@"Injection Error"
//                                 defaultButton:@"OK" alternateButton:nil otherButton:nil
//                     informativeTextWithFormat:@"%@",
//                  [dylib substringFromIndex:@"ERROR ".length]] runModal];
//            });
            break;
        default:
            NSLog(@"InjectionServer: Unexpected case %d", command);
            break;
        }
    }

    // client app disconnected
    injector = nil;
    fileWatcher = nil;
    [appDelegate setMenuIcon:@"InjectionIdle"];
}

- (void)injectPending {
    for (NSString *swiftSource in pending)
        dispatch_async(injectionQueue, ^{
            [self writeCommand:InjectionInject withString:swiftSource];
        });
    [pending removeAllObjects];
}

- (void)setProject:(NSString *)project {
    if (!injector) return;
    [self writeCommand:InjectionProject withString:project];
    [self writeCommand:InjectionVaccineSettingChanged withString:[appDelegate vaccineConfiguration]];
    fileWatcher = [[FileWatcher alloc]
                   initWithRoot:project.stringByDeletingLastPathComponent
                   plugin:injector];
}

+ (NSArray *)searchForTestWithFile:(NSString *)injectedFile projectRoot:(NSString *)projectRoot fileManager:(NSFileManager *)fileManager;
{
    NSMutableArray *matchedTests = [NSMutableArray array];
    NSString *injectedFileName = [[injectedFile lastPathComponent] stringByDeletingPathExtension];
    NSURL *projectUrl = [NSURL URLWithString:[self urlEncodeString:projectRoot]];
    NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtURL:projectUrl
                                          includingPropertiesForKeys:@[NSURLNameKey, NSURLIsDirectoryKey]
                                                             options:NSDirectoryEnumerationSkipsHiddenFiles
                                                        errorHandler:^BOOL(NSURL *url, NSError *error)
                                         {
                                             if (error) {
                                                 NSLog(@"[Error] %@ (%@)", error, url);
                                                 return NO;
                                             }

                                             return YES;
                                         }];


    for (NSURL *fileURL in enumerator) {
        NSString *filename;
        NSNumber *isDirectory;

        [fileURL getResourceValue:&filename forKey:NSURLNameKey error:nil];
        [fileURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];

        if ([filename hasPrefix:@"_"] && [isDirectory boolValue]) {
            [enumerator skipDescendants];
            continue;
        }

        if (![isDirectory boolValue] &&
            ![[filename lastPathComponent] isEqualToString:[injectedFile lastPathComponent]] &&
            [[filename lowercaseString] containsString:[injectedFileName lowercaseString]]) {
            [matchedTests addObject:fileURL.path];
        }
    }

    return matchedTests;
}

+ (nullable NSString *)urlEncodeString:(NSString *)string {
    NSString *unreserved = @"-._~/?";
    NSMutableCharacterSet *allowed = [NSMutableCharacterSet alphanumericCharacterSet];
    [allowed addCharactersInString:unreserved];
    return [string stringByAddingPercentEncodingWithAllowedCharacters: allowed];
}

- (void)dealloc {
    NSLog(@"- [%@ dealloc]", self);
}

@end

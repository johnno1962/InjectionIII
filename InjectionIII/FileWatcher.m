//
//  FileWatcher.m
//  InjectionIII
//
//  Created by John Holdsworth on 08/03/2015.
//  Copyright (c) 2015 John Holdsworth. All rights reserved.
//

#import "UserDefaults.h"
#import "FileWatcher.h"

@implementation FileWatcher {
    FSEventStreamRef fileEvents;
}

static void fileCallback(ConstFSEventStreamRef streamRef,
                         void *clientCallBackInfo,
                         size_t numEvents, void *eventPaths,
                         const FSEventStreamEventFlags eventFlags[],
                         const FSEventStreamEventId eventIds[]) {
    FileWatcher *self = (__bridge FileWatcher *)clientCallBackInfo;
    // Check that the event flags include an item renamed flag, this helps avoid
    // unnecessary injection, such as triggering injection when switching between
    // files in Xcode.
    BOOL shouldRespondToFileChange = NO;
    for (int i = 0; i < numEvents; i++) {
        uint32 flag = eventFlags[i];
        if (flag & kFSEventStreamEventFlagItemRenamed) {
            shouldRespondToFileChange = YES;
            break;
        }
    }

    if (shouldRespondToFileChange == YES) {
        [self performSelectorOnMainThread:@selector(filesChanged:)
                               withObject:(__bridge id)eventPaths waitUntilDone:NO];
    }
}

- (instancetype)initWithRoot:(NSString *)projectRoot plugin:(InjectionCallback)callback;
{
    if ((self = [super init])) {
        self.projectRoot = projectRoot;
        self.callback = callback;
        static struct FSEventStreamContext context;
        context.info = (__bridge void *)self;
        fileEvents = FSEventStreamCreate(kCFAllocatorDefault,
                                         fileCallback, &context,
                                         (__bridge CFArrayRef) @[ projectRoot ],
                                         kFSEventStreamEventIdSinceNow, .1,
                                         kFSEventStreamCreateFlagUseCFTypes |
                                         kFSEventStreamCreateFlagFileEvents);
        FSEventStreamScheduleWithRunLoop(fileEvents, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
        FSEventStreamStart(fileEvents);
    }

    return self;
}

- (void)filesChanged:(NSArray *)changes;
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSMutableSet *changed = [NSMutableSet new];

    for (NSString *path in changes) {
        if ([path rangeOfString:INJECTABLE_PATTERN
                        options:NSRegularExpressionSearch].location != NSNotFound &&
            [path rangeOfString:@"DerivedData/|InjectionProject/|main.mm?$"
                        options:NSRegularExpressionSearch].location == NSNotFound &&
            [fileManager fileExistsAtPath:path]) {

            [changed addObject:path];

            if ([[NSUserDefaults standardUserDefaults] boolForKey:UserDefaultsTDDEnabled]) {
                NSArray *matchedTests = [self searchForTestWithFile:path projectRoot:self.projectRoot fileManager:fileManager];
                [changed addObjectsFromArray:matchedTests];
            }
        }
    }

    //NSLog( @"filesChanged: %@", changed );
    if (changed.count)
        self.callback([[changed objectEnumerator] allObjects]);
}

- (NSArray *)searchForTestWithFile:(NSString *)injectedFile projectRoot:(NSString *)projectRoot fileManager:(NSFileManager *)fileManager;
{
    NSString *injectedFileName = [[injectedFile lastPathComponent] stringByDeletingPathExtension];
    NSURL *projectUrl = [NSURL URLWithString:projectRoot];
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

    NSMutableArray *matchedTests = [NSMutableArray array];
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

- (void)dealloc;
{
    FSEventStreamStop(fileEvents);
    FSEventStreamInvalidate(fileEvents);
    FSEventStreamRelease(fileEvents);
}

@end

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

@implementation InjectionServer {
    FileWatcher *fileWatcher;
}

- (void)runInBackground {
    XcodeApplication *xcode = (XcodeApplication *)[SBApplication
           applicationWithBundleIdentifier:@"com.apple.dt.Xcode"];
    XcodeWorkspaceDocument *workspace = [xcode activeWorkspaceDocument];
    NSString *projectRoot = workspace.file.path.stringByDeletingLastPathComponent;
    NSLog(@"Connection with project root: %@", projectRoot);

    [appDelegate performSelectorOnMainThread:@selector(setMenuIcon:) withObject:@"InjectionOK" waitUntilDone:YES];

    fileWatcher = [[FileWatcher alloc] initWithRoot:projectRoot plugin:^(NSArray *changed) {
        if (appDelegate.enableWatcher.state)
            for (NSString *swiftSource in changed)
                [self writeString:swiftSource];
    }];

    while (NSString *dylib = [self readString])
        [self writeString:[SignerService codesignDylib:dylib] ? @"CODESIGN1" : @"CODESIGN0"];
    fileWatcher = nil;

    [appDelegate performSelectorOnMainThread:@selector(setMenuIcon:) withObject:@"InjectionIdle" waitUntilDone:YES];
}

@end

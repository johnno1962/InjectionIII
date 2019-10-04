//
//  AppDelegate.h
//  InjectionIII
//
//  Created by John Holdsworth on 06/11/2017.
//  Copyright © 2017 John Holdsworth. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "InjectionServer.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (weak) IBOutlet NSMenuItem *enableWatcher, *traceItem;
@property NSMutableSet<NSString *> *watchedDirectories;
@property (weak) InjectionServer *lastConnection;
@property NSString *selectedProject;

- (NSString *)vaccineConfiguration;
- (void)setMenuIcon:(NSString *)tiffName;
- (IBAction)openProject:sender;

@end

extern AppDelegate *appDelegate;

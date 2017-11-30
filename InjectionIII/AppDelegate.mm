//
//  AppDelegate.m
//  InjectionIII
//
//  Created by John Holdsworth on 06/11/2017.
//  Copyright © 2017 John Holdsworth. All rights reserved.
//

#import "AppDelegate.h"
#import "SignerService.h"
#import "InjectionServer.h"

#import "HelperInstaller.h"
#import "HelperProxy.h"

#import <Carbon/Carbon.h>
#import <AppKit/NSEvent.h>
#import "DDHotKeyCenter.h"

AppDelegate *appDelegate;

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate {
    IBOutlet NSMenu *statusMenu;
    IBOutlet NSMenuItem *startItem;
    IBOutlet NSStatusItem *statusItem;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    appDelegate = self;
    [InjectionServer startServer:INJECTION_ADDRESS];

    NSStatusBar *statusBar = [NSStatusBar systemStatusBar];
    statusItem = [statusBar statusItemWithLength:statusBar.thickness];
    statusItem.toolTip = @"Code Injection";
    statusItem.highlightMode = TRUE;
    statusItem.menu = statusMenu;
    statusItem.enabled = TRUE;
    statusItem.title = @"";

    [self setMenuIcon:@"InjectionIdle"];

    [[DDHotKeyCenter sharedHotKeyCenter] registerHotKeyWithKeyCode:kVK_ANSI_Equal
                                                     modifierFlags:NSEventModifierFlagControl
                                                            target:self action:@selector(autoInject:) object:nil];
}

- (void)setMenuIcon:(NSString *)tiffName {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (NSString *path = [NSBundle.mainBundle pathForResource:tiffName ofType:@"tif"]) {
            NSImage *image = [[NSImage alloc] initWithContentsOfFile:path];
    //        image.template = TRUE;
            statusItem.image = image;
            statusItem.alternateImage = statusItem.image;
            startItem.enabled = [tiffName isEqualToString:@"InjectionIdle"];
        }
    });
}

- (IBAction)toggleState:(NSMenuItem *)sender {
    sender.state = !sender.state;
}

- (IBAction)autoInject:(NSMenuItem *)sender {
    NSError *error = nil;

    // Install helper tool
    if ([HelperInstaller isInstalled] == NO && [HelperInstaller install:&error] == NO) {
        NSLog(@"Couldn't install Smuggler Helper (domain: %@ code: %d)", error.domain, (int)error.code);
        [[NSAlert alertWithError:error] runModal];
    }

    // Inject Simulator process
    NSString *bundlePath = [[NSBundle mainBundle] pathForResource:@"iOSInjection" ofType:@"bundle"];
    if ([HelperProxy inject:bundlePath error:&error] == FALSE) {
        NSLog(@"Couldn't inject Simulator (domain: %@ code: %d)", error.domain, (int)error.code);
        [[NSAlert alertWithError:error] runModal];
    }
}

- (IBAction)donate:sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://johnholdsworth.com/cgi-bin/injection3.cgi"]];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
    [[DDHotKeyCenter sharedHotKeyCenter] unregisterHotKeyWithKeyCode:kVK_ANSI_Equal
                                                       modifierFlags:NSEventModifierFlagControl];
}


@end

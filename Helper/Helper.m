//
//  Helper.m
//  Smuggler
//
//  Created by John Holdsworth on 24/06/2016.
//  Copyright © 2016 John Holdsworth. All rights reserved.
//

#import "Helper.h"
#import "mach_inject.h"
#import "mach_inject_bundle_stub.h"

#include <libproc.h>

static FILE *logger;

@implementation Helper

- (NSString *)projectRoot:(const char *)sourceFile {
    return [NSString stringWithCString:sourceFile encoding:NSUTF8StringEncoding]
            .stringByDeletingLastPathComponent.stringByDeletingLastPathComponent;
}

- (mach_error_t)inject:(NSString *)appPath bundle:(NSString *)payload client:(const char *)client
      dlopenPageOffset: (unsigned)dlopenPageOffset dlerrorPageOffset: (unsigned)dlerrorPageOffset {
    assert([[self projectRoot:client] isEqualToString:[self projectRoot:__FILE__]]);

    logger = fopen(HELPER_LOGFILE, "w");
    setvbuf(logger, NULL, _IONBF, 0);
    fchmod(fileno(logger), 0666);

    NSBundle *appBundle = [NSBundle bundleWithPath:appPath];
    assert(appBundle && "App Bundle");

    NSURL *boostrapURL = [appBundle URLForResource:@"Bootstrap" withExtension:@"bundle"];
    CFBundleRef bootstrapBundle = CFBundleCreate(kCFAllocatorDefault, (__bridge CFURLRef)boostrapURL);
    void *bootstrapEntry = CFBundleGetFunctionPointerForName(bootstrapBundle, CFSTR( INJECT_ENTRY_SYMBOL ));
    assert(bootstrapEntry && "Bootstrap Entry");

    fprintf( logger, "bootstrapEntry: %p\n", bootstrapEntry );

    NSBundle *payloadBundle = [NSBundle bundleWithPath:payload];
    fprintf( logger, "payloadBundle: %p\n", payloadBundle );
    if (!payloadBundle) {
        fprintf( logger, "Could not init payload bundle: %s\n", [payload UTF8String] );
        return SMHelperErrorsPayload;
    }

    const char *payloadPath = payloadBundle.executablePath.fileSystemRepresentation;
    assert(payloadPath && "Payload Path");

    fprintf( logger, "payloadPath: %s\n", payloadPath );

    size_t paramSize = sizeof( mach_inject_bundle_stub_param ) + strlen( payloadPath );
    mach_inject_bundle_stub_param *param = malloc( paramSize );

    param->dlopenPageOffset = dlopenPageOffset;
    param->dlerrorPageOffset = dlerrorPageOffset;
    strcpy( param->bundleExecutableFileSystemRepresentation, payloadPath );

    char pathBuff[PROC_PIDPATHINFO_MAXSIZE];
    memset(pathBuff, 0, sizeof pathBuff);

    pid_t pid = [self pidContaining:"/usr/libexec/MobileGestaltHelper" returning:pathBuff];
    fprintf( logger, "pathBuff: %d %s\n", pid, pathBuff );
    if( pid <= 0 ) {
        fprintf( logger, "Simulator does not seem to be running\n" );
        return SMHelperErrorsNoSim;
    }

    NSString *simPath = [NSString stringWithUTF8String:pathBuff];
    NSString *dyldPath = [[simPath.stringByDeletingLastPathComponent.stringByDeletingLastPathComponent
                           stringByAppendingPathComponent:@"lib/system/libdyld.dylib"]
                          stringByReplacingOccurrencesOfString:@"'" withString:@""];

    fprintf( logger, "dyldPath: %s\n", [dyldPath UTF8String] );

    NSString *output = [self run:[NSString stringWithFormat:@"nm '%@' | grep ' _dlopen'", dyldPath]];
    [[NSScanner scannerWithString:output] scanHexInt:&param->dlopenPageOffset];

    output = [self run:[NSString stringWithFormat:@"nm '%@' | grep ' _dlerror'", dyldPath]];
    [[NSScanner scannerWithString:output] scanHexInt:&param->dlerrorPageOffset];

    fprintf( logger, "dlopen() offset: 0x%x, dlerror() offset: 0x%x\n", param->dlopenPageOffset, param->dlerrorPageOffset );
    if( !param->dlopenPageOffset || !param->dlerrorPageOffset ) {
        fprintf( logger, "Could not locate locate dlopen() offset, is xcode-select correct\n" );
        return SMHelperErrorsNoNm;
    }

    pid = [self pidContaining:"/data/Containers/Bundle/Application/" returning:NULL];
    if( pid <= 0 ) {
        fprintf( logger, "Could not locate app running in simulator\n" );
        return SMHelperErrorsNoApp;
    }

    fclose( logger );

    // vm_write() Bootstrap.bundle into target process and execute to load payload
    mach_error_t err = mach_inject( bootstrapEntry, param, paramSize, pid, 0 );

    CFRelease( bootstrapBundle );
    free( param );
    return err;
}

- (pid_t)pidContaining:(const char *)text returning:(char *)returning {
    int procCnt = proc_listpids(PROC_ALL_PIDS, 0, NULL, 0);
    pid_t pids[65536];
    memset(pids, 0, sizeof pids);
    proc_listpids(PROC_ALL_PIDS, 0, pids, sizeof(pids));

    char curPath[PROC_PIDPATHINFO_MAXSIZE];
    memset(curPath, 0, sizeof curPath);
    for (int i = 0; i < procCnt; i++) {
        proc_pidpath(pids[i], curPath, sizeof curPath);
        if ( strstr(curPath, text) != NULL ) {
            if (returning)
                strcpy( returning, curPath );
            return pids[i];
        }
    }

    return 0;
}

- (NSString *)run:(NSString *)command {
    NSTask *task = [NSTask new];
    NSPipe *pipe = [NSPipe new];
    task.launchPath = @"/bin/bash";
    task.arguments = @[@"-c", command];
    task.standardOutput = pipe.fileHandleForWriting;
    [task launch];
    [pipe.fileHandleForWriting closeFile];
    [task waitUntilExit];
    NSData *output = pipe.fileHandleForReading.readDataToEndOfFile;
    return [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
}

@end

//
//  SignerService.m
//  InjectionIII
//
//  Created by John Holdsworth on 06/11/2017.
//  Copyright © 2017 John Holdsworth. All rights reserved.
//

#import "SignerService.h"

@implementation SignerService

+ (BOOL)codesignDylib:(NSString *)dylib {
    NSString *command = [NSString stringWithFormat:@""
                         "(export CODESIGN_ALLOCATE=/Applications/Xcode.app"
                         "/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/codesign_allocate; "
                         "/usr/bin/codesign --force -s '-' \"%@\")", dylib];
    return system(command.UTF8String) >> 8 == EXIT_SUCCESS;
}

- (void)runInBackground {
    char __unused skip, buffer[1000];
    buffer[read(clientSocket, buffer, sizeof buffer-1)] = '\000';
    NSString *path = [[NSString stringWithUTF8String:buffer] componentsSeparatedByString:@" "][1];

    if ([[self class] codesignDylib:path]) {
        snprintf(buffer, sizeof buffer, "HTTP/1.0 200 OK\r\n\r\n");
        write(clientSocket, buffer, strlen(buffer));
    }
}

@end

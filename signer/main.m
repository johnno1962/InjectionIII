//
//  main.m
//  signer
//
//  Created by John Holdsworth on 03/11/2017.
//  Copyright © 2017 John Holdsworth. All rights reserved.
//

#import <Foundation/Foundation.h>

#include <sys/socket.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>

int main(int argc, const char * argv[]) {
    static struct sockaddr_in serverAddr;

    serverAddr.sin_family = AF_INET;
    serverAddr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    serverAddr.sin_port = htons(8899);

    int optval = 1, serverSocket;
    if ((serverSocket = socket(serverAddr.sin_family, SOCK_STREAM, 0)) < 0)
        NSLog(@"Could not open service socket: %s", strerror(errno));
    else if (setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &optval, sizeof optval) < 0)
        NSLog(@"Could not set socket option: %s", strerror(errno));
    else if (setsockopt(serverSocket, SOL_SOCKET, SO_NOSIGPIPE, (void *)&optval, sizeof(optval)) < 0)
        NSLog(@"Could not set socket option: %s", strerror(errno));
    else if (setsockopt(serverSocket, IPPROTO_TCP, TCP_NODELAY, (void *)&optval, sizeof(optval)) < 0)
        NSLog(@"Could not set socket option: %s", strerror(errno));
    else if (bind(serverSocket, (struct sockaddr *)&serverAddr, sizeof serverAddr) < 0)
        NSLog(@"Could not bind service socket: %s", strerror(errno));
    else if (listen(serverSocket, 5) < 0)
        NSLog(@"Service socket would not listen: %s", strerror(errno));
    else while (TRUE) {
        struct sockaddr_in clientAddr;
        socklen_t addrLen = sizeof clientAddr;
        char buffer[1000];

        int client = accept(serverSocket, (struct sockaddr *)&clientAddr, &addrLen);
        if (client > 0) {
            @autoreleasepool {
                NSLog(@"Connection from %s:%d\n",
                      inet_ntoa(clientAddr.sin_addr), ntohs(clientAddr.sin_port));
                buffer[read(client, buffer, sizeof buffer-1)] = '\000';
                NSString *path = [[NSString stringWithUTF8String:buffer] componentsSeparatedByString:@" "][1];

                if ([path.pathExtension isEqualToString:@"dylib"]) {
                    system([[NSString stringWithFormat:@"export CODESIGN_ALLOCATE=/Applications/Xcode.app"
                             "/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/codesign_allocate; "
                             "/usr/bin/codesign --force -s '-' \"%@\"", path] UTF8String]);

                    snprintf(buffer, sizeof buffer, "HTTP/1.0 200 OK\r\n\r\n");
                    write(client, buffer, strlen(buffer));
                }

                close(client);
            }
        }
        else
            [NSThread sleepForTimeInterval:.5];
    }
    return 0;
}


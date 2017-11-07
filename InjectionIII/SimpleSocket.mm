//
//  SimpleSocket.mm
//  signer
//
//  Created by John Holdsworth on 06/11/2017.
//  Copyright © 2017 John Holdsworth. All rights reserved.
//

#import "SimpleSocket.h"

#include <sys/socket.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>

@implementation SimpleSocket

+ (int)error:(NSString *)message {
    NSLog(message, strerror(errno));
    return -1;
}

+ (void)startServer:(NSString *)address {
    [self performSelectorInBackground:@selector(runServer:) withObject:address];
}

+ (void)runServer:(NSString *)address {
    struct sockaddr_in serverAddr;
    [self parseV4Address:address into:&serverAddr];

    int serverSocket = [self newSocket:serverAddr.sin_family];
    if (serverSocket < 0)
        return;

    if (bind(serverSocket, (struct sockaddr *)&serverAddr, sizeof serverAddr) < 0)
        [self error:@"Could not bind service socket: %s"];
    else if (listen(serverSocket, 5) < 0)
        [self error:@"Service socket would not listen: %s"];
    else while (TRUE) {
        struct sockaddr_in clientAddr;
        socklen_t addrLen = sizeof clientAddr;

        int clientSocket = accept(serverSocket, (struct sockaddr *)&clientAddr, &addrLen);
        if (clientSocket > 0) {
            @autoreleasepool {
                NSLog(@"Connection from %s:%d\n",
                      inet_ntoa(clientAddr.sin_addr), ntohs(clientAddr.sin_port));
                [[[self alloc] initSocket:clientSocket] run];
            }
        }
        else
            [NSThread sleepForTimeInterval:.5];
    }
}

+ (instancetype)connectTo:(NSString *)address {
    struct sockaddr_in serverAddr;
    [self parseV4Address:address into:&serverAddr];

    int clientSocket = [self newSocket:serverAddr.sin_family];
    if (clientSocket < 0)
        return nil;

    if (connect(clientSocket, (struct sockaddr *)&serverAddr, sizeof serverAddr) >= 0)
        return [[self alloc] initSocket:clientSocket];

    [self error:@"Counld not connect: %s"];
    return nil;
}

+ (int)newSocket:(sa_family_t)family {
    int optval = 1, newSocket;
    if ((newSocket = socket(family, SOCK_STREAM, 0)) < 0)
        [self error:@"Could not open service socket: %s"];
    else if (setsockopt(newSocket, SOL_SOCKET, SO_REUSEADDR, &optval, sizeof optval) < 0)
        [self error:@"Could not set socket option: %s"];
    else if (setsockopt(newSocket, SOL_SOCKET, SO_NOSIGPIPE, (void *)&optval, sizeof(optval)) < 0)
        [self error:@"Could not set socket option: %s"];
    else if (setsockopt(newSocket, IPPROTO_TCP, TCP_NODELAY, (void *)&optval, sizeof(optval)) < 0)
        [self error:@"Could not set socket option: %s"];
    else
        return newSocket;
    return -1;
}

+ (void)parseV4Address:(NSString *)address into:(struct sockaddr_in *)serverAddr {
    NSArray<NSString *> *parts = [address componentsSeparatedByString:@":"];
    NSString *host = parts[0], *port = parts[1];

    bzero(serverAddr, sizeof *serverAddr);
    serverAddr->sin_family = AF_INET;
    serverAddr->sin_addr.s_addr = host.length ? inet_addr(host.UTF8String) : htonl(INADDR_LOOPBACK);
    serverAddr->sin_port = htons(port.intValue);
}

- (instancetype)initSocket:(int)socket {
    if ( (self = [super init]) ) {
        clientSocket = socket;
    }
    return self;
}

- (void)run {
    [self performSelectorInBackground:@selector(runInBackground) withObject:nil];
 }

- (void)runInBackground {
    [[self class] error:@"-[Networking run] not implemented in subclass"];
}

- (NSString *)readString {
    int length;
    if (read(clientSocket, &length, sizeof length) != sizeof length)
        return nil;
    char utf8[length];
    if (read(clientSocket, utf8, length) != length)
        return nil;
    return [NSString stringWithUTF8String:utf8];
}

- (BOOL)writeString:(NSString *)string {
    const char *utf8 = string.UTF8String;
    int length = (int)strlen(utf8) + 1;
    if (write(clientSocket, &length, sizeof length) != sizeof length)
        return NO;
    if (write(clientSocket, utf8, length) != length)
        return NO;
    return YES;
}

- (void)dealloc {
    close(clientSocket);
}

@end

//
//  SimpleSocket.mm
//  InjectionIII
//
//  Created by John Holdsworth on 06/11/2017.
//  Copyright © 2017 John Holdsworth. All rights reserved.
//

#import "SimpleSocket.h"

#include <sys/socket.h>
#include <netinet/tcp.h>
#include <netdb.h>

@implementation SimpleSocket

+ (int)error:(NSString *)message {
    NSLog(message, strerror(errno));
    return -1;
}

+ (void)startServer:(NSString *)address {
    [self performSelectorInBackground:@selector(runServer:) withObject:address];
}

+ (void)runServer:(NSString *)address {
    struct sockaddr_storage serverAddr;
    [self parseV4Address:address into:&serverAddr];

    int serverSocket = [self newSocket:serverAddr.ss_family];
    if (serverSocket < 0)
        return;

    if (bind(serverSocket, (struct sockaddr *)&serverAddr, serverAddr.ss_len) < 0)
        [self error:@"Could not bind service socket: %s"];
    else if (listen(serverSocket, 5) < 0)
        [self error:@"Service socket would not listen: %s"];
    else while (TRUE) {
        struct sockaddr_storage clientAddr;
        socklen_t addrLen = sizeof clientAddr;

        int clientSocket = accept(serverSocket, (struct sockaddr *)&clientAddr, &addrLen);
        if (clientSocket > 0) {
            @autoreleasepool {
                struct sockaddr_in *v4Addr = (struct sockaddr_in *)&clientAddr;
                NSLog(@"Connection from %s:%d\n",
                      inet_ntoa(v4Addr->sin_addr), ntohs(v4Addr->sin_port));
                [[[self alloc] initSocket:clientSocket] run];
            }
        }
        else
            [NSThread sleepForTimeInterval:.5];
    }
}

+ (instancetype)connectTo:(NSString *)address {
    struct sockaddr_storage serverAddr;
    [self parseV4Address:address into:&serverAddr];

    int clientSocket = [self newSocket:serverAddr.ss_family];
    if (clientSocket < 0)
        return nil;

    if (connect(clientSocket, (struct sockaddr *)&serverAddr, serverAddr.ss_len) < 0) {
        [self error:@"Could not connect: %s"];
        return nil;
    }

    return [[self alloc] initSocket:clientSocket];
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

+ (BOOL)parseV4Address:(NSString *)address into:(struct sockaddr_storage *)serverAddr {
    NSArray<NSString *> *parts = [address componentsSeparatedByString:@":"];

    struct sockaddr_in *v4Addr = (struct sockaddr_in *)serverAddr;
    bzero(v4Addr, sizeof *v4Addr);

    v4Addr->sin_family = AF_INET;
    v4Addr->sin_len = sizeof *v4Addr;
    v4Addr->sin_port = htons(parts[1].intValue);

    const char *host = parts[0].UTF8String;

    if (!host[0])
        v4Addr->sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    else if (host[0] == '*')
        v4Addr->sin_addr.s_addr = htonl(INADDR_ANY);
    else if (isdigit(host[0]))
        v4Addr->sin_addr.s_addr = inet_addr(host);
    else if (struct hostent *hp = gethostbyname2(host, v4Addr->sin_family))
        memcpy((void *)&v4Addr->sin_addr, hp->h_addr, hp->h_length);
    else {
        [self error:[NSString stringWithFormat:@"Unable to look up host for %@", address]];
        return FALSE;
    }

    return TRUE;
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

//
//  SimpleSocket.h
//  InjectionIII
//
//  Created by John Holdsworth on 06/11/2017.
//  Copyright © 2017 John Holdsworth. All rights reserved.
//

#import <Foundation/Foundation.h>

#include <arpa/inet.h>

@interface SimpleSocket : NSObject {
@protected
    int clientSocket;
}

+ (void)startServer:(NSString *_Nonnull)address;
+ (void)runServer:(NSString *_Nonnull)address;

+ (instancetype _Nullable)connectTo:(NSString *_Nonnull)address;
+ (BOOL)parseV4Address:(NSString *_Nonnull)address into:(struct sockaddr_storage *_Nonnull)serverAddr;

- (instancetype _Nonnull)initSocket:(int)socket;

- (void)run;
- (void)runInBackground;

- (int)readInt;
- (NSString *_Nullable)readString;
- (BOOL)writeString:(NSString *_Nonnull)string;
- (BOOL)writeCommand:(int)command withString:(NSString *_Nullable)string;

@end


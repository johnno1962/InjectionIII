//
//  SimpleSocket.h
//  signer
//
//  Created by John Holdsworth on 06/11/2017.
//  Copyright © 2017 John Holdsworth. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SimpleSocket : NSObject {
@protected
    int clientSocket;
}

+ (void)startServer:(NSString * _Nonnull)address;
+ (void)runServer:(NSString * _Nonnull)address;

+ (instancetype _Nonnull)connectTo:(NSString * _Nonnull)address;

- (void)run;
- (void)runInBackground;

- (NSString * _Nonnull)readString;
- (BOOL)writeString:(NSString * _Nonnull)string;

@end

